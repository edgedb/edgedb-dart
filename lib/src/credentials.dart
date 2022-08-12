import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import 'connect_config.dart';
import 'errors/errors.dart';
import 'platform.dart';

class Credentials {
  String? host;
  int? port;
  String user;
  String? password;
  String? database;
  String? tlsCAData;
  TLSSecurity? tlsSecurity;

  Credentials(
      {this.host,
      this.port,
      required this.user,
      this.password,
      this.database,
      this.tlsCAData,
      this.tlsSecurity});
}

Future<String> getCredentialsPath(String instanceName) async {
  return searchConfigDir(join('credentials', '$instanceName.json'));
}

Future<Credentials> readCredentialsFile(String file) async {
  try {
    final data = await File(file).readAsString();
    return validateCredentials(json.decode(data));
  } catch (e) {
    throw InterfaceError('cannot read credentials file $file: $e');
  }
}

Credentials validateCredentials(dynamic data) {
  if (data is! Map) {
    throw InterfaceError('credentials expected to contain top level object');
  }

  final port = data['port'];
  if (port != null && (port is! int || port < 1 || port > 65535)) {
    throw InterfaceError("invalid 'port' value: $port");
  }

  final user = data['user'];
  if (user == null) {
    throw InterfaceError("'user' key is required");
  }
  if (user is! String) {
    throw InterfaceError("'user' must be a String");
  }

  final host = data['host'];
  if (host != null && host is! String) {
    throw InterfaceError("'host' must be a String");
  }

  final database = data['database'];
  if (database != null && database is! String) {
    throw InterfaceError("'database' must be a String");
  }

  final password = data['password'];
  if (password != null && password is! String) {
    throw InterfaceError("'password' must be a String");
  }

  var caData = data['tls_ca'];
  if (caData != null && caData is! String) {
    throw InterfaceError("'tls_ca' must be a String");
  }

  final certData = data['tls_cert_data'];
  if (certData != null) {
    if (certData is! String) {
      throw InterfaceError("'tls_cert_data' must be a String");
    }
    if (caData != null && certData != caData) {
      throw InterfaceError("both 'tls_ca' and 'tls_cert_data' are defined, "
          "and are not in agreement");
    }
    caData = certData;
  }

  var verifyHostname = data['tls_verify_hostname'];
  var tlsSecurity = data['tls_security'];
  if (verifyHostname != null) {
    if (verifyHostname is bool) {
      verifyHostname =
          verifyHostname ? TLSSecurity.strict : TLSSecurity.noHostVerification;
    } else {
      throw InterfaceError("'tls_verify_hostname' must be boolean");
    }
  }
  if (tlsSecurity != null) {
    if (tlsSecurity is String && tlsSecurityValues.containsKey(tlsSecurity)) {
      tlsSecurity = tlsSecurityValues[tlsSecurity];
    } else {
      throw InterfaceError("'tls_security' must be one of "
          "${tlsSecurityValues.keys.map((k) => "'$k'").join(', ')}");
    }
  }
  if (verifyHostname != null &&
      tlsSecurity != null &&
      verifyHostname != tlsSecurity &&
      !(verifyHostname == TLSSecurity.noHostVerification &&
          tlsSecurity == TLSSecurity.insecure)) {
    throw InterfaceError(
        "both 'tls_security' and 'tls_verify_hostname' are defined, "
        "and are not in agreement");
  }

  return Credentials(
      host: host,
      port: port,
      user: user,
      database: database,
      password: password,
      tlsCAData: caData,
      tlsSecurity: tlsSecurity ?? verifyHostname);
}
