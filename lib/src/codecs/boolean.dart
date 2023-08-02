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

class BoolCodec extends ScalarCodec {
  BoolCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'bool';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! bool) {
      throw InvalidArgumentError(
          'a boolean was expected, got "${object.runtimeType}"');
    }
    buf.writeInt32(1);
    buf.writeUint8(object ? 1 : 0);
  }

  @override
  bool decode(ReadBuffer buf) {
    return buf.readUint8() != 0;
  }
}
