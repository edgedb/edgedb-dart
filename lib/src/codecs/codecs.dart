import 'dart:typed_data';

import '../errors/errors.dart';
import '../primitives/buffer.dart';
import 'boolean.dart';
import 'bytes.dart';
import 'consts.dart';
import 'datetime.dart';
import 'json.dart';
import 'memory.dart';
import 'numbers.dart';
import 'numerics.dart';
import 'text.dart';
import 'uuid.dart';

export 'array.dart';
export 'enum.dart';
export 'namedtuple.dart';
export 'object.dart';
export 'set.dart';
export 'tuple.dart';

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

  @override
  String toString() {
    return '$runtimeType ($tid)';
  }
}

abstract class ScalarCodec extends Codec {
  ScalarCodec(super.tid);

  final String returnType = 'dynamic';
  final String? returnTypeImport = null;

  derive(String tid) {
    return _scalarCodecConstructors[this.tid]!(this.tid);
  }
}

class NullCodec extends Codec {
  NullCodec([String? codecId]) : super(codecId ?? nullCodecID);

  @override
  void encode(WriteBuffer buf, dynamic object) {
    throw InternalClientError("null codec cannot used to encode data");
  }

  @override
  dynamic decode(ReadBuffer buf) {
    throw InternalClientError("null codec cannot used to decode data");
  }
}

final nullCodec = NullCodec();
final invalidCodec = NullCodec(invalidCodecID);

final _scalarCodecConstructors = {
  'std::int16': Int16Codec.new,
  'std::int32': Int32Codec.new,
  'std::int64': Int64Codec.new,
  'std::float32': Float32Codec.new,
  'std::float64': Float64Codec.new,
  'std::bigint': BigIntCodec.new,
  'std::bool': BoolCodec.new,
  'std::json': JSONCodec.new,
  'std::str': StrCodec.new,
  'std::bytes': BytesCodec.new,
  'std::uuid': UUIDCodec.new,
  'std::datetime': DateTimeCodec.new,
  'std::duration': DurationCodec.new,
  // 'cal::local_date': LocalDateCodec.new,
  // 'cal::local_time': LocalTimeCodec.new,
  // 'cal::local_datetime': LocalDateTimeCodec.new,
  // 'cal::relative_duration': RelativeDurationCodec.new,
  // 'cal::date_duration': DateDurationCodec.new,
  'cfg::memory': ConfigMemoryCodec.new,
}.map<String, ScalarCodec Function(String)>((typename, type) {
  final id = knownTypeNames[typename];
  if (id == null) {
    throw InternalClientError("unknown codec type name");
  }
  return MapEntry(id, type);
});

final scalarCodecs = {
  for (var codec in _scalarCodecConstructors.entries)
    codec.key: codec.value(codec.key)
};
