select {
  str := <str>$0,
  optStr := <optional str>$1,
  tup := <tuple<str, int64>>$2,
  namedTup := <tuple<a: str, b: int64>>$3,
  arrayTup := <array<tuple<str, bool>>>$4,
  optTup := <optional tuple<str, int64>>$5,
}