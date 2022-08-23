import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:edgedb/edgedb.dart';
import 'package:path/path.dart';

void main(List<String> testArgs) async {
  print('Starting EdgeDB test cluster...');

  final statusFile = await generateStatusFileName('dart');
  print('Dart status file: ${statusFile.path}');

  final args = getServerCommand(getWSLPath(statusFile.path));

  final server = await startServer(args, statusFile);

  print('EdgeDB test cluster is up [port: ${server.config.port}]...');

  final adminConn = await setupServer(server.config);

  final testProc = await Process.start('dart', [
    'test',
    if (Platform.environment['GITHUB_ACTIONS'] != 'true') '--reporter=expanded',
    ...testArgs
  ], environment: {
    '_DART_EDGEDB_CONNECT_CONFIG': jsonEncode(server.config)
  });

  testProc.stdout.listen((event) => stdout.add(event));
  testProc.stderr.listen((event) => stderr.add(event));

  exitCode = await testProc.exitCode;

  print('Shutting down EdgeDB test cluster...');

  try {
    await shutdown(server.process, adminConn);
  } finally {
    print('...EdgeDB test cluster is down');
  }

  File(statusFile.path).delete().ignore();
}

String generateTempId() {
  return Random().nextInt(999999999).toString();
}

Future<File> generateStatusFileName(String tag) async {
  final dir =
      Directory(join(Directory.systemTemp.path, 'edgedb-dart-status-file'));
  await dir.create(recursive: true);
  return File(join(dir.path, '$tag-${generateTempId()}'));
}

String getWSLPath(String wslPath) {
  return wslPath
      .replaceAllMapped(RegExp(r'^([a-z]):', caseSensitive: false),
          (match) => '/mnt/${match.group(1)}')
      .split("\\")
      .join("/")
      .toLowerCase();
}

List<String> getServerCommand(String statusFile) {
  var args = [Platform.environment['EDGEDB_SERVER_BIN'] ?? 'edgedb-server'];
  if (Platform.isWindows) {
    args = ['wsl', '-u', 'edgedb', ...args];
  }

  final help =
      Process.runSync(args[0], [...args.sublist(1), '--help']).stdout as String;

  if (help.contains('--tls-cert-mode')) {
    args.add('--tls-cert-mode=generate_self_signed');
  } else if (help.contains('--generate-self-signed-cert')) {
    args.add('--generate-self-signed-cert');
  }

  if (help.contains('--auto-shutdown-after')) {
    args.add('--auto-shutdown-after=0');
  } else {
    args.add('--auto-shutdown');
  }

  args.addAll([
    '--bind-address=127.0.0.1',
    '--bind-address=::1',
    '--temp-dir',
    '--testmode',
    '--port=auto',
    '--emit-server-status=$statusFile',
    '--security=strict',
    '--bootstrap-command=ALTER ROLE edgedb { SET password := "edgedbtest" }',
  ]);

  return args;
}

class ServerInst {
  Process process;
  ConnectConfig config;
  ServerInst(this.process, this.config);
}

Future<ServerInst> startServer(List<String> cmd, File statusFile) async {
  final proc = await Process.start(cmd[0], cmd.sublist(1));

  if (Platform.environment['EDGEDB_DEBUG_SERVER'] != null) {
    print('starting server: ${cmd.join(' ')}');
    proc.stdout.listen((event) => stdout.add(event));
    proc.stderr.listen((event) => stderr.add(event));
  } else {
    proc.stdout.drain();
    proc.stderr.drain();
  }

  final runtimeData = await Future.any([
    getServerInfo(statusFile),
    proc.exitCode.then((code) {
      throw Exception('server exited with code $code before status file ready');
    })
  ]);

  if (Platform.isWindows && runtimeData['tls_cert_file'] != null) {
    final tmpFile =
        join(Directory.systemTemp.path, 'edbtlscert-${generateTempId()}.pem');
    await Process.run('wsl', [
      '-u',
      'edgedb',
      'cp',
      runtimeData['tls_cert_file'],
      getWSLPath(tmpFile)
    ]);
    runtimeData['tls_cert_file'] = tmpFile;
  }

  final connectConfig = ConnectConfig(
      host: 'localhost',
      port: runtimeData['port'],
      user: 'edgedb',
      password: 'edgedbtest',
      database: 'edgedb',
      tlsSecurity: TLSSecurity.noHostVerification,
      tlsCAFile: runtimeData['tls_cert_file']);

  return ServerInst(proc, connectConfig);
}

Future<dynamic> getServerInfo(File statusFile) async {
  final events = statusFile.parent.watch(events: FileSystemEvent.create);
  await for (var event in events) {
    if (File(event.path).absolute.path == statusFile.absolute.path) {
      // server ready
      break;
    }
  }

  for (var line in await statusFile.readAsLines()) {
    if (line.startsWith('READY=')) {
      return jsonDecode(line.substring(6));
    }
  }

  throw Exception('no ready data found ${statusFile.path}');
}

Future<Client> setupServer(ConnectConfig config) async {
  final client = createClient(concurrency: 1, config: config);

  try {
    await client.execute('create database dart_test');
    await client.execute('''
      create superuser role dart_test {
        set password := 'darttest'
      };
    ''');
    await client.execute('''
      configure instance insert Auth {
        user := 'dart_test',
        priority := 10,
        method := (insert SCRAM),
      };
    ''');
  } catch (e) {
    await client.close();
    rethrow;
  }

  return client;
}

Future<void> shutdown(Process proc, Client adminConn) async {
  adminConn.close();

  final timeout = Timer(Duration(seconds: 30), () {
    proc.kill();
    print('!!! EdgeDB exit timeout... !!!');
  });

  final code = await proc.exitCode;

  timeout.cancel();

  if (code != 0) {
    print('EdgeDB server did not shutdown gracefully');
  }
}
