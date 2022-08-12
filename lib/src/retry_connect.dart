import 'dart:math';

import 'base_proto.dart';
import 'codecs/registry.dart';
import 'connect_config.dart';
import 'errors/errors.dart';

Future<Connection> retryingConnect<Connection extends BaseProtocol>(
    CreateConnection<Connection> createConnection,
    ResolvedConnectConfig config,
    CodecsRegistry registry) async {
  final waitMilliseconds = config.waitUntilAvailable;
  final timeout = Stopwatch()..start();
  while (true) {
    try {
      return await createConnection(config: config, registry: registry);
    } on ClientConnectionError catch (e) {
      if (timeout.elapsedMilliseconds < waitMilliseconds &&
          e.hasTag(EdgeDBErrorTag.shouldReconnect)) {
        print(e);
        await Future.delayed(
            Duration(milliseconds: 10 + Random().nextInt(200)));
        // if (
        //   config.logging &&
        //   (!lastLoggingAt || now - lastLoggingAt > 5000)
        // ) {
        //   lastLoggingAt = now;
        //   const logMsg = [
        //     `A client connection error occurred; reconnecting because ` +
        //       `of "waitUntilAvailable=${config.connectionParams.waitUntilAvailable}".`,
        //     e,
        //   ];

        //   if (config.inProject && !config.fromProject && !config.fromEnv) {
        //     logMsg.push(
        //       `\n\n\n` +
        //         `Hint: it looks like the program is running from a ` +
        //         `directory initialized with "edgedb project init". ` +
        //         `Consider calling "edgedb.connect()" without arguments.` +
        //         `\n`
        //     );
        //   }
        //   // tslint:disable-next-line: no-console
        //   console.warn(...logMsg);
        // }
      } else {
        rethrow;
      }
    }
  }
}
