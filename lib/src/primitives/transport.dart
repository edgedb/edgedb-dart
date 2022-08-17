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

class MessageTransport {
  late StreamSubscription<ReadMessageBuffer> _sub;
  late IOSink _sink;
  Completer<ReadMessageBuffer>? _messageAwaiter;

  MessageTransport(Stream<Uint8List> stream, IOSink sink,
      {required Function(Object) onError}) {
    _sink = sink;
    _sub = createMessageStream(stream).listen((message) {
      // print('got message: ${message.messageType.name}');
      if (_messageAwaiter == null) {
        throw StateError(
            'received message from stream while not waiting for message');
      }
      _sub.pause();
      _messageAwaiter!.complete(message);
      _messageAwaiter = null;
    }, onDone: () => close(), onError: onError, cancelOnError: true);
    _sub.pause();
  }

  Future<ReadMessageBuffer> takeMessage() {
    if (_messageAwaiter != null) {
      return _messageAwaiter!.future;
    }
    _messageAwaiter = Completer();
    _sub.resume();
    return _messageAwaiter!.future;
  }

  sendMessage(WriteMessageBuffer message) {
    _sink.add(message.unwrap());
    // print(
    //     'sent message: ${clientMessageTypes[message.buffer.getUint8(0)]!.name}');
  }

  Future<void> close() {
    // print('closing');
    return _sink.close();
  }
}
