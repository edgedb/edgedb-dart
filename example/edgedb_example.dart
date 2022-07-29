import 'package:edgedb/edgedb.dart';

void main() async {
  var conn = BinaryProtocol();

  await conn.connect();

  final result =
      await conn.fetch(query: 'select 1 + 2', asJson: false, expectOne: false);

  print(result);
}
