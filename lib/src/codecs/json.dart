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

import 'dart:convert';
import 'dart:typed_data';

import '../errors/errors.dart';
import '../primitives/buffer.dart';
import 'codecs.dart';

class JSONCodec extends ScalarCodec {
  JSONCodec(super.tid, super.typeName);

  @override
  void encode(WriteBuffer buf, dynamic object) {
    dynamic jsonStr;
    try {
      jsonStr = json.encode(object);
    } catch (e) {
      throw InvalidArgumentError(
          'a JSON-serializable value was expected, got "$object"');
    }
    final jsonBytes = utf8.encode(jsonStr);
    buf
      ..writeInt32(jsonBytes.length + 1)
      ..writeUint8(1)
      ..writeBuffer(Uint8List.fromList(jsonBytes));
  }

  @override
  dynamic decode(ReadBuffer buf) {
    final format = buf.readUint8();
    if (format != 1) {
      throw ProtocolError('unexpected JSON format: $format');
    }
    return json.decode(utf8.decode(buf.readBytes(buf.length)));
  }
}
