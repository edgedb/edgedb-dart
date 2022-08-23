import 'dart:convert';
import 'dart:io';

import 'package:edgedb/edgedb.dart';

Client getClient({int? concurrency}) {
  return createClient(config: _getOpts(), concurrency: concurrency);
}

ConnectConfig? _config;
ConnectConfig _getOpts() {
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
