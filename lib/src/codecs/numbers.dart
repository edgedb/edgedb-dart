import '../primitives/buffer.dart';
import 'codecs.dart';

class Int16Codec extends ScalarCodec {
  Int16Codec(super.tid);

  @override
  void encode(WriteBuffer buf, dynamic object) {}

  @override
  dynamic decode(ReadBuffer buf) {}
}

class Int64Codec extends ScalarCodec {
  Int64Codec(super.tid);

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! int) {
      throw ArgumentError('an int was expected, got $object');
    }
    buf.writeInt32(8);
    buf.writeInt64(object);
  }

  @override
  dynamic decode(ReadBuffer buf) {
    return buf.readInt64();
  }
}
