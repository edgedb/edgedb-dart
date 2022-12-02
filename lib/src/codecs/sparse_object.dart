import 'dart:typed_data';

import '../errors/errors.dart';
import '../primitives/buffer.dart';
import 'codecs.dart';

class SparseObjectCodec extends Codec {
  final List<Codec> codecs;
  final List<String> names;

  SparseObjectCodec(
    super.tid,
    this.codecs,
    this.names,
  );

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! Map<String, dynamic>) {
      throw InvalidArgumentError(
          "a Map<String, dynamic> was expected, got ${object.runtimeType}");
    }

    final elemBuf = WriteBuffer();

    var objLen = 0;
    for (var entry in object.entries) {
      final i = names.indexOf(entry.key);
      if (i == -1) {
        throw UnknownArgumentError(
            'invalid global "${entry.key}", ${names.isEmpty ? 'no valid globals exist' : 'valid globals are "${names.join('", "')}"'}');
      }
      objLen += 1;
      elemBuf.writeInt32(i);
      if (entry.value == null) {
        elemBuf.writeInt32(-1);
      } else {
        codecs[i].encode(elemBuf, entry.value);
      }
    }

    final elemData = elemBuf.unwrap();
    buf.writeInt32(4 + elemData.length);
    buf.writeInt32(objLen);
    buf.writeBuffer(elemData as Uint8List);
  }

  @override
  dynamic decode(ReadBuffer buf) {
    final els = buf.readUint32();

    final result = <String, dynamic>{};
    for (var ei = 0; ei < els; ei++) {
      final i = buf.readUint32();
      final elemLen = buf.readInt32();
      final name = names[i];
      if (elemLen == -1) {
        result[name] = null;
      } else {
        final elemBuf = buf.slice(elemLen);
        result[name] = codecs[i].decode(elemBuf);
        elemBuf.finish();
      }
    }

    return result;
  }

  @override
  bool compare(Codec codec) {
    if (codec is! SparseObjectCodec || codec.codecs.length != codecs.length) {
      return false;
    }
    for (var i = 0; i < codecs.length; i++) {
      if (names[i] != codec.names[i] || !codecs[i].compare(codec.codecs[i])) {
        return false;
      }
    }
    return true;
  }
}
