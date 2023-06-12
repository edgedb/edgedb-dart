import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:edgedb/src/utils/crc_hqx.dart';
import 'package:path/path.dart';

import 'credentials.dart';
import 'errors/errors.dart';
import 'platform.dart';
import 'utils/env.dart';
import 'utils/parse_duration.dart';

const domainNameMaxLen = 63;

class Address {
  String host;
  int port;

  Address(this.host, this.port);
}

enum TLSSecurity {
  insecure('insecure'),
  noHostVerification('no_host_verification'),
  strict('strict'),
  defaultSecurity('default');

  final String value;
  const TLSSecurity(this.value);

  String toJson() {
    return value;
  }
}

final tlsSecurityValues = {
  for (var type in TLSSecurity.values) type.value: type
};

class ConnectConfig {
  String? dsn;
  String? instanceName;
  String? credentials;
  String? credentialsFile;
  String? host;
  int? port;
  String? database;
  String? user;
  String? password;
  String? secretKey;
  Map<String, String>? serverSettings;
  String? tlsCA;
  String? tlsCAFile;
  TLSSecurity? tlsSecurity;
  Duration? waitUntilAvailable;

  ConnectConfig(
      {this.dsn,
      this.instanceName,
      this.credentials,
      this.credentialsFile,
      this.host,
      this.port,
      this.database,
      this.user,
      this.password,
      this.secretKey,
      this.serverSettings,
      this.tlsCA,
      this.tlsCAFile,
      this.tlsSecurity,
      this.waitUntilAvailable});

  ConnectConfig.fromJson(Map<String, dynamic> json)
      : dsn = json['dsn'],
        instanceName = json['instanceName'],
        credentials = json['credentials'],
        credentialsFile = json['credentialsFile'],
        host = json['host'],
        port = json['port'],
        database = json['database'],
        user = json['user'],
        password = json['password'],
        secretKey = json['secretKey'],
        serverSettings = json['serverSettings'] != null
            ? Map.castFrom(json['serverSettings'])
            : null,
        tlsCA = json['tlsCA'],
        tlsCAFile = json['tlsCAFile'],
        tlsSecurity = json['tlsSecurity'] != null
            ? tlsSecurityValues[json['tlsSecurity']] ??
                (throw InterfaceError(
                    "invalid tlsSecurity value: '${json['tlsSecurity']}'"))
            : null,
        waitUntilAvailable = json['waitUntilAvailable'] != null
            ? Duration(milliseconds: json['waitUntilAvailable'])
            : null;

  Map<String, dynamic> toJson() {
    return {
      'dsn': dsn,
      'instanceName': instanceName,
      'credentials': credentials,
      'credentialsFile': credentialsFile,
      'host': host,
      'port': port,
      'database': database,
      'user': user,
      'password': password,
      'secretKey': secretKey,
      'serverSettings': serverSettings,
      'tlsCA': tlsCA,
      'tlsCAFile': tlsCAFile,
      'tlsSecurity': tlsSecurity,
      'waitUntilAvailable': waitUntilAvailable?.inMilliseconds,
    };
  }
}

class SourcedValue<T> {
  T value;
  String source;

  SourcedValue(this.value, this.source);

  SourcedValue.from(SourcedValue val)
      : value = val.value as T,
        source = val.source;
}

TLSSecurity? debugGetRawTlsSecurity(ResolvedConnectConfig config) {
  return config._tlsSecurity?.value;
}

String? debugGetRawCAData(ResolvedConnectConfig config) {
  return config._tlsCAData?.value;
}

class ResolvedConnectConfig {
  SourcedValue<String>? _host;
  SourcedValue<int>? _port;
  SourcedValue<String>? _database;
  SourcedValue<String>? _user;
  SourcedValue<String>? _password;
  SourcedValue<String>? _secretKey;
  SourcedValue<String>? _cloudProfile;
  SourcedValue<String>? _tlsCAData;
  SourcedValue<TLSSecurity>? _tlsSecurity;
  SourcedValue<int>? _waitUntilAvailable;
  Map<String, String> serverSettings = {};

  void setHost(SourcedValue<String?> host) {
    if (_host == null && host.value != null) {
      validateHost(host.value!);
      _host = SourcedValue.from(host);
    }
  }

  void setPort(SourcedValue<dynamic> port) {
    if (_port == null && port.value != null) {
      _port = SourcedValue(parseValidatePort(port.value), port.source);
    }
  }

  void setDatabase(SourcedValue<String?> db) {
    if (_database == null && db.value != null) {
      if (db.value == '') {
        throw InterfaceError("invalid database name: '${db.value}'");
      }
      _database = SourcedValue.from(db);
    }
  }

  void setUser(SourcedValue<String?> user) {
    if (_user == null && user.value != null) {
      if (user.value == '') {
        throw InterfaceError("invalid username: '${user.value}'");
      }
      _user = SourcedValue.from(user);
    }
  }

  void setPassword(SourcedValue<String?> password) {
    if (_password == null && password.value != null) {
      _password = SourcedValue.from(password);
    }
  }

  void setSecretKey(SourcedValue<String?> secretKey) {
    if (_secretKey == null && secretKey.value != null) {
      _secretKey = SourcedValue.from(secretKey);
    }
  }

  void setCloudProfile(SourcedValue<String?> cloudProfile) {
    if (_cloudProfile == null && cloudProfile.value != null) {
      _cloudProfile = SourcedValue.from(cloudProfile);
    }
  }

  void setTlsCAData(SourcedValue<String?> caData) {
    if (_tlsCAData == null && caData.value != null) {
      _tlsCAData = SourcedValue.from(caData);
    }
  }

  Future<void> setTlsCAFile(SourcedValue<String?> caFile) async {
    if (_tlsCAData == null && caFile.value != null) {
      try {
        _tlsCAData = SourcedValue(
            await File(caFile.value!).readAsString(), caFile.source);
      } on FileSystemException catch (e) {
        throw InterfaceError(
            "cannot open file '${caFile.value}' specified by '${caFile.source}' ($e)");
      }
    }
  }

  void setTlsSecurity(SourcedValue<dynamic> tlsSecurity) {
    if (_tlsSecurity == null && tlsSecurity.value != null) {
      TLSSecurity tlsSec;
      if (tlsSecurity.value is TLSSecurity) {
        tlsSec = tlsSecurity.value;
      } else if (tlsSecurity.value is String) {
        if (!tlsSecurityValues.containsKey(tlsSecurity.value)) {
          throw InterfaceError(
              "invalid 'tlsSecurity' value: ${tlsSecurity.value}, must be one "
              "of ${tlsSecurityValues.keys.map((k) => "'$k'").join(', ')}");
        }
        tlsSec = tlsSecurityValues[tlsSecurity.value]!;
      } else {
        throw InterfaceError(
            'invalid tlsSecurity value, must be of type TLSSecurity');
      }
      final origTlsSec = tlsSec;
      final clientSecurity = getEnvVar('EDGEDB_CLIENT_SECURITY');
      if (clientSecurity != null) {
        if (!{'default', 'insecure_dev_mode', 'strict'}
            .contains(clientSecurity)) {
          throw InterfaceError(
              "invalid EDGEDB_CLIENT_SECURITY value: '$clientSecurity', "
              "must be one of 'default', 'insecure_dev_mode' or 'strict'");
        }
        if (clientSecurity == 'insecure_dev_mode') {
          if (tlsSec == TLSSecurity.defaultSecurity) {
            tlsSec = TLSSecurity.insecure;
          }
        } else if (clientSecurity == 'strict') {
          if (tlsSec == TLSSecurity.insecure ||
              tlsSec == TLSSecurity.noHostVerification) {
            throw InterfaceError(
                "'tlsSecurity' value (${tlsSec.value}) conflicts with "
                "EDGEDB_CLIENT_SECURITY value ($clientSecurity), "
                "'tlsSecurity' value cannot be lower than security level "
                "set by EDGEDB_CLIENT_SECURITY");
          }
          tlsSec = TLSSecurity.strict;
        }
      }
      _tlsSecurity = SourcedValue(
          tlsSec,
          '${tlsSecurity.source}'
          '${tlsSec != origTlsSec ? " (modified from '${origTlsSec.value}' "
              "by EDGEDB_CLIENT_SECURITY env var)" : ''}');
    }
  }

  void setWaitUntilAvailable(SourcedValue<dynamic> duration) {
    if (_waitUntilAvailable == null && duration.value != null) {
      _waitUntilAvailable =
          SourcedValue(parseDuration(duration.value), duration.source);
    }
  }

  void addServerSettings(Map<String, String> settings) {
    for (var entry in settings.entries) {
      serverSettings[entry.key] ??= entry.value;
    }
  }

  Address get address {
    return Address(_host?.value ?? 'localhost', _port?.value ?? 5656);
  }

  String get database {
    return _database?.value ?? 'edgedb';
  }

  String get user {
    return _user?.value ?? 'edgedb';
  }

  String? get password {
    return _password?.value;
  }

  String? get secretKey {
    return _secretKey?.value;
  }

  String? get cloudProfile {
    return _cloudProfile?.value ?? 'default';
  }

  TLSSecurity get tlsSecurity {
    return _tlsSecurity != null &&
            _tlsSecurity!.value != TLSSecurity.defaultSecurity
        ? _tlsSecurity!.value
        : _tlsCAData != null
            ? TLSSecurity.noHostVerification
            : TLSSecurity.strict;
  }

  SecurityContext? _tlsOptions;
  SecurityContext get tlsOptions {
    if (_tlsOptions != null) {
      return _tlsOptions!;
    }

    final context = SecurityContext(withTrustedRoots: _tlsCAData == null);
    _tlsOptions = context;

    context.setAlpnProtocols(['edgedb-binary'], false);

    if (_tlsCAData != null) {
      context.setTrustedCertificatesBytes(utf8.encode(_tlsCAData!.value));
    }

    return context;
  }

  bool verifyCert(X509Certificate cert) {
    // We need to be able to both completely override the cert validity check
    // for 'insecure' mode, and check a cert is valid with the exception
    // of the server hostname for 'no_host_verification' mode.
    // The 'SecureSocket' api has a single 'onBadCertificate' handler, which
    // only provides the cert without the reason it's considered 'bad'. Since
    // there seems to be no way to otherwise manually validate the cert, in
    // 'no_host_verification' mode, we just assume the cert is valid (ignoring
    // for the hostname), if the cert's pem data matches the 'tlsCAData' value.
    return (tlsSecurity == TLSSecurity.insecure ||
        (tlsSecurity == TLSSecurity.noHostVerification &&
            _tlsCAData != null &&
            cert.pem == _tlsCAData!.value));
  }

  int get waitUntilAvailable {
    return _waitUntilAvailable?.value ?? 30000;
  }

  String explainConfig() {
    final output = [
      'Parameter     Value                                     Source',
      '---------     -----                                     ------',
    ];

    outputLine(String param, dynamic val, SourcedValue? rawVal) {
      final isDefault = rawVal == null;
      final maxValLength = 40 - (isDefault ? 10 : 0);
      var value = val.toString();
      if (value.length > maxValLength) {
        value = '${value.substring(0, maxValLength - 3)}...';
      }
      output.add(param.padRight(14, " ") +
          (value + (isDefault ? " (default)" : "")).padRight(42, " ") +
          (rawVal?.source ?? 'default'));
    }

    outputLine("host", address.host, _host);
    outputLine("port", address.port, _port);
    outputLine(
      "database",
      database,
      _database,
    );
    outputLine(
      "user",
      user,
      _user,
    );
    outputLine(
      "password",
      password
          ?.substring(0, (password!.length - 3).clamp(0, 3))
          .padRight(password!.length, "*"),
      _password,
    );
    outputLine(
      "tlsCAData",
      _tlsCAData?.value.replaceAll(RegExp(r'\r\n?|\n'), ""),
      _tlsCAData,
    );
    outputLine(
      "tlsSecurity",
      tlsSecurity,
      _tlsSecurity,
    );

    return output.join("\n");
  }
}

Future<String> getStashPath(String projectDir) async {
  var projectPath = await Directory(projectDir).resolveSymbolicLinks();
  if (Platform.isWindows && !projectPath.startsWith('\\\\')) {
    projectPath = '\\\\?\\$projectPath';
  }

  final hash = sha1.convert(utf8.encode(projectPath)).toString();
  final baseName = basename(projectPath);
  final dirName = '$baseName-$hash';

  return join('projects', dirName);
}

final Map<String, String?> projectDirCache = {};

Future<String?> findProjectDir() async {
  final workingDir = Directory.current;

  if (projectDirCache.containsKey(workingDir.path)) {
    return projectDirCache[workingDir.path];
  }

  var dir = workingDir;
  // TODO: stop searching at device boundary
  while (true) {
    if (await File(join(dir.path, 'edgedb.toml')).exists()) {
      projectDirCache[workingDir.path] = dir.path;
      return dir.path;
    }
    final parentDir = dir.parent;
    if (parentDir.path == dir.path) {
      projectDirCache[workingDir.path] = null;
      return null;
    }
    dir = parentDir;
  }
}

int parseValidatePort(dynamic port) {
  int parsedPort;
  if (port is String) {
    try {
      parsedPort = int.parse(port, radix: 10);
    } catch (e) {
      throw InterfaceError('invalid port: $port');
    }
  } else if (port is int) {
    parsedPort = port;
  } else {
    throw InterfaceError('invalid port: $port');
  }
  if (parsedPort < 1 || parsedPort > 65535) {
    throw InterfaceError('invalid port: $port');
  }
  return parsedPort;
}

String validateHost(String host) {
  if (host.contains('/')) {
    throw InterfaceError('unix socket paths not supported');
  }
  if (host.isEmpty || host.contains(',')) {
    throw InterfaceError("invalid host: '$host'");
  }
  return host;
}

int parseDuration(dynamic rawDuration) {
  int duration;
  if (rawDuration is int) {
    duration = rawDuration;
  } else if (rawDuration is Duration) {
    duration = rawDuration.inMilliseconds;
  } else if (rawDuration is String) {
    duration = (rawDuration.startsWith('P')
            ? parseISODurationString(rawDuration)
            : parseHumanDurationString(rawDuration))
        .inMilliseconds;
  } else {
    throw InterfaceError('invalid duration, expected int or Duration');
  }
  if (duration < 0) {
    throw InterfaceError('invalid waitUntilAvailable duration, must be >= 0');
  }
  return duration;
}

Future<ResolvedConnectConfig> parseConnectConfig(ConnectConfig config) async {
  final resolvedConfig = ResolvedConnectConfig();

  SourcedValue<String?>? sourcedDsn;
  SourcedValue<String?>? sourcedInstance;
  if (config.instanceName == null &&
      config.dsn != null &&
      !RegExp(r'^[a-z]+:\/\/', caseSensitive: true).hasMatch(config.dsn!)) {
    sourcedInstance =
        SourcedValue(config.dsn, "'dsn' option (parsed as instance name)");
    sourcedDsn = SourcedValue(null, "'dsn' option");
  } else {
    sourcedInstance =
        SourcedValue(config.instanceName, "'instanceName' option");
    sourcedDsn = SourcedValue(config.dsn, "'dsn' option");
  }

  var hasCompoundOptions = await resolveConfigOptions(
    resolvedConfig,
    "Cannot have more than one of the following connection options: "
    "'dsn', 'instanceName', 'credentials', 'credentialsFile' or 'host'/'port'",
    null,
    dsn: sourcedDsn,
    instanceName: sourcedInstance,
    credentials: SourcedValue(config.credentials, "'credentials' option"),
    credentialsFile:
        SourcedValue(config.credentialsFile, "'credentialsFile' option"),
    host: SourcedValue(config.host, "'host' option"),
    port: SourcedValue(config.port, "'port' option"),
    database: SourcedValue(config.database, "'database' option"),
    user: SourcedValue(config.user, "'user' option"),
    password: SourcedValue(config.password, "'password' option"),
    secretKey: SourcedValue(config.secretKey, "'secretKey' option"),
    tlsCA: SourcedValue(config.tlsCA, "'tlsCA' option"),
    tlsCAFile: SourcedValue(config.tlsCAFile, "'tlsCAFile' option"),
    tlsSecurity: SourcedValue(config.tlsSecurity, "'tlsSecurity' option"),
    serverSettings: config.serverSettings,
    waitUntilAvailable:
        SourcedValue(config.waitUntilAvailable, "'waitUntilAvailable' option"),
  );

  if (!hasCompoundOptions) {
    // resolve config from env vars

    var port = getEnvVar('EDGEDB_PORT');
    if (resolvedConfig._port == null &&
        port != null &&
        port.startsWith('tcp://')) {
      // EDGEDB_PORT is set by 'docker --link' so ignore and warn
      log('EDGEDB_PORT in \'tcp://host:port\' format, so will be ignored');
      port = null;
    }

    hasCompoundOptions = await resolveConfigOptions(
      resolvedConfig,
      "Cannot have more than one of the following connection environment variables: "
      "'EDGEDB_DSN', 'EDGEDB_INSTANCE', 'EDGEDB_CREDENTIALS', "
      "'EDGEDB_CREDENTIALS_FILE' or 'EDGEDB_HOST'",
      null,
      dsn: SourcedValue(
          getEnvVar('EDGEDB_DSN'), "'EDGEDB_DSN' environment variable"),
      instanceName: SourcedValue(getEnvVar('EDGEDB_INSTANCE'),
          "'EDGEDB_INSTANCE' environment variable"),
      credentials: SourcedValue(getEnvVar('EDGEDB_CREDENTIALS'),
          "'EDGEDB_CREDENTIALS' environment variable"),
      credentialsFile: SourcedValue(getEnvVar('EDGEDB_CREDENTIALS_FILE'),
          "'EDGEDB_CREDENTIALS_FILE' environment variable"),
      host: SourcedValue(
          getEnvVar('EDGEDB_HOST'), "'EDGEDB_HOST' environment variable"),
      port: SourcedValue(port, "'EDGEDB_PORT' environment variable"),
      database: SourcedValue(getEnvVar('EDGEDB_DATABASE'),
          "'EDGEDB_DATABASE' environment variable"),
      user: SourcedValue(
          getEnvVar('EDGEDB_USER'), "'EDGEDB_USER' environment variable"),
      password: SourcedValue(getEnvVar('EDGEDB_PASSWORD'),
          "'EDGEDB_PASSWORD' environment variable"),
      secretKey: SourcedValue(getEnvVar('EDGEDB_SECRET_KEY'),
          "'EDGEDB_SECRET_KEY' environment variable"),
      cloudProfile: SourcedValue(getEnvVar('EDGEDB_CLOUD_PROFILE'),
          "'EDGEDB_CLOUD_PROFILE' environment variable"),
      tlsCA: SourcedValue(
          getEnvVar('EDGEDB_TLS_CA'), "'EDGEDB_TLS_CA' environment variable"),
      tlsCAFile: SourcedValue(getEnvVar('EDGEDB_TLS_CA_FILE'),
          "'EDGEDB_TLS_CA_FILE' environment variable"),
      tlsSecurity: SourcedValue(getEnvVar('EDGEDB_CLIENT_TLS_SECURITY'),
          "'EDGEDB_CLIENT_TLS_SECURITY' environment variable"),
      waitUntilAvailable: SourcedValue(getEnvVar('EDGEDB_WAIT_UNTIL_AVAILABLE'),
          "'EDGEDB_WAIT_UNTIL_AVAILABLE' environment variable"),
    );
  }

  if (!hasCompoundOptions) {
    // resolve config from project
    final projectDir = await findProjectDir();
    if (projectDir == null) {
      throw ClientConnectionError(
          "no 'edgedb.toml' found and no connection options specified"
          " either via arguments to `connect()` API or via environment"
          " variables EDGEDB_HOST, EDGEDB_INSTANCE, EDGEDB_DSN, "
          "EDGEDB_CREDENTIALS or EDGEDB_CREDENTIALS_FILE");
    }
    final stashPath = await getStashPath(projectDir);
    final instancePath =
        await searchConfigDir(join(stashPath, 'instance-name'));
    final instName = (await readFileOrNull(instancePath))?.trim();

    if (instName != null) {
      final cloudProfile = (await readFileOrNull(
              await searchConfigDir(join(stashPath, 'cloud-profile'))))
          ?.trim();

      await resolveConfigOptions(resolvedConfig, '', stashPath,
          instanceName:
              SourcedValue(instName, "project linked instance ('$instName')"),
          cloudProfile: SourcedValue(
              cloudProfile, "project defined cloud instance('$cloudProfile')"));
    } else {
      throw ClientConnectionError(
          "Found 'edgedb.toml' but the project is not initialized. "
          "Run `edgedb project init`.");
    }
  }

  resolvedConfig
      .setTlsSecurity(SourcedValue(TLSSecurity.defaultSecurity, 'default'));

  return resolvedConfig;
}

Future<String?> readFileOrNull(String path) async {
  try {
    return await File(path).readAsString();
  } catch (e) {
    return null;
  }
}

Future<bool> resolveConfigOptions(ResolvedConnectConfig resolvedConfig,
    String compoundParamsError, String? stashPath,
    {SourcedValue<String?>? dsn,
    SourcedValue<String?>? instanceName,
    SourcedValue<String?>? credentials,
    SourcedValue<String?>? credentialsFile,
    SourcedValue<String?>? host,
    SourcedValue<dynamic>? port,
    SourcedValue<String?>? database,
    SourcedValue<String?>? user,
    SourcedValue<String?>? password,
    SourcedValue<String?>? secretKey,
    SourcedValue<String?>? cloudProfile,
    SourcedValue<String?>? tlsCA,
    SourcedValue<String?>? tlsCAFile,
    SourcedValue<dynamic>? tlsSecurity,
    Map<String, String>? serverSettings,
    SourcedValue<dynamic>? waitUntilAvailable}) async {
  if (tlsCA?.value != null && tlsCAFile?.value != null) {
    throw InterfaceError(
        'Cannot specify both ${tlsCA!.source} and ${tlsCAFile?.source}');
  }

  if (database != null) resolvedConfig.setDatabase(database);
  if (user != null) resolvedConfig.setUser(user);
  if (password != null) resolvedConfig.setPassword(password);
  if (secretKey != null) resolvedConfig.setSecretKey(secretKey);
  if (cloudProfile != null) resolvedConfig.setCloudProfile(cloudProfile);
  if (tlsCA != null) resolvedConfig.setTlsCAData(tlsCA);
  if (tlsCAFile != null) await resolvedConfig.setTlsCAFile(tlsCAFile);
  if (tlsSecurity != null) resolvedConfig.setTlsSecurity(tlsSecurity);
  if (waitUntilAvailable != null) {
    resolvedConfig.setWaitUntilAvailable(waitUntilAvailable);
  }
  if (serverSettings != null) resolvedConfig.addServerSettings(serverSettings);

  final compoundParamsCount = ({
    dsn?.value,
    instanceName?.value,
    credentials?.value,
    credentialsFile?.value,
    host?.value ?? port?.value
  }..remove(null))
      .length;

  if (compoundParamsCount > 1) {
    throw InterfaceError(compoundParamsError);
  }

  if (compoundParamsCount == 1) {
    if (dsn?.value != null || host?.value != null || port?.value != null) {
      SourcedValue<String> resolvedDsn;
      if (dsn?.value == null) {
        if (port?.value != null) {
          resolvedConfig.setPort(port!);
        }
        final validHost = host?.value != null ? validateHost(host!.value!) : '';
        resolvedDsn = SourcedValue(
            'edgedb://${validHost.contains(':') ? '[${Uri.encodeFull(validHost)}]' : validHost}',
            host?.value != null ? host!.source : port!.source);
      } else {
        resolvedDsn = SourcedValue.from(dsn!);
      }
      await parseDSNIntoConfig(resolvedConfig, resolvedDsn);
    } else {
      Credentials creds;
      String source;
      if (credentials?.value != null) {
        creds = validateCredentials(json.decode(credentials!.value!));
        source = credentials.source;
      } else {
        var credsFile = credentialsFile?.value;
        if (credsFile == null) {
          if (RegExp(r'^\w(-?\w)*$').hasMatch(instanceName!.value!)) {
            credsFile = await getCredentialsPath(instanceName.value!);
            source = instanceName.source;
          } else {
            if (!RegExp(
                    r'^([A-Za-z0-9](-?[A-Za-z0-9])*)/([A-Za-z0-9](-?[A-Za-z0-9])*)$')
                .hasMatch(instanceName.value!)) {
              throw InterfaceError(
                  "invalid DSN or instance name: '${instanceName.value}'");
            }
            await parseCloudInstanceNameIntoConfig(
                resolvedConfig, SourcedValue.from(instanceName), stashPath);
            return true;
          }
        } else {
          source = credentialsFile!.source;
        }
        creds = await readCredentialsFile(credsFile);
      }

      resolvedConfig.setHost(SourcedValue(creds.host, source));
      resolvedConfig.setPort(SourcedValue(creds.port, source));
      resolvedConfig.setDatabase(SourcedValue(creds.database, source));
      resolvedConfig.setUser(SourcedValue(creds.user, source));
      resolvedConfig.setPassword(SourcedValue(creds.password, source));
      resolvedConfig.setTlsCAData(SourcedValue(creds.tlsCAData, source));
      resolvedConfig.setTlsSecurity(SourcedValue(creds.tlsSecurity, source));
    }
    return true;
  }

  return false;
}

Future<void> parseDSNIntoConfig(
    ResolvedConnectConfig config, SourcedValue<String> dsnString) async {
  final parsed = Uri.tryParse(dsnString.value);
  if (parsed == null) {
    throw InterfaceError("invalid DSN or instance name: '${dsnString.value}'");
  }

  if (!parsed.isScheme('edgedb')) {
    throw InterfaceError(
        "invalid DSN: schema is expected to be 'edgedb', got '${parsed.scheme}'");
  }

  final searchParams = <String, String>{};
  for (var param in parsed.queryParametersAll.entries) {
    if (param.value.length > 1) {
      throw InterfaceError(
          "invalid DSN: duplicate query parameter '${param.key}'");
    }
    searchParams[param.key] = param.value.first;
  }

  Future<void> handleDSNPart(
      String paramName,
      dynamic value,
      dynamic currentValue,
      FutureOr<void> Function(SourcedValue<dynamic>) setter,
      [String Function(String)? formatter]) async {
    if (({
          value,
          searchParams[paramName],
          searchParams['${paramName}_env'],
          searchParams['${paramName}_file']
        }..remove(null))
            .length >
        1) {
      throw InterfaceError(
          "invalid DSN: more than one of ${value != null ? "'$paramName', " : ''}"
          "'?$paramName=', '?${paramName}_env=' or '?${paramName}_file=' "
          "was specified");
    }

    if (currentValue == null) {
      var param = value ?? searchParams[paramName];
      var paramSource = dsnString.source;
      if (param == null) {
        final env = searchParams['${paramName}_env'];
        if (env != null) {
          param = getEnvVar(env);
          if (param == null) {
            throw InterfaceError(
                "'${paramName}_env' environment variable '$env' doesn't exist");
          }
          paramSource += ' (${paramName}_env: $env)';
        }
      }
      if (param == null) {
        final file = searchParams['${paramName}_file'];
        if (file != null) {
          try {
            param = await File(file).readAsString();
          } on FileSystemException catch (e) {
            throw InterfaceError(
                "cannot open file '$file' specified by '${paramName}_file' ($e)");
          }
          paramSource += ' (${paramName}_file: $file)';
        }
      }

      if (param != null && formatter != null) {
        param = formatter(param);
      }

      await setter(SourcedValue(param, paramSource));
    }

    searchParams.remove(paramName);
    searchParams.remove('${paramName}_env');
    searchParams.remove('${paramName}_file');
  }

  await handleDSNPart(
      'host',
      parsed.host.isNotEmpty ? parsed.host.replaceAll('%25', '%') : null,
      config._host,
      (host) => config.setHost(SourcedValue.from(host)));

  await handleDSNPart('port', parsed.hasPort ? parsed.port : null, config._port,
      config.setPort);

  String stripLeadingSlash(String str) {
    return str.startsWith('/') ? str.substring(1) : str;
  }

  final strippedPath = stripLeadingSlash(parsed.path);
  await handleDSNPart(
      'database',
      strippedPath.isNotEmpty ? strippedPath : null,
      config._database,
      (db) => config.setDatabase(SourcedValue.from(db)),
      stripLeadingSlash);

  final auth = parsed.userInfo.split(':');
  await handleDSNPart('user', auth[0].isNotEmpty ? auth[0] : null, config._user,
      (user) => config.setUser(SourcedValue.from(user)));
  await handleDSNPart(
      'password',
      auth.length == 2 && auth[1].isNotEmpty ? auth[1] : null,
      config._password,
      (password) => config.setPassword(SourcedValue.from(password)));

  await handleDSNPart('secret_key', null, config._secretKey,
      (secretKey) => config.setSecretKey(SourcedValue.from(secretKey)));

  await handleDSNPart('tls_ca', null, config._tlsCAData,
      (caData) => config.setTlsCAData(SourcedValue.from(caData)));
  await handleDSNPart('tls_ca_file', null, config._tlsCAData,
      (caFile) => config.setTlsCAFile(SourcedValue.from(caFile)));

  await handleDSNPart(
      'tls_security', null, config._tlsSecurity, config.setTlsSecurity);

  await handleDSNPart('wait_until_available', null, config._waitUntilAvailable,
      config.setWaitUntilAvailable);

  config.addServerSettings(searchParams);
}

Future<void> parseCloudInstanceNameIntoConfig(ResolvedConnectConfig config,
    SourcedValue<String> cloudInstanceName, String? stashPath) async {
  final normalisedInstanceName = cloudInstanceName.value.toLowerCase();
  final instanceParts = normalisedInstanceName.split('/');
  final domainName = '${instanceParts[1]}--${instanceParts[0]}';
  if (domainName.length > domainNameMaxLen) {
    throw InterfaceError(
        'invalid instance name: cloud instance name length cannot '
        'exceed ${domainNameMaxLen - 1} characters: ${cloudInstanceName.value}');
  }

  String? secretKey = config.secretKey;
  if (secretKey == null) {
    try {
      final profile = config.cloudProfile;
      final profilePath =
          await searchConfigDir(join('cloud-credentials', '$profile.json'));
      final fileData = await File(profilePath).readAsString();

      secretKey = json.decode(fileData)['secret_key']!;

      config.setSecretKey(
          SourcedValue(secretKey, "cloud-credentials/$profile.json"));
    } catch (e) {
      throw InterfaceError(
          'Cannot connect to cloud instances without a secret key');
    }
  }

  try {
    final keyParts = secretKey!.split('.');
    if (keyParts.length < 2) {
      throw InterfaceError('Invalid secret key: does not contain payload');
    }
    final dnsZone = _jwtBase64Decode(keyParts[1])["iss"] as String;
    final dnsBucket = (crcHqx(utf8.encode(normalisedInstanceName), 0) % 100)
        .toString()
        .padLeft(2, '0');

    final host = "$domainName.c-$dnsBucket.i.$dnsZone";
    config.setHost(SourcedValue(
        host, "resolved from 'secretKey' and ${cloudInstanceName.source}"));
  } on EdgeDBError {
    rethrow;
  } catch (e) {
    throw InterfaceError('Invalid secret key: $e');
  }
}

dynamic _jwtBase64Decode(String payload) {
  return json.decode(utf8.decode(
      base64.decode(payload.padRight((payload.length ~/ 4 + 1) * 4, '='))));
}
