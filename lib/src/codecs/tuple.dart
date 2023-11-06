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
import 'consts.dart';

typedef TupleReturnTypeConstructor = dynamic Function(List<dynamic>);

abstract class EdgeDBTuple {
  List<dynamic> toList();
}

class TupleCodec extends Codec {
  final List<Codec> subCodecs;
  final TupleReturnTypeConstructor? returnType;
  final String? typeName;

  TupleCodec(super.tid, this.typeName, this.subCodecs, {this.returnType});

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! List && object is! EdgeDBTuple) {
      throw InvalidArgumentError(
          'a List or EdgeDBTuple was expected, got "${object.runtimeType}"');
    }

    final els = object is EdgeDBTuple ? object.toList() : object as List;

    final elsLen = subCodecs.length;

    if (els.length != elsLen) {
      throw QueryArgumentError(
          'expected $elsLen element${elsLen == 1 ? "" : "s"} in Tuple, got ${els.length}');
    }

    final elemData = WriteBuffer();
    for (var i = 0; i < elsLen; i++) {
      final el = els[i];

      if (el == null) {
        throw MissingArgumentError(
            "element at index $i in Tuple cannot be 'null'");
      } else {
        elemData.writeInt32(0); // reserved
        try {
          subCodecs[i].encode(elemData, el);
        } on QueryArgumentError catch (e) {
          throw InvalidArgumentError(
              'invalid element at index $i in Tuple: ${e.message}');
        }
      }
    }

    final elemBuf = elemData.unwrap();
    buf.writeInt32(4 + elemBuf.length);
    buf.writeInt32(elsLen);
    buf.writeBuffer(elemBuf as Uint8List);
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
