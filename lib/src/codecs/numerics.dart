import '../errors/errors.dart';
import '../primitives/buffer.dart';
import 'codecs.dart';

const numericPos = 0x0000;
const numericNeg = 0x4000;
final nBase = BigInt.from(10000);

class BigIntCodec extends ScalarCodec {
  BigIntCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'BigInt';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! BigInt) {
      throw InvalidArgumentError(
          'an BigInt was expected, got ${object.runtimeType}');
    }

    if (object == BigInt.zero) {
      buf
        ..writeUint32(8) // len
        ..writeUint32(0) // ndigits + weight
        ..writeUint16(numericPos) // sign
        ..writeUint16(0); // dscale
      return;
    }

    final digits = <int>[];
    var sign = numericPos;
    var uval = object;

    if (object < BigInt.zero) {
      sign = numericNeg;
      uval = -uval;
    }

    while (uval != BigInt.zero) {
      digits.add((uval % nBase).toInt());
      uval ~/= nBase;
    }

    buf
      ..writeUint32(8 + digits.length * 2) // len
      ..writeUint16(digits.length) // ndigits
      ..writeUint16(digits.length - 1) // weight
      ..writeUint16(sign)
      ..writeUint16(0); // dscale
    for (var i = digits.length - 1; i >= 0; i--) {
      buf.writeUint16(digits[i]);
    }
  }

  @override
  BigInt decode(ReadBuffer buf) {
    return BigInt.parse(decodeBigIntToString(buf));
  }
}

String decodeBigIntToString(ReadBuffer buf) {
  final ndigits = buf.readUint16();
  final weight = buf.readInt16();
  final sign = buf.readUint16();
  final dscale = buf.readUint16();
  final result = StringBuffer();

  switch (sign) {
    case numericPos:
      break;
    case numericNeg:
      result.write('-');
      break;
    default:
      throw ProtocolError("bad bigint sign data");
  }

  if (dscale != 0) {
    throw ProtocolError("bigint data has fractional part");
  }

  if (ndigits == 0) {
    return "0";
  }

  var i = weight;
  var d = 0;

  while (i >= 0) {
    if (i <= weight && d < ndigits) {
      final digit = buf.readUint16().toString();
      result.write(d > 0 ? digit.padLeft(4, "0") : digit);
      d++;
    } else {
      result.write("0000");
    }
    i--;
  }

  return result.toString();
}
