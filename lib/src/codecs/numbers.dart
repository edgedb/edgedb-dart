import '../errors/errors.dart';
import '../primitives/buffer.dart';
import 'codecs.dart';

class Int16Codec extends ScalarCodec {
  Int16Codec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'int';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! int) {
      throw InvalidArgumentError(
          'an int was expected, got ${object.runtimeType}');
    }
    buf.writeInt32(2);
    buf.writeInt16(object);
  }

  @override
  int decode(ReadBuffer buf) {
    return buf.readInt16();
  }
}

class Int32Codec extends ScalarCodec {
  Int32Codec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'int';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! int) {
      throw InvalidArgumentError(
          'an int was expected, got ${object.runtimeType}');
    }
    buf.writeInt32(4);
    buf.writeInt32(object);
  }

  @override
  int decode(ReadBuffer buf) {
    return buf.readInt32();
  }
}

class Int64Codec extends ScalarCodec {
  Int64Codec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'int';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! int) {
      throw InvalidArgumentError(
          'an int was expected, got ${object.runtimeType}');
    }
    buf.writeInt32(8);
    buf.writeInt64(object);
  }

  @override
  int decode(ReadBuffer buf) {
    return buf.readInt64();
  }
}

class Float32Codec extends ScalarCodec {
  Float32Codec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'double';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! num) {
      throw InvalidArgumentError(
          'an num was expected, got ${object.runtimeType}');
    }
    buf.writeInt32(4);
    buf.writeFloat32(object.toDouble());
  }

  @override
  double decode(ReadBuffer buf) {
    return buf.readFloat32();
  }
}

class Float64Codec extends ScalarCodec {
  Float64Codec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'double';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! num) {
      throw InvalidArgumentError(
          'an num was expected, got ${object.runtimeType}');
    }
    buf.writeInt32(8);
    buf.writeFloat64(object.toDouble());
  }

  @override
  double decode(ReadBuffer buf) {
    return buf.readFloat64();
  }
}
