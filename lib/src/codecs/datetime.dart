/*!
 * This source file is part of the EdgeDB open source project.
 *
 * Copyright 2019-present MagicStack Inc. and the EdgeDB authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import '../errors/errors.dart';
import '../primitives/buffer.dart';
import '../datatypes/datetime.dart';
import 'codecs.dart';

const timeshift = 946684800000000;
final epochDate = DateTime.utc(2000, 1, 1);

class DateTimeCodec extends ScalarCodec {
  DateTimeCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'DateTime';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! DateTime) {
      throw InvalidArgumentError(
          'a DateTime was expected, got "${object.runtimeType}"');
    }
    buf.writeInt32(8);
    buf.writeInt64(object.microsecondsSinceEpoch - timeshift);
  }

  @override
  DateTime decode(ReadBuffer buf) {
    return DateTime.fromMicrosecondsSinceEpoch(buf.readInt64() + timeshift,
        isUtc: true);
  }
}

class LocalDateTimeCodec extends ScalarCodec {
  LocalDateTimeCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'LocalDateTime';
  @override
  // ignore: overridden_fields
  final returnTypeImport = 'package:edgedb/edgedb.dart';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! LocalDateTime) {
      throw InvalidArgumentError(
          'a LocalDateTime was expected, got "${object.runtimeType}"');
    }
    buf.writeInt32(8);
    buf.writeInt64(getDateTimeFromLocalDateTime(object).microsecondsSinceEpoch -
        timeshift);
  }

  @override
  LocalDateTime decode(ReadBuffer buf) {
    return LocalDateTime.fromDateTime(DateTime.fromMicrosecondsSinceEpoch(
        buf.readInt64() + timeshift,
        isUtc: true));
  }
}

class LocalDateCodec extends ScalarCodec {
  LocalDateCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'LocalDate';
  @override
  // ignore: overridden_fields
  final returnTypeImport = 'package:edgedb/edgedb.dart';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! LocalDate) {
      throw InvalidArgumentError(
          'a LocalDate was expected, got "${object.runtimeType}"');
    }
    final date = getDateTimeFromLocalDate(object);

    buf.writeInt32(4);
    buf.writeInt32(date.difference(epochDate).inDays);
  }

  @override
  LocalDate decode(ReadBuffer buf) {
    return LocalDate.fromDateTime(
        epochDate.add(Duration(days: buf.readInt32())));
  }
}

class LocalTimeCodec extends ScalarCodec {
  LocalTimeCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'LocalTime';
  @override
  // ignore: overridden_fields
  final returnTypeImport = 'package:edgedb/edgedb.dart';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! LocalTime) {
      throw InvalidArgumentError(
          'a LocalTime was expected, got "${object.runtimeType}"');
    }
    buf.writeInt32(8);
    buf.writeInt64(getDateTimeFromLocalTime(object).microsecondsSinceEpoch);
  }

  @override
  LocalTime decode(ReadBuffer buf) {
    return LocalTime.fromDateTime(
        DateTime.fromMicrosecondsSinceEpoch(buf.readInt64(), isUtc: true));
  }
}

class DurationCodec extends ScalarCodec {
  DurationCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'Duration';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! Duration) {
      throw InvalidArgumentError(
          'a Duration was expected, got "${object.runtimeType}"');
    }
    buf
      ..writeInt32(16)
      ..writeInt64(object.inMicroseconds)
      ..writeInt32(0)
      ..writeInt32(0);
  }

  @override
  Duration decode(ReadBuffer buf) {
    final us = buf.readInt64();
    if (buf.readInt32() != 0 || buf.readInt32() != 0) {
      throw ProtocolError('non-zero reserved bytes in duration');
    }

    return Duration(microseconds: us);
  }
}

class RelativeDurationCodec extends ScalarCodec {
  RelativeDurationCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'RelativeDuration';
  @override
  // ignore: overridden_fields
  final returnTypeImport = 'package:edgedb/edgedb.dart';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! RelativeDuration) {
      throw InvalidArgumentError(
          'a RelativeDuration was expected, got "${object.runtimeType}"');
    }
    buf
      ..writeInt32(16)
      ..writeInt64(object.microseconds)
      ..writeInt32(object.days)
      ..writeInt32(object.months);
  }

  @override
  RelativeDuration decode(ReadBuffer buf) {
    final us = buf.readInt64();
    final days = buf.readInt32();
    final months = buf.readInt32();

    return RelativeDuration(microseconds: us, days: days, months: months);
  }
}

class DateDurationCodec extends ScalarCodec {
  DateDurationCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'DateDuration';
  @override
  // ignore: overridden_fields
  final returnTypeImport = 'package:edgedb/edgedb.dart';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! DateDuration) {
      throw InvalidArgumentError(
          'a DateDuration was expected, got "${object.runtimeType}"');
    }
    buf
      ..writeInt32(16)
      ..writeInt64(0)
      ..writeInt32(object.days)
      ..writeInt32(object.months);
  }

  @override
  DateDuration decode(ReadBuffer buf) {
    if (buf.readInt64() != 0) {
      throw ProtocolError('non-zero reserved bytes in cal::date_duration');
    }
    final days = buf.readInt32();
    final months = buf.readInt32();

    return DateDuration(days: days, months: months);
  }
}
