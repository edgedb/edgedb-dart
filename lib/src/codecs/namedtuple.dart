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
import '../utils/indent.dart';
import 'codecs.dart';

class NamedTupleField {
  final String name;
  final Codec codec;

  NamedTupleField(this.name, this.codec);
}

class NamedTupleCodec extends Codec {
  final List<NamedTupleField> fields;
  final ReturnTypeConstructor? returnType;

  NamedTupleCodec(super.tid, List<Codec> subCodecs, List<String> names,
      {this.returnType})
      : fields = List.generate(
            subCodecs.length, (i) => NamedTupleField(names[i], subCodecs[i]));

  @override
  void encode(WriteBuffer buf, dynamic object) {
    throw InvalidArgumentError(
        'Named tuples cannot be passed in query arguments');
  }

  @override
  dynamic decode(ReadBuffer buf) {
    final els = buf.readUint32();
    if (els != fields.length) {
      throw ProtocolError('cannot decode NamedTuple: expected  '
          '${fields.length} elements, got $els');
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
    return 'NamedTupleCodec ($tid) {\n'
        '${fields.map((field) => '  ${field.name}: '
            '${indent(field.codec.toString())}\n').join('')}'
        '}';
  }
}
