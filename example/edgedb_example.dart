import 'package:edgedb/edgedb.dart';

void main() async {
  var conn = TCPProtocol();

  await conn.connect(
      host: 'localhost', port: 5656, username: 'test', password: 'test');

  final result = await conn.fetch(
      query: 'select 1 + 2',
      outputFormat: OutputFormat.binary,
      expectedCardinality: Cardinality.many);

  print(result);
}
