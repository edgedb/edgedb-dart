import 'dart:io';

import 'package:path/path.dart';

String homeDir() {
  final homeDir =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (homeDir != null) {
    return homeDir;
  }
  final homeDrive = Platform.environment['HOMEDRIVE'],
      homePath = Platform.environment['HOMEPATH'];
  if (homeDrive != null && homePath != null) {
    return join(homeDrive, homePath);
  }
  throw UnsupportedError("Unable to determine home path on this system");
}

final _configDir = Platform.isMacOS
    ? () {
        return join(homeDir(), 'Library', 'Application Support', 'edgedb');
      }
    : (Platform.isWindows
        ? () {
            final localAppDataDir = Platform.environment['LOCALAPPDATA'] ??
                join(homeDir(), 'AppData', 'Local');
            return join(localAppDataDir, 'EdgeDB', 'config');
          }
        : () {
            var xdgConfigDir = Platform.environment['XDG_CONFIG_HOME'];
            if (xdgConfigDir == null || !Directory(xdgConfigDir).isAbsolute) {
              xdgConfigDir = join(homeDir(), '.config');
            }

            return join(xdgConfigDir, 'edgedb');
          });

Future<String> searchConfigDir(configPath) async {
  final filePath = join(_configDir(), configPath);

  if (await Directory(filePath).exists()) {
    return filePath;
  }

  final fallbackPath = join(homeDir(), '.edgedb', configPath);
  if (await Directory(fallbackPath).exists()) {
    return fallbackPath;
  }

  // None of the searched files exists, return the new path.
  return filePath;
}
