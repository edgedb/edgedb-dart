import 'dart:io';

Map<String, String> _env = Platform.environment;

String? getEnvVar(String name) {
  return _env[name];
}

void setEnvOverrides(Map<String, String> overrides) {
  _env = overrides;
}

void clearEnvOverrides() {
  _env = Platform.environment;
}
