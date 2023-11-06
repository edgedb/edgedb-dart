/// This is the core client library, providing the main [createClient()]
/// function for configuring a connection to an EdgeDB server, and the [Client]
/// class, which implements all the methods to run queries, work with
/// transactions, and manage other client state.
///
/// ## Parameters​
/// If your query contains parameters (e.g. `$foo`), you can pass in values as
/// the second argument to all the `execute()` and `query*()` methods.
///
/// Named parameters are expected to be passed as a `Map<String, dynamic>`, and
/// positional parameters as a `List<dynamic>`.
///
/// ```dart
/// // Named parameters
/// await client.execute(r'''insert Movie {
///   title := <str>$title
/// }''', {'title': 'Iron Man'});
///
/// // Positional parameters
/// await client.execute(r'''insert Movie {
///   title := <str>$0
/// }''', ['Iron Man']);
/// ```
///
/// Remember that [parameters](https://www.edgedb.com/docs/edgeql/parameters#parameter-types-and-json)
/// can only be scalars or arrays of scalars.
///
/// ## Scripts​
/// All the `execute()` and the `query*()` methods support scripts (queries
/// containing multiple statements). The statements are run in an implicit
/// transaction (unless already in an explicit transaction), so the whole
/// script remains atomic. For the `query*()` methods only the result of the
/// final statement in the script will be returned.
///
/// ```dart
/// final result = await client.query(r'''
///   insert Movie {
///     title := <str>$title
///   };
///   insert Person {
///     name := <str>$name
///   };
/// ''', {
///   'title': 'Thor: Ragnarok',
///   'name': 'Anson Mount'
/// });
/// // [{id: "5dd2557b..."}]
/// // Note: only the single item of the `insert Person ...`
/// // statement is returned
/// ```
///
/// For more fine grained control of atomic exectution of multiple statements,
/// use the [Client.transaction()] API.
///
/// ## Type Conversion
/// EdgeDB types are decoded into/encoded from Dart types as follows (any types
/// in parentheses are also valid for query parameters):
///
/// | EdgeDB type                                 | Dart type                     |
/// |---------------------------------------------|-------------------------------|
/// | Sets                                        | [List<dynamic>]               |
/// | Arrays                                      | [List<dynamic>]               |
/// | Objects                                     | [Map<String, dynamic>]        |
/// | Tuples (`tuple<x, y, ...>`)                 | [List<dynamic>]               |
/// | Named tuples (`tuple<foo: x, bar: y, ...>`) | [Map<String, dynamic>]        |
/// | Ranges                                      | [Range<dynamic>]              |
/// | Multiranges                                 | [MultiRange<dynamic>]         |
/// | Enums                                       | [String]                      |
/// | `str`                                       | [String]                      |
/// | `bool`                                      | [bool]                        |
/// | `int16`/`int32`/`int64`                     | [int]                         |
/// | `float32`/`float64`                         | [double]                      |
/// | `json`                                      | as decoded by `json.decode()` |
/// | `uuid`                                      | [String]                      |
/// | `bigint`                                    | [BigInt]                      |
/// | `decimal`                                   | _(unsupported)_               |
/// | `bytes`                                     | [Uint8List]                   |
/// | `datetime`                                  | [DateTime]                    |
/// | `duration`                                  | [Duration]                    |
/// | `cal::local_datetime`                       | [LocalDateTime]               |
/// | `cal::local_date`                           | [LocalDate]                   |
/// | `cal::local_time`                           | [LocalTime]                   |
/// | `cal::relative_duration`                    | [RelativeDuration]            |
/// | `cal::date_duration`                        | [DateDuration]                |
/// | `cfg::memory`                               | [ConfigMemory]                |
/// | `ext::pgvector::vector`                     | [Float32List] ([List<double>])|
///
/// ## Custom types
/// For EdgeDB types that don't have a built-in Dart type, we provide some
/// custom types:
/// - [LocalDateTime]
/// - [LocalDate]
/// - [LocalTime]
/// - [RelativeDuration]
/// - [DateDuration]
/// - [Range]
/// - [ConfigMemory]
///
/// ## EdgeDB errors
/// EdgeDB has a large range of type errors for fine-grained error handling,
/// with all exported error types inheriting from a base [EdgeDBError] type.
/// These are the main error types which are useful to watch out for (along
/// with their subtypes):
/// - [QueryError]: Errors relating to an issue with the query you're trying
///                 to run, such as syntax errors, or non-existant types/properties/links.
/// - [ExecutionError]: Runtime errors while running your query, such as
///                     cardinality violations.
/// - [ClientError]: Client side errors arising from incorrect arguments being
///                  passed to methods, etc.
/// - [AccessError]: The authentication details you provided were incorrect.
/// - [InternalServerError]: Ideally these should never happen; they indicate a
///                          bug in the EdgeDB server. It's useful if you can
///                          report these errors here: <https://github.com/edgedb/edgedb/issues>
///

library edgedb;

export 'src/client.dart' show createClient, Client, Executor, Transaction;
export 'src/options.dart' hide serialiseState, getRuleForException;
export 'src/connect_config.dart' show ConnectConfig, TLSSecurity;
export 'src/errors/errors.dart';
export 'src/datatypes/datetime.dart'
    show LocalDateTime, LocalDate, LocalTime, RelativeDuration, DateDuration;
export 'src/datatypes/range.dart' show Range, MultiRange;
export 'src/datatypes/memory.dart' show ConfigMemory;
