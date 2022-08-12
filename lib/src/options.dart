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

class RetryOptions {
  final RetryRule defaultRetryRule;
  final Map<RetryCondition, RetryRule> _overrides;

  RetryOptions({int attempts = 3, BackoffFunction backoff = defaultBackoff})
      : defaultRetryRule = RetryRule(attempts: attempts, backoff: backoff),
        _overrides = Map.unmodifiable({});

  RetryOptions._cloneWithOverrides(
      RetryOptions from, Map<RetryCondition, RetryRule> overrides)
      : defaultRetryRule = from.defaultRetryRule,
        _overrides = Map.unmodifiable({...from._overrides, ...overrides});

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

  RetryRule getRuleForException(EdgeDBError err) {
    RetryRule? rule;
    if (err is TransactionConflictError) {
      rule = _overrides[RetryCondition.transactionConflict];
    } else if (err is ClientError) {
      rule = _overrides[RetryCondition.networkError];
    }
    return rule ?? defaultRetryRule;
  }

  static RetryOptions defaults() {
    return RetryOptions();
  }
}

class TransactionOptions {
  final IsolationLevel isolation;
  final bool readonly;
  final bool deferrable;

  TransactionOptions({
    this.isolation = IsolationLevel.serializable,
    this.readonly = false,
    this.deferrable = false,
  });

  static TransactionOptions defaults() {
    return TransactionOptions();
  }
}

class Session {
  final String module;
  final Map<String, String> moduleAliases;
  final Map<String, Object> config;
  final Map<String, Object> globals;

  Session({
    this.module = 'default',
    Map<String, String>? moduleAliases,
    Map<String, Object>? config,
    Map<String, Object>? globals,
  })  : moduleAliases = Map.unmodifiable(moduleAliases ?? {}),
        config = Map.unmodifiable(config ?? {}),
        globals = Map.unmodifiable(globals ?? {});

  Session withModuleAliases(Map<String, String> aliases) {
    return Session(
        module: aliases['module'] ?? module,
        moduleAliases: {...moduleAliases, ...aliases}..remove('module'),
        config: config,
        globals: globals);
  }

  Session withConfig(Map<String, Object> config) {
    return Session(
        config: {...this.config, ...config},
        module: module,
        moduleAliases: moduleAliases,
        globals: globals);
  }

  Session withGlobals(Map<String, Object> globals) {
    return Session(
        globals: {...this.globals, ...globals},
        module: module,
        moduleAliases: moduleAliases,
        config: config);
  }

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

  Options withTransactionOptions(TransactionOptions options) {
    return Options(
        transactionOptions: options,
        retryOptions: retryOptions,
        session: session);
  }

  Options withRetryOptions(RetryOptions options) {
    return Options(
        retryOptions: options,
        transactionOptions: transactionOptions,
        session: session);
  }

  Options withSession(Session session) {
    return Options(
        session: session,
        retryOptions: retryOptions,
        transactionOptions: transactionOptions);
  }

  static Options defaults() {
    return Options();
  }
}
