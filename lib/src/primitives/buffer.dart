import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../errors.dart';
import 'message_types.dart';

const bufferIncSize = 4096;

class BufferError extends Error {
  final String message;
  BufferError(this.message);
}

class WriteBuffer {
  ByteData buffer = ByteData(bufferIncSize);
  int pos = 0;

  void _ensureAlloced(int extraLength) {
    if (pos + extraLength > buffer.buffer.lengthInBytes) {
      final newBuffer = ByteData(buffer.buffer.lengthInBytes + bufferIncSize);
      newBuffer.buffer.asUint8List().setRange(
          0, buffer.buffer.lengthInBytes, buffer.buffer.asUint8List());
      buffer = newBuffer;
    }
  }

  void writeString(String string) {
    writeBytes(utf8.encode(string));
  }

  void writeBuffer(Uint8List buf) {
    buffer.buffer.asUint8List().setRange(pos, pos + buf.length, buf);
    pos += buf.length;
  }

  void writeBytes(List<int> bytes) {
    _ensureAlloced(bytes.length + 4);
    buffer.setUint32(pos, bytes.length);
    pos += 4;
    writeBuffer(Uint8List.fromList(bytes));
  }

  void writeUint8(int i) {
    _ensureAlloced(1);
    buffer.setUint8(pos, i);
    pos++;
  }

  void writeInt8(int i) {
    _ensureAlloced(1);
    buffer.setInt8(pos, i);
    pos++;
  }

  void writeUint16(int i) {
    _ensureAlloced(2);
    buffer.setUint16(pos, i);
    pos += 2;
  }

  void writeInt16(int i) {
    _ensureAlloced(2);
    buffer.setInt16(pos, i);
    pos += 2;
  }

  void writeUint32(int i) {
    _ensureAlloced(4);
    buffer.setUint32(pos, i);
    pos += 4;
  }

  void writeInt32(int i) {
    _ensureAlloced(4);
    buffer.setInt32(pos, i);
    pos += 4;
  }

  void writeInt64(int i) {
    _ensureAlloced(8);
    buffer.setInt64(pos, i);
    pos += 8;
  }

  List<int> unwrap() {
    return buffer.buffer.asUint8List(0, pos);
  }
}

final syncMessage =
    (WriteMessageBuffer(MessageType.Sync)..endMessage()).unwrap();

class WriteMessageBuffer extends WriteBuffer {
  bool messageFinished = false;

  WriteMessageBuffer(MessageType mtype) {
    writeUint8(mtype.value);
    writeInt32(0);
  }

  void endMessage() {
    if (messageFinished) {
      throw BufferError('cannot end the message: message already ended');
    }

    buffer.setInt32(1, pos - 1);
    messageFinished = true;
  }

  void writeSync() {
    if (!messageFinished) {
      throw BufferError('cannot writeSync: the message is not finished');
    }

    _ensureAlloced(syncMessage.length);
    writeBuffer(syncMessage as Uint8List);
  }

  @override
  List<int> unwrap() {
    if (!messageFinished) {
      throw BufferError(
          'cannot unwrap: an unfinished message is in the buffer');
    }
    return super.unwrap();
  }
}

class ReadBuffer {
  final ByteData buffer;
  int pos = 0;

  ReadBuffer(Uint8List data) : buffer = ByteData.sublistView(data);

  int get length {
    return buffer.lengthInBytes - pos;
  }

  void finish() {
    if (pos != buffer.lengthInBytes) {
      throw BufferError('unexpected trailing data in buffer');
    }
  }

  void _checkOverread(int size) {
    if (pos + size > buffer.lengthInBytes) {
      throw BufferError('buffer overread');
    }
  }

  void discard(int size) {
    _checkOverread(size);
    pos += size;
  }

  int readUint8() {
    _checkOverread(1);
    final num = buffer.getUint8(pos);
    pos += 1;
    return num;
  }

  int readInt8() {
    _checkOverread(1);
    final num = buffer.getInt8(pos);
    pos += 1;
    return num;
  }

  int readUint16() {
    _checkOverread(2);
    final num = buffer.getUint16(pos);
    pos += 2;
    return num;
  }

  int readInt16() {
    _checkOverread(2);
    final num = buffer.getInt16(pos);
    pos += 2;
    return num;
  }

  int readUint32() {
    _checkOverread(4);
    final num = buffer.getUint32(pos);
    pos += 4;
    return num;
  }

  int readInt32() {
    _checkOverread(4);
    final num = buffer.getInt32(pos);
    pos += 4;
    return num;
  }

  int readUint64() {
    _checkOverread(8);
    final num = buffer.getUint64(pos);
    pos += 8;
    return num;
  }

  int readInt64() {
    _checkOverread(8);
    final num = buffer.getInt64(pos);
    pos += 8;
    return num;
  }

  double readFloat32() {
    _checkOverread(4);
    final num = buffer.getFloat32(pos);
    pos += 4;
    return num;
  }

  double readFloat64() {
    _checkOverread(8);
    final num = buffer.getFloat64(pos);
    pos += 8;
    return num;
  }

  Uint8List readBytes(int size) {
    _checkOverread(size);
    final bytes = Uint8List.sublistView(buffer, pos, pos + size);
    pos += size;
    return bytes;
  }

  Uint8List readLenPrefixedBytes() {
    final size = readInt32();
    return readBytes(size);
  }

  ReadBuffer slice(int size) {
    return ReadBuffer(readBytes(size));
  }

  String readUUID() {
    _checkOverread(16);
    final first = buffer.getInt64(pos);
    final second = buffer.getInt64(pos + 8);
    pos += 16;
    return first.toRadixString(16).padLeft(16, '0') +
        second.toRadixString(16).padLeft(16, '0');
  }
}

class ReadMessageBuffer extends ReadBuffer {
  final MessageType messageType;

  ReadMessageBuffer(this.messageType, super.data);

  void ignoreHeaders() {
    var numFields = readInt16();
    while (numFields > 0) {
      readInt16();
      readLenPrefixedBytes();
      numFields--;
    }
  }

  void finishMessage() {}
}

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

          messageType = messageTypes[header.getUint8(0)];
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
  Completer<ReadMessageBuffer>? _messageAwaiter;

  MessageTransport(Socket sock) {
    _sub = createMessageStream(sock).listen((message) {
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
}
