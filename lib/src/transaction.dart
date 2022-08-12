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

import 'base_proto.dart';

import 'client.dart';
import 'errors/errors.dart';
import 'primitives/types.dart';

enum TransactionState { active, committed, rolledback, failed }

Future<Transaction> startTransaction(ClientConnectionHolder holder) async {
  final conn = await holder.getConnection();

  // await conn.resetState();

  final options = holder.options.transactionOptions;
  await conn.fetch(
      query:
          'start transaction isolation ${options.isolation.name}, ${options.readonly ? "read only" : "read write"}, ${options.deferrable ? "" : "not "}deferrable;',
      outputFormat: OutputFormat.none,
      expectedCardinality: Cardinality.noResult,
      state: holder.options.session,
      privilegedMode: true);

  return Transaction._(holder, conn);
}

Future<void> commit(Transaction transaction) async {
  await transaction._runOp("commit", () async {
    await transaction._conn.fetch(
        query: 'commit',
        outputFormat: OutputFormat.none,
        expectedCardinality: Cardinality.noResult,
        state: transaction._holder.options.session,
        privilegedMode: true);
    transaction._state = TransactionState.committed;
  }, "A query is still in progress after transaction block has returned.");
}

Future<void> rollback(Transaction transaction) async {
  await transaction._runOp('rollback', () async {
    await transaction._conn.fetch(
        query: 'rollback',
        outputFormat: OutputFormat.none,
        expectedCardinality: Cardinality.noResult,
        state: transaction._holder.options.session,
        privilegedMode: true);
    transaction._state = TransactionState.rolledback;
  }, "A query is still in progress after transaction block has returned.");
}

class Transaction<Connection extends BaseProtocol> implements Executor {
  final ClientConnectionHolder _holder;
  final Connection _conn;

  TransactionState _state = TransactionState.active;
  bool _opInProgress = false;

  Transaction._(this._holder, this._conn);

  // Future<void> _waitForConnAbort() {
  //   await this._rawConn.connAbortWaiter.wait();

  //   const abortError = this._rawConn.getConnAbortError();
  //   if (
  //     abortError instanceof errors.EdgeDBError &&
  //     abortError.source instanceof errors.TransactionTimeoutError
  //   ) {
  //     throw abortError.source;
  //   } else {
  //     throw abortError;
  //   }
  // }

  Future<T> _runOp<T>(String opname, Future<T> Function() op,
      [String? errMessage]) async {
    if (_opInProgress) {
      throw InterfaceError(errMessage ??
          "Another query is in progress. Use the query methods "
              "on 'Client' to run queries concurrently.");
    }
    if (_state != TransactionState.active) {
      throw InterfaceError(
          'cannot $opname; the transaction is ${_state == TransactionState.committed ? 'already committed' : _state == TransactionState.rolledback ? 'already rolled back' : 'in error state'}');
    }
    _opInProgress = true;
    try {
      return await op();
    } finally {
      _opInProgress = false;
    }
  }

  @override
  Future<void> execute(String query, [dynamic args]) async {
    await _runOp(
        'execute',
        () => _conn.fetch(
            query: query,
            args: args,
            outputFormat: OutputFormat.none,
            expectedCardinality: Cardinality.noResult,
            state: _holder.options.session));
  }

  @override
  Future<List<dynamic>> query(String query, [dynamic args]) {
    return _runOp(
        'query',
        () async => await _conn.fetch(
            query: query,
            args: args,
            outputFormat: OutputFormat.binary,
            expectedCardinality: Cardinality.many,
            state: _holder.options.session) as List<dynamic>);
  }

  @override
  Future<String> queryJSON(String query, [dynamic args]) {
    return _runOp(
        'queryJSON',
        () async => await _conn.fetch(
            query: query,
            args: args,
            outputFormat: OutputFormat.json,
            expectedCardinality: Cardinality.many,
            state: _holder.options.session) as String);
  }

  @override
  Future<dynamic> querySingle(String query, [dynamic args]) {
    return _runOp(
        'querySingle',
        () => _conn.fetch(
            query: query,
            args: args,
            outputFormat: OutputFormat.binary,
            expectedCardinality: Cardinality.atMostOne,
            state: _holder.options.session));
  }

  @override
  Future<String> querySingleJSON(String query, [dynamic args]) {
    return _runOp(
        'querySingleJSON',
        () async => await _conn.fetch(
            query: query,
            args: args,
            outputFormat: OutputFormat.json,
            expectedCardinality: Cardinality.atMostOne,
            state: _holder.options.session) as String);
  }

  @override
  Future<dynamic> queryRequiredSingle(String query, [dynamic args]) {
    return _runOp(
        'querySingle',
        () => _conn.fetch(
            query: query,
            args: args,
            outputFormat: OutputFormat.binary,
            expectedCardinality: Cardinality.one,
            state: _holder.options.session));
  }

  @override
  Future<String> queryRequiredSingleJSON(String query, [dynamic args]) {
    return _runOp(
        'querySingle',
        () async => await _conn.fetch(
            query: query,
            args: args,
            outputFormat: OutputFormat.binary,
            expectedCardinality: Cardinality.one,
            state: _holder.options.session) as String);
  }
}
