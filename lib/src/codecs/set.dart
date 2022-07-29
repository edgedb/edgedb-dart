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

import '../primitives/buffer.dart';
import 'array.dart';
import 'codecs.dart';
import 'registry.dart';

class SetCodec extends Codec {
  final Codec subCodec;

  SetCodec(super.tid, this.subCodec);

  @override
  void encode(WriteBuffer buf, dynamic object) {
    throw CodecError("Sets cannot be passed in query arguments");
  }

  @override
  dynamic decode(ReadBuffer buf) {
    if (subCodec is ArrayCodec) {
      return _decodeSetOfArrays(buf);
    } else {
      return _decodeSet(buf);
    }
  }

  dynamic _decodeSetOfArrays(ReadBuffer buf) {
    final ndims = buf.readInt32();

    buf.discard(4); // ignore flags
    buf.discard(4); // reserved

    if (ndims == 0) {
      return [];
    }
    if (ndims != 1) {
      throw CodecError('expected 1-dimensional array of records of arrays');
    }

    final len = buf.readUint32();

    buf.discard(4); // ignore the lower bound info

    final result = [];

    for (var i = 0; i < len; i++) {
      buf.discard(4); // ignore array element size

      final recSize = buf.readUint32();
      if (recSize != 1) {
        throw CodecError(
            "expected a record with a single element as an array set "
            "element envelope");
      }

      buf.discard(4); // reserved

      final elemLen = buf.readInt32();
      if (elemLen == -1) {
        throw CodecError("unexpected NULL value in array set element");
      }

      final elemBuf = buf.slice(elemLen);
      result[i] = subCodec.decode(elemBuf);
      elemBuf.finish();
    }

    return result;
  }

  dynamic _decodeSet(ReadBuffer buf) {
    final ndims = buf.readInt32();

    buf.discard(4); // ignore flags
    buf.discard(4); // reserved

    if (ndims == 0) {
      return [];
    }
    if (ndims != 1) {
      throw CodecError('invalid set dimensinality: $ndims');
    }

    final len = buf.readUint32();

    buf.discard(4); // ignore the lower bound info

    const result = [];

    for (var i = 0; i < len; i++) {
      final elemLen = buf.readInt32();
      if (elemLen == -1) {
        result[i] = null;
      } else {
        final elemBuf = buf.slice(elemLen);
        result[i] = subCodec.decode(elemBuf);
        elemBuf.finish();
      }
    }

    return result;
  }
}
