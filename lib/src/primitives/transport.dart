import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../errors/errors.dart';
import 'buffer.dart';
import 'message_types.dart';

final maxMessageLength = pow(2, 26);

Stream<ReadMessageBuffer> createMessageStream(Stream<Uint8List> source) async* {
  final List<Uint8List> chunks = [];
  int bufferLength = 0;

  MessageType? messageType;
  var messageLength = -1;

  await for (var data in source) {
    chunks.add(data);
    bufferLength += data.lengthInBytes;

    while (true) {
      if (messageLength == -1) {
        if (bufferLength >= 5) {
          ByteData header;
          if (chunks[0].length >= 5) {
            header = ByteData.sublistView(chunks[0]);
          } else {
            header = ByteData(5);
            var offset = 0;
            var i = 0;
            while (offset < 5) {
              final chunk = chunks[i++];
              header.buffer.asUint8List().setRange(
                  offset, min(offset + chunk.lengthInBytes, 5), chunk);
              offset += chunk.lengthInBytes;
            }
          }

          final messageCode = header.getUint8(0);
          messageType = serverMessageTypes[messageCode];
          if (messageType == null) {
            throw ProtocolError(
                'unknown message type 0x${messageCode.toRadixString(16).padLeft(2, '0')}'
                '${(messageCode > 32 && messageCode < 127) ? ' (${ascii.decode([
                        header.getUint8(0)
                      ])})' : ''}');
          }
          messageLength = header.getInt32(1) + 1;
          if (messageLength > maxMessageLength) {
            throw InternalClientError('message too big');
          }
        } else {
          break;
        }
      }

      if (bufferLength >= messageLength) {
        Uint8List buffer;
        if (chunks.length == 1) {
          buffer = Uint8List.sublistView(chunks[0], 5, messageLength);
          bufferLength -= messageLength;
          if (bufferLength == 0) {
            chunks.clear();
          } else {
            chunks[0] = Uint8List.sublistView(chunks[0], messageLength);
          }
        } else {
          buffer = Uint8List(messageLength);
          var offset = 0;
          Uint8List chunk;
          do {
            chunk = chunks.removeAt(0);
            buffer.setRange(offset,
                min(offset + chunk.lengthInBytes, messageLength), chunk);
            offset += chunk.lengthInBytes;
          } while (offset < messageLength);
          if (offset > messageLength) {
            chunks.insert(
                0,
                Uint8List.sublistView(
                    chunk, chunk.lengthInBytes - offset + messageLength));
          }

          buffer = Uint8List.sublistView(buffer, 5);
          bufferLength -= messageLength;
        }
        messageLength = -1;

        yield ReadMessageBuffer(messageType!, buffer);
      } else {
        break;
      }
    }
  }
}

typedef TransportCreator = MessageTransport Function(
    {required Error Function(ReadMessageBuffer?) onClose,
    required Error Function(Object) onError,
    Map<MessageType, void Function(ReadMessageBuffer)>? asyncMessageHandlers});

TransportCreator transportCreator(Stream<Uint8List> stream, IOSink sink) {
  return (
          {required Error Function(ReadMessageBuffer?) onClose,
          required Error Function(Object) onError,
          Map<MessageType, void Function(ReadMessageBuffer)>?
              asyncMessageHandlers}) =>
      MessageTransport(stream, sink,
          onClose: onClose,
          onError: onError,
          asyncMessageHandlers: asyncMessageHandlers ?? {});
}

class MessageTransport {
  late IOSink _sink;
  Completer<ReadMessageBuffer>? _messageAwaiter;
  bool _closed = false;

  MessageTransport(Stream<Uint8List> stream, IOSink sink,
      {required Error Function(ReadMessageBuffer?) onClose,
      required Error Function(Object) onError,
      required Map<MessageType, void Function(ReadMessageBuffer)>
          asyncMessageHandlers}) {
    _sink = sink;
    createMessageStream(stream).listen((message) {
      // print('got message: ${message.messageType.name}');
      if (asyncMessageHandlers.containsKey(message.messageType)) {
        return asyncMessageHandlers[message.messageType]!(message);
      }
      if (_messageAwaiter != null) {
        _messageAwaiter!.complete(message);
        _messageAwaiter = null;
      } else {
        // received non-async message while not waiting for message
        close();
        onClose(message);
      }
    }, onDone: () async {
      close();
      if (_messageAwaiter != null) {
        _messageAwaiter!.completeError(onClose(null));
        _messageAwaiter = null;
      } else {
        onClose(null);
      }
    }, onError: (err) {
      if (_messageAwaiter != null) {
        _messageAwaiter!.completeError(onError(err));
        _messageAwaiter = null;
      } else {
        onError(err);
      }
    }, cancelOnError: true);
  }

  Future<ReadMessageBuffer> takeMessage() {
    if (_messageAwaiter != null) {
      throw InternalClientError('already waiting for message');
    }
    _messageAwaiter = Completer();
    return _messageAwaiter!.future;
  }

  void sendMessage(WriteMessageBuffer message) {
    _sink.add(message.unwrap());
    // print(
    //     'sent message: ${clientMessageTypes[message.buffer.getUint8(0)]!.name}');
  }

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      return _sink.close();
    }
  }
}
