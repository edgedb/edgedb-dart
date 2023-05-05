import 'dart:convert';
import 'dart:io';

import 'base_proto.dart';
import 'codecs/registry.dart';
import 'connect_config.dart';
import 'errors/errors.dart';
import 'primitives/buffer.dart';
import 'primitives/message_types.dart';
import 'primitives/transport.dart';
import 'primitives/types.dart';
import 'scram.dart';
import 'utils/bytes_equal.dart';

enum AuthenticationStatus {
  authOK(0),
  authSASL(10),
  authSASLContinue(11),
  authSASLFinal(12);

  final int value;
  const AuthenticationStatus(this.value);
}

class TCPProtocol extends BaseProtocol {
  TCPProtocol({
    required super.transportCreator,
    required super.codecsRegistry,
  });

  static Future<TCPProtocol> create({
    required ResolvedConnectConfig config,
    required CodecsRegistry registry,
    Duration? timeout,
  }) async {
    final address = config.address;
    try {
      final sock = await SecureSocket.connect(address.host, address.port,
          onBadCertificate: config.verifyCert,
          context: config.tlsOptions,
          timeout: timeout);
      sock.setOption(SocketOption.tcpNoDelay, true);

      if (sock.selectedProtocol != 'edgedb-binary') {
        throw ClientConnectionFailedError(
            "The server doesn't support the edgedb-binary protocol.");
      }

      final conn = TCPProtocol(
        transportCreator: transportCreator(sock, sock),
        codecsRegistry: registry,
      );

      await conn._connectHandshake(
          database: config.database,
          user: config.user,
          password: config.password,
          secretKey: config.secretKey);

      return conn;
    } on SocketException catch (e) {
      switch (e.osError?.errorCode) {
        // case 71: // EPROTO
        case 111: // ECONNREFUSED
        case 103: // ECONNABORTED
        case 104: // ECONNRESET
        case -2: // ENOTFOUND (DNS name not found)
        case 2: // ENOENT (unix socket is not created yet)
          throw ClientConnectionFailedTemporarilyError(e.message, e);
        default:
          throw ClientConnectionFailedError(e.message, e);
      }
    }
  }

  @override
  Error onClose(ReadMessageBuffer? lastMessage) {
    final err = ClientConnectionClosedError(
        'the connection has been closed',
        lastMessage?.messageType == MessageType.ErrorResponse
            ? parseErrorMessage(lastMessage!)
            : null);
    abortWithError(err);
    return err;
  }

  @override
  Error onError(Object error) {
    final err = ClientConnectionClosedError('network error: $error', error);
    abortWithError(err);
    return err;
  }

  Future<void> _connectHandshake(
      {required String database,
      required String user,
      String? password,
      String? secretKey}) async {
    final handshake = WriteMessageBuffer(ClientMessageType.ClientHandshake)
      ..writeInt16(protoVer.hi)
      ..writeInt16(protoVer.lo);

    final params = {
      'user': user,
      'database': database,
    };
    if (secretKey != null) {
      params['secret_key'] = secretKey;
    }

    handshake.writeInt16(params.length);
    for (var param in params.entries) {
      handshake
        ..writeString(param.key)
        ..writeString(param.value);
    }
    handshake
      ..writeInt16(0)
      ..endMessage();

    transport.sendMessage(handshake);

    while (true) {
      final message = await transport.takeMessage();

      switch (message.messageType) {
        case MessageType.ServerHandshake:
          final hi = message.readInt16();
          final lo = message.readInt16();

          message
            ..ignoreHeaders()
            ..finishMessage();

          final proposed = ProtocolVersion(hi, lo);

          if (proposed > protoVer || minProtoVer > proposed) {
            throw ProtocolError('the server requested an unsupported version '
                'of the protocol $hi.$lo');
          }

          protocolVersion = proposed;
          break;
        case MessageType.Authentication:
          final status = message.readInt32();

          if (status == AuthenticationStatus.authOK.value) {
            message.finishMessage();
          } else if (status == AuthenticationStatus.authSASL.value) {
            await authSASL(
                message: message, username: user, password: password);
          } else {
            throw ProtocolError('unsupported authentication method requested '
                'by the server: $status');
          }
          break;
        case MessageType.ServerKeyData:
          serverSecret = message.readBytes(32);
          message.finishMessage();
          break;
        case MessageType.ErrorResponse:
          throw parseErrorMessage(message);
        case MessageType.ReadyForCommand:
          parseSyncMessage(message);

          connected = true;
          // print('connected');
          return;
        case MessageType.StateDataDescription:
          break;
        default:
          fallthrough(message);
      }
    }
  }

  Future<void> authSASL(
      {required ReadMessageBuffer message,
      required String username,
      String? password}) async {
    final numMethods = message.readInt32();
    if (numMethods <= 0) {
      throw ProtocolError(
          "the server requested SASL authentication but did not offer any methods");
    }

    final methods = [];
    var foundScram256 = false;
    for (var i = 0; i < numMethods; i++) {
      final method = utf8.decode(message.readLenPrefixedBytes());
      if (method == "SCRAM-SHA-256") {
        foundScram256 = true;
      }
      methods.add(method);
    }

    message.finishMessage();

    if (!foundScram256) {
      throw ProtocolError(
          'the server offered the following SASL authentication '
          'methods: ${methods.join(", ")}, none are supported.');
    }

    final clientNonce = generateNonce();
    final clientFirst = buildClientFirstMessage(clientNonce, username);

    final wb =
        WriteMessageBuffer(ClientMessageType.AuthenticationSASLInitialReponse)
          ..writeString("SCRAM-SHA-256")
          ..writeString(clientFirst[0])
          ..endMessage();
    transport.sendMessage(wb);

    message = await _ensureNextMessage(MessageType.Authentication);
    var status = message.readInt32();
    if (status != AuthenticationStatus.authSASLContinue.value) {
      throw ProtocolError(
          'expected SASLContinue from the server, received $status');
    }

    final serverFirst = message.readString();
    message.finishMessage();

    final serverFirstMessage = parseServerFirstMessage(serverFirst);

    final clientFinalMessage = buildClientFinalMessage(
        password ?? '',
        serverFirstMessage.salt,
        serverFirstMessage.iterCount,
        clientFirst[1],
        serverFirst,
        serverFirstMessage.nonce);

    final wb2 = WriteMessageBuffer(ClientMessageType.AuthenticationSASLResponse)
      ..writeString(clientFinalMessage.msg)
      ..endMessage();
    transport.sendMessage(wb2);

    message = await _ensureNextMessage(MessageType.Authentication);
    status = message.readInt32();
    if (status != AuthenticationStatus.authSASLFinal.value) {
      throw ProtocolError(
          'expected SASLFinal from the server, received $status');
    }

    final serverFinal = message.readString();
    message.finishMessage();

    final serverSig = parseServerFinalMessage(serverFinal);

    if (!serverSig.bytesEqual(clientFinalMessage.serverProof)) {
      throw ProtocolError("server SCRAM proof does not match");
    }
  }

  Future<ReadMessageBuffer> _ensureNextMessage(
      MessageType expectedMessageType) async {
    final message = await transport.takeMessage();

    if (message.messageType == MessageType.ErrorResponse) {
      throw parseErrorMessage(message);
    } else if (message.messageType == expectedMessageType) {
      return message;
    } else {
      throw UnexpectedMessageError(
          'expected ${expectedMessageType.name} from the server, received ${message.messageType.name}');
    }
  }
}
