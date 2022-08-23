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

import 'package:edgedb/src/scram.dart';
import 'package:test/test.dart';

void main() {
  test("scram: RFC example", () {
    // Test SCRAM-SHA-256 against an example in RFC 7677

    const username = "user";
    const password = "pencil";
    const clientNonce = "rOprNGfwEbeRWgbNEkqO";
    const serverNonce = r"rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0";
    const salt = "W22ZaJ0SNY7soEsUEjb6gQ==";
    const channelBinding = "biws";
    const iterations = 4096;

    const clientFirst = 'n=$username,r=$clientNonce';
    const serverFirst = 'r=$serverNonce,s=$salt,i=$iterations';
    const clientFinal = 'c=$channelBinding,r=$serverNonce';

    const authMessage = '$clientFirst,$serverFirst,$clientFinal';

    final saltedPassword = getSaltedPassword(
        utf8.encode(saslprep(password)), base64.decode(salt), iterations);

    final clientKey = getClientKey(saltedPassword);
    final serverKey = getServerKey(saltedPassword);
    final storedKey = h(clientKey);

    final clientSignature = hmac(storedKey, [utf8.encode(authMessage)]);
    final clientProof = xor(clientKey, clientSignature);
    final serverProof = hmac(serverKey, [utf8.encode(authMessage)]);

    expect(base64.encode(clientProof),
        "dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ=");
    expect(base64.encode(serverProof),
        "6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=");
  });
}
