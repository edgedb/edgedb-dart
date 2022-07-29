import 'dart:convert' as convert;
import 'dart:io';
import 'dart:typed_data';

import 'package:edgedb/src/codecs/registry.dart';
import 'package:edgedb/src/errors.dart';
import 'package:edgedb/src/primitives/buffer.dart';
import 'package:edgedb/src/primitives/message_types.dart';
import 'package:edgedb/src/primitives/proto_version.dart';

import 'codecs/codecs.dart';

const protoVer = ProtocolVersion(1, 0);
const minProtoVer = ProtocolVersion(1, 0);

enum AuthenticationStatus {
  AuthOK(0),
  AuthSASL(10),
  AuthSASLContinue(11),
  AuthSASLFinal(12);

  final int value;
  const AuthenticationStatus(this.value);
}

enum IOFormat {
  Binary(0x62),
  Json(0x6a),
  JsonElements(0x4a);

  final int value;
  const IOFormat(this.value);
}

enum Cardinality {
  NoResult(0x6e),
  AtMostOne(0x6f),
  One(0x41),
  Many(0x6d),
  AtLeastOne(0x4d);

  final int value;
  const Cardinality(this.value);
}

final cardinalities = {for (var card in Cardinality.values) card.value: card};

class BinaryProtocol {
  Uint8List? serverSecret;
  ProtocolVersion protocolVersion = protoVer;

  late SecureSocket sock;
  late MessageTransport messages;

  final codecsRegistry = CodecsRegistry();

  Future<void> connect() async {
    sock = await SecureSocket.connect('localhost', 5656,
        onBadCertificate: (certificate) => true,
        supportedProtocols: ['edgedb-binary']);
    print(sock);
    print(sock.selectedProtocol);

    messages = MessageTransport(sock);

    final handshake = WriteMessageBuffer(MessageType.ClientHandshake)
      ..writeInt16(protoVer.hi)
      ..writeInt16(protoVer.lo)
      ..writeInt16(2)
      ..writeString('user')
      ..writeString('edgedb')
      ..writeString('database')
      ..writeString('edgedb')
      ..writeInt16(0)
      ..endMessage();

    sock.add(handshake.unwrap());
    print('sent message: ${MessageType.ClientHandshake.name}');

    // await for (var message in messages!) {
    //   final bytesStr = message.buffer.buffer
    //       .asUint8List(
    //           message.buffer.offsetInBytes, message.buffer.lengthInBytes)
    //       .toString();
    //   print('${message.messageType.name}: $bytesStr');
    // }

    while (true) {
      final message = await messages.takeMessage();

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
        case MessageType.AuthenticationOK:
          final status = message.readInt32();

          if (status == AuthenticationStatus.AuthOK.value) {
            message.finishMessage();
          } else if (status == AuthenticationStatus.AuthSASL.value) {
            await authSASL();
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

          print('connected');
          return;
        default:
          _fallthrough(message);
      }
    }
  }

  Future<void> authSASL() {
    throw UnimplementedError('authSASL not implemented');
  }

  void parseSyncMessage(ReadMessageBuffer message) {}

  void _fallthrough(ReadMessageBuffer message) {
    if (message.messageType == MessageType.ParameterStatus) {
      return;
    }

    throw ProtocolError('unexpected "${message.messageType.name}" message '
        '("${convert.ascii.decode([message.messageType.value])}")');
  }

  Error parseErrorMessage(ReadMessageBuffer message) {
    throw UnimplementedError('parseErrorMessage not implemented');
  }

  Future<dynamic> fetch(
      {required String query,
      dynamic args,
      required bool asJson,
      required bool expectOne,
      bool? requiredOne}) async {
    // this._checkState();

    // const key = this._getQueryCacheKey(query, asJson, expectOne);
    // const ret = new Array();
    final ret = [];

    // if (this.queryCodecCache.has(key)) {
    //   const [card, inCodec, outCodec] = this.queryCodecCache.get(key)!;
    //   this._validateFetchCardinality(card, asJson, requiredOne);
    //   await this._optimisticExecuteFlow(
    //     args,
    //     asJson,
    //     expectOne,
    //     requiredOne,
    //     inCodec,
    //     outCodec,
    //     query,
    //     ret
    //   );
    // } else {

    final parseResult = await _parse(
      query: query,
      asJson: asJson,
      expectOne: expectOne,
    );
    // this._validateFetchCardinality(card, asJson, requiredOne);
    // this.queryCodecCache.set(key, [card, inCodec, outCodec, capabilities]);
    // if (this.alwaysUseOptimisticFlow) {
    await _execute(
        args: args,
        asJson: asJson,
        expectOne: expectOne,
        requiredOne: requiredOne,
        inCodec: parseResult.inCodec,
        outCodec: parseResult.outCodec,
        query: query,
        result: ret);
    // } else {
    //   await this._executeFlow(args, inCodec, outCodec, ret);
    // }

    // }

    if (expectOne) {
      if (requiredOne == true && ret.isEmpty) {
        // throw new errors.NoDataError("query returned no data");
      } else {
        return ret[0] ?? (asJson ? "null" : null);
      }
    } else {
      if (ret.isNotEmpty) {
        if (asJson) {
          return ret[0];
        } else {
          return ret;
        }
      } else {
        if (asJson) {
          return "[]";
        } else {
          return ret;
        }
      }
    }
  }

  // void _parseDataMessages(Codec codec, List<dynamic> result) {
  //   const frb = ReadBuffer.alloc();
  //   const $D = chars.$D;
  //   const buffer = this.buffer;

  //   while (buffer.takeMessageType($D)) {
  //     buffer.consumeMessageInto(frb);
  //     frb.discard(6);
  //     result.push(codec.decode(frb));
  //     frb.finish();
  //   }
  // }

  Future<void> _execute({
    dynamic args,
    required bool asJson,
    required bool expectOne,
    bool? requiredOne,
    required Codec inCodec,
    required Codec outCodec,
    required String query,
    required List<dynamic> result,
    // options?: ParseOptions
  }) async {
    final wb = WriteMessageBuffer(MessageType.Execute)
      ..writeUint16(0) // no headers
      // ..writeHeaders({
      //   explicitObjectids: "true",
      //   ...(options?.headers ?? {}),
      //   allowCapabilities: NO_TRANSACTION_CAPABILITIES_BYTES,
      // });
      ..writeUint8(asJson ? IOFormat.Json.value : IOFormat.Binary.value)
      ..writeUint8(
          expectOne ? Cardinality.AtMostOne.value : Cardinality.Many.value)
      ..writeString(query)
      ..writeBuffer(Uint8List.fromList(inCodec.tidBuffer))
      ..writeBuffer(Uint8List.fromList(outCodec.tidBuffer))
      // ..writeBytes(this._encodeArgs(args, inCodec))
      ..writeInt32(0)
      ..endMessage()
      ..writeSync();

    sock.add(wb.unwrap());
    print('sent message: ${MessageType.Execute.name}');

    bool reExec = false;
    Error? error;
    bool parsing = true;
    Cardinality? newCard;
    int capabilities = -1;

    while (parsing) {
      final message = await messages.takeMessage();

      switch (message.messageType) {
        case MessageType.Data:
          {
            if (error == null) {
              try {
                final numData = message.readUint16();
                assert(numData == 1);
                message.discard(4);
                result.add(outCodec.decode(message));
                message.finishMessage();
              } catch (e) {
                error = e as Error;
              }
            }
            break;
          }

        case MessageType.CommandComplete:
          {
            // this.lastStatus = this._parseCommandCompleteMessage();
            break;
          }

        case MessageType.ReadyForCommand:
          {
            parseSyncMessage(message);
            parsing = false;
            break;
          }

        case MessageType.CommandDataDescription:
          {
            // try {
            //   [newCard, inCodec, outCodec, capabilities] =
            //     this._parseDescribeTypeMessage();
            //   const key = this._getQueryCacheKey(query, asJson, expectOne);
            //   this.queryCodecCache.set(key, [
            //     newCard,
            //     inCodec,
            //     outCodec,
            //     capabilities,
            //   ]);
            //   reExec = true;
            // } catch (e: any) {
            //   error = e;
            // }
            break;
          }

        case MessageType.ErrorResponse:
          {
            error = parseErrorMessage(message);
            break;
          }

        default:
          _fallthrough(message);
      }
    }

    if (error != null) {
      throw error;
    }

    // if (reExec) {
    //   this._validateFetchCardinality(newCard!, asJson, requiredOne);
    //   if (this.isLegacyProtocol) {
    //     return await this._executeFlow(args, inCodec, outCodec, result);
    //   } else {
    //     return await this._optimisticExecuteFlow(
    //       args,
    //       asJson,
    //       expectOne,
    //       requiredOne,
    //       inCodec,
    //       outCodec,
    //       query,
    //       result,
    //       options
    //     );
    //   }
    // }
  }

  Future<ParseResult> _parse({
    required String query,
    required bool asJson,
    required bool expectOne,
    // headers
  }) async {
    final wb = WriteMessageBuffer(MessageType.Parse)
      ..writeUint16(0) // no headers

      // .writeHeaders({
      //   explicitObjectids: "true",
      //   ...(options?.headers ?? {}),
      //   allowCapabilities: NO_TRANSACTION_CAPABILITIES_BYTES,
      // })
      ..writeUint8(asJson ? IOFormat.Json.value : IOFormat.Binary.value)
      ..writeUint8(
          expectOne ? Cardinality.AtMostOne.value : Cardinality.Many.value)
      ..writeString(query)
      ..endMessage()
      ..writeSync();

    sock.add(wb.unwrap());
    print('sent message ${MessageType.Parse.name}');

    Cardinality? cardinality;
    String? inTypeId;
    String? outTypeId;
    Codec? inCodec;
    Codec? outCodec;
    int capabilities = -1;
    bool parsing = true;
    Error? error;
    Uint8List? inCodecData;
    Uint8List? outCodecData;

    while (parsing) {
      final message = await messages.takeMessage();

      switch (message.messageType) {
        case MessageType.ParseComplete:
          {
            message.ignoreHeaders();
            // const headers = this._parseHeaders();
            // if (headers.has(HeaderCodes.capabilities)) {
            //   capabilities = Number(
            //     headers.get(HeaderCodes.capabilities)!.readBigInt64BE()
            //   );
            // }
            final card = message.readUint8();
            cardinality = cardinalities[card]!;

            inTypeId = message.readUUID();
            inCodecData = message.readLenPrefixedBytes();
            outTypeId = message.readUUID();
            outCodecData = message.readLenPrefixedBytes();

            message.finishMessage();
            break;
          }

        case MessageType.ErrorResponse:
          {
            error = parseErrorMessage(message);
            break;
          }

        case MessageType.ReadyForCommand:
          {
            parseSyncMessage(message);
            parsing = false;
            break;
          }

        default:
          _fallthrough(message);
      }
    }

    if (error != null) {
      throw error;
    }

    if (inTypeId == null || outTypeId == null) {
      throw ProtocolError('did not receive in/out type ids in Parse response');
    }

    inCodec = codecsRegistry.getCodec(inTypeId);
    outCodec = codecsRegistry.getCodec(outTypeId);

    if (inCodec == null && inCodecData != null) {
      inCodec = codecsRegistry.buildCodec(inCodecData, protocolVersion);
    }

    if (outCodec == null && outCodecData != null) {
      outCodec = codecsRegistry.buildCodec(outCodecData, protocolVersion);
    }

    if (cardinality == null || outCodec == null || inCodec == null) {
      throw ProtocolError(
          'failed to receive type information in response to a Parse message');
    }

    return ParseResult(
        cardinality: cardinality,
        inCodec: inCodec,
        outCodec: outCodec,
        capabilities: capabilities);
  }
}

class ParseResult {
  Cardinality cardinality;
  Codec inCodec;
  Codec outCodec;
  int capabilities;

  ParseResult(
      {required this.cardinality,
      required this.inCodec,
      required this.outCodec,
      required this.capabilities});
}
