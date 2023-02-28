import 'dart:convert';
import 'dart:io';

import 'package:edgedb/edgedb.dart';

Client getClient({int? concurrency, String? database}) {
  return createClient(
      config: getClientConfig(), concurrency: concurrency, database: database);
}

class ServerVersion {
  final int major;
  final int minor;

  const ServerVersion(this.major, [this.minor = 0]);

  bool operator >(ServerVersion other) {
    if (major == other.major) {
      return minor > other.minor;
    }
    return major > other.major;
  }

  bool operator <(ServerVersion other) {
    if (major == other.major) {
      return minor < other.minor;
    }
    return major < other.major;
  }

  @override
  bool operator ==(Object other) {
    return other is ServerVersion &&
        major == other.major &&
        minor == other.minor;
  }

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() {
    return '$major.$minor';
  }
}

ServerVersion getServerVersion() {
  final ver = jsonDecode(Platform.environment['_DART_EDGEDB_VERSION'] ?? '');
  return ServerVersion(ver[0], ver[1]);
}

ConnectConfig? _config;
ConnectConfig getClientConfig() {
  if (_config != null) {
    return _config!;
  }
  try {
    final config =
        jsonDecode(Platform.environment['_DART_EDGEDB_CONNECT_CONFIG'] ?? '');
    return _config = ConnectConfig.fromJson(config);
  } catch (e) {
    throw Exception('test environment is not initialised');
  }
}
