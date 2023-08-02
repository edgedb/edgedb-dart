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

      final dt = DateTime.now().toUtc();
      expect(await client.querySingle(r'select <datetime>$0', [dt]), dt);
      expect(
          await client
              .querySingle(r'select [<datetime>$0, <datetime>$0]', [dt]),
          [dt, dt]);

      final ldt = LocalDateTime(2012, 6, 30, 14, 11, 33, 123, 456);
      final res =
          await client.querySingle(r'select <cal::local_datetime>$0', [ldt]);
      expect(res, isA<LocalDateTime>());
      expect((res as LocalDateTime).hour, 14);
      expect(res.toString(), '2012-06-30T14:11:33.123456');

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

  test("fetch: tuples in args",
      skip: getServerVersion() < ServerVersion(3, 0)
          ? 'tuple args only supported in EdgeDB >= 3.0'
          : null, () async {
    final client = getClient();
    try {
      final tests = <String, List<dynamic>>{
        // Basic tuples
        'tuple<str, bool>': [
          ['x', true],
          ['y', false]
        ],
        'optional tuple<str, bool>': [
          ['x', true],
          null
        ],
        // Some pointlessly nested tuples
        'tuple<tuple<str, bool>>': [
          [
            ['x', true]
          ]
        ],
        'tuple<tuple<str, bool>, int64>': [
          [
            ['x', true],
            1
          ]
        ],
        // Basic array examples
        'array<tuple<int64, str>>': [
          [],
          [
            [0, 'zero']
          ],
          [
            [0, 'zero'],
            [1, 'one']
          ],
        ],
        'optional array<tuple<int64, str>>': [
          null,
          [],
          [
            [0, 'zero']
          ],
          [
            [0, 'zero'],
            [1, 'one']
          ],
        ],
        'array<tuple<str, array<int64>>>': [
          [],
          [
            ['x', []]
          ],
          [
            [
              'x',
              [1]
            ]
          ],
          [
            ['x', []],
            ['y', []],
            ['z', []]
          ],
          [
            [
              'x',
              [1]
            ],
            ['y', []],
            ['z', []]
          ],
          [
            ['x', []],
            [
              'y',
              [1]
            ],
            ['z', []]
          ],
          [
            ['x', []],
            ['y', []],
            [
              'z',
              [1]
            ]
          ],
          [
            ['x', []],
            [
              'y',
              [1, 2]
            ],
            [
              'z',
              [1, 2, 3]
            ]
          ],
        ],
        // Arrays of pointlessly nested tuples
        'array<tuple<tuple<str, bool>, int64>>': [
          [],
          [
            [
              ['x', true],
              1
            ]
          ],
          [
            [
              ['x', true],
              1
            ],
            [
              ['z', false],
              2
            ]
          ],
        ],
        'array<tuple<tuple<array<str>, bool>, int64>>': [
          [],
          [
            [
              [[], true],
              1
            ]
          ],
          [
            [
              [
                ['x', 'y', 'z'],
                true
              ],
              1
            ],
            [
              [
                ['z'],
                false
              ],
              2
            ]
          ],
        ],
        // Named tuples
        'tuple<a: str, b: bool>': [
          {'a': 'x', 'b': true}
        ],
        'optional tuple<a: str, b: bool>': [
          {'a': 'x', 'b': true},
          null
        ],
        'tuple<x: tuple<a: str, b: bool>>': [
          {
            'x': {'a': 'x', 'b': true}
          }
        ],
        'tuple<x: tuple<a: str, b: bool>, y: int64>': [
          {
            'x': {'a': 'x', 'b': true},
            'y': 1
          }
        ],
        'array<tuple<a: int64, b: str>>': [
          [],
          [
            {'a': 0, 'b': 'zero'}
          ],
          [
            {'a': 0, 'b': 'zero'},
            {'a': 1, 'b': 'one'}
          ],
        ],
        'optional array<tuple<a: int64, b: str>>': [
          null,
          [],
          [
            {'a': 0, 'b': 'zero'}
          ],
          [
            {'a': 0, 'b': 'zero'},
            {'a': 1, 'b': 'one'}
          ],
        ],
        'array<tuple<a: str, b: array<int64>>>': [
          [],
          [
            {'a': 'x', 'b': []}
          ],
          [
            {
              'a': 'x',
              'b': [1]
            }
          ],
          [
            {'a': 'x', 'b': []},
            {'a': 'y', 'b': []},
            {'a': 'z', 'b': []}
          ],
          [
            {
              'a': 'x',
              'b': [1]
            },
            {'a': 'y', 'b': []},
            {'a': 'z', 'b': []}
          ],
          [
            {'a': 'x', 'b': []},
            {
              'a': 'y',
              'b': [1]
            },
            {'a': 'z', 'b': []}
          ],
          [
            {'a': 'x', 'b': []},
            {'a': 'y', 'b': []},
            {
              'a': 'z',
              'b': [1]
            }
          ],
          [
            {'a': 'x', 'b': []},
            {
              'a': 'y',
              'b': [1, 2]
            },
            {
              'a': 'z',
              'b': [1, 2, 3]
            }
          ],
        ],
      };

      for (var entry in tests.entries) {
        for (var input in entry.value) {
          expect(await client.querySingle('select <${entry.key}>\$0', [input]),
              input);
        }
      }

      await expectLater(
          client.query(r'select <tuple<str, int64>>$test', {
            'test': ['str', 123, 456]
          }),
          throwsA(isA<QueryArgumentError>().having((e) => e.message, 'message',
              contains('expected 2 elements in Tuple, got 3'))));

      await expectLater(
          client.query(r'select <tuple<str, int64>>$test', {
            'test': ['str', '123']
          }),
          throwsA(isA<QueryArgumentError>().having(
              (e) => e.message,
              'message',
              contains(
                  'invalid element at index 1 in Tuple: an int was expected, got String'))));

      await expectLater(
          client.query(r'select <tuple<str, int64>>$test', {
            'test': ['str', null]
          }),
          throwsA(isA<QueryArgumentError>().having((e) => e.message, 'message',
              contains("element at index 1 in Tuple cannot be 'null'"))));

      await expectLater(
          client.query(r'select <tuple<a: str, b: int64>>$test', {
            'test': ['str', 123]
          }),
          throwsA(isA<QueryArgumentError>().having(
              (e) => e.message,
              'message',
              contains(
                  'a Map<String, dynamic> or EdgeDBNamedTuple was expected, got "List<Object>"'))));

      await expectLater(
          client.query(r'select <tuple<str, int64>>$test', {
            'test': {'a': 'str', 'b': 123}
          }),
          throwsA(isA<QueryArgumentError>().having(
              (e) => e.message,
              'message',
              contains(
                  'a List or EdgeDBTuple was expected, got "_Map<String, Object>"'))));

      await expectLater(
          client.query(r'select <tuple<a: str, b: int64>>$test', {
            'test': {'a': 'str', 'b': 123, 'c': 456}
          }),
          throwsA(isA<QueryArgumentError>().having((e) => e.message, 'message',
              contains('expected 2 elements in NamedTuple, got 3'))));

      await expectLater(
          client.query(r'select <tuple<a: str, b: int64>>$test', {
            'test': {'a': 'str', 'b': '123'}
          }),
          throwsA(isA<QueryArgumentError>().having(
              (e) => e.message,
              'message',
              contains(
                  "invalid element 'b' in NamedTuple: an int was expected, got String"))));

      await expectLater(
          client.query(r'select <tuple<a: str, b: int64>>$test', {
            'test': {'a': 'str', 'b': null}
          }),
          throwsA(isA<QueryArgumentError>().having((e) => e.message, 'message',
              contains("element 'b' in NamedTuple cannot be 'null'"))));
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

  test("fetch: cal::local_date", () async {
    final con = getClient();

    try {
      var res = await con.querySingle("select <cal::local_date>'2016-01-10'");
      expect(res, isA<LocalDate>());
      expect(res.toString(), '2016-01-10');

      res = await con.querySingle(r'select <cal::local_date>$0;', [res]);
      expect(res, isA<LocalDate>());
      expect(res.toString(), '2016-01-10');
    } finally {
      await con.close();
    }
  });

  test("fetch: cal::local_time", () async {
    final con = getClient();
    try {
      for (var time in [
        "11:12:13",
        "00:01:11.34",
        "00:00:00",
        "23:59:59.999",
      ]) {
        var res = await con.querySingle(
            r'select (<cal::local_time><str>$time, <str><cal::local_time><str>$time);',
            {'time': time});
        expect(res[0].toString(), res[1]);

        var res2 = await con
            .querySingle(r'select <cal::local_time>$time;', {'time': res[0]});
        expect(res2, res[0]);
      }
    } finally {
      await con.close();
    }
  });

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

  test("fetch: cal::relative_duration", () async {
    final con = getClient();
    try {
      for (var time in [
        "24 hours",
        "68464977 seconds 74 milliseconds 11 microseconds",
        "-752043.296 milliseconds",
        "20 years 5 days 10 seconds",
        "3 months",
        "7 weeks 9 microseconds",
      ]) {
        var res = await con.querySingle(r'''
        select (
          <cal::relative_duration><str>$time,
          <str><cal::relative_duration><str>$time,
        );''', {'time': time});
        expect(res[0].toString(), res[1]);

        var res2 = await con.querySingle(
            r'select <cal::relative_duration>$time;', {'time': res[0]});
        expect(res2, res[0]);
      }
    } finally {
      await con.close();
    }
  });

  test("fetch: ConfigMemory", () async {
    final client = getClient();

    try {
      for (var memStr in [
        "0B",
        "0GiB",
        "1024MiB",
        "9223372036854775807B",
        "123KiB",
        "9MiB",
        "102938GiB",
        "108TiB",
        "42PiB",
      ]) {
        final res = await client.querySingle(r'''
          select (
            <cfg::memory><str>$mem,
            <str><cfg::memory><str>$mem,
          );''', {'mem': memStr});
        expect(res[0].toString(), res[1]);

        final res2 = await client
            .querySingle(r'select <cfg::memory>$mem;', {'mem': res[0]});
        expect(res2.toString(), res[0].toString());
      }
    } finally {
      await client.close();
    }
  });

  test("fetch: ranges", () async {
    expandRangeEQL(String lower, String upper) {
      return [
        [false, false],
        [true, false],
        [false, true],
        [true, true],
      ]
          .map((inc) =>
              'range($lower, $upper, inc_lower := ${inc[0]}, inc_upper := ${inc[1]})')
          .join(",\n");
    }

    expandRange(dynamic lower, dynamic upper) {
      return [
        Range<dynamic>(lower, upper, incLower: false, incUpper: false),
        Range<dynamic>(lower, upper, incLower: true, incUpper: false),
        Range<dynamic>(lower, upper, incLower: false, incUpper: true),
        Range<dynamic>(lower, upper, incLower: true, incUpper: true),
      ];
    }

    final client = getClient();

    try {
      final res = await client.querySingle('''
        select {
          ints := (${expandRangeEQL("123", "456")}),
          floats := (${expandRangeEQL("123.456", "456.789")}),
          datetimes := (${expandRangeEQL("<datetime>'2022-07-01T16:00:00+00'", "<datetime>'2022-07-01T16:30:00+00'")}),
        }
      ''');
      // local_dates := (${expandRangeEQL("<cal::local_date>'2022-07-01'", "<cal::local_date>'2022-07-14'")}),
      // local_datetimes := (${expandRangeEQL("<cal::local_datetime>'2022-07-01T12:00:00'", "<cal::local_datetime>'2022-07-14T12:00:00'")}),

      expect(res, {
        'ints': [
          Range<dynamic>(124, 456),
          Range<dynamic>(123, 456),
          Range<dynamic>(124, 457),
          Range<dynamic>(123, 457),
        ],
        'floats': expandRange(123.456, 456.789),
        'datetimes': expandRange(DateTime.parse("2022-07-01T16:00:00Z"),
            DateTime.parse("2022-07-01T16:30:00Z")),
        // local_dates: [
        //   new Range(new LocalDate(2022, 7, 2), new LocalDate(2022, 7, 14)),
        //   new Range(new LocalDate(2022, 7, 1), new LocalDate(2022, 7, 14)),
        //   new Range(new LocalDate(2022, 7, 2), new LocalDate(2022, 7, 15)),
        //   new Range(new LocalDate(2022, 7, 1), new LocalDate(2022, 7, 15)),
        // ],
        // local_datetimes: expandRangeJS(
        //   new LocalDateTime(2022, 7, 1, 12),
        //   new LocalDateTime(2022, 7, 14, 12)
        // ),
      });

      expect(await client.querySingle('''
          select all({
            [${expandRangeEQL("123", "456")}] = <array<range<int64>>>\$ints,
            [${expandRangeEQL("123.456", "456.789")}] = <array<range<float64>>>\$floats,
            [${expandRangeEQL("<datetime>'2022-07-01T16:00:00+00'", "<datetime>'2022-07-01T16:30:00+00'")}] = <array<range<datetime>>>\$datetimes,
          })''', res), true);

      // [${expandRangeEQL(
      //   "<cal::local_date>'2022-07-01'",
      //   "<cal::local_date>'2022-07-14'"
      // )}] = <array<range<cal::local_date>>>$local_dates,
      // [${expandRangeEQL(
      //   "<cal::local_datetime>'2022-07-01T12:00:00'",
      //   "<cal::local_datetime>'2022-07-14T12:00:00'"
      // )}] = <array<range<cal::local_datetime>>>$local_datetimes,
    } finally {
      await client.close();
    }
  });

  test("fetch: multirange",
      skip: getServerVersion() < ServerVersion(4, 0)
          ? 'multiranges only supported in EdgeDB >= 4.0'
          : null, () async {
    final samples = [
      {'in': MultiRange([])},
      {
        'in': MultiRange([Range.empty()]),
        'out': MultiRange([]),
      },
      {
        'in': MultiRange<dynamic>([
          Range(null, 0),
          Range(1, 2),
          Range(4, null),
        ])
      },
      {
        'in': MultiRange<int>([
          Range(null, 2, incUpper: true),
          Range(5, 9),
          Range(5, 9),
          Range(5, 9),
          Range(null, 2, incUpper: true),
        ]),
        'out': MultiRange<dynamic>([
          Range(5, 9),
          Range(null, 3),
        ]),
      },
      {
        'in': MultiRange<int>([
          Range(null, 2),
          Range(-5, 9),
          Range(13, null),
        ]),
        'out': MultiRange<dynamic>([Range(null, 9), Range(13, null)]),
      }
    ];

    final client = getClient();

    try {
      final result =
          await client.querySingle(r'SELECT <array<multirange<int32>>>$0', [
        [
          MultiRange([Range(1, 2)])
        ]
      ]);
      expect(result, [
        MultiRange<dynamic>([Range(1, 2)])
      ]);

      for (var sample in samples) {
        final result = await client
            .querySingle(r'select <multirange<int64>>$0', [sample['in']]);

        expect(result, sample['out'] ?? sample['in']);
      }
    } finally {
      await client.close();
    }
  });

  test("fetch: cal::date_duration", () async {
    final con = getClient();

    try {
      for (var time in [
        "1 day",
        "-752043 days",
        "20 years 5 days",
        "3 months",
        "7 weeks",
      ]) {
        var res = await con.querySingle(r'''
          select (
            <cal::date_duration><str>$time,
            <str><cal::date_duration><str>$time,
          );''', {'time': time});
        expect(res[0].toString(), res[1]);

        var res2 = await con.querySingle(
            r'select <cal::date_duration>$time;', {'time': res[0]});
        expect(res2, res[0]);
      }
    } finally {
      await con.close();
    }
  });

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
      await expectLater(
          client.querySingle("select str_repeat('aa', <int64>(10^8));"),
          throwsA(isA<EdgeDBError>().having(
              (e) => e.message, 'message', contains('message too big'))));
    } finally {
      await client.close();
    }
  });

  test("fetch: pgvector",
      skip: getServerVersion() < ServerVersion(3, 0)
          ? 'pgvector only supported in EdgeDB >= 3.0'
          : null, () async {
    final client = getClient();

    try {
      await client
          .withRetryOptions(RetryOptions(attempts: 1))
          .transaction((tx) async {
        await tx.execute('create extension pgvector');

        expect(
            await tx
                .querySingle(r"select <ext::pgvector::vector>[1.5,2.0,3.8]"),
            Float32List.fromList([1.5, 2.0, 3.8]));

        expect(
            await tx.querySingle(r"select <ext::pgvector::vector>$0", [
              Float32List.fromList([3.0, 9.0, -42.5])
            ]),
            Float32List.fromList([3, 9, -42.5]));

        expect(
            await tx.querySingle(r"select <json><ext::pgvector::vector>$0", [
              Float32List.fromList([3.0, 9.0, -42.5])
            ]),
            [3, 9, -42.5]);

        expect(
            await tx.querySingle(r"select <ext::pgvector::vector>$0", [
              [3.0, 9.0, -42.5]
            ]),
            Float32List.fromList([3, 9, -42.5]));

        expect(
            await tx.querySingle(r"select <json><ext::pgvector::vector>$0", [
              [3.0, 9.0, -42.5]
            ]),
            [3, 9, -42.5]);

        throw CancelTransaction();
      });
    } on CancelTransaction {
      // ignore error
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
      try {
        await client.transaction((tx) => tests(tx));
      } catch (e) {
        //
      }
    }

    client.close();
  });

  test("transaction state cleanup", () async {
    // concurrency 1 to ensure we reuse the underlying connection
    final client = getClient(concurrency: 1);

    await expectLater(client.transaction((tx) async {
      try {
        await tx.query('select 1/0');
      } catch (e) {
        // catch the error in the transaction so `transaction` method doesn't
        // attempt rollback
      }
    }),
        throwsA(isA<EdgeDBError>().having((e) => e.message, 'message',
            contains('current transaction is aborted'))));

    expect(await client.querySingle('select "success"'), 'success');

    client.close();
  });

  test("execute", () async {
    final client = getClient();
    try {
      await expectLater(
          client.execute('select 1/0;'),
          throwsA(isA<DivisionByZeroError>()
              .having((e) => e.code, 'error code', 0x05010001)
              .having(
                  (e) => e.message, 'message', contains('division by zero'))));
    } finally {
      await client.close();
    }
  });

  test("scripts and args", () async {
    final client = getClient();

    await client.execute('''create type ScriptTest {
    create property name -> str;
  };''');

    try {
      await expectLater(client.execute('''
          insert ScriptTest {
            name := 'test'
          }''', {'name': "test"}), throwsA(isA<QueryArgumentError>()));

      await client.execute('''
          select 1 + 2;

          insert ScriptTest {
            name := 'test0'
          };''');

      expect(await client.query('select ScriptTest {name}'), [
        {'name': "test0"},
      ]);

      await expectLater(client.execute(r'''
          insert ScriptTest {
            name := <str>$name
          };

          insert ScriptTest {
            name := 'test' ++ <str>count(detached ScriptTest)
          };'''), throwsA(isA<QueryArgumentError>()));

      await client.execute(r'''
          insert ScriptTest {
            name := <str>$name
          };

          insert ScriptTest {
            name := 'test' ++ <str>count(detached ScriptTest)
          };''', {'name': "test1"});

      expect(await client.query('select ScriptTest {name}'), [
        {'name': "test0"},
        {'name': "test1"},
        {'name': "test2"},
      ]);

      expect(await client.query(r'''
          insert ScriptTest {
            name := <str>$name
          };

          insert ScriptTest {
            name := 'test' ++ <str>count(detached ScriptTest)
          };

          select ScriptTest.name;''', {'name': "test3"}),
          ["test0", "test1", "test2", "test3", "test4"]);
    } finally {
      await client.execute('drop type ScriptTest;');
      client.close();
    }
  });

  test("fetch/optimistic cache invalidation", () async {
    const typename = "CacheInv_01";
    const query = 'SELECT $typename.prop1 LIMIT 1';
    final client = getClient();

    try {
      await client.transaction((tx) async {
        await tx.execute('''
        CREATE TYPE $typename {
          CREATE REQUIRED PROPERTY prop1 -> std::str;
        };

        INSERT $typename {
          prop1 := 'aaa'
        };
      ''');

        for (var i = 0; i < 5; i++) {
          expect(await tx.querySingle(query), 'aaa');
        }

        await tx.execute('''
        DELETE (SELECT $typename);

        ALTER TYPE $typename {
          DROP PROPERTY prop1;
        };

        ALTER TYPE $typename {
          CREATE REQUIRED PROPERTY prop1 -> std::int64;
        };

        INSERT $typename {
          prop1 := 123
        };
      ''');

        for (var i = 0; i < 5; i++) {
          expect(await tx.querySingle(query), 123);
        }

        throw CancelTransaction();
      });
    } on CancelTransaction {
      //
    } finally {
      await client.close();
    }
  });

  test("fetch no codec", () async {
    final client = getClient();
    try {
      await expectLater(
          client.querySingle("select <decimal>1"),
          throwsA(isA<EdgeDBError>().having((e) => e.message, 'message',
              contains('no Dart codec for std::decimal'))));

      expect(await client.querySingle("select 123"), 123);
    } finally {
      await client.close();
    }
  });

  test("concurrent ops", () async {
    final client = getClient();

    try {
      expect(
          await Future.wait([
            client.querySingle('SELECT 1 + 2'),
            client.querySingle('SELECT 2 + 2')
          ]),
          [3, 4]);
    } finally {
      await client.close();
    }
  });

  test('pretty error message', () async {
    final client = getClient();

    try {
      await expectLater(
          client.query('''
select {
  ver := sys::get_version(),
  unknown := .abc,
};'''),
          throwsA(isA<InvalidReferenceError>()
              .having((e) => e.toString(), 'error message', '''
InvalidReferenceError: object type 'std::FreeObject' has no link or property 'abc'
   |
 3 |   unknown := .abc,
   |              ^^^^
''')));
    } finally {
      await client.close();
    }
  });
}
