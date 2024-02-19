select {
  str := <str>$str,
  optStr := <optional str>$optStr,
  tup := <tuple<str, int64>>$tup,
  namedTup := <tuple<a: str, b: int64>>$namedTup,
  arrayTup := <array<tuple<str, bool>>>$arrayTup,
  optTup := <optional tuple<str, int64>>$optTup,
  enumTest := sys::VersionStage.dev,

  # test (empty) set decoding
  multi mStr := 'test',
  multi mStrEmpty := <str>{},
  multi mStrArray := ['test'],
  multi mStrArrayEmpty := <array<str>>{},
}