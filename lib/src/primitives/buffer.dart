import 'dart:convert';
import 'dart:typed_data';

import 'message_types.dart';

const bufferIncSize = 4096;

class BufferError extends Error {
  final String message;
  BufferError(this.message);

  @override
  String toString() {
    return 'BufferError: $message';
  }
}

class WriteBuffer {
  ByteData buffer = ByteData(bufferIncSize);
  int pos = 0;

  void _ensureAlloced(int extraLength) {
    if (pos + extraLength > buffer.buffer.lengthInBytes) {
      final newBuffer =
          ByteData(buffer.buffer.lengthInBytes + extraLength + bufferIncSize);
      newBuffer.buffer.asUint8List().setRange(
          0, buffer.buffer.lengthInBytes, buffer.buffer.asUint8List());
      buffer = newBuffer;
    }
  }

  void writeString(String string) {
    writeBytes(utf8.encode(string));
  }

  void writeBuffer(Uint8List buf) {
    _ensureAlloced(buf.lengthInBytes);
    buffer.buffer.asUint8List().setRange(pos, pos + buf.lengthInBytes, buf);
    pos += buf.lengthInBytes;
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

  void writeFloat32(double i) {
    _ensureAlloced(4);
    buffer.setFloat32(pos, i);
    pos += 4;
  }

  void writeFloat64(double i) {
    _ensureAlloced(8);
    buffer.setFloat64(pos, i);
    pos += 8;
  }

  List<int> unwrap() {
    return buffer.buffer.asUint8List(0, pos);
  }
}

final syncMessage =
    (WriteMessageBuffer(ClientMessageType.Sync)..endMessage()).unwrap();

class WriteMessageBuffer extends WriteBuffer {
  bool messageFinished = false;

  WriteMessageBuffer(ClientMessageType mtype) {
    writeUint8(mtype.value);
    writeInt32(0);
  }

  void writeFlags(int flags) {
    writeInt64(flags);
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

  void finish([String? message]) {
    if (pos != buffer.lengthInBytes) {
      throw BufferError(message ?? 'unexpected trailing data in buffer');
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

  bool readBool() {
    return readUint8() != 0;
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

  String readString() {
    return utf8.decode(readLenPrefixedBytes());
  }

  ReadBuffer slice(int size) {
    return ReadBuffer(readBytes(size));
  }

  String readUUID() {
    _checkOverread(16);
    final uuid = buffer.getUint32(pos).toRadixString(16).padLeft(8, '0') +
        buffer.getUint32(pos + 4).toRadixString(16).padLeft(8, '0') +
        buffer.getUint32(pos + 8).toRadixString(16).padLeft(8, '0') +
        buffer.getUint32(pos + 12).toRadixString(16).padLeft(8, '0');
    pos += 16;
    return uuid;
  }
}

class ReadMessageBuffer extends ReadBuffer {
  final MessageType messageType;

  ReadMessageBuffer(this.messageType, super.data);

  void ignoreHeaders() {
    var numFields = readInt16();
    while (numFields > 0) {
      discard(2);
      discard(readInt32());
      numFields--;
    }
  }

  Map<int, Uint8List> readHeaders() {
    var numFields = readInt16();
    final headers = <int, Uint8List>{};
    while (numFields > 0) {
      final key = readUint16();
      headers[key] = readLenPrefixedBytes();
      numFields--;
    }
    return headers;
  }

  void finishMessage() {
    finish();
  }
}
