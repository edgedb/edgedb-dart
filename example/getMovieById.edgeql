select Movie {
  title,
  release_year,
  actors: {
    name
  },
  bytes := b'hello world',
  version := sys::get_version(),
  tup := (123, 'abc'),
} filter .id = <uuid>$id