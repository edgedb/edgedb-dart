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
import 'consts.dart';

typedef TupleReturnTypeConstructor = dynamic Function(List<dynamic>);

class TupleCodec extends Codec {
  final List<Codec> subCodecs;
  final TupleReturnTypeConstructor? returnType;

  TupleCodec(super.tid, this.subCodecs, {this.returnType});

  @override
  void encode(WriteBuffer buf, dynamic object) {
    throw InvalidArgumentError("Tuples cannot be passed in query arguments");
  }

  @override
  dynamic decode(ReadBuffer buf) {
    final els = buf.readUint32();
    if (els != subCodecs.length) {
      throw ProtocolError('cannot decode Tuple: expected '
          '${subCodecs.length} elements, got $els');
    }

    final result = [];
    for (var i = 0; i < els; i++) {
      buf.discard(4); // reserved
      final elemLen = buf.readInt32();
      if (elemLen == -1) {
        result.add(null);
      } else {
        final elemBuf = buf.slice(elemLen);
        result.add(subCodecs[i].decode(elemBuf));
        elemBuf.finish();
      }
    }

    return returnType != null ? returnType!(result) : result;
  }

  @override
  String toString() {
    var i = 0;
    return 'TupleCodec ($tid) {\n'
        '${subCodecs.map((subCodec) => '  ${i++}: '
            '${indent(subCodec.toString())}\n').join('')}'
        '}';
  }

  @override
  bool compare(Codec codec) {
    if (codec is! TupleCodec || codec.subCodecs.length != subCodecs.length) {
      return false;
    }
    for (var i = 0; i < subCodecs.length; i++) {
      if (!subCodecs[i].compare(codec.subCodecs[i])) {
        return false;
      }
    }
    return true;
  }
}

final emptyTupleCodecBuffer = (WriteBuffer()
      ..writeInt32(4)
      ..writeInt32(0))
    .unwrap();

class EmptyTupleCodec extends Codec {
  EmptyTupleCodec(super.tid);

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! List) {
      throw InvalidArgumentError(
          'cannot encode empty Tuple: expected an array');
    }
    if (object.isNotEmpty) {
      throw InvalidArgumentError(
          'cannot encode empty Tuple: expected 0 elements got ${object.length}');
    }
    buf.writeInt32(4);
    buf.writeInt32(0);
  }

  @override
  dynamic decode(ReadBuffer buf) {
    final els = buf.readInt32();
    if (els != 0) {
      throw ProtocolError(
          'cannot decode empty Tuple: expected 0 elements, received $els');
    }
    return [];
  }

  @override
  bool compare(Codec codec) {
    return codec is EmptyTupleCodec;
  }
}

final emptyTupleCodec = EmptyTupleCodec(emptyTupleCodecID);
