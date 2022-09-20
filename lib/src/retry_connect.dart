import 'dart:math';

import 'base_proto.dart';
import 'codecs/registry.dart';
import 'connect_config.dart';
import 'errors/errors.dart';

Future<Connection> retryingConnect<Connection extends BaseProtocol>(
    CreateConnection<Connection> createConnection,
    ResolvedConnectConfig config,
    CodecsRegistry registry,
    {required bool logAttempts}) async {
  final waitMilliseconds = config.waitUntilAvailable;
  final timeout = Stopwatch()..start();
  int? lastLoggingAt;

  while (true) {
    try {
      return await createConnection(
        config: config,
        registry: registry,
      );
    } on ClientConnectionError catch (e) {
      if (logAttempts && lastLoggingAt == null) {
        print(
            'Connection attempt failed with the following config:\n${config.explainConfig()}');
      }
      if (timeout.elapsedMilliseconds < waitMilliseconds &&
          e.hasTag(EdgeDBErrorTag.shouldReconnect)) {
        if (logAttempts &&
            (lastLoggingAt == null ||
                timeout.elapsedMilliseconds - lastLoggingAt > 10000)) {
          lastLoggingAt = timeout.elapsedMilliseconds;

          print('Attempting reconnection for the next '
              '${((waitMilliseconds - timeout.elapsedMilliseconds) / 1000).round()}s, '
              'due to waitUntilAvailable=${waitMilliseconds}ms');
        }

        await Future.delayed(
            Duration(milliseconds: 10 + Random().nextInt(200)));
      } else {
        rethrow;
      }
    }
  }
}
