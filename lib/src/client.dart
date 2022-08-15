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
import 'dart:developer';

import 'base_proto.dart';
import 'codecs/codecs.dart';
import 'codecs/registry.dart';
import 'connect_config.dart';
import 'errors/errors.dart';
import 'options.dart';
import 'primitives/queues.dart';
import 'primitives/types.dart';
import 'retry_connect.dart';
import 'tcp_proto.dart';
import 'transaction.dart';

class ClientConnectionHolder<Connection extends BaseProtocol> {
  final ClientPool<Connection> _pool;
  Connection? _connection;
  Options? _options;
  Completer<void>? _inUse;

  ClientConnectionHolder(this._pool);

  Options get options {
    return _options ?? Options.defaults();
  }

  Future<Connection> getConnection() async {
    if (!connectionOpen) {
      _connection = await _pool.getNewConnection();
    }
    return _connection!;
  }

  bool get connectionOpen {
    return _connection != null && !_connection!.isClosed;
  }

  Future<ClientConnectionHolder> acquire(Options options) async {
    if (_inUse != null) {
      throw InternalClientError(
          'ClientConnectionHolder cannot be acquired, already in use');
    }

    _options = options;
    _inUse = Completer();

    return this;
  }

  Future<void> release() async {
    if (_inUse == null) {
      throw ClientError(
          'ClientConnectionHolder.release() called on a free connection holder');
    }

    _options = null;

    // await this._connection?.resetState();

    if (!_inUse!.isCompleted) {
      _inUse!.complete();
    }
    _inUse = null;

    // Put ourselves back to the pool queue.
    _pool.enqueue(this);
  }

  Future<void> _waitUntilReleasedAndClose() async {
    if (_inUse != null) {
      await _inUse!.future;
    }
    await _connection?.close();
  }

  void terminate() {
    _connection?.close();
  }

  Future<T> transaction<T>(Future<T> Function(Transaction) action) async {
    T result;
    for (var iteration = 0; true; ++iteration) {
      final transaction = await startTransaction(this);

      var commitFailed = false;
      try {
        result = await Future.any([
          action(transaction),
          // transaction._waitForConnAbort(),
        ]);
        try {
          await commit(transaction);
        } catch (err) {
          commitFailed = true;
          rethrow;
        }
      } catch (err) {
        try {
          if (!commitFailed) {
            await rollback(transaction);
          }
        } catch (rollbackErr) {
          if (rollbackErr is! EdgeDBError) {
            // We ignore EdgeDBError errors on rollback, retrying
            // if possible. All other errors are propagated.
            rethrow;
          }
        }
        if (err is EdgeDBError &&
            err.hasTag(EdgeDBErrorTag.shouldRetry) &&
            !(commitFailed && err is ClientConnectionError)) {
          final rule = options.retryOptions.getRuleForException(err);
          if (iteration + 1 >= rule.attempts) {
            rethrow;
          }
          await Future.delayed(rule.backoff(iteration + 1));
          continue;
        }
        rethrow;
      }
      return result;
    }
  }

  Future<dynamic> _retryingFetch<T>(
      {required String query,
      dynamic args,
      required OutputFormat outputFormat,
      required Cardinality expectedCardinality,
      Codec? inCodec,
      Codec? outCodec}) async {
    dynamic result;
    for (var iteration = 0; true; iteration++) {
      final conn = await getConnection();
      try {
        result = await conn.fetch<T>(
            query: query,
            args: args,
            outputFormat: outputFormat,
            expectedCardinality: expectedCardinality,
            inCodec: inCodec,
            outCodec: outCodec,
            state: options.session);
      } catch (err) {
        if (err is EdgeDBError &&
            err.hasTag(EdgeDBErrorTag.shouldRetry) &&
            (
                // query is readonly or it's a transaction serialization error
                err is TransactionConflictError ||
                    conn.getQueryCapabilities(
                            query, outputFormat, expectedCardinality) ==
                        0)) {
          final rule = options.retryOptions.getRuleForException(err);
          if (iteration + 1 >= rule.attempts) {
            rethrow;
          }
          await Future.delayed(rule.backoff(iteration + 1));
          continue;
        }
        rethrow;
      }
      return result;
    }
  }

  Future<void> execute(String query, [dynamic args]) async {
    await _retryingFetch(
        query: query,
        args: args,
        outputFormat: OutputFormat.none,
        expectedCardinality: Cardinality.noResult);
  }

  Future<List<dynamic>> query(String query, [dynamic args]) async {
    return await _retryingFetch(
        query: query,
        args: args,
        outputFormat: OutputFormat.binary,
        expectedCardinality: Cardinality.many) as List<dynamic>;
  }

  Future<String> queryJSON(String query, [dynamic args]) async {
    return await _retryingFetch(
        query: query,
        args: args,
        outputFormat: OutputFormat.json,
        expectedCardinality: Cardinality.many) as String;
  }

  Future<dynamic> querySingle(String query, [dynamic args]) {
    return _retryingFetch(
        query: query,
        args: args,
        outputFormat: OutputFormat.binary,
        expectedCardinality: Cardinality.atMostOne);
  }

  Future<String> querySingleJSON(String query, [dynamic args]) async {
    return await _retryingFetch(
        query: query,
        args: args,
        outputFormat: OutputFormat.json,
        expectedCardinality: Cardinality.atMostOne) as String;
  }

  Future<dynamic> queryRequiredSingle(String query, [dynamic args]) {
    return _retryingFetch(
        query: query,
        args: args,
        outputFormat: OutputFormat.binary,
        expectedCardinality: Cardinality.one);
  }

  Future<String> queryRequiredSingleJSON(String query, [dynamic args]) async {
    return await _retryingFetch(
        query: query,
        args: args,
        outputFormat: OutputFormat.json,
        expectedCardinality: Cardinality.one) as String;
  }
}

class ClientPool<Connection extends BaseProtocol> {
  final CreateConnection<Connection> _createConnection;
  Completer<void>? _closing;
  final _queue = LIFOQueue<ClientConnectionHolder>();
  final _holders = <ClientConnectionHolder>[];
  int? _userConcurrency;
  int? _suggestedConcurrency;
  final ConnectConfig _connectConfig;
  Future<ResolvedConnectConfig>? _resolvedConnectConfig;
  final _codecsRegistry = CodecsRegistry();

  ClientPool(this._createConnection, this._connectConfig, {int? concurrency}) {
    if (concurrency != null && concurrency <= 0) {
      throw InterfaceError(
          "invalid 'concurrency' value: expected int greater than 0 (got $concurrency)");
    }

    _userConcurrency = concurrency;

    _resizeHolderPool();
  }

  // _getStats(): {openConnections: number; queueLength: number} {
  //   return {
  //     queueLength: this._queue.pending,
  //     openConnections: this._holders.filter(holder => holder.connectionOpen)
  //       .length,
  //   };
  // }

  Future<void> ensureConnected() async {
    if (_closing != null) {
      throw InterfaceError(_closing!.isCompleted
          ? 'The client is closed'
          : 'The client is closing');
    }

    final openConnections =
        _holders.where((holder) => holder.connectionOpen).length;
    if (openConnections > 0) {
      return;
    }
    final connHolder = await _queue.get();
    try {
      await connHolder.getConnection();
    } finally {
      _queue.push(connHolder);
    }
  }

  int get _concurrency {
    return _userConcurrency ?? _suggestedConcurrency ?? 1;
  }

  void _resizeHolderPool() {
    final holdersDiff = _concurrency - _holders.length;
    if (holdersDiff > 0) {
      print('resizing pool to $_concurrency');
      for (var i = 0; i < holdersDiff; i++) {
        final holder = ClientConnectionHolder(this);
        _holders.add(holder);
        _queue.push(holder);
      }
    } else if (holdersDiff < 0) {
      // TODO: remove unconnected holders, followed by idle connection holders
      // until pool reduced to concurrency setting
      // (Also need to way to drop currently in use holders once they're
      // returned to the pool)
    }
  }

  Future<Connection> getNewConnection() async {
    if (_closing != null && _closing!.isCompleted) {
      throw InterfaceError('The client is closed');
    }

    final config =
        await (_resolvedConnectConfig ??= parseConnectConfig(_connectConfig));
    final connection =
        await retryingConnect(_createConnection, config, _codecsRegistry);

    final suggestedConcurrency =
        connection.serverSettings.suggestedPoolConcurrency;
    if (suggestedConcurrency != null &&
        suggestedConcurrency != _suggestedConcurrency) {
      _suggestedConcurrency = suggestedConcurrency;
      _resizeHolderPool();
    }
    return connection;
  }

  Future<ClientConnectionHolder> acquireHolder(Options options) async {
    if (_closing != null) {
      throw InterfaceError(_closing!.isCompleted
          ? "The client is closed"
          : "The client is closing");
    }

    final connectionHolder = await _queue.get();
    try {
      return await connectionHolder.acquire(options);
    } catch (error) {
      _queue.push(connectionHolder);
      rethrow;
    }
  }

  void enqueue(ClientConnectionHolder holder) {
    _queue.push(holder);
  }

  /// Attempt to gracefully close all connections in the client pool.
  ///
  /// Waits until all client pool connections are released, closes them and
  /// shuts down the client. If any error occurs
  /// in ``close()``, the client will terminate by calling ``terminate()``.
  Future<void> close() async {
    if (_closing != null) {
      return _closing!.future;
    }

    _closing = Completer();

    _queue.cancelAllPending(InterfaceError('The client is closing'));

    final warningTimer = Timer(Duration(seconds: 60), () {
      log('Client.close() is taking over 60 seconds to complete. '
          'Check if you have any unreleased connections left.');
    });

    try {
      await Future.wait(
          _holders.map((holder) => holder._waitUntilReleasedAndClose()),
          eagerError: true);
    } catch (e) {
      _terminate();
      _closing!.completeError(e);
      rethrow;
    } finally {
      warningTimer.cancel();
    }

    _closing!.complete();
  }

  void _terminate() {
    for (var holder in _holders) {
      holder.terminate();
    }
  }

  /// Terminate all connections in the client pool. If the client is already
  /// closed, it returns without doing anything.
  void terminate() {
    if (_closing != null && _closing!.isCompleted) {
      return;
    }

    _queue.cancelAllPending(InterfaceError('The client is closed'));

    _terminate();

    _closing ??= Completer()..complete();
  }

  bool get isClosed {
    return _closing != null;
  }
}

abstract class Executor {
  Future<void> execute(String query, [dynamic args]);

  Future<List<dynamic>> query(String query, [dynamic args]);

  Future<String> queryJSON(String query, [dynamic args]);

  Future<dynamic> querySingle(String query, [dynamic args]);

  Future<String> querySingleJSON(String query, [dynamic args]);

  Future<dynamic> queryRequiredSingle(String query, [dynamic args]);

  Future<String> queryRequiredSingleJSON(String query, [dynamic args]);
}

Future<dynamic> executeWithCodec<T>(Client client, Codec outCodec,
    Codec inCodec, Cardinality resultCard, String query, dynamic args) {
  return client._executeWithCodec(outCodec, inCodec, resultCard, query, args);
}

class Client implements Executor {
  final ClientPool _pool;
  final Options _options;

  Client._create(this._pool, this._options);

  Client withTransactionOptions(TransactionOptions options) {
    return Client._create(_pool, _options.withTransactionOptions(options));
  }

  Client withRetryOptions(RetryOptions options) {
    return Client._create(_pool, _options.withRetryOptions(options));
  }

  Client withSession(Session session) {
    return Client._create(_pool, _options.withSession(session));
  }

  Client withModuleAliases(Map<String, String> aliases) {
    return Client._create(_pool,
        _options.withSession(_options.session.withModuleAliases(aliases)));
  }

  Client withConfig(Map<String, Object> config) {
    return Client._create(
        _pool, _options.withSession(_options.session.withConfig(config)));
  }

  Client withGlobals(Map<String, Object> globals) {
    return Client._create(
        _pool, _options.withSession(_options.session.withGlobals(globals)));
  }

  Future<void> ensureConnected() {
    return _pool.ensureConnected();
  }

  bool get isClosed {
    return _pool.isClosed;
  }

  Future<void> close() {
    return _pool.close();
  }

  void terminate() {
    _pool.terminate();
  }

  Future<T> transaction<T>(Future<T> Function(Transaction) action) async {
    final holder = await _pool.acquireHolder(_options);
    try {
      return await holder.transaction(action);
    } finally {
      await holder.release();
    }
  }

  @override
  Future<void> execute(String query, [dynamic args]) async {
    final holder = await _pool.acquireHolder(_options);
    try {
      return await holder.execute(query, args);
    } finally {
      await holder.release();
    }
  }

  @override
  Future<List<dynamic>> query(String query, [dynamic args]) async {
    final holder = await _pool.acquireHolder(_options);
    try {
      return await holder.query(query, args);
    } finally {
      await holder.release();
    }
  }

  @override
  Future<String> queryJSON(String query, [dynamic args]) async {
    final holder = await _pool.acquireHolder(_options);
    try {
      return await holder.queryJSON(query, args);
    } finally {
      await holder.release();
    }
  }

  @override
  Future<dynamic> querySingle(String query, [dynamic args]) async {
    final holder = await _pool.acquireHolder(_options);
    try {
      return await holder.querySingle(query, args);
    } finally {
      await holder.release();
    }
  }

  @override
  Future<String> querySingleJSON(String query, [dynamic args]) async {
    final holder = await _pool.acquireHolder(_options);
    try {
      return await holder.querySingleJSON(query, args);
    } finally {
      await holder.release();
    }
  }

  @override
  Future<dynamic> queryRequiredSingle(String query, [dynamic args]) async {
    final holder = await _pool.acquireHolder(_options);
    try {
      return await holder.queryRequiredSingle(query, args);
    } finally {
      await holder.release();
    }
  }

  @override
  Future<String> queryRequiredSingleJSON(String query, [dynamic args]) async {
    final holder = await _pool.acquireHolder(_options);
    try {
      return await holder.queryRequiredSingleJSON(query, args);
    } finally {
      await holder.release();
    }
  }

  Future<dynamic> _executeWithCodec<T>(Codec outCodec, Codec inCodec,
      Cardinality resultCard, String query, dynamic args) async {
    final holder = await _pool.acquireHolder(_options);
    try {
      return await holder._retryingFetch<T>(
          query: query,
          args: args,
          outputFormat: OutputFormat.binary,
          expectedCardinality: resultCard,
          inCodec: inCodec,
          outCodec: outCodec);
    } finally {
      await holder.release();
    }
  }
}

Client createClient(
    {String? dsn,
    String? instanceName,
    String? credentials,
    String? credentialsFile,
    String? host,
    int? port,
    String? database,
    String? user,
    String? password,
    Map<String, String>? serverSettings,
    String? tlsCA,
    String? tlsCAFile,
    TLSSecurity? tlsSecurity,
    Duration? waitUntilAvailable,
    int? concurrency}) {
  return Client._create(
      ClientPool(
          TCPProtocol.create,
          ConnectConfig(
              dsn: dsn,
              instanceName: instanceName,
              credentials: credentials,
              credentialsFile: credentialsFile,
              host: host,
              port: port,
              database: database,
              user: user,
              password: password,
              serverSettings: serverSettings,
              tlsCA: tlsCA,
              tlsCAFile: tlsCAFile,
              tlsSecurity: tlsSecurity,
              waitUntilAvailable: waitUntilAvailable),
          concurrency: concurrency),
      Options.defaults());
}
