
API
===

:edb-alt-title: Client API Reference


.. _edgedb-dart-createClient:

*function* createClient()
-------------------------

.. code-block:: dart

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
      int? concurrency}
    )

Creates a new :ref:`Client <edgedb-dart-Client>` instance with the provided connection options.

Usually it's recommended to not pass any connection options here, and
instead let the client resolve the connection options from the edgedb
project or environment variables. See the
:ref:`Client Library Connection <ref_reference_connection>`
documentation for details on connection options and how they are
resolved.

The ``config`` parameter allows you to pass in a `ConnectConfig <https://pub.dev/documentation/edgedb/latest/edgedb/ConnectConfig-class.html>`__ object, which
is just a wrapper object containing connection options to make them easier
to manage in your application. If a connection option exists both in the
``config`` object and is passed as a parameter, the value passed as a
parameter will override the value in the ``config`` object.

Alongside the connection options, there are the following parameters:


* ``concurrency``: Specifies the maximum number of connections the :ref:`Client <edgedb-dart-Client>`
  will create in it's connection pool. If not specified the
  concurrency will be controlled by the server. This is
  recommended as it allows the server to better manage the
  number of client connections based on it's own available
  resources.

.. _edgedb-dart-Client:

*class* Client
--------------

Represents a pool of connections to the database, provides methods to run
queries and manages the context in which queries are run (ie. setting
globals, modifying session config, etc.)

The :ref:`Client <edgedb-dart-Client>` class cannot be instantiated directly, and is instead created
by the :ref:`createClient() <edgedb-dart-createClient>` function. Since creating a client is relatively
expensive, it is recommended to create a single :ref:`Client <edgedb-dart-Client>` instance that you
can then import and use across your app.

The ``with*()`` methods return a new :ref:`Client <edgedb-dart-Client>` instance derived from this
instance. The derived instances all share the pool of connections managed
by the root :ref:`Client <edgedb-dart-Client>` instance (ie. the instance created by :ref:`createClient() <edgedb-dart-createClient>`),
so calling the :ref:`ensureConnected() <edgedb-dart-Client-ensureConnected>`, :ref:`close() <edgedb-dart-Client-close>` or :ref:`terminate() <edgedb-dart-Client-terminate>` methods on
any of these instances will affect them all.

.. _edgedb-dart-Client-isClosed:

*property* ``.isClosed``
........................


.. code-block:: dart

    bool get isClosed

Whether :ref:`close() <edgedb-dart-Client-close>` (or :ref:`terminate() <edgedb-dart-Client-terminate>`) has been called on the client.
If :ref:`isClosed <edgedb-dart-Client-isClosed>` is ``true``, subsequent calls to query methods will fail.

.. _edgedb-dart-Client-close:

*method* ``.close()``
.....................


.. code-block:: dart

    Future<void> close()

Close the client's open connections gracefully.

Returns a ``Future`` that completes when all connections in the client's
pool have finished any currently running query. Any pending queries
awaiting a free connection from the pool, and have not started executing
yet, will return an error.

A warning is produced if the pool takes more than 60 seconds to close.

.. _edgedb-dart-Client-ensureConnected:

*method* ``.ensureConnected()``
...............................


.. code-block:: dart

    Future<void> ensureConnected()

If the client does not yet have any open connections in its pool,
attempts to open a connection, else returns immediately.

Since the client lazily creates new connections as needed (up to the
configured ``concurrency`` limit), the first connection attempt will
usually only happen when the first query is run on a client.
The :ref:`ensureConnected() <edgedb-dart-Client-ensureConnected>` method allows you to explicitly check that the
client can connect to the database without running a query
(can be useful to catch any errors resulting from connection
mis-configuration).

.. _edgedb-dart-Client-execute:

*method* ``.execute()``
.......................


.. code-block:: dart

    Future<void> execute(
      String query, 
      [dynamic args]
    )

Executes a query, returning no result.

For details on ``args`` see the ``edgedb`` library
`docs page <https://pub.dev/documentation/edgedb/latest/edgedb-library.html>`__.

.. _edgedb-dart-Client-query:

*method* ``.query()``
.....................


.. code-block:: dart

    Future<List> query(
      String query, 
      [dynamic args]
    )

Executes a query, returning a ``List`` of results.

For details on result types and ``args`` see the ``edgedb`` library
`docs page <https://pub.dev/documentation/edgedb/latest/edgedb-library.html>`__.

.. _edgedb-dart-Client-queryJSON:

*method* ``.queryJSON()``
.........................


.. code-block:: dart

    Future<String> queryJSON(
      String query, 
      [dynamic args]
    )

Executes a query, returning the result as a JSON encoded ``String``.

For details on ``args`` see the ``edgedb`` library
`docs page <https://pub.dev/documentation/edgedb/latest/edgedb-library.html>`__.

.. _edgedb-dart-Client-queryRequiredSingle:

*method* ``.queryRequiredSingle()``
...................................


.. code-block:: dart

    Future queryRequiredSingle(
      String query, 
      [dynamic args]
    )

Executes a query, returning a single (non-``null``) result.

The query must return exactly one element. If the query returns more
than one element, a `ResultCardinalityMismatchError <https://pub.dev/documentation/edgedb/latest/edgedb/ResultCardinalityMismatchError-class.html>`__ error is thrown.
If the query returns an empty set, a `NoDataError <https://pub.dev/documentation/edgedb/latest/edgedb/NoDataError-class.html>`__ error is thrown.

For details on result types and ``args`` see the ``edgedb`` library
`docs page <https://pub.dev/documentation/edgedb/latest/edgedb-library.html>`__.

.. _edgedb-dart-Client-queryRequiredSingleJSON:

*method* ``.queryRequiredSingleJSON()``
.......................................


.. code-block:: dart

    Future<String> queryRequiredSingleJSON(
      String query, 
      [dynamic args]
    )

Executes a query, returning the result as a JSON encoded ``String``.

The query must return exactly one element. If the query returns more
than one element, a `ResultCardinalityMismatchError <https://pub.dev/documentation/edgedb/latest/edgedb/ResultCardinalityMismatchError-class.html>`__ error is thrown.
If the query returns an empty set, a `NoDataError <https://pub.dev/documentation/edgedb/latest/edgedb/NoDataError-class.html>`__ error is thrown.

For details on ``args`` see the ``edgedb`` library
`docs page <https://pub.dev/documentation/edgedb/latest/edgedb-library.html>`__.

.. _edgedb-dart-Client-querySingle:

*method* ``.querySingle()``
...........................


.. code-block:: dart

    Future querySingle(
      String query, 
      [dynamic args]
    )

Executes a query, returning a single (possibly ``null``) result.

The query must return no more than one element. If the query returns
more than one element, a `ResultCardinalityMismatchError <https://pub.dev/documentation/edgedb/latest/edgedb/ResultCardinalityMismatchError-class.html>`__ error is thrown.

For details on result types and ``args`` see the ``edgedb`` library
`docs page <https://pub.dev/documentation/edgedb/latest/edgedb-library.html>`__.

.. _edgedb-dart-Client-querySingleJSON:

*method* ``.querySingleJSON()``
...............................


.. code-block:: dart

    Future<String> querySingleJSON(
      String query, 
      [dynamic args]
    )

Executes a query, returning the result as a JSON encoded ``String``.

The query must return no more than one element. If the query returns
more than one element, a `ResultCardinalityMismatchError <https://pub.dev/documentation/edgedb/latest/edgedb/ResultCardinalityMismatchError-class.html>`__ error is thrown.

For details on ``args`` see the ``edgedb`` library
`docs page <https://pub.dev/documentation/edgedb/latest/edgedb-library.html>`__.

.. _edgedb-dart-Client-terminate:

*method* ``.terminate()``
.........................


.. code-block:: dart

    void terminate()

Immediately closes all connections in the client's pool, without waiting
for any running queries to finish.

.. _edgedb-dart-Client-transaction:

*method* ``.transaction<T>()``
..............................


.. code-block:: dart

    Future<T> transaction<T>(
      Future<T> action(Transaction)
    )

Execute a retryable transaction.

Use this method to atomically execute multiple queries, where you also
need to run some logic client side. If you only need to run multiple
queries atomically, instead consider just using the ``execute()``/
``query*()`` methods - they all support queries containing multiple
statements.

The :ref:`transaction() <edgedb-dart-Client-transaction>` method expects an ``action`` function returning a
``Future``, and will automatically handle starting the transaction before
the ``action`` function is run, and commiting / rolling back the transaction
when the ``Future`` completes / throws an error.

The ``action`` function is passed a `Transaction <https://pub.dev/documentation/edgedb/latest/edgedb/Transaction-class.html>`__ object, which implements
the same ``execute()``/``query*()`` methods as on :ref:`Client <edgedb-dart-Client>`, and should be
used instead of the :ref:`Client <edgedb-dart-Client>` methods. The notable difference of these
methods on `Transaction <https://pub.dev/documentation/edgedb/latest/edgedb/Transaction-class.html>`__ as compared to the :ref:`Client <edgedb-dart-Client>` query methods, is
that they do not attempt to retry on errors. Instead the entire ``action``
function is re-executed if a retryable error (such as a transient
network error or transaction serialization error) is thrown inside it.
Non-retryable errors will cause the transaction to be automatically
rolled back, and the error re-thrown by :ref:`transaction() <edgedb-dart-Client-transaction>`.

A key implication of the whole ``action`` function being re-executed on
transaction retries, is that non-querying code will also be re-executed,
so the ``action`` should should not have side effects. It is also
recommended that the ``action`` does not have long running code, as
holding a transaction open is expensive on the server, and will negatively
impact performance.

The number of times :ref:`transaction() <edgedb-dart-Client-transaction>` will attempt to execute the
transaction, and the backoff timeout between retries can be configured
with :ref:`withRetryOptions() <edgedb-dart-Client-withRetryOptions>`.

.. _edgedb-dart-Client-withConfig:

*method* ``.withConfig()``
..........................


.. code-block:: dart

    Client withConfig(
      Map<String, Object> config
    )

Returns a new :ref:`Client <edgedb-dart-Client>` instance with the specified client session
configuration.

The ``config`` parameter is merged with any existing
session config defined on the current client instance.

Equivalent to using the ``configure session`` command. For available
configuration parameters refer to the
:ref:`Config documentation <ref_std_cfg_client_connections>`.

.. _edgedb-dart-Client-withGlobals:

*method* ``.withGlobals()``
...........................


.. code-block:: dart

    Client withGlobals(
      Map<String, dynamic> globals
    )

Returns a new :ref:`Client <edgedb-dart-Client>` instance with the specified global values.

The ``globals`` parameter is merged with any existing globals defined
on the current client instance.

Equivalent to using the ``set global`` command.

Example:

.. code-block:: dart

    final user = await client.withGlobals({
      'userId': '...'
    }).querySingle('''
      select User {name} filter .id = global userId
    ''');
    
.. _edgedb-dart-Client-withModuleAliases:

*method* ``.withModuleAliases()``
.................................


.. code-block:: dart

    Client withModuleAliases(
      Map<String, String> aliases
    )

Returns a new :ref:`Client <edgedb-dart-Client>` instance with the specified module aliases.

The ``aliases`` parameter is merged with any existing module aliases
defined on the current client instance.

If the alias ``name`` is ``'module'`` this is equivalent to using the
``set module`` command, otherwise it is equivalent to the ``set alias``
command.

Example:

.. code-block:: dart

    final user = await client.withModuleAliases({
      'module': 'sys'
    }).querySingle('''
      select get_version_as_str()
    ''');
    // "2.0"
    
.. _edgedb-dart-Client-withRetryOptions:

*method* ``.withRetryOptions()``
................................


.. code-block:: dart

    Client withRetryOptions(
      RetryOptions options
    )

Returns a new :ref:`Client <edgedb-dart-Client>` instance with the specified :ref:`RetryOptions <edgedb-dart-RetryOptions>`.

.. _edgedb-dart-Client-withSession:

*method* ``.withSession()``
...........................


.. code-block:: dart

    Client withSession(
      Session session
    )

Returns a new :ref:`Client <edgedb-dart-Client>` instance with the specified :ref:`Session <edgedb-dart-Session>` options.

Instead of specifying an entirely new :ref:`Session <edgedb-dart-Session>` options object, :ref:`Client <edgedb-dart-Client>`
also implements the :ref:`withModuleAliases <edgedb-dart-Client-withModuleAliases>`, :ref:`withConfig <edgedb-dart-Client-withConfig>` and :ref:`withGlobals <edgedb-dart-Client-withGlobals>`
methods for convenience.

.. _edgedb-dart-Client-withTransactionOptions:

*method* ``.withTransactionOptions()``
......................................


.. code-block:: dart

    Client withTransactionOptions(
      TransactionOptions options
    )

Returns a new :ref:`Client <edgedb-dart-Client>` instance with the specified :ref:`TransactionOptions <edgedb-dart-TransactionOptions>`.

.. _edgedb-dart-Options:

*class* Options
---------------

Manages all options (:ref:`RetryOptions <edgedb-dart-RetryOptions>`, :ref:`TransactionOptions <edgedb-dart-TransactionOptions>` and
:ref:`Session <edgedb-dart-Session>`) for a :ref:`Client <edgedb-dart-Client>`.

.. _edgedb-dart-Options-Options:

*constructor* ``Options()``
...........................


.. code-block:: dart

    Options(
      {RetryOptions? retryOptions, 
      TransactionOptions? transactionOptions, 
      Session? session}
    )


.. _edgedb-dart-Options-retryOptions:

*property* ``.retryOptions``
............................


.. code-block:: dart

    final RetryOptions retryOptions;


.. _edgedb-dart-Options-session:

*property* ``.session``
.......................


.. code-block:: dart

    final Session session;


.. _edgedb-dart-Options-transactionOptions:

*property* ``.transactionOptions``
..................................


.. code-block:: dart

    final TransactionOptions transactionOptions;


.. _edgedb-dart-Options-defaults:

*method* ``.defaults()``
........................


.. code-block:: dart

    Options defaults()

Creates a new :ref:`Options <edgedb-dart-Options>` object with all options set to their defaults.

.. _edgedb-dart-Options-withRetryOptions:

*method* ``.withRetryOptions()``
................................


.. code-block:: dart

    Options withRetryOptions(
      RetryOptions options
    )

Returns a new :ref:`Options <edgedb-dart-Options>` object with the specified :ref:`RetryOptions <edgedb-dart-RetryOptions>`.

.. _edgedb-dart-Options-withSession:

*method* ``.withSession()``
...........................


.. code-block:: dart

    Options withSession(
      Session session
    )

Returns a new :ref:`Options <edgedb-dart-Options>` object with the specified :ref:`Session <edgedb-dart-Session>` options.

.. _edgedb-dart-Options-withTransactionOptions:

*method* ``.withTransactionOptions()``
......................................


.. code-block:: dart

    Options withTransactionOptions(
      TransactionOptions options
    )

Returns a new :ref:`Options <edgedb-dart-Options>` object with the specified :ref:`TransactionOptions <edgedb-dart-TransactionOptions>`.

.. _edgedb-dart-Session:

*class* Session
---------------

Configuration of a session, containing the config, aliases, and globals
to be used when executing a query.

.. _edgedb-dart-Session-Session:

*constructor* ``Session()``
...........................


.. code-block:: dart

    Session(
      {String module = 'default', 
      Map<String, String>? moduleAliases, 
      Map<String, Object>? config, 
      Map<String, dynamic>? globals}
    )

Creates a new :ref:`Session <edgedb-dart-Session>` object with the given options.

Refer to the individial ``with*`` methods for details on each option.

.. _edgedb-dart-Session-config:

*property* ``.config``
......................


.. code-block:: dart

    final Map<String, Object> config;


.. _edgedb-dart-Session-globals:

*property* ``.globals``
.......................


.. code-block:: dart

    final Map<String, dynamic> globals;


.. _edgedb-dart-Session-module:

*property* ``.module``
......................


.. code-block:: dart

    final String module;


.. _edgedb-dart-Session-moduleAliases:

*property* ``.moduleAliases``
.............................


.. code-block:: dart

    final Map<String, String> moduleAliases;


.. _edgedb-dart-Session-defaults:

*method* ``.defaults()``
........................


.. code-block:: dart

    Session defaults()

Creates a new :ref:`Session <edgedb-dart-Session>` with all options set to their defaults.

.. _edgedb-dart-Session-withConfig:

*method* ``.withConfig()``
..........................


.. code-block:: dart

    Session withConfig(
      Map<String, Object> config
    )

Returns a new :ref:`Session <edgedb-dart-Session>` with the specified client session
configuration.

The ``config`` parameter is merged with any existing
session config defined on the current :ref:`Session <edgedb-dart-Session>`.

Equivalent to using the ``configure session`` command. For available
configuration parameters refer to the
:ref:`Config documentation <ref_std_cfg_client_connections>`.

.. _edgedb-dart-Session-withGlobals:

*method* ``.withGlobals()``
...........................


.. code-block:: dart

    Session withGlobals(
      Map<String, dynamic> globals
    )

Returns a new :ref:`Session <edgedb-dart-Session>` with the specified global values.

The ``globals`` parameter is merged with any existing globals defined
on the current :ref:`Session <edgedb-dart-Session>`.

Equivalent to using the ``set global`` command.

.. _edgedb-dart-Session-withModuleAliases:

*method* ``.withModuleAliases()``
.................................


.. code-block:: dart

    Session withModuleAliases(
      Map<String, String> aliases
    )

Returns a new :ref:`Session <edgedb-dart-Session>` with the specified module aliases.

The ``aliases`` parameter is merged with any existing module aliases
defined on the current :ref:`Session <edgedb-dart-Session>`.

If the alias ``name`` is ``'module'`` this is equivalent to using the
``set module`` command, otherwise it is equivalent to the ``set alias``
command.

.. _edgedb-dart-RetryOptions:

*class* RetryOptions
--------------------

Options that define how a :ref:`Client <edgedb-dart-Client>` will handle automatically retrying
queries in the event of a retryable error.

The options are specified by `RetryRule <https://pub.dev/documentation/edgedb/latest/edgedb/RetryRule-class.html>`__'s, which define a number of times
to attempt to retry a query, and a backoff function to determine how long
to wait after each retry before attempting the query again. :ref:`RetryOptions <edgedb-dart-RetryOptions>`
has a default `RetryRule <https://pub.dev/documentation/edgedb/latest/edgedb/RetryRule-class.html>`__, and can be configured with extra `RetryRule <https://pub.dev/documentation/edgedb/latest/edgedb/RetryRule-class.html>`__'s
which override the default for given error conditions.

.. _edgedb-dart-RetryOptions-RetryOptions:

*constructor* ``RetryOptions()``
................................


.. code-block:: dart

    RetryOptions(
      {int? attempts, 
      BackoffFunction? backoff}
    )

Creates a new :ref:`RetryOptions <edgedb-dart-RetryOptions>` object, with a default `RetryRule <https://pub.dev/documentation/edgedb/latest/edgedb/RetryRule-class.html>`__, with
the given ``attempts`` and ``backoff`` function.

If ``attempts`` or ``backoff`` are not specified, the defaults of 3 ``attempts``
and the exponential `defaultBackoff <https://pub.dev/documentation/edgedb/latest/edgedb/defaultBackoff.html>`__ function are used.

.. _edgedb-dart-RetryOptions-defaultRetryRule:

*property* ``.defaultRetryRule``
................................


.. code-block:: dart

    final RetryRule defaultRetryRule;


.. _edgedb-dart-RetryOptions-defaults:

*method* ``.defaults()``
........................


.. code-block:: dart

    RetryOptions defaults()

Creates a new :ref:`RetryOptions <edgedb-dart-RetryOptions>` with all options set to their defaults.

.. _edgedb-dart-RetryOptions-withRule:

*method* ``.withRule()``
........................


.. code-block:: dart

    RetryOptions withRule(
      {required RetryCondition condition, 
      int? attempts, 
      BackoffFunction? backoff}
    )

Adds a new `RetryRule <https://pub.dev/documentation/edgedb/latest/edgedb/RetryRule-class.html>`__ with the given ``attempts`` and ``backoff`` function,
that overrides the default `RetryRule <https://pub.dev/documentation/edgedb/latest/edgedb/RetryRule-class.html>`__ for a given error ``condition``.

If ``attempts`` or ``backoff`` are not specified, the values of the default
`RetryRule <https://pub.dev/documentation/edgedb/latest/edgedb/RetryRule-class.html>`__ of this :ref:`RetryOptions <edgedb-dart-RetryOptions>` are used.

.. _edgedb-dart-TransactionOptions:

*class* TransactionOptions
--------------------------

Defines the transaction mode that :ref:`Client.transaction <edgedb-dart-Client-transaction>` runs
transactions with.

For more details on transaction modes see the
:ref:`Transaction docs <ref_eql_statements_start_tx>`.

.. _edgedb-dart-TransactionOptions-TransactionOptions:

*constructor* ``TransactionOptions()``
......................................


.. code-block:: dart

    TransactionOptions(
      {IsolationLevel? isolation, 
      bool? readonly, 
      bool? deferrable}
    )

Creates a new :ref:`TransactionOptions <edgedb-dart-TransactionOptions>` object with the given ``isolation``,
``readonly`` and ``deferrable`` options.

If not specified, the defaults are as follows:


* ``isolation``: serializable

* ``readonly``: false

* ``deferrable``: false

.. _edgedb-dart-TransactionOptions-deferrable:

*property* ``.deferrable``
..........................


.. code-block:: dart

    final bool deferrable;


.. _edgedb-dart-TransactionOptions-isolation:

*property* ``.isolation``
.........................


.. code-block:: dart

    final IsolationLevel isolation;


.. _edgedb-dart-TransactionOptions-readonly:

*property* ``.readonly``
........................


.. code-block:: dart

    final bool readonly;


.. _edgedb-dart-TransactionOptions-defaults:

*method* ``.defaults()``
........................


.. code-block:: dart

    TransactionOptions defaults()

Creates a new :ref:`TransactionOptions <edgedb-dart-TransactionOptions>` with all options set to their defaults.
