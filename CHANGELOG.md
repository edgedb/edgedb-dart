# 0.1.0

- First release of edgedb-dart 🎉

# 0.2.0

- Add support for cloud instances and `secretKey` option
- Add support for tuples in query parameters (requires EdgeDB >= v3.0)
- Fix some bugs in codegen:
  - Validate the generated codec is compatible with the codec returned by
    the server at runtime if type descriptor ids don't match (Can happen if
    the generated query method is run against a different EdgeDB instance from
    the one that was used to run codegen)
  - Fix handling of optional and complex query parameters
