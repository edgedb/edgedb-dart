import 'package:edgedb/edgedb.dart';

void main() async {
  final client = createClient(instanceName: '_localdev');

  print(await client.query(r'''
    select {
      nums := {1, 2, 3} * <int32>$num,
      message := 'Hello ' ++ <str>$name ++ '!',
      version := sys::get_version()
    }
  ''', {'num': 4, 'name': 'Dart'}));

  client.close();
}
