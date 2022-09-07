import 'dart:math';

import 'errors/errors.dart';

typedef BackoffFunction = Duration Function(int attempt);

Duration defaultBackoff(int attempt) {
  return Duration(
      milliseconds:
          (pow(2, attempt) * 100 + Random().nextDouble() * 100).toInt());
}

enum IsolationLevel { serializable }

enum RetryCondition {
  transactionConflict,
  networkError,
}

class RetryRule {
  final int attempts;
  final BackoffFunction backoff;

  RetryRule({required this.attempts, required this.backoff});
}

/// Options that define how a [Client] will handle automatically retrying
/// queries in the event of a retryable error.
///
/// The options are specified by [RetryRule]'s, which define a number of times
/// to attempt to retry a query, and a backoff function to determine how long
/// to wait after each retry before attempting the query again. [RetryOptions]
/// has a default [RetryRule], and can be configured with extra [RetryRule]'s
/// which override the default for given error conditions.
///
class RetryOptions {
  final RetryRule defaultRetryRule;
  final Map<RetryCondition, RetryRule> _overrides;

  /// Creates a new [RetryOptions] object, with a default [RetryRule], with
  /// the given [attempts] and [backoff] function.
  ///
  /// If [attempts] or [backoff] are not specified, the defaults of 3 [attempts]
  /// and the exponential [defaultBackoff] function are used.
  ///
  RetryOptions({int? attempts, BackoffFunction? backoff})
      : defaultRetryRule = RetryRule(
            attempts: attempts ?? 3, backoff: backoff ?? defaultBackoff),
        _overrides = Map.unmodifiable({});

  RetryOptions._cloneWithOverrides(
      RetryOptions from, Map<RetryCondition, RetryRule> overrides)
      : defaultRetryRule = from.defaultRetryRule,
        _overrides = Map.unmodifiable({...from._overrides, ...overrides});

  /// Adds a new [RetryRule] with the given [attempts] and [backoff] function,
  /// that overrides the default [RetryRule] for a given error [condition].
  ///
  /// If [attempts] or [backoff] are not specified, the values of the default
  /// [RetryRule] of this [RetryOptions] are used.
  ///
  RetryOptions withRule(
      {required RetryCondition condition,
      int? attempts,
      BackoffFunction? backoff}) {
    return RetryOptions._cloneWithOverrides(this, {
      condition: RetryRule(
          attempts: attempts ?? defaultRetryRule.attempts,
          backoff: backoff ?? defaultRetryRule.backoff)
    });
  }

  /// Creates a new [RetryOptions] with all options set to their defaults.
  static RetryOptions defaults() {
    return RetryOptions();
  }
}

RetryRule getRuleForException(RetryOptions options, EdgeDBError err) {
  RetryRule? rule;
  if (err is TransactionConflictError) {
    rule = options._overrides[RetryCondition.transactionConflict];
  } else if (err is ClientError) {
    rule = options._overrides[RetryCondition.networkError];
  }
  return rule ?? options.defaultRetryRule;
}

/// Defines the transaction mode that [Client.transaction] runs
/// transactions with.
///
/// For more details on transaction modes see the
/// [Transaction docs](https://www.edgedb.com/docs/reference/edgeql/tx_start#parameters).
///
class TransactionOptions {
  final IsolationLevel isolation;
  final bool readonly;
  final bool deferrable;

  /// Creates a new [TransactionOptions] object with the given [isolation],
  /// [readonly] and [deferrable] options.
  ///
  /// If not specified, the defaults are as follows:
  /// - `isolation`: serializable
  /// - `readonly`: false
  /// - `deferrable`: false
  ///
  TransactionOptions(
      {IsolationLevel? isolation, bool? readonly, bool? deferrable})
      : isolation = isolation ?? IsolationLevel.serializable,
        readonly = readonly ?? false,
        deferrable = deferrable ?? false;

  /// Creates a new [TransactionOptions] with all options set to their defaults.
  static TransactionOptions defaults() {
    return TransactionOptions();
  }
}

/// Configuration of a session, containing the config, aliases, and globals
/// to be used when executing a query.
///
class Session {
  final String module;
  final Map<String, String> moduleAliases;
  final Map<String, Object> config;
  final Map<String, dynamic> globals;

  /// Creates a new [Session] object with the given options.
  ///
  /// Refer to the individial `with*` methods for details on each option.
  ///
  Session({
    this.module = 'default',
    Map<String, String>? moduleAliases,
    Map<String, Object>? config,
    Map<String, dynamic>? globals,
  })  : moduleAliases = Map.unmodifiable(moduleAliases ?? {}),
        config = Map.unmodifiable(config ?? {}),
        globals = Map.unmodifiable(globals ?? {});

  /// Returns a new [Session] with the specified module aliases.
  ///
  /// The [aliases] parameter is merged with any existing module aliases
  /// defined on the current [Session].
  ///
  /// If the alias `name` is `'module'` this is equivalent to using the
  /// `set module` command, otherwise it is equivalent to the `set alias`
  /// command.
  ///
  Session withModuleAliases(Map<String, String> aliases) {
    return Session(
        module: aliases['module'] ?? module,
        moduleAliases: {...moduleAliases, ...aliases}..remove('module'),
        config: config,
        globals: globals);
  }

  /// Returns a new [Session] with the specified client session
  /// configuration.
  ///
  /// The [config] parameter is merged with any existing
  /// session config defined on the current [Session].
  ///
  /// Equivalent to using the `configure session` command. For available
  /// configuration parameters refer to the
  /// [Config documentation](https://www.edgedb.com/docs/stdlib/cfg#client-connections).
  ///
  Session withConfig(Map<String, Object> config) {
    return Session(
        config: {...this.config, ...config},
        module: module,
        moduleAliases: moduleAliases,
        globals: globals);
  }

  /// Returns a new [Session] with the specified global values.
  ///
  /// The [globals] parameter is merged with any existing globals defined
  /// on the current [Session].
  ///
  /// Equivalent to using the `set global` command.
  ///
  Session withGlobals(Map<String, dynamic> globals) {
    return Session(
        globals: {...this.globals, ...globals},
        module: module,
        moduleAliases: moduleAliases,
        config: config);
  }

  /// Creates a new [Session] with all options set to their defaults.
  static Session defaults() {
    return _defaultSession;
  }
}

Map<String, Object> serialiseState(Session session) {
  final state = <String, Object>{};
  if (session.module != "default") {
    state['module'] = session.module;
  }
  if (session.moduleAliases.isNotEmpty) {
    state['aliases'] =
        session.moduleAliases.entries.map((e) => [e.key, e.value]);
  }
  if (session.config.isNotEmpty) {
    state['config'] = session.config;
  }
  if (session.globals.isNotEmpty) {
    state['globals'] = session.globals.map((key, value) =>
        MapEntry(key.contains('::') ? key : '${session.module}::$key', value));
  }
  return state;
}

final _defaultSession = Session();

/// Manages all options ([RetryOptions], [TransactionOptions] and
/// [Session]) for a [Client].
///
class Options {
  final RetryOptions retryOptions;
  final TransactionOptions transactionOptions;
  final Session session;

  Options({
    RetryOptions? retryOptions,
    TransactionOptions? transactionOptions,
    Session? session,
  })  : retryOptions = retryOptions ?? RetryOptions.defaults(),
        transactionOptions =
            transactionOptions ?? TransactionOptions.defaults(),
        session = session ?? Session.defaults();

  /// Returns a new [Options] object with the specified [TransactionOptions].
  ///
  Options withTransactionOptions(TransactionOptions options) {
    return Options(
        transactionOptions: options,
        retryOptions: retryOptions,
        session: session);
  }

  /// Returns a new [Options] object with the specified [RetryOptions].
  ///
  Options withRetryOptions(RetryOptions options) {
    return Options(
        retryOptions: options,
        transactionOptions: transactionOptions,
        session: session);
  }

  /// Returns a new [Options] object with the specified [Session] options.
  ///
  Options withSession(Session session) {
    return Options(
        session: session,
        retryOptions: retryOptions,
        transactionOptions: transactionOptions);
  }

  /// Creates a new [Options] object with all options set to their defaults.
  static Options defaults() {
    return Options();
  }
}
