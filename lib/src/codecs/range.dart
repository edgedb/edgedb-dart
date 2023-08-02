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

import 'dart:typed_data';

import '../datatypes/range.dart';
import '../errors/errors.dart';
import '../primitives/buffer.dart';
import '../utils/indent.dart';
import 'codecs.dart';

enum RangeFlags {
  empty(1 << 0),
  incLower(1 << 1),
  incUpper(1 << 2),
  emptyLower(1 << 3),
  emptyUpper(1 << 4);

  final int value;
  const RangeFlags(this.value);
}

class RangeCodec<T> extends Codec {
  final Codec subCodec;
  final String? typeName;

  RangeCodec(super.tid, this.typeName, this.subCodec);

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! Range) {
      throw InvalidArgumentError(
          "a 'Range' type was expected, got '${object.runtimeType}'");
    }

    final elemData = WriteBuffer();
    if (object.lower != null) {
      subCodec.encode(elemData, object.lower);
    }
    if (object.upper != null) {
      subCodec.encode(elemData, object.upper);
    }

    final elemBuf = elemData.unwrap();
    buf
      ..writeInt32(elemBuf.length + 1)
      ..writeUint8(object.isEmpty
          ? RangeFlags.empty.value
          : (object.incLower ? RangeFlags.incLower.value : 0) |
              (object.incUpper ? RangeFlags.incUpper.value : 0) |
              (object.lower == null ? RangeFlags.emptyLower.value : 0) |
              (object.upper == null ? RangeFlags.emptyUpper.value : 0))
      ..writeBuffer(elemBuf as Uint8List);
  }

  @override
  dynamic decode(ReadBuffer buf) {
    final flags = buf.readUint8();

    if (flags & RangeFlags.empty.value != 0) {
      return Range.empty();
    }

    T? lower;
    T? upper;

    if (flags & RangeFlags.emptyLower.value == 0) {
      final elemBuf = buf.slice(buf.readInt32());
      lower = subCodec.decode(elemBuf);
      elemBuf.finish();
    }

    if (flags & RangeFlags.emptyUpper.value == 0) {
      final elemBuf = buf.slice(buf.readInt32());
      upper = subCodec.decode(elemBuf);
      elemBuf.finish();
    }

    return Range<T>(lower, upper,
        incLower: flags & RangeFlags.incLower.value != 0,
        incUpper: flags & RangeFlags.incUpper.value != 0);
  }

  @override
  String toString() {
    return 'RangeCodec ($tid) {\n  ${indent(subCodec.toString())}\n}';
  }

  @override
  bool compare(Codec codec) {
    return codec is RangeCodec && subCodec.compare(codec.subCodec);
  }
}
