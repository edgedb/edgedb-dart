import 'dart:typed_data';

import '../errors/errors.dart';
import '../primitives/buffer.dart';
import '../primitives/types.dart';
import '../utils/indent.dart';
import 'codecs.dart';

typedef ReturnTypeConstructor = dynamic Function(Map<String, dynamic>);

class ObjectField {
  final String name;
  final Codec codec;
  final Cardinality cardinality;

  ObjectField(this.name, this.codec, this.cardinality);
}

class ObjectCodec extends Codec {
  final List<ObjectField> fields;
  final ReturnTypeConstructor? returnType;

  ObjectCodec(
      super.tid, List<Codec> codecs, List<String> names, List<int> cards,
      {this.returnType})
      : fields = List.generate(codecs.length, (i) {
          return ObjectField(
              names[i], codecs[i], cardinalitiesByValue[cards[i]]!);
        });

  @override
  void encode(WriteBuffer buf, dynamic object) {
    throw ArgumentError("Objects cannot be passed as arguments");
  }

  void encodeArgs(WriteBuffer buf, dynamic args) {
    if (fields[0].name == '0') {
      _encodePositionalArgs(buf, args);
    } else {
      _encodeNamedArgs(buf, args);
    }
  }

  void _encodePositionalArgs(WriteBuffer buf, dynamic args) {
    if (args is! List) {
      throw InvalidArgumentError("a List of arguments was expected");
    }

    final fieldsLen = fields.length;

    if (args.length != fieldsLen) {
      throw QueryArgumentError(
          'expected $fieldsLen argument${fieldsLen == 1 ? "" : "s"}, got ${args.length}');
    }

    final elemData = WriteBuffer();
    for (var i = 0; i < fieldsLen; i++) {
      final field = fields[i];
      final arg = args[i];

      elemData.writeInt32(0); // reserved
      if (arg == null) {
        final card = field.cardinality;
        if (card == Cardinality.one || card == Cardinality.atLeastOne) {
          throw MissingArgumentError(
              'argument ${field.name} is required, but received $arg');
        }
        elemData.writeInt32(-1);
      } else {
        field.codec.encode(elemData, arg);
      }
    }

    final elemBuf = elemData.unwrap();
    buf.writeInt32(4 + elemBuf.length);
    buf.writeInt32(fieldsLen);
    buf.writeBuffer(elemBuf as Uint8List);
  }

  void _encodeNamedArgs(WriteBuffer buf, dynamic args) {
    if (args is! Map<String, dynamic>) {
      throw InvalidArgumentError(
          "a Map<String, dynamic> of arguments was expected");
    }

    final keys = args.keys;
    final fieldsLen = fields.length;

    if (keys.length > fieldsLen) {
      final validNames = fields.map((f) => f.name);
      final extraKeys = keys.where((key) => !validNames.contains(key));
      throw UnknownArgumentError(
          'Unused named argument${extraKeys.length == 1 ? "" : "s"}: "${extraKeys.join('", "')}"');
    }

    final elemData = WriteBuffer();
    for (var i = 0; i < fieldsLen; i++) {
      final field = fields[i];
      final key = field.name;
      final val = args[key];

      elemData.writeInt32(0); // reserved bytes
      if (val == null) {
        final card = field.cardinality;
        if (card == Cardinality.one || card == Cardinality.atLeastOne) {
          throw MissingArgumentError(
              'argument ${field.name} is required, but received $val');
        }
        elemData.writeInt32(-1);
      } else {
        field.codec.encode(elemData, val);
      }
    }

    final elemBuf = elemData.unwrap();
    buf.writeInt32(4 + elemBuf.length);
    buf.writeInt32(fieldsLen);
    buf.writeBuffer(elemBuf as Uint8List);
  }

  @override
  dynamic decode(ReadBuffer buf) {
    final els = buf.readUint32();
    if (els != fields.length) {
      throw ProtocolError(
          'cannot decode Object: expected ${fields.length} elements, got $els');
    }

    final result = <String, dynamic>{};
    for (var field in fields) {
      buf.discard(4); // reserved
      final elemLen = buf.readInt32();
      final name = field.name;
      if (elemLen == -1) {
        result[name] = null;
      } else {
        final elemBuf = buf.slice(elemLen);
        result[name] = field.codec.decode(elemBuf);
        elemBuf.finish();
      }
    }

    return returnType != null ? returnType!(result) : result;
  }

  @override
  String toString() {
    return 'ObjectCodec ($tid) {\n'
        '${fields.map((field) => '  ${field.name}: (${field.cardinality.name})'
            ' ${indent(field.codec.toString())}\n').join('')}'
        '}';
  }

  @override
  bool compare(Codec codec) {
    if (codec is! ObjectCodec || codec.fields.length != fields.length) {
      return false;
    }
    for (var i = 0; i < fields.length; i++) {
      if (fields[i].name != codec.fields[i].name ||
          fields[i].cardinality != codec.fields[i].cardinality ||
          !fields[i].codec.compare(codec.fields[i].codec)) {
        return false;
      }
    }
    return true;
  }
}
