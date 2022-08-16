import 'package:edgedb/edgedb.dart';
import 'getMovieById.edgeql.dart';

const movieId = '85a3621e-0db9-11ed-aa0d-c7e99bf760a2';

void main() async {
  final client = createClient(instanceName: '_localdev', database: '_example');

  final res = await client.getMovieById(id: movieId);

  final res2 = await client.transaction((t) async {
    return await t.getMovieById(id: movieId);
  });

  print(res2);

  print(res?.actors.map((actor) => actor.name));
  print(res?.tup.$0);

  client.close();
}
