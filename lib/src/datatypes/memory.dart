// ignore_for_file: constant_identifier_names

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

const KiB = 1024;
const MiB = 1024 * KiB;
const GiB = 1024 * MiB;
const TiB = 1024 * GiB;
const PiB = 1024 * TiB;

class ConfigMemory {
  final int _bytes;

  ConfigMemory(this._bytes);

  int get bytes {
    return _bytes;
  }

  num get kibibytes {
    return _bytes / KiB;
  }

  num get mebibytes {
    return _bytes / MiB;
  }

  num get gibibytes {
    return _bytes / GiB;
  }

  num get tebibytes {
    return _bytes / TiB;
  }

  num get pebibytes {
    return _bytes / PiB;
  }

  @override
  String toString() {
    if (_bytes >= PiB && _bytes % PiB == 0) {
      return '${_bytes ~/ PiB}PiB';
    }
    if (_bytes >= TiB && _bytes % TiB == 0) {
      return '${_bytes ~/ TiB}TiB';
    }
    if (_bytes >= GiB && _bytes % GiB == 0) {
      return '${_bytes ~/ GiB}GiB';
    }
    if (_bytes >= MiB && _bytes % MiB == 0) {
      return '${_bytes ~/ MiB}MiB';
    }
    if (_bytes >= KiB && _bytes % KiB == 0) {
      return '${_bytes ~/ KiB}KiB';
    }
    return '${_bytes}B';
  }
}
