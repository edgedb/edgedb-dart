import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'codecs/codecs.dart';
import 'codecs/registry.dart';
import 'connect_config.dart';
import 'errors/base.dart';
import 'errors/errors.dart';
import 'errors/resolve.dart';
import 'options.dart';
import 'primitives/buffer.dart';
import 'primitives/lru.dart';
import 'primitives/message_types.dart';
import 'primitives/transport.dart';
import 'primitives/types.dart';
import 'utils/indent.dart';

const protoVer = ProtocolVersion(2, 0);
const minProtoVer = ProtocolVersion(1, 0);

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

enum TransactionStatus {
  idle(0x49),
  active(0x100),
  inTrans(0x54),
  inError(0x45),
  unknown(-1);

  final int value;
  const TransactionStatus(this.value);
}

final transactionStatuses = {
  for (var status in TransactionStatus.values) status.value: status
};

typedef CreateConnection<Connection extends BaseProtocol>
    = Future<Connection> Function(
        {required ResolvedConnectConfig config,
        required CodecsRegistry registry,
        Duration? timeout});

class ParseResult {
  final Cardinality cardinality;
  final Codec inCodec;
  final Codec outCodec;
  final int capabilities;

  ParseResult(
      {required this.cardinality,
      required this.inCodec,
      required this.outCodec,
      required this.capabilities});

  @override
  String toString() {
    return 'ParseResult {\n'
        '  cardinality: $cardinality\n'
        '  inCodec: ${indent(inCodec.toString())}\n'
        '  outCodec: ${indent(outCodec.toString())}\n'
        '  capabilities: $capabilities\n'
        '}';
  }
}

class ServerSettings {
  int? suggestedPoolConcurrency;
  dynamic systemConfig;
}

class StateCache {
  Session session;
  Uint8List buffer;

  StateCache(this.session, this.buffer);
}

abstract class BaseProtocol {
  Uint8List? serverSecret;
  TransactionStatus transactionStatus = TransactionStatus.idle;
  String? lastStatus;
  ProtocolVersion protocolVersion = protoVer;
  final serverSettings = ServerSettings();
  late final MessageTransport transport;
  final CodecsRegistry codecsRegistry;
  final queryCodecCache = LRU<int, ParseResult>(capacity: 1000);
  Codec stateCodec = invalidCodec;
  StateCache? stateCache;
  bool connected = false;
  final Completer<Error> connAbortWaiter = Completer();
  Error? _abortedWithError;

  BaseProtocol(
      {required TransportCreator transportCreator,
      required this.codecsRegistry}) {
    transport = transportCreator(
        onClose: onClose,
        onError: onError,
        asyncMessageHandlers: {
          MessageType.ParameterStatus: _parseServerSettings,
          MessageType.LogMessage: _parseLogMessage,
        });
  }

  // connection state handling

  bool get isClosed {
    return !connected;
  }

  Error onClose(ReadMessageBuffer? lastMessage);

  Error onError(Object error);

  Future<void> _abort() async {
    if (connected) {
      connected = false;
      if (!connAbortWaiter.isCompleted) {
        connAbortWaiter.complete(
            _abortedWithError ?? InterfaceError('connection has been closed'));
      }
      return transport.close();
    }
  }

  void abortWithError(Error err) {
    _abortedWithError = err;
    _abort();
  }

  Future<void> close() async {
    if (connected) {
      transport.sendMessage(
          WriteMessageBuffer(ClientMessageType.Terminate)..endMessage());
    }
    return _abort();
  }

  Future<void> resetState() async {
    if (connected && transactionStatus != TransactionStatus.idle) {
      try {
        await fetch(
            query: 'rollback',
            outputFormat: OutputFormat.none,
            expectedCardinality: Cardinality.noResult,
            state: Session.defaults(),
            privilegedMode: true);
      } catch (e) {
        abortWithError(ClientConnectionClosedError('failed to reset state'));
      }
    }
  }

  void _checkState() {
    if (!connected) {
      throw _abortedWithError ?? InterfaceError('connection has been closed');
    }
  }

  // message parsers

  void fallthrough(ReadMessageBuffer message) {
    throw ProtocolError('unexpected "${message.messageType.name}" message '
        '("${ascii.decode([message.messageType.value])}")');
  }

  void parseSyncMessage(ReadMessageBuffer message) {
    message.ignoreHeaders();
    final status = message.readUint8();
    transactionStatus =
        transactionStatuses[status] ?? TransactionStatus.unknown;
  }

  void _parseLogMessage(ReadMessageBuffer message) {
    final severity = message.readUint8();
    final code = message.readUint32();
    final logMessage = message.readString();
    message
      ..ignoreHeaders()
      ..finishMessage();
    print('SERVER MESSAGE | $severity $code | $logMessage');
  }

  void _parseServerSettings(ReadMessageBuffer message) {
    final name = message.readString();
    switch (name) {
      case 'suggested_pool_concurrency':
        {
          serverSettings.suggestedPoolConcurrency =
              int.parse(message.readString(), radix: 10);
          break;
        }
      case 'system_config':
        {
          final buf = ReadBuffer(message.readLenPrefixedBytes());
          final typedescLen = buf.readInt32() - 16;
          final typedescId = buf.readUUID();
          final typedesc = buf.readBytes(typedescLen);

          final codec = codecsRegistry.getCodec(typedescId) ??
              codecsRegistry.buildCodec(typedesc, protocolVersion);
          buf.discard(4);
          final data = codec.decode(buf);
          buf.finish();

          serverSettings.systemConfig = data;
          break;
        }
      default:
        {
          log('unknown server settings name: "$name"');
          message.discard(message.readInt32());
        }
    }

    message.finishMessage();
  }

  EdgeDBError parseErrorMessage(ReadMessageBuffer message) {
    message.discard(1); // ignore severity
    final errCode = message.readUint32();
    final errMessage = message.readString();

    final errorType = resolveErrorCode(errCode);
    final err = errorType(errMessage);

    final attrs = message.readHeaders().map((key, value) => MapEntry(
        errorAttrsByCode[key] ?? ErrorAttr.unknown, utf8.decode(value)));
    setErrorAttrs(err, attrs);

    message.finishMessage();

    if (err is AuthenticationError) {
      throw err;
    }

    return err;
  }

  void _parseDescribeStateMessage(ReadMessageBuffer message) {
    final typedescId = message.readUUID();
    final typedesc = message.readLenPrefixedBytes();

    stateCodec = codecsRegistry.getCodec(typedescId) ??
        codecsRegistry.buildCodec(typedesc, protocolVersion);
    stateCache = null;
    message.finishMessage();
  }

  ParseResult _parseDescribeTypeMessage(ReadMessageBuffer message) {
    message.ignoreHeaders();
    final capabilities = message.readInt64();

    final cardinality = cardinalitiesByValue[message.readUint8()]!;

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

  String _parseCommandCompleteMessage(ReadMessageBuffer message) {
    message
      ..ignoreHeaders()
      ..readInt64();
    final status = message.readString();
    message
      ..readUUID() // state type id
      ..discard(message.readInt32()) // state data
      ..finishMessage();
    return status;
  }

  // query cache methods

  int _getQueryCacheKey(String query, OutputFormat outputFormat,
      Cardinality expectedCardinality) {
    final expectOne = expectedCardinality == Cardinality.one ||
        expectedCardinality == Cardinality.atMostOne;
    return Object.hash(outputFormat, expectOne, query);
  }

  int? getQueryCapabilities(String query, OutputFormat outputFormat,
      Cardinality expectedCardinality) {
    final key = _getQueryCacheKey(query, outputFormat, expectedCardinality);
    return queryCodecCache.get(key)?.capabilities;
  }

  // utils

  void _encodeArgs(WriteBuffer buffer, Codec inCodec, dynamic args) {
    if (inCodec == nullCodec) {
      if (args != null) {
        throw QueryArgumentError(
            'This query does not contain any query parameters, '
            'but query arguments were provided to the \'query*()\' method');
      }

      buffer.writeInt32(0);
    } else if (inCodec is ObjectCodec) {
      inCodec.encodeArgs(buffer, args);
    } else {
      // Shouldn't ever happen.
      throw ProtocolError('invalid input codec');
    }
  }

  void _encodeParseParams(
      {required WriteMessageBuffer buffer,
      required String query,
      required OutputFormat outputFormat,
      required Cardinality expectedCardinality,
      required Session state,
      required bool privilegedMode
      // options
      }) {
    buffer
      ..writeFlags(
          privilegedMode ? Capabilities.all.value : restrictedCapabilities)
      ..writeFlags(0)
      ..writeInt64(0)
      ..writeUint8(outputFormat.value)
      ..writeUint8(expectedCardinality == Cardinality.one ||
              expectedCardinality == Cardinality.atMostOne
          ? Cardinality.atMostOne.value
          : Cardinality.many.value)
      ..writeString(query);

    if (state == Session.defaults()) {
      buffer
        ..writeBuffer(nullCodec.tidBuffer)
        ..writeUint32(0);
    } else {
      buffer.writeBuffer(stateCodec.tidBuffer);
      if (stateCodec == invalidCodec) {
        buffer.writeUint32(0);
      } else {
        if (stateCache?.session != state) {
          final buf = WriteBuffer();
          stateCodec.encode(buf, serialiseState(state));
          stateCache = StateCache(state, buf.unwrap() as Uint8List);
        }
        buffer.writeBuffer(stateCache!.buffer);
      }
    }
  }

  // protocol flow

  Future<dynamic> fetch<T>(
      {required String query,
      String? queryName,
      dynamic args,
      required OutputFormat outputFormat,
      required Cardinality expectedCardinality,
      required Session state,
      Codec? inCodec,
      Codec? outCodec,
      bool privilegedMode = false}) async {
    final requiredOne = expectedCardinality == Cardinality.one;
    final expectOne =
        requiredOne || expectedCardinality == Cardinality.atMostOne;
    final asJson = outputFormat == OutputFormat.json;

    final key = _getQueryCacheKey(query, outputFormat, expectedCardinality);
    final ret = <T>[];

    var cacheItem = queryCodecCache.get(key);

    ParseResult? parseResult;
    if ((inCodec == null && cacheItem == null && args != null) ||
        (stateCodec == invalidCodec && state != Session.defaults())) {
      parseResult = await parse(
          query: query,
          outputFormat: outputFormat,
          expectedCardinality: expectedCardinality,
          state: state,
          privilegedMode: privilegedMode);
    }
    try {
      await execute(
          query: query,
          queryName: queryName,
          args: args,
          outputFormat: outputFormat,
          expectedCardinality: expectedCardinality,
          state: state,
          inCodec: inCodec ??
              parseResult?.inCodec ??
              cacheItem?.inCodec ??
              nullCodec,
          outCodec: outCodec ??
              parseResult?.outCodec ??
              cacheItem?.outCodec ??
              nullCodec,
          updateCodecIds: outCodec != null,
          result: ret,
          privilegedMode: privilegedMode);
    } on ParameterTypeMismatchError {
      cacheItem = queryCodecCache.get(key)!;
      if (inCodec != null) {
        if (cacheItem.inCodec.compare(inCodec)) {
          inCodec.updateTid(cacheItem.inCodec);
        } else {
          throw InterfaceError(
              'query parameter types for query "$queryName" do not '
              'match query parameter types from codegen. '
              'Re-run `dart run build_runner build`.');
        }
      }
      await execute(
          query: query,
          queryName: queryName,
          args: args,
          outputFormat: outputFormat,
          expectedCardinality: expectedCardinality,
          state: state,
          inCodec: inCodec ?? parseResult?.inCodec ?? cacheItem.inCodec,
          outCodec: outCodec ?? parseResult?.outCodec ?? cacheItem.outCodec,
          updateCodecIds: outCodec != null,
          result: ret,
          privilegedMode: privilegedMode);
    }

    if (outputFormat == OutputFormat.none) {
      return;
    }
    if (expectOne) {
      if (requiredOne == true && ret.isEmpty) {
        throw NoDataError("query returned no data");
      } else {
        return ret.isEmpty ? (asJson ? "null" : null) : ret[0];
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

  Future<ParseResult> parse({
    required String query,
    required OutputFormat outputFormat,
    required Cardinality expectedCardinality,
    required Session state,
    required bool privilegedMode,
    // options
  }) async {
    _checkState();

    final wb = WriteMessageBuffer(ClientMessageType.Parse)
      ..writeUint16(0); // no headers

    _encodeParseParams(
        buffer: wb,
        query: query,
        outputFormat: outputFormat,
        expectedCardinality: expectedCardinality,
        state: state,
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
              final key =
                  _getQueryCacheKey(query, outputFormat, expectedCardinality);
              queryCodecCache.set(key, parseResult);
            } catch (e) {
              error = e as Error;
            }
            break;
          }

        case MessageType.ErrorResponse:
          {
            error = parseErrorMessage(message);
            setErrorQuery(error as EdgeDBError, query);
            break;
          }

        case MessageType.StateDataDescription:
          {
            _parseDescribeStateMessage(message);
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
      if (error is StateMismatchError) {
        return parse(
            query: query,
            outputFormat: outputFormat,
            expectedCardinality: expectedCardinality,
            state: state,
            privilegedMode: privilegedMode);
      }
      throw error;
    }

    return parseResult!;
  }

  Future<void> execute({
    required String query,
    String? queryName,
    dynamic args,
    required OutputFormat outputFormat,
    required Cardinality expectedCardinality,
    required Session state,
    required bool privilegedMode,
    required Codec inCodec,
    required Codec outCodec,
    required bool updateCodecIds,
    required List<dynamic> result,
    // options?: ParseOptions
  }) async {
    _checkState();

    final wb = WriteMessageBuffer(ClientMessageType.Execute)
      ..writeUint16(0); // no headers

    _encodeParseParams(
        buffer: wb,
        query: query,
        outputFormat: outputFormat,
        expectedCardinality: expectedCardinality,
        state: state,
        privilegedMode: privilegedMode);

    wb
      ..writeBuffer(inCodec.updatedTidBuffer ?? inCodec.tidBuffer)
      ..writeBuffer(outCodec.updatedTidBuffer ?? outCodec.tidBuffer);

    _encodeArgs(wb, inCodec, args);

    wb
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
            lastStatus = _parseCommandCompleteMessage(message);
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
              final key =
                  _getQueryCacheKey(query, outputFormat, expectedCardinality);
              queryCodecCache.set(key, parseResult);

              if (updateCodecIds) {
                if (parseResult.outCodec.compare(outCodec)) {
                  outCodec.updateTid(parseResult.outCodec);
                } else {
                  throw InterfaceError(
                      'return type response for query "$queryName" does not '
                      'match return type from codegen. '
                      'Re-run `dart run build_runner build`.');
                }
              } else {
                outCodec = parseResult.outCodec;
              }
            } catch (e) {
              error = e as Error;
            }
            break;
          }

        case MessageType.StateDataDescription:
          {
            _parseDescribeStateMessage(message);
            break;
          }

        case MessageType.ErrorResponse:
          {
            error = parseErrorMessage(message);
            setErrorQuery(error as EdgeDBError, query);
            break;
          }

        default:
          fallthrough(message);
      }
    }

    if (error != null) {
      if (error is StateMismatchError) {
        return execute(
          query: query,
          queryName: queryName,
          args: args,
          outputFormat: outputFormat,
          expectedCardinality: expectedCardinality,
          state: state,
          inCodec: inCodec,
          outCodec: outCodec,
          updateCodecIds: updateCodecIds,
          result: result,
          privilegedMode: privilegedMode,
        );
      }
      throw error;
    }
  }
}
