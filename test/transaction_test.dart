/*!
 * This source file is part of the EdgeDB open source project.
 *
 * Copyright 2020-present MagicStack Inc. and the EdgeDB authors.
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

import 'dart:async';

import 'package:edgedb/edgedb.dart';
import 'package:test/test.dart';

import 'testbase.dart';

const typename = "TransactionTest";

Future<void> run(Future<void> Function(Client) test) async {
  final client = getClient();

  try {
    await test(client);
  } finally {
    await client.close();
  }
}

void main() {
  setUpAll(() => run((client) async {
        await client.execute('''
          CREATE TYPE $typename {
            CREATE REQUIRED PROPERTY name -> std::str;
          };
        ''');
      }));

  tearDownAll(() => run((client) async {
        await client.execute('DROP TYPE $typename;');
      }));

  test(
      "transaction: regular 01",
      () => run((client) async {
            final rawTransaction =
                client.withRetryOptions(RetryOptions(attempts: 1)).transaction;

            await expectLater(rawTransaction((tx) async {
              await tx.execute('''
                  INSERT $typename {
                    name := 'Test Transaction'
                  };
                ''');
              await tx.execute('select 1/0;');
            }), throwsA(isA<DivisionByZeroError>()));

            expect(
                await client.query(
                    "select $typename {name} filter .name = 'Test Transaction'"),
                hasLength(0));
          }));

  test(
      "transaction: kinds",
      () => run((client) async {
            for (var isolation in [null, IsolationLevel.serializable]) {
              for (var readonly in [null, true, false]) {
                for (var deferred in [null, true, false]) {
                  final opts = TransactionOptions(
                      isolation: isolation,
                      readonly: readonly,
                      deferrable: deferred);
                  await client
                      .withTransactionOptions(opts)
                      .withRetryOptions(RetryOptions(attempts: 1))
                      .transaction((tx) async {});
                  await client
                      .withTransactionOptions(opts)
                      .transaction((tx) async {});
                }
              }
            }
          }));

  test("no transaction statements", () async {
    final client = getClient();

    try {
      await expectLater(
          client.execute("start transaction"), throwsA(isA<CapabilityError>()));

      await expectLater(
          client.query("start transaction"), throwsA(isA<CapabilityError>()));

      // This test is broken, first rollback query throws CapabilityError, but
      // then second rollback query doesn't throw any error
      // https://github.com/edgedb/edgedb/issues/3120

      // await client.transaction((tx) async {
      //   await expectLater(
      //       tx.execute("rollback"), throwsA(isA<CapabilityError>()));

      //   await expectLater(
      //       tx.query("rollback"), throwsA(isA<CapabilityError>()));
      // });
    } finally {
      await client.close();
    }
  });

  test("transaction timeout", timeout: Timeout(Duration(seconds: 20)),
      () async {
    final client = getClient(concurrency: 1);

    try {
      final timer = Stopwatch()..start();
      final timedoutQueryDone = Completer();

      try {
        await client.transaction((tx) async {
          await Future.delayed(Duration(seconds: 15));

          try {
            await tx.query('select 123');
          } catch (err) {
            timedoutQueryDone.completeError(err);
          }
        });
      } catch (err) {
        expect(timer.elapsed, lessThan(Duration(seconds: 15)));
        expect(err, isA<IdleTransactionTimeoutError>());
      }

      expect(await client.querySingle('select 123'), 123);

      await expectLater(timedoutQueryDone.future,
          throwsA(isA<ClientConnectionClosedError>()));
    } finally {
      await client.close();
    }
  });

  test("transaction deadlocking client pool",
      timeout: Timeout(Duration(seconds: 20)), () async {
    final client = getClient(concurrency: 1);

    try {
      final innerQueryDone = Completer();
      dynamic innerQueryResult;

      await expectLater(client.transaction((tx) async {
        // This query will hang forever waiting on the connection holder
        // held by the transaction, which itself will not return the holder
        // to the pool until the query completes. This deadlock should be
        // resolved by the transaction timeout forcing the transaction to
        // return the holder to the pool.
        innerQueryResult = await client.querySingle('select 123');
        innerQueryDone.complete();
      }), throwsA(isA<TransactionTimeoutError>()));

      await innerQueryDone.future;
      expect(innerQueryResult, 123);
    } finally {
      await client.close();
    }
  });
}
