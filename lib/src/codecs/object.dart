import 'dart:typed_data';

import '../errors/errors.dart';
import '../primitives/buffer.dart';
import '../primitives/types.dart';
import 'codecs.dart';

class ObjectCodec extends Codec {
  final List<Codec> codecs;
  final List<String> names;
  final List<Cardinality> cardinalities;

  ObjectCodec(
    super.tid,
    this.codecs,
    List<String> names,
    List<int> flags,
    List<int> cards,
  )   : names = List.generate(names.length, (i) {
          final isLinkprop = (flags[i] & (1 << 1)) != 0;
          return isLinkprop ? '@${names[i]}' : names[i];
        }),
        cardinalities = [for (var card in cards) cardinalitiesByValue[card]!];

  @override
  void encode(WriteBuffer buf, dynamic object) {
    throw ArgumentError("Objects cannot be passed as arguments");
  }

  void encodeArgs(WriteBuffer buf, dynamic args) {
    if (names[0] == '0') {
      _encodePositionalArgs(buf, args);
    } else {
      _encodeNamedArgs(buf, args);
    }
  }

  void _encodePositionalArgs(WriteBuffer buf, dynamic args) {
    if (args is! List) {
      throw InvalidArgumentError("a List of arguments was expected");
    }

    final codecsLen = codecs.length;

    if (args.length != codecsLen) {
      throw QueryArgumentError(
          'expected $codecsLen argument${codecsLen == 1 ? "" : "s"}, got ${args.length}');
    }

    final elemData = WriteBuffer();
    for (var i = 0; i < codecsLen; i++) {
      elemData.writeInt32(0); // reserved
      final arg = args[i];
      if (arg == null) {
        final card = cardinalities[i];
        if (card == Cardinality.one || card == Cardinality.atLeastOne) {
          throw MissingArgumentError(
              'argument ${names[i]} is required, but received $arg');
        }
        elemData.writeInt32(-1);
      } else {
        codecs[i].encode(elemData, arg);
      }
    }

    final elemBuf = elemData.unwrap();
    buf.writeInt32(4 + elemBuf.length);
    buf.writeInt32(codecsLen);
    buf.writeBuffer(Uint8List.fromList(elemBuf));
  }

  void _encodeNamedArgs(WriteBuffer buf, dynamic args) {
    if (args is! Map<String, dynamic>) {
      throw InvalidArgumentError(
          "a Map<String, dynamic> of arguments was expected");
    }

    final keys = args.keys;
    final codecsLen = codecs.length;

    if (keys.length > codecsLen) {
      final extraKeys = keys.where((key) => !names.contains(key));
      throw UnknownArgumentError(
          'Unused named argument${extraKeys.length == 1 ? "" : "s"}: "${extraKeys.join('", "')}"');
    }

    final elemData = WriteBuffer();
    for (var i = 0; i < codecsLen; i++) {
      final key = names[i];
      final val = args[key];

      elemData.writeInt32(0); // reserved bytes
      if (val == null) {
        final card = cardinalities[i];
        if (card == Cardinality.one || card == Cardinality.atLeastOne) {
          throw MissingArgumentError(
              'argument ${names[i]} is required, but received $val');
        }
        elemData.writeInt32(-1);
      } else {
        codecs[i].encode(elemData, val);
      }
    }

    final elemBuf = elemData.unwrap();
    buf.writeInt32(4 + elemBuf.length);
    buf.writeInt32(codecsLen);
    buf.writeBuffer(Uint8List.fromList(elemBuf));
  }

  @override
  dynamic decode(ReadBuffer buf) {
    final els = buf.readUint32();
    if (els != codecs.length) {
      throw ProtocolError(
          'cannot decode Object: expected ${codecs.length} elements, got $els');
    }

    final result = <String, dynamic>{};
    for (var i = 0; i < els; i++) {
      buf.discard(4); // reserved
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
}
