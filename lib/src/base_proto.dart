import 'dart:convert';
import 'dart:typed_data';

import 'codecs/codecs.dart';
import 'codecs/registry.dart';
import 'errors/errors.dart';
import 'errors/resolve.dart';
import 'primitives/buffer.dart';
import 'primitives/transport.dart';
import 'primitives/message_types.dart';
import 'primitives/proto_version.dart';

const protoVer = ProtocolVersion(1, 0);
const minProtoVer = ProtocolVersion(1, 0);

enum Cardinality {
  noResult(0x6e),
  atMostOne(0x6f),
  one(0x41),
  many(0x6d),
  atLeastOne(0x4d);

  final int value;
  const Cardinality(this.value);
}

final cardinalities = {for (var card in Cardinality.values) card.value: card};

enum OutputFormat {
  binary(0x62),
  json(0x6a),
  none(0x6e);

  final int value;
  const OutputFormat(this.value);
}

enum Capabilities {
  none(0),
  modifications(1 << 0),
  sessionConfig(1 << 1),
  transaction(1 << 2),
  ddl(1 << 3),
  persistentConfig(1 << 4),
  all(~0);

  final int value;
  const Capabilities(this.value);
}

final restrictedCapabilities = Capabilities.all.value &
    ~Capabilities.transaction.value &
    ~Capabilities.sessionConfig.value;

abstract class BaseProtocol {
  Uint8List? serverSecret;
  ProtocolVersion protocolVersion = protoVer;

  late MessageTransport transport;

  final codecsRegistry = CodecsRegistry();

  bool connected = false;

  Future<void> connect(
      {required String host,
      required int port,
      String? database,
      required String username,
      String? password});

  void parseSyncMessage(ReadMessageBuffer message) {}

  void fallthrough(ReadMessageBuffer message) {
    if (message.messageType == MessageType.ParameterStatus) {
      return;
    }

    throw ProtocolError('unexpected "${message.messageType.name}" message '
        '("${ascii.decode([message.messageType.value])}")');
  }

  Error parseErrorMessage(ReadMessageBuffer message) {
    message.discard(1); // ignore severity
    final errCode = message.readUint32();
    final errMessage = message.readString();

    final errorType = resolveErrorCode(errCode);
    final err = errorType(errMessage);

    message
      ..ignoreHeaders()
      ..finishMessage();

    if (err is AuthenticationError) {
      throw err;
    }

    return err;
  }

  Future<dynamic> fetch({
    required String query,
    dynamic args,
    required OutputFormat outputFormat,
    required Cardinality expectedCardinality,
  }) async {
    // this._checkState();

    final requiredOne = expectedCardinality == Cardinality.one;
    final expectOne =
        requiredOne || expectedCardinality == Cardinality.atMostOne;
    final asJson = outputFormat == OutputFormat.json;

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
      outputFormat: outputFormat,
      expectedCardinality: expectedCardinality,
    );
    // this._validateFetchCardinality(card, asJson, requiredOne);
    // this.queryCodecCache.set(key, [card, inCodec, outCodec, capabilities]);
    // if (this.alwaysUseOptimisticFlow) {
    await _execute(
        query: query,
        args: args,
        outputFormat: outputFormat,
        expectedCardinality: expectedCardinality,
        inCodec: parseResult.inCodec,
        outCodec: parseResult.outCodec,
        result: ret);
    // } else {
    //   await this._executeFlow(args, inCodec, outCodec, ret);
    // }

    // }

    if (outputFormat == OutputFormat.none) {
      return;
    }
    if (expectOne) {
      if (requiredOne == true && ret.isEmpty) {
        throw NoDataError("query returned no data");
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
    required String query,
    dynamic args,
    required OutputFormat outputFormat,
    required Cardinality expectedCardinality,
    // state
    bool privilegedMode = false,
    required Codec inCodec,
    required Codec outCodec,
    required List<dynamic> result,
    // options?: ParseOptions
  }) async {
    final wb = WriteMessageBuffer(ClientMessageType.Execute)
      ..writeUint16(0); // no headers

    _encodeParseParams(
        buffer: wb,
        query: query,
        outputFormat: outputFormat,
        expectedCardinality: expectedCardinality,
        privilegedMode: privilegedMode);

    wb
      ..writeBuffer(inCodec.tidBuffer)
      ..writeBuffer(outCodec.tidBuffer)
      // ..writeBytes(this._encodeArgs(args, inCodec))
      ..writeInt32(0)
      ..endMessage()
      ..writeSync();

    transport.sendMessage(wb);

    Error? error;
    bool parsing = true;

    while (parsing) {
      final message = await transport.takeMessage();

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
            try {
              final parseResult = _parseDescribeTypeMessage(message);
              // const key = this._getQueryCacheKey(query, asJson, expectOne);
              // this.queryCodecCache.set(key, [
              //   newCard,
              //   inCodec,
              //   outCodec,
              //   capabilities,
              // ]);
              outCodec = parseResult.outCodec;
            } catch (e) {
              error = e as Error;
            }
            break;
          }

        case MessageType.ErrorResponse:
          {
            error = parseErrorMessage(message);
            break;
          }

        default:
          fallthrough(message);
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
    required OutputFormat outputFormat,
    required Cardinality expectedCardinality,
    // state
    bool privilegedMode = false,
    // options
  }) async {
    final wb = WriteMessageBuffer(ClientMessageType.Parse)
      ..writeUint16(0); // no headers

    _encodeParseParams(
        buffer: wb,
        query: query,
        outputFormat: outputFormat,
        expectedCardinality: expectedCardinality,
        privilegedMode: privilegedMode);

    wb
      ..endMessage()
      ..writeSync();

    transport.sendMessage(wb);

    ParseResult? parseResult;
    bool parsing = true;
    Error? error;

    while (parsing) {
      final message = await transport.takeMessage();

      switch (message.messageType) {
        case MessageType.CommandDataDescription:
          {
            try {
              parseResult = _parseDescribeTypeMessage(message);
              //   const key = this._getQueryCacheKey(
              //     query,
              //     outputFormat,
              //     expectedCardinality
              //   );
              //   this.queryCodecCache.set(key, [
              //     newCard,
              //     inCodec,
              //     outCodec,
              //     capabilities,
              //   ]);
            } catch (e) {
              error = e as Error;
            }
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
          fallthrough(message);
      }
    }

    if (error != null) {
      throw error;
    }

    return parseResult!;
  }

  void _encodeParseParams(
      {required WriteMessageBuffer buffer,
      required String query,
      required OutputFormat outputFormat,
      required Cardinality expectedCardinality,
      // state
      required bool privilegedMode
      // options
      }) {
    buffer
      ..writeFlags(
          privilegedMode ? Capabilities.all.value : restrictedCapabilities)
      ..writeFlags(0)
      ..writeUint64(0)
      ..writeUint8(outputFormat.value)
      ..writeUint8(expectedCardinality == Cardinality.one ||
              expectedCardinality == Cardinality.atMostOne
          ? Cardinality.atMostOne.value
          : Cardinality.many.value)
      ..writeString(query);

    // state
    buffer
      ..writeBuffer(nullCodec.tidBuffer)
      ..writeUint32(0);
  }

  ParseResult _parseDescribeTypeMessage(ReadMessageBuffer message) {
    message.ignoreHeaders();
    final capabilities = message.readUint64();

    final cardinality = cardinalities[message.readUint8()]!;

    final inTypeId = message.readUUID();
    final inTypeData = message.readLenPrefixedBytes();

    final outTypeId = message.readUUID();
    final outTypeData = message.readLenPrefixedBytes();

    message.finishMessage();

    final inCodec = codecsRegistry.getCodec(inTypeId) ??
        codecsRegistry.buildCodec(inTypeData, protocolVersion);

    final outCodec = codecsRegistry.getCodec(outTypeId) ??
        codecsRegistry.buildCodec(outTypeData, protocolVersion);

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
