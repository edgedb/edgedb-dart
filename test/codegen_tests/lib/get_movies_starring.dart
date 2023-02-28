import 'package:edgedb/edgedb.dart';

import 'getMoviesStarring.edgeql.dart';

void main() async {
  final client = createClient();

  try {
    final movies = await client.getMoviesStarring(name: 'Ben Kingsley');

    for (var movie in movies) {
      print('Title: ${movie.title}\n'
          'Release Year: ${movie.release_year}\n'
          'Cast:\n${movie.actors.map((actor) {
        return '  ${actor.$character_name}: ${actor.name}';
      }).join('\n')}\n');
    }
  } finally {
    await client.close();
  }
}
