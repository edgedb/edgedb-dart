import 'package:edgedb/edgedb.dart';

import 'positionalParams.edgeql.dart';

void main() async {
  final client = createClient();

  try {
    await client.positionalParams(
        'test',
        'opt test',
        Param_2('test', 123),
        Param_3(a: 'test', b: 456),
        [Param_4('test', true)],
        Param_5('test', 123));

    // skip optional params
    await client.positionalParams('test', null, Param_2('test', 123),
        Param_3(a: 'test', b: 456), [Param_4('test', true)], null);
  } finally {
    await client.close();
  }
}
