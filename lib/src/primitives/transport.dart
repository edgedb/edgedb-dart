import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../errors/errors.dart';
import 'buffer.dart';
import 'message_types.dart';

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
            throw UnimplementedError();
          }

          messageType = serverMessageTypes[header.getUint8(0)];
          if (messageType == null) {
            throw ProtocolError(
                'unknown message type 0x${header.getUint8(0).toRadixString(16)}'
                ' (${ascii.decode([header.getUint8(0)])})');
          }
          messageLength = header.getInt32(1);
        } else {
          break;
        }
      }

      if (bufferLength > messageLength) {
        Uint8List buffer;
        if (chunks.length == 1 && bufferLength > messageLength) {
          buffer = Uint8List.sublistView(chunks[0], 5, messageLength + 1);
          bufferLength -= messageLength + 1;
          if (bufferLength == 0) {
            chunks.clear();
          } else {
            chunks[0] = Uint8List.sublistView(chunks[0], messageLength + 1);
          }
        } else {
          throw UnimplementedError();
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

  MessageTransport(Stream<Uint8List> stream, IOSink sink) {
    _sink = sink;
    _sub = createMessageStream(stream).listen((message) {
      print('got message: ${message.messageType.name}');
      if (_messageAwaiter == null) {
        throw StateError(
            'received message from stream while not waiting for message');
      }
      _sub.pause();
      _messageAwaiter!.complete(message);
      _messageAwaiter = null;
    });
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
    print(
        'sent message: ${clientMessageTypes[message.buffer.getUint8(0)]!.name}');
  }

  Future<void> close() {
    print('closing');
    return _sub.cancel();
  }
}
