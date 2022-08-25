select Movie {
  title,
  release_year,
  actors: {
    name,
    @character_name,
  }
} filter .actors.name = <str>$name;
