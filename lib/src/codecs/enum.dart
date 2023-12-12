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

import "../primitives/buffer.dart";
import "text.dart";

abstract class EnumType {
  abstract final String value;
}

class EnumCodec extends StrCodec {
  final List<String> values;
  final Enum Function(String val)? fromString;

  EnumCodec(super.tid, super.typeName, this.values, {this.fromString});

  @override
  // ignore: overridden_fields
  final returnType = 'String';

  @override
  dynamic decode(ReadBuffer buf) {
    final val = super.decode(buf);

    return fromString != null ? fromString!(val) : val;
  }

  @override
  void encode(WriteBuffer buf, object) {
    super.encode(buf, object is EnumType ? object.value : object);
  }
}
