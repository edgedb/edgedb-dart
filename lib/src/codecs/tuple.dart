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

import 'package:edgedb/src/codecs/consts.dart';

import '../primitives/buffer.dart';
import 'codecs.dart';
import 'registry.dart';

class TupleCodec extends Codec {
  final List<Codec> subCodecs;

  TupleCodec(super.tid, this.subCodecs);

  @override
  void encode(WriteBuffer buf, dynamic object) {
    throw CodecError("Tuples cannot be passed in query arguments");
  }

  // encodeArgs(args: any): Buffer {
  //   if (!Array.isArray(args)) {
  //     throw new Error("an array of arguments was expected");
  //   }

  //   const codecs = this.subCodecs;
  //   const codecsLen = codecs.length;

  //   if (args.length !== codecsLen) {
  //     throw new Error(
  //       `expected ${codecsLen} argument${codecsLen === 1 ? "" : "s"}, got ${
  //         args.length
  //       }`
  //     );
  //   }

  //   if (!codecsLen) {
  //     return EmptyTupleCodec.BUFFER;
  //   }

  //   const elemData = new WriteBuffer();
  //   for (let i = 0; i < codecsLen; i++) {
  //     const arg = args[i];
  //     elemData.writeInt32(0); // reserved bytes
  //     if (arg == null) {
  //       elemData.writeInt32(-1);
  //     } else {
  //       const codec = codecs[i];
  //       codec.encode(elemData, arg);
  //     }
  //   }

  //   const elemBuf = elemData.unwrap();
  //   const buf = new WriteBuffer();
  //   buf.writeInt32(4 + elemBuf.length);
  //   buf.writeInt32(codecsLen);
  //   buf.writeBuffer(elemBuf);
  //   return buf.unwrap();
  // }

  @override
  dynamic decode(ReadBuffer buf) {
    final els = buf.readUint32();
    if (els != subCodecs.length) {
      throw CodecError('cannot decode Tuple: expected '
          '${subCodecs.length} elements, got $els');
    }

    const result = [];
    for (var i = 0; i < els; i++) {
      buf.discard(4); // reserved
      final elemLen = buf.readInt32();
      if (elemLen == -1) {
        result[i] = null;
      } else {
        final elemBuf = buf.slice(elemLen);
        result[i] = subCodecs[i].decode(elemBuf);
        elemBuf.finish();
      }
    }

    return result;
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
      throw ArgumentError('cannot encode empty Tuple: expected an array');
    }
    if (object.isNotEmpty) {
      throw ArgumentError(
          'cannot encode empty Tuple: expected 0 elements got ${object.length}');
    }
    buf.writeInt32(4);
    buf.writeInt32(0);
  }

  @override
  dynamic decode(ReadBuffer buf) {
    final els = buf.readInt32();
    if (els != 0) {
      throw CodecError(
          'cannot decode empty Tuple: expected 0 elements, received ${els}');
    }
    return [];
  }
}

final emptyTupleCodec = EmptyTupleCodec(emptyTupleCodecID);
