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

import '../errors/errors.dart';
import '../primitives/buffer.dart';
import 'codecs.dart';

class StrCodec extends ScalarCodec {
  StrCodec(super.tid, super.typeName);

  @override
  // ignore: overridden_fields
  final returnType = 'String';

  @override
  void encode(WriteBuffer buf, dynamic object) {
    if (object is! String) {
      throw InvalidArgumentError(
          'a string was expected, got "${object.runtimeType}"');
    }
    buf.writeString(object);
  }

  @override
  String decode(ReadBuffer buf) {
    return utf8.decode(buf.readBytes(buf.length));
  }
}
