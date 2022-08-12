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
import 'codecs.dart';

const timeshift = 946684800000000;

class DateTimeCodec extends ScalarCodec {
  DateTimeCodec(super.tid);

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
    return DateTime.fromMicrosecondsSinceEpoch(buf.readInt64());
  }
}

class DurationCodec extends ScalarCodec {
  DurationCodec(super.tid);

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
