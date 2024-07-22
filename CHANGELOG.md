# 0.5.1

- Fix bug in decoding of secret key JWT payload

# 0.5.0

- Add support for branching in EdgeDB 5.0 (`branch` option / `EDGEDB_BRANCH`
  env var / `branch` param in DSN)

# 0.4.1

- Fix bug in set codec type casting, that was causing an error when codegen
  queries returned an empty set or set of arrays
- Fix regression in codegen for enum types, introduced in 0.4.0

# 0.4.0

- Add support for multiranges in EdgeDB 4.0
- Update to handle EdgeDB protocol v2
- Add support for project default database config
- Fix handling of `EDGEDB_CLOUD_PROFILE` env var when instance name is
  specified as a config option to `createClient`
- Update error classes

# 0.3.0

- Fix cloud instance resolution by normalizing cloud instance names to
  lowercase when computing cloud host
- Add support for pgvector extension (<https://www.edgedb.com/docs/stdlib/pgvector>)
- Codegen bug fixes:
  - Fix query escaping
  - Fix bug when query returns scalar type that is not a builtin dart type

# 0.2.2

- Update EdgeDB error classes
- Add `toJson` method to codegen result classes
- Fix bug in connection config explain when password is empty string

# 0.2.1

- Update to handle new instance name rules
- Fix sending of secret key parameter in connection handshake

# 0.2.0

- Add support for cloud instances and `secretKey` option
- Add support for tuples in query parameters (requires EdgeDB >= v3.0)
- Fix some bugs in codegen:
  - Validate the generated codec is compatible with the codec returned by
    the server at runtime if type descriptor ids don't match (Can happen if
    the generated query method is run against a different EdgeDB instance from
    the one that was used to run codegen)
  - Fix handling of optional and complex query parameters

# 0.1.0

- First release of edgedb-dart 🎉
