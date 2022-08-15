select Movie {
  title,
  release_year,
  actors: {
    name
  },
} filter .id = <uuid>$id