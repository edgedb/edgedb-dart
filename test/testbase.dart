import 'dart:convert';
import 'dart:io';

import 'package:edgedb/edgedb.dart';

Client getClient([ConnectConfig? opts]) {
  return createClient(config: _getOpts());
}

ConnectConfig _getOpts() {
  try {
    final config =
        jsonDecode(Platform.environment['_DART_EDGEDB_CONNECT_CONFIG'] ?? '');
    return ConnectConfig.fromJson(config);
  } catch (e) {
    throw Exception('test environment is not initialised');
  }
}
