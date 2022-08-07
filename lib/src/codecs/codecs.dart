import 'dart:typed_data';

import 'package:edgedb/src/codecs/consts.dart';

import '../primitives/buffer.dart';
import 'numbers.dart';
import 'registry.dart';

abstract class Codec {
  final String tid;
  late final Uint8List tidBuffer;

  Codec(this.tid) {
    if (tid.length != 32) {
      throw ArgumentError('invalid uuid');
    }
    tidBuffer = Uint8List.fromList(List.generate(
        16, (int i) => int.parse(tid.substring(i * 2, i * 2 + 2), radix: 16),
        growable: false));
  }

  void encode(WriteBuffer buf, dynamic object);
  dynamic decode(ReadBuffer buf);
}

abstract class ScalarCodec extends Codec {
  ScalarCodec(super.tid);
}

class NullCodec extends Codec {
  NullCodec() : super(nullCodecID);

  @override
  void encode(WriteBuffer buf, dynamic object) {
    throw CodecError("null codec cannot used to encode data");
  }

  @override
  dynamic decode(ReadBuffer buf) {
    throw CodecError("null codec cannot used to decode data");
  }
}

final nullCodec = NullCodec();

final scalarCodecs = {
  'std::int16': Int16Codec.new,
  'std::int64': Int64Codec.new
}.map<String, Codec>((typename, type) {
  final id = knownTypeNames[typename];
  if (id == null) {
    throw CodecError("unknown codec type name");
  }
  return MapEntry(id, type(id));
});
