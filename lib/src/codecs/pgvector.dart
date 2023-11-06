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
import 'codecs.dart';

const pgvectorMaxDim = (1 << 16) - 1;

class PgVectorCodec extends ScalarCodec {
  PgVectorCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'Float32List';
  @override
  // ignore: overridden_fields
  final returnTypeImport = 'dart:typed_data';
  @override
  // ignore: overridden_fields
  final argType = 'List<double>';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! List<double>) {
      throw InvalidArgumentError(
          'a Float32List or List<double> was expected, got "${object.runtimeType}"');
    }
    if (object.length > pgvectorMaxDim) {
      throw InvalidArgumentError(
          'too many elements in List to encode into pgvector');
    }

    buf
      ..writeInt32(4 + object.length * 4)
      ..writeUint16(object.length)
      ..writeUint16(0);
    for (var el in object) {
      buf.writeFloat32(el);
    }
  }

  @override
  Float32List decode(ReadBuffer buf) {
    final dim = buf.readUint16();
    buf.discard(2);

    final data = ByteData.sublistView(buf.readBytes(dim * 4));
    final vec = Float32List(dim);

    for (var i = 0; i < dim; i++) {
      vec[i] = data.getFloat32(i * 4);
    }

    return vec;
  }
}
