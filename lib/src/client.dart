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

part 'transaction.dart';

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

    await _connection?.resetState();

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
      final transaction = await Transaction._startTransaction(this);

      var commitFailed = false;
      try {
        result = await Future.any([
          action(transaction),
          transaction._waitForConnAbort(),
        ]);
        try {
          await transaction._commit();
        } catch (err) {
          commitFailed = true;
          rethrow;
        }
      } catch (err) {
        try {
          if (!commitFailed) {
            await transaction._rollback();
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
          final rule = getRuleForException(options.retryOptions, err);
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
      String? queryName,
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
            queryName: queryName,
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
          final rule = getRuleForException(options.retryOptions, err);
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
      // print('resizing pool to $_concurrency');
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

  bool _firstConnection = true;

  Future<Connection> getNewConnection() async {
    if (_closing != null && _closing!.isCompleted) {
      throw InterfaceError('The client is closed');
    }

    final config =
        await (_resolvedConnectConfig ??= parseConnectConfig(_connectConfig));

    final logAttempts = _firstConnection;
    _firstConnection = false;
    final connection = await retryingConnect(
        _createConnection, config, _codecsRegistry,
        logAttempts: logAttempts);

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
  /// in `close()`, the client will terminate by calling `terminate()`.
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

/// Abstract class that defines the interface for the `execute()` and
/// `query*()` methods.
///
/// Implemented by [Client] and [Transaction].
///
abstract class Executor {
  /// Executes a query, returning no result.
  ///
  /// For details on [args] see the `edgedb` library
  /// [docs page](../edgedb-library.html).
  Future<void> execute(String query, [dynamic args]);

  /// Executes a query, returning a `List` of results.
  ///
  /// For details on result types and [args] see the `edgedb` library
  /// [docs page](../edgedb-library.html).
  Future<List<dynamic>> query(String query, [dynamic args]);

  /// Executes a query, returning the result as a JSON encoded `String`.
  ///
  /// For details on [args] see the `edgedb` library
  /// [docs page](../edgedb-library.html).
  Future<String> queryJSON(String query, [dynamic args]);

  /// Executes a query, returning a single (possibly `null`) result.
  ///
  /// The query must return no more than one element. If the query returns
  /// more than one element, a [ResultCardinalityMismatchError] error is thrown.
  ///
  /// For details on result types and [args] see the `edgedb` library
  /// [docs page](../edgedb-library.html).
  Future<dynamic> querySingle(String query, [dynamic args]);

  /// Executes a query, returning the result as a JSON encoded `String`.
  ///
  /// The query must return no more than one element. If the query returns
  /// more than one element, a [ResultCardinalityMismatchError] error is thrown.
  ///
  /// For details on [args] see the `edgedb` library
  /// [docs page](../edgedb-library.html).
  Future<String> querySingleJSON(String query, [dynamic args]);

  /// Executes a query, returning a single (non-`null`) result.
  ///
  /// The query must return exactly one element. If the query returns more
  /// than one element, a [ResultCardinalityMismatchError] error is thrown.
  /// If the query returns an empty set, a [NoDataError] error is thrown.
  ///
  /// For details on result types and [args] see the `edgedb` library
  /// [docs page](../edgedb-library.html).
  Future<dynamic> queryRequiredSingle(String query, [dynamic args]);

  /// Executes a query, returning the result as a JSON encoded `String`.
  ///
  /// The query must return exactly one element. If the query returns more
  /// than one element, a [ResultCardinalityMismatchError] error is thrown.
  /// If the query returns an empty set, a [NoDataError] error is thrown.
  ///
  /// For details on [args] see the `edgedb` library
  /// [docs page](../edgedb-library.html).
  Future<String> queryRequiredSingleJSON(String query, [dynamic args]);

  Future<dynamic> _executeWithCodec<T>(String methodName, Codec outCodec,
      Codec inCodec, Cardinality resultCard, String query, dynamic args);
}

Future<dynamic> executeWithCodec<T>(
    Executor executor,
    String methodName,
    Codec outCodec,
    Codec inCodec,
    Cardinality resultCard,
    String query,
    dynamic args) {
  return executor._executeWithCodec<T>(
      methodName, outCodec, inCodec, resultCard, query, args);
}

/// Represents a pool of connections to the database, provides methods to run
/// queries and manages the context in which queries are run (ie. setting
/// globals, modifying session config, etc.)
///
/// The [Client] class cannot be instantiated directly, and is instead created
/// by the [createClient()] function. Since creating a client is relatively
/// expensive, it is recommended to create a single [Client] instance that you
/// can then import and use across your app.
///
/// The `with*()` methods return a new [Client] instance derived from this
/// instance. The derived instances all share the pool of connections managed
/// by the root [Client] instance (ie. the instance created by [createClient()]),
/// so calling the [ensureConnected()], [close()] or [terminate()] methods on
/// any of these instances will affect them all.
///
class Client implements Executor {
  final ClientPool _pool;
  final Options _options;

  Client._create(this._pool, this._options);

  /// Returns a new [Client] instance with the specified [TransactionOptions].
  Client withTransactionOptions(TransactionOptions options) {
    return Client._create(_pool, _options.withTransactionOptions(options));
  }

  /// Returns a new [Client] instance with the specified [RetryOptions].
  ///
  Client withRetryOptions(RetryOptions options) {
    return Client._create(_pool, _options.withRetryOptions(options));
  }

  /// Returns a new [Client] instance with the specified [Session] options.
  ///
  /// Instead of specifying an entirely new [Session] options object, [Client]
  /// also implements the [withModuleAliases], [withConfig] and [withGlobals]
  /// methods for convenience.
  ///
  Client withSession(Session session) {
    return Client._create(_pool, _options.withSession(session));
  }

  /// Returns a new [Client] instance with the specified module aliases.
  ///
  /// The [aliases] parameter is merged with any existing module aliases
  /// defined on the current client instance.
  ///
  /// If the alias `name` is `'module'` this is equivalent to using the
  /// `set module` command, otherwise it is equivalent to the `set alias`
  /// command.
  ///
  /// Example:
  /// ```dart
  /// final user = await client.withModuleAliases({
  ///   'module': 'sys'
  /// }).querySingle('''
  ///   select get_version_as_str()
  /// ''');
  /// // "2.0"
  /// ```
  ///
  Client withModuleAliases(Map<String, String> aliases) {
    return Client._create(_pool,
        _options.withSession(_options.session.withModuleAliases(aliases)));
  }

  /// Returns a new [Client] instance with the specified client session
  /// configuration.
  ///
  /// The [config] parameter is merged with any existing
  /// session config defined on the current client instance.
  ///
  /// Equivalent to using the `configure session` command. For available
  /// configuration parameters refer to the
  /// [Config documentation](https://www.edgedb.com/docs/stdlib/cfg#client-connections).
  ///
  Client withConfig(Map<String, Object> config) {
    return Client._create(
        _pool, _options.withSession(_options.session.withConfig(config)));
  }

  /// Returns a new [Client] instance with the specified global values.
  ///
  /// The [globals] parameter is merged with any existing globals defined
  /// on the current client instance.
  ///
  /// Equivalent to using the `set global` command.
  ///
  /// Example:
  /// ```dart
  /// final user = await client.withGlobals({
  ///   'userId': '...'
  /// }).querySingle('''
  ///   select User {name} filter .id = global userId
  /// ''');
  /// ```
  ///
  Client withGlobals(Map<String, dynamic> globals) {
    return Client._create(
        _pool, _options.withSession(_options.session.withGlobals(globals)));
  }

  /// If the client does not yet have any open connections in its pool,
  /// attempts to open a connection, else returns immediately.
  ///
  /// Since the client lazily creates new connections as needed (up to the
  /// configured `concurrency` limit), the first connection attempt will
  /// usually only happen when the first query is run on a client.
  /// The [ensureConnected()] method allows you to explicitly check that the
  /// client can connect to the database without running a query
  /// (can be useful to catch any errors resulting from connection
  /// mis-configuration).
  Future<void> ensureConnected() {
    return _pool.ensureConnected();
  }

  /// Whether [close()] (or [terminate()]) has been called on the client.
  /// If [isClosed] is `true`, subsequent calls to query methods will fail.
  bool get isClosed {
    return _pool.isClosed;
  }

  /// Close the client's open connections gracefully.
  ///
  /// Returns a `Future` that completes when all connections in the client's
  /// pool have finished any currently running query. Any pending queries
  /// awaiting a free connection from the pool, and have not started executing
  /// yet, will return an error.
  ///
  /// A warning is produced if the pool takes more than 60 seconds to close.
  Future<void> close() {
    return _pool.close();
  }

  /// Immediately closes all connections in the client's pool, without waiting
  /// for any running queries to finish.
  void terminate() {
    _pool.terminate();
  }

  /// Execute a retryable transaction.
  ///
  /// Use this method to atomically execute multiple queries, where you also
  /// need to run some logic client side. If you only need to run multiple
  /// queries atomically, instead consider just using the `execute()`/
  /// `query*()` methods - they all support queries containing multiple
  /// statements.
  ///
  /// The [transaction()] method expects an [action] function returning a
  /// `Future`, and will automatically handle starting the transaction before
  /// the [action] function is run, and commiting / rolling back the transaction
  /// when the `Future` completes / throws an error.
  ///
  /// The [action] function is passed a [Transaction] object, which implements
  /// the same `execute()`/`query*()` methods as on [Client], and should be
  /// used instead of the [Client] methods. The notable difference of these
  /// methods on [Transaction] as compared to the [Client] query methods, is
  /// that they do not attempt to retry on errors. Instead the entire [action]
  /// function is re-executed if a retryable error (such as a transient
  /// network error or transaction serialization error) is thrown inside it.
  /// Non-retryable errors will cause the transaction to be automatically
  /// rolled back, and the error re-thrown by [transaction()].
  ///
  /// A key implication of the whole [action] function being re-executed on
  /// transaction retries, is that non-querying code will also be re-executed,
  /// so the [action] should should not have side effects. It is also
  /// recommended that the [action] does not have long running code, as
  /// holding a transaction open is expensive on the server, and will negatively
  /// impact performance.
  ///
  /// The number of times [transaction()] will attempt to execute the
  /// transaction, and the backoff timeout between retries can be configured
  /// with [withRetryOptions()].
  ///
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

  @override
  Future<dynamic> _executeWithCodec<T>(String methodName, Codec outCodec,
      Codec inCodec, Cardinality resultCard, String query, dynamic args) async {
    final holder = await _pool.acquireHolder(_options);
    try {
      return await holder._retryingFetch<T>(
          query: query,
          queryName: methodName,
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

/// Creates a new [Client] instance with the provided connection options.
///
/// Usually it's recommended to not pass any connection options here, and
/// instead let the client resolve the connection options from the edgedb
/// project or environment variables. See the
/// [Client Library Connection](https://www.edgedb.com/docs/reference/connection)
/// documentation for details on connection options and how they are
/// resolved.
///
/// The [config] parameter allows you to pass in a [ConnectConfig] object, which
/// is just a wrapper object containing connection options to make them easier
/// to manage in your application. If a connection option exists both in the
/// [config] object and is passed as a parameter, the value passed as a
/// parameter will override the value in the [config] object.
///
/// Alongside the connection options, there are the following parameters:
/// - [concurrency]: Specifies the maximum number of connections the [Client]
///                  will create in it's connection pool. If not specified the
///                  concurrency will be controlled by the server. This is
///                  recommended as it allows the server to better manage the
///                  number of client connections based on it's own available
///                  resources.
///
Client createClient(
    {String? dsn,
    String? instanceName,
    String? credentials,
    String? credentialsFile,
    String? host,
    int? port,
    String? database,
    String? branch,
    String? user,
    String? password,
    String? secretKey,
    Map<String, String>? serverSettings,
    String? tlsCA,
    String? tlsCAFile,
    TLSSecurity? tlsSecurity,
    Duration? waitUntilAvailable,
    ConnectConfig? config,
    int? concurrency}) {
  return Client._create(
      ClientPool(
          TCPProtocol.create,
          ConnectConfig(
              dsn: dsn ?? config?.dsn,
              instanceName: instanceName ?? config?.instanceName,
              credentials: credentials ?? config?.credentials,
              credentialsFile: credentialsFile ?? config?.credentialsFile,
              host: host ?? config?.host,
              port: port ?? config?.port,
              database: database ?? config?.database,
              branch: branch ?? config?.branch,
              user: user ?? config?.user,
              password: password ?? config?.password,
              secretKey: secretKey ?? config?.secretKey,
              serverSettings: serverSettings ?? config?.serverSettings,
              tlsCA: tlsCA ?? config?.tlsCA,
              tlsCAFile: tlsCAFile ?? config?.tlsCAFile,
              tlsSecurity: tlsSecurity ?? config?.tlsSecurity,
              waitUntilAvailable:
                  waitUntilAvailable ?? config?.waitUntilAvailable),
          concurrency: concurrency),
      Options.defaults());
}
