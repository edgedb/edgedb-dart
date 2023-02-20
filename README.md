# Dart client library for EdgeDB

This is the official [EdgeDB](https://github.com/edgedb/edgedb) client library
for Dart.

If you're just getting started with EdgeDB, we recommend going through the
[EdgeDB Quickstart](https://www.edgedb.com/docs/quickstart) first. This walks
you through the process of installing EdgeDB, creating a simple schema, and
writing some simple queries.

> Note: Only EdgeDB version >=2.0 is supported by this library.

## Installing

Add `edgedb` to the dependencies in your `pubspec.yaml` file:

```sh
dart pub add edgedb
```

This package contains both the core `edgedb` library, which exports all the
API's needed to connect to an EdgeDB server and run queries, along with the
`edgeql-codegen` library, which provides a builder for Dart's
[build_runner](https://dart.dev/tools/build_runner) to generate fully
typed query methods from `.edgeql` files.

## Basic Usage

First you'll need to have EdgeDB installed, and to have created an instance for
your project; we recommend the [Quickstart guide](https://www.edgedb.com/docs/quickstart)
for a overview on how to do this.

Then import the `edgedb` library, and create a new client with `createClient()`.

```dart
import 'package:edgedb/edgedb.dart';

final client = createClient();
```

In most cases `createClient()` needs no arguments; the library will determine
how to connect to your instance automatically if you're either: using an
EdgeDB project, as recommended for development, or providing connection
options via environment variables, as recommended for production use. For
more advanced use cases refer to the `createClient()` api docs, for the full
list of connection options you can provide.

Now you're ready to start making queries:

```dart
void main() async {
  final movie = await client.querySingle(r'''
    select Movie {
      title,
      release_year,
      actors: {
        name,
        @character_name
      }
    } filter .title = <str>$title
  ''', {
    'title': 'Spider-man'
  });

  print(movie);
}
```

The `Client` class provides a range of methods to run queries, with options
return the results as JSON, and enforce result cardinality. All query methods
have the ability to recover from temporary errors (like network interruptions)
when it is safe to do so. `Client` also has API's for easily working with
transactions, setting `globals` for your queries, and configuring other
client behaviour. See the [API documentation] for the full details.

## Type safety

The basic query methods on `Client` return results typed as `dynamic`, and
only have runtime checks on the types of query parameters passed to them.
For fully type safe querying, this package provides a `build_runner` builder
in the `edgeql_codegen` library. This builder takes any `.edgeql` files in your
project and generates extension methods on the `Client` class, which return
fully typed results, and take correctly typed query arguments.

To use `edgeql_codegen`, first add the `build_runner` dependency to your
`pubspec.yaml` file:

```sh
dart pub add build_runner
```

Out of the box, the `edgeql_codegen` builder will generate `.edgeql.dart`
files containing the typed query methods alongside all `.edgeql` files for the
default `build_runner` target, so you can just run the `build` or `watch`
commands without any configuration needed:

```sh
dart run build_runner build
# or
dart run build_runner watch
```

For an example using `edgeql_codegen`, check out the `example` directory. Full
details on how generated types are converted from `edgeql` queries, see the
`edgeql_codegen` library api docs.

To customise the build, create a `build.yaml` in your project root, and follow
the [build_config](https://pub.dev/packages/build_config) docs. If you
customise the `sources` configuration, be sure to exclude the `.edgeql` files
in your `dbschema/migrations` directory.

## Contributing

Development of this library requires a local installation of EdgeDB to run
the test suite. (You'll need the `edgedb-server` binary in your `PATH`).
This can be done either following these
[install instructions](https://www.edgedb.com/install#linux-debianubuntults)
or [building from source](https://www.edgedb.com/docs/guides/contributing).

To run tests use the command:

```sh
dart run test/run.dart
```

This is a wrapper around the `dart test` tool which handles starting/shutting
down an EdgeDB server instance required by the tests.

## License

edgedb-dart is developed and distributed under the Apache 2.0 license.
