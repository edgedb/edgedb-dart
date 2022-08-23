import 'dart:io';

import 'package:path/path.dart';

import 'utils/env.dart';

String homeDir() {
  final homeDir = getEnvVar('HOME') ?? getEnvVar('USERPROFILE');
  if (homeDir != null) {
    return homeDir;
  }
  final homeDrive = getEnvVar('HOMEDRIVE'), homePath = getEnvVar('HOMEPATH');
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
            final localAppDataDir = getEnvVar('LOCALAPPDATA') ??
                join(homeDir(), 'AppData', 'Local');
            return join(localAppDataDir, 'EdgeDB', 'config');
          }
        : () {
            var xdgConfigDir = getEnvVar('XDG_CONFIG_HOME');
            if (xdgConfigDir == null || !Directory(xdgConfigDir).isAbsolute) {
              xdgConfigDir = join(homeDir(), '.config');
            }

            return join(xdgConfigDir, 'edgedb');
          });

Future<String> searchConfigDir(configPath) async {
  final filePath = join(_configDir(), configPath);

  if (await File(filePath).exists()) {
    return filePath;
  }

  final fallbackPath = join(homeDir(), '.edgedb', configPath);
  if (await File(fallbackPath).exists()) {
    return fallbackPath;
  }

  // None of the searched files exists, return the new path.
  return filePath;
}
