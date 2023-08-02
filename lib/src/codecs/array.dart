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

import '../errors/errors.dart';
import '../primitives/buffer.dart';
import '../utils/indent.dart';
import 'codecs.dart';

class ArrayCodec<T> extends Codec {
  final Codec subCodec;
  final int length;
  final String? typeName;

  ArrayCodec(super.tid, this.typeName, this.subCodec, this.length);

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (!(subCodec is ScalarCodec ||
        subCodec is TupleCodec ||
        subCodec is NamedTupleCodec ||
        subCodec is RangeCodec ||
        subCodec is MultiRangeCodec)) {
      throw InvalidArgumentError(
          "only arrays of scalars or tuples are supported");
    }

    if (object is! List) {
      throw InvalidArgumentError("a list was expected");
    }

    final elemData = WriteBuffer();
    final objLen = object.length;

    if (objLen > 0x7fffffff) {
      // objLen > MAXINT32
      throw InvalidArgumentError("too many elements in array");
    }

    for (var i = 0; i < objLen; i++) {
      final item = object[i];
      if (item == null) {
        elemData.writeInt32(-1);
      } else {
        subCodec.encode(elemData, item);
      }
    }
    final elemBuf = elemData.unwrap();

    buf.writeInt32(12 + 8 + elemBuf.length);
    buf.writeInt32(1); // number of dimensions
    buf.writeInt32(0); // flags
    buf.writeInt32(0); // reserved

    buf.writeInt32(objLen);
    buf.writeInt32(1);

    buf.writeBuffer(elemBuf as Uint8List);
  }

  @override
  dynamic decode(ReadBuffer buf) {
    final ndims = buf.readInt32();

    buf.discard(8); // ignore flags + reserved

    if (ndims == 0) {
      return [];
    }
    if (ndims != 1) {
      throw ProtocolError("only 1-dimensional arrays are supported");
    }

    final len = buf.readUint32();
    if (length != -1 && len != length) {
      throw ProtocolError(
          'invalid array size: received $len, expected $length');
    }

    buf.discard(4); // ignore the lower bound info

    final result = <T>[];

    for (var i = 0; i < len; i++) {
      final elemLen = buf.readInt32();
      if (elemLen == -1) {
        throw ProtocolError("unexpected NULL value in array");
      } else {
        final elemBuf = buf.slice(elemLen);
        result.add(subCodec.decode(elemBuf));
        elemBuf.finish();
      }
    }

    return result;
  }

  @override
  String toString() {
    return 'ArrayCodec ($tid) $length {\n  ${indent(subCodec.toString())}\n}';
  }

  @override
  bool compare(Codec codec) {
    return codec is ArrayCodec && codec.subCodec.compare(subCodec);
  }
}
