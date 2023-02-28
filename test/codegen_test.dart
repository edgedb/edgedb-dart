import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart';

import 'testbase.dart';

void main() {
  test('codegen',
      skip: getServerVersion() < ServerVersion(3, 0)
          ? 'codegen tests use tuple args, which are only supported in EdgeDB >= 3.0'
          : null,
      timeout: Timeout(Duration(minutes: 2)), () async {
    final config = getClientConfig();

    final env = {
      'EDGEDB_DSN': 'edgedb://${config.user}:${config.password}@'
          '${config.host}:${config.port}/codegen?'
          'tls_security=no_host_verification&tls_ca_file=${config.tlsCAFile}'
    };

    final res = await Process.run('dart', ['run', 'build_runner', 'build'],
        environment: env, workingDirectory: './test/codegen_tests');
    if (res.exitCode != 0) {
      throw Exception('Failed to run build_runner: ${res.stdout + res.stderr}');
    }

    final testFiles = await Directory('./test/codegen_tests/lib')
        .list()
        .where((file) => extension(file.path, 2) == '.dart')
        .toList();

    await Future.wait(testFiles.map((file) async {
      final res =
          await Process.run('dart', ['run', file.path], environment: env);
      if (res.exitCode != 0) {
        throw Exception(
            'Failed to run ${basename(file.path)}: ${res.stdout + res.stderr}');
      }
    }).toList());
  });
}
