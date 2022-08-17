import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:edgedb/edgedb.dart';
import 'package:test/test.dart';

import 'testbase.dart';

class CancelTransaction extends Error {}

void main() {
  test('query: basic scalars', () async {
    final client = getClient();
    try {
      expect(await client.query('select {"a", "bc"}'), ['a', 'bc']);

      expect(await client.querySingle('''select [
        -1,
        1,
        0,
        15,
        281474976710656,
        22,
        -11111,
        346456723423,
        -346456723423,
        2251799813685125,
        -2251799813685125
      ];'''), [
        -1,
        1,
        0,
        15,
        281474976710656,
        22,
        -11111,
        346456723423,
        -346456723423,
        2251799813685125,
        -2251799813685125,
      ]);

      expect(await client.query('select <int32>{-1, 0, 1, 10, 2147483647};'),
          [-1, 0, 1, 10, 2147483647]);

      expect(await client.query('select <int16>{-1, 0, 1, 10, 15, 22, -1111};'),
          [-1, 0, 1, 10, 15, 22, -1111]);

      expect(await client.query('select {true, false, false, true, false};'),
          [true, false, false, true, false]);

      expect(await client.querySingle('select [<float64>123.2, <float64>-1.1]'),
          [123.2, -1.1]);

      var floatRes =
          await client.querySingle('select [<float32>123.2, <float32>-1.1]');
      expect(floatRes[0], closeTo(123.2, 0.00001));
      expect(floatRes[1], closeTo(-1.1, 0.00001));

      expect(await client.querySingle('select b"abcdef"'),
          Uint8List.fromList(utf8.encode('abcdef')));

      expect(await client.querySingle('select <json>[1, 2, 3]'), [1, 2, 3]);
    } finally {
      client.close();
    }
  });

  test('fetch: bigint', () async {
    final client = getClient();

    final testInts = [
      BigInt.parse("0"),
      BigInt.parse("-0"),
      BigInt.parse("+0"),
      BigInt.parse("1"),
      BigInt.parse("-1"),
      BigInt.parse("123"),
      BigInt.parse("-123"),
      BigInt.parse("123789"),
      BigInt.parse("-123789"),
      BigInt.parse("19876"),
      BigInt.parse("-19876"),
      BigInt.parse("19876"),
      BigInt.parse("-19876"),
      BigInt.parse("198761239812739812739801279371289371932"),
      BigInt.parse("-198761182763908473812974620938742386"),
      BigInt.parse("98761239812739812739801279371289371932"),
      BigInt.parse("-98761182763908473812974620938742386"),
      BigInt.parse("8761239812739812739801279371289371932"),
      BigInt.parse("-8761182763908473812974620938742386"),
      BigInt.parse("761239812739812739801279371289371932"),
      BigInt.parse("-761182763908473812974620938742386"),
      BigInt.parse("61239812739812739801279371289371932"),
      BigInt.parse("-61182763908473812974620938742386"),
      BigInt.parse("1239812739812739801279371289371932"),
      BigInt.parse("-1182763908473812974620938742386"),
      BigInt.parse("9812739812739801279371289371932"),
      BigInt.parse("-3908473812974620938742386"),
      BigInt.parse("98127373373209"),
      BigInt.parse("-4620938742386"),
      BigInt.parse("100000000000"),
      BigInt.parse("-100000000000"),
      BigInt.parse("10000000000"),
      BigInt.parse("-10000000000"),
      BigInt.parse("1000000000"),
      BigInt.parse("-1000000000"),
      BigInt.parse("100000000"),
      BigInt.parse("-100000000"),
      BigInt.parse("10000000"),
      BigInt.parse("-10000000"),
      BigInt.parse("1000000"),
      BigInt.parse("-1000000"),
      BigInt.parse("100000"),
      BigInt.parse("-100000"),
      BigInt.parse("10000"),
      BigInt.parse("-10000"),
      BigInt.parse("1000"),
      BigInt.parse("-1000"),
      BigInt.parse("100"),
      BigInt.parse("-100"),
      BigInt.parse("10"),
      BigInt.parse("-10"),
      BigInt.parse("100030000010"),
      BigInt.parse("-100000600004"),
      BigInt.parse("10000000100"),
      BigInt.parse("-10030000000"),
      BigInt.parse("1000040000"),
      BigInt.parse("-1000000000"),
      BigInt.parse("1010000001"),
      BigInt.parse("-1000000001"),
      BigInt.parse("1001001000"),
      BigInt.parse("-10000099"),
      BigInt.parse("99999"),
      BigInt.parse("9999"),
      BigInt.parse("999"),
      BigInt.parse("1011"),
      BigInt.parse("1009"),
      BigInt.parse("1709"),
    ];

    final rand = Random();
    // Generate random bigints
    for (var i = 0; i < 1000; i++) {
      final len = rand.nextInt(30) + 1;
      var num = '';
      for (var j = 0; j < len; j++) {
        num += '0123456789'[rand.nextInt(10)];
      }
      testInts.add(BigInt.parse(num));
    }

    // Generate more random bigints consisting from mostly 0s
    for (var i = 0; i < 1000; i++) {
      final len = rand.nextInt(50) + 1;
      var num = "";
      for (var j = 0; j < len; j++) {
        num += "0000000012"[rand.nextInt(10)];
      }
      testInts.add(BigInt.parse(num));
    }

    try {
      expect(await client.querySingle(r'select <array<bigint>>$0', [testInts]),
          testInts);
    } finally {
      client.close();
    }
  });

  test(skip: 'Decimal type unimplemented', "fetch: decimal", () async {});

  test("fetch: positional args", () async {
    final client = getClient();
    try {
      final intCases = [
        [
          ["int16", "int32", "int64"],
          [1, 1111],
        ],
        [
          ["int16", "int32", "int64"],
          [100, -101],
        ],
        [
          ["int16", "int32", "int64"],
          [10011, 0],
        ],
        [
          ["int64"],
          [17592186032104, -4398037227340]
        ],
        [
          ["float32", "float64"],
          [10011, 12312],
        ],
      ];
      for (var intCase in intCases) {
        for (var type in intCase[0]) {
          expect(
              await client.querySingle(
                  'select (<$type>\$0 + <$type>\$1,);', intCase[1]),
              [(intCase[1][0] as int) + (intCase[1][1] as int)]);
        }
      }

      expect(
          await client.querySingle(r'select <json>$0', [
            [1, 2]
          ]),
          [1, 2]);

      expect(await client.querySingle(r'select <str>$0', ["[1,2]"]), "[1,2]");

      expect(
          await client
              .querySingle(r'select (<bool>$0, <bool>$1)', [true, false]),
          [true, false]);

      final bytes = (ByteData(4)..setInt32(0, -12312)).buffer.asUint8List();
      expect(await client.querySingle(r'select <bytes>$0', [bytes]), bytes);

      final dt = DateTime.now();
      expect(await client.querySingle(r'select <datetime>$0', [dt]), dt);
      expect(
          await client
              .querySingle(r'select [<datetime>$0, <datetime>$0]', [dt]),
          [dt, dt]);

      // final ldt = LocalDateTime(2012, 6, 30, 14, 11, 33, 123, 456);
      // final res = await client.querySingle(r'select <cal::local_datetime>$0', [ldt]);
      // expect(res, isA<LocalDateTime>());
      // expect((res as LocalDateTime).hour).toBe(14);
      // expect((res as LocalDateTime).toString()).toBe(
      //   "2012-06-30T14:11:33.123456"
      // );

      expect(
          await client.querySingle(r'select len(<array<int64>>$0)', [
            [1, 2, 3, 4, 5],
          ]),
          5);
    } finally {
      await client.close();
    }
  });

  test("fetch: named args", () async {
    final client = getClient();
    try {
      expect(await client.querySingle(r'select <str>$a', {'a': '123'}), '123');

      expect(
          await client.querySingle(r'select <str>$a ++ <str>$b', {
            'b': "abc",
            'a': "123",
          }),
          "123abc");

      expect(
          client.querySingle(r'select <str>$a ++ <str>$b', {
            'b': "abc",
            'a': "123",
            'c': "def",
          }),
          throwsA(isA<UnknownArgumentError>().having((e) => e.message,
              'message', contains('Unused named argument: "c"'))));

      expect(
          await client.querySingle(r'select len(<OPTIONAL str>$a ?? "aa")', {
            'a': null,
          }),
          2);
    } finally {
      await client.close();
    }
  });

  test("fetch: datetime", () async {
    final client = getClient();
    try {
      var res = await client.querySingle('''
      with dt := <datetime>'2016-01-10T17:11:01.123Z'
      select (dt, datetime_get(dt, 'epochseconds') * 1000)
    ''');
      expect((res[0] as DateTime).millisecondsSinceEpoch, res[1]);

      res = await client.querySingle('''
      with dt := <datetime>'1716-01-10T01:00:00.123123Z'
      select (dt, datetime_get(dt, 'epochseconds') * 1000)
    ''');
      expect(
          (res[0] as DateTime).millisecondsSinceEpoch, (res[1] as num).ceil());
    } finally {
      await client.close();
    }
  });

  test(
      skip: 'LocalDate type unimplemented',
      "fetch: cal::local_date",
      () async {});

  test(skip: 'LocalTime type unimplemented', "fetch: local_time", () async {});

  test("fetch: duration", () async {
    final client = getClient();
    try {
      for (var time in [
        ["24 hours", Duration(hours: 24)],
        [
          "68464977 seconds 74 milliseconds 11 microseconds",
          Duration(seconds: 68464977, milliseconds: 74, microseconds: 11)
        ],
        [
          "-752043.296 milliseconds",
          Duration(milliseconds: -752043, microseconds: -296)
        ],
      ]) {
        var res = await client.querySingle(
            r'select (<duration><str>$timeStr, <duration>$time);',
            {'timeStr': time[0], 'time': time[1]});

        expect(res[0], res[1]);
        expect(res[1], time[1]);
      }
    } finally {
      await client.close();
    }
  });

  test(
      skip: 'RelativeDurationCodec unimplemented',
      "fetch: relative_duration",
      () async {});

  test(
      skip: 'ConfigMemory type unimplemented',
      "fetch: ConfigMemory",
      () async {});

  test(skip: 'range type unimplemented', "fetch: ranges", () async {});

  test(
      skip: 'DateDuration type unimplemented',
      "fetch: date_duration",
      () async {});

  test("fetch: tuple", () async {
    final client = getClient();

    try {
      expect(await client.query("select ()"), [[]]);

      expect(await client.querySingle("select (1,)"), [1]);

      expect(await client.query("select (1, 'abc')"), [
        [1, "abc"]
      ]);

      expect(await client.query("select {(1, 'abc'), (2, 'bcd')}"), [
        [1, "abc"],
        [2, "bcd"],
      ]);
    } finally {
      await client.close();
    }
  });

  test("fetch: object", () async {
    final client = getClient();

    try {
      expect(await client.querySingle('''
      select schema::Function {
        name,
        params: {
          kind,
          num,
          @foo := 42
        } order by .num asc
      }
      filter .name = 'std::str_repeat'
      limit 1
    '''), {
        'name': "std::str_repeat",
        'params': [
          {
            'kind': "PositionalParam",
            'num': 0,
            "@foo": 42,
          },
          {
            'kind': "PositionalParam",
            'num': 1,
            "@foo": 42,
          },
        ],
      });

      // regression test: test that empty sets are properly decoded.
      await client.querySingle('''
      select schema::Function {
        name,
        params: {
          kind,
        } limit 0,
        multi setarr := <array<int32>>{}
      }
      filter .name = 'std::str_repeat'
      limit 1
    ''');
    } finally {
      await client.close();
    }
  });

  test("fetch: set of arrays", () async {
    final client = getClient();

    try {
      expect(await client.querySingle('''
      select {
        sets := {[1, 2], [1]}
      }
    '''), {
        'sets': [
          [1, 2],
          [1]
        ]
      });

      expect(await client.query('select {[1, 2], [1]};'), [
        [1, 2],
        [1]
      ]);
    } finally {
      await client.close();
    }
  });

  test("fetch: object implicit fields", () async {
    final client = getClient();

    try {
      expect(
          (await client.querySingle('''
      select schema::Function {
        id,
      }
      limit 1
    ''')).toString(),
          matches(RegExp(
              r'^\{id: ([a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[a-f0-9]{4}-[a-f0-9]{12}|00000000-0000-0000-0000-000000000000)\}$')));

      var res = await client.querySingle('''
      select schema::Function
      limit 1
    ''');

      expect(res.toString(), '{id: ${res['id']}}');

      expect((await client.querySingle('''
      select schema::Function {
        name
      }
      filter .name = 'std::str_repeat'
      limit 1
    ''')).toString(), '{name: std::str_repeat}');
    } finally {
      await client.close();
    }
  });

  test("fetch: uuid", () async {
    final client = getClient();

    try {
      var res =
          await client.querySingle("SELECT schema::ObjectType.id LIMIT 1");
      expect(res, isA<String>());
      expect(res.length, 36);
      expect(res.replaceAll('-', '').length, 32);

      expect(
          await client.querySingle(
              "SELECT <uuid>'759637d8-6635-11e9-b9d4-098002d459d5'"),
          "759637d8-6635-11e9-b9d4-098002d459d5");

      expect(
          await client.queryRequiredSingle('SELECT uuid_generate_v1mc()'),
          matches(RegExp(
              r'^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$')));
    } finally {
      await client.close();
    }
  });

  test("fetch: enum", () async {
    final client = getClient();

    try {
      await client
          .withRetryOptions(RetryOptions(attempts: 1))
          .transaction((tx) async {
        await tx.execute('CREATE SCALAR TYPE MyEnum EXTENDING enum<"A", "B">;');

        expect(await tx.querySingle(r"SELECT <MyEnum><str>$0", ["A"]), 'A');

        expect(await tx.querySingle(r"SELECT <MyEnum>$0", ["A"]), 'A');

        throw CancelTransaction();
      });
    } on CancelTransaction {
      // ignore error
    } finally {
      await client.close();
    }
  });

  test("fetch: namedtuple", () async {
    final client = getClient();

    try {
      expect(await client.querySingle("select (a := 1)"), {'a': 1});

      expect(await client.querySingle("select (a := 1, b:= 'abc')"),
          {'a': 1, 'b': 'abc'});
    } finally {
      await client.close();
    }
  });

  test("querySingle: basic scalars", () async {
    final client = getClient();

    try {
      expect(await client.querySingle("select 'abc'"), 'abc');

      expect(
          await client.querySingle("select 281474976710656;"), 281474976710656);

      expect(await client.querySingle("select <int32>2147483647;"), 2147483647);

      expect(
          await client.querySingle("select <int32>-2147483648;"), -2147483648);

      expect(await client.querySingle("select <int16>-10;"), -10);

      expect(await client.querySingle("select false;"), false);
    } finally {
      await client.close();
    }
  });

  test("querySingle: arrays", () async {
    final client = getClient();

    try {
      expect(await client.querySingle("select [12312312, -1, 123, 0, 1]"),
          [12312312, -1, 123, 0, 1]);

      expect(await client.querySingle("select ['aaa']"), ["aaa"]);

      expect(await client.querySingle("select <array<str>>[]"), []);

      expect(await client.querySingle("select ['aaa', '', 'bbbb']"),
          ["aaa", "", "bbbb"]);

      expect(
          await client
              .querySingle("select ['aaa', '', 'bbbb', '', 'aaaaaa🚀a']"),
          ["aaa", "", "bbbb", "", "aaaaaa🚀a"]);
    } finally {
      await client.close();
    }
  });

  test("fetch: long strings", timeout: Timeout.factor(2), () async {
    final client = getClient();

    try {
      // A 1mb string.
      expect(
          (await client.querySingle("select str_repeat('a', <int64>(10^6));"))
              .length,
          1000000);

      // A 100mb string.
      // TODO: fix this
      // await expectLater(
      //     client.querySingle("select str_repeat('aa', <int64>(10^8));"),
      //     throwsA(isA<InternalClientError>().having(
      //         (e) => e.message, 'message', contains('message too big'))));
    } finally {
      await client.close();
    }
  });

  test("querySingleJSON", () async {
    final client = getClient();

    try {
      expect(await client.querySingleJSON("select (a := 1)"), '{"a" : 1}');

      expect(await client.querySingleJSON("select (a := 1n)"), '{"a" : 1}');

      expect(await client.querySingleJSON("select (a := 1.5n)"), '{"a" : 1.5}');
    } finally {
      await client.close();
    }
  });

  test("queryJSON", () async {
    final client = getClient();
    try {
      expect(
          jsonDecode(await client.queryJSON("select {(a := 1), (a := 2)}")), [
        {'a': 1},
        {'a': 2}
      ]);
    } finally {
      await client.close();
    }
  });

  test("query(Required)Single cardinality", () async {
    final client = getClient();

    Future<void> querySingleTests(Executor conn) async {
      expect(await conn.querySingle("select 'test'"), 'test');
      expect(await conn.querySingle("select <str>{}"), null);
      await expectLater(
          conn.querySingle("select {'multiple', 'test', 'strings'}"),
          throwsA(isA<ResultCardinalityMismatchError>()));
    }

    Future<void> queryRequiredSingleTests(Executor conn) async {
      expect(await conn.queryRequiredSingle("select 'test'"), 'test');
      await expectLater(conn.queryRequiredSingle("select <str>{}"),
          throwsA(isA<NoDataError>()));
      await expectLater(
          conn.queryRequiredSingle("select {'multiple', 'test', 'strings'}"),
          throwsA(isA<ResultCardinalityMismatchError>()));
    }

    Future<void> querySingleJSONTests(Executor conn) async {
      expect(await conn.querySingleJSON("select 'test'"), '"test"');
      expect(await conn.querySingleJSON("select <str>{}"), "null");
      await expectLater(
          conn.querySingleJSON("select {'multiple', 'test', 'strings'}"),
          throwsA(isA<ResultCardinalityMismatchError>()));
    }

    Future<void> queryRequiredSingleJSONTests(Executor conn) async {
      expect(await conn.queryRequiredSingleJSON("select 'test'"), '"test"');
      await expectLater(conn.queryRequiredSingleJSON("select <str>{}"),
          throwsA(isA<NoDataError>()));
      await expectLater(
          conn.queryRequiredSingleJSON(
              "select {'multiple', 'test', 'strings'}"),
          throwsA(isA<ResultCardinalityMismatchError>()));
    }

    for (var tests in [
      querySingleTests,
      queryRequiredSingleTests,
      querySingleJSONTests,
      queryRequiredSingleJSONTests,
    ]) {
      await tests(client);
      // TODO: fix errors in transactions
      // await client.transaction((tx) => tests(tx));
    }

    client.close();
  });
}
