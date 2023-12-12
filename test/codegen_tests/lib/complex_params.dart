import 'package:edgedb/edgedb.dart';

import 'complexParams.edgeql.dart';

void main() async {
  final client = createClient();

  try {
    await client.complexParams(
        str: 'test',
        optStr: 'opt test',
        tup: Param_tup('test', 123),
        namedTup: Param_namedTup(a: 'test', b: 456),
        arrayTup: [Param_arrayTup('test', true)],
        optTup: Param_optTup('test', 123),
        verStage: sys_VersionStage.dev);

    // skip optional params
    await client.complexParams(
        str: 'test',
        tup: Param_tup('test', 123),
        namedTup: Param_namedTup(a: 'test', b: 456),
        arrayTup: [Param_arrayTup('test', true)],
        verStage: sys_VersionStage.dev);
  } finally {
    await client.close();
  }
}
