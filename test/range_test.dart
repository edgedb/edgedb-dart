import 'dart:math';

import 'package:edgedb/edgedb.dart';
import 'package:test/test.dart';

void main() {
  group('basic tests:', () {
    test('empty range', () {
      final range = Range.empty();
      expect(range.lower, null);
      expect(range.upper, null);
      expect(range.incLower, false);
      expect(range.incUpper, false);
      expect(range.isEmpty, true);
    });

    test('range 1', () {
      final range = Range(1, 2);
      expect(range.toString(), "[1,2)");

      expect(range.lower, 1);
      expect(range.upper, 2);
      expect(range.incLower, true);
      expect(range.incUpper, false);
      expect(range.isEmpty, false);
    });

    test('range 2', () {
      var range = Range(1, null);
      expect(range.lower, 1);
      expect(range.upper, null);
      expect(range.incLower, true);
      expect(range.incUpper, false);
      expect(range.isEmpty, false);

      range = Range(null, 1);
      expect(range.lower, null);
      expect(range.upper, 1);
      expect(range.incLower, false);
      expect(range.incUpper, false);
      expect(range.isEmpty, false);

      range = Range(null, null);
      expect(range.lower, null);
      expect(range.upper, null);
      expect(range.incLower, false);
      expect(range.incUpper, false);
      expect(range.isEmpty, false);
    });

    test('range 3', () {
      expect(Range(null, 2, incUpper: true).hashCode,
          Range(null, 2, incUpper: true).hashCode);
      expect(Range(1, 2).hashCode, Range(1, 2).hashCode);
    });
  });

  group('multirange tests:', () {
    test('empty multirange', () {
      final multirange = MultiRange([]);
      expect(multirange.length, 0);
      expect(multirange, MultiRange([]));
    });

    test('multirange 1', () {
      final multirange = MultiRange<int>([
        Range(1, 2),
        Range(4, null),
      ]);
      expect(multirange.toString(), "[[1,2), [4,)]");

      expect(
          multirange,
          MultiRange<int>([
            Range(1, 2),
            Range(4, null),
          ]));
    });

    test('multirange 2', () {
      final ranges = [
        Range(null, 0),
        Range(1, 2),
        Range(4, null),
      ];
      final multirange = MultiRange<int>([
        Range(null, 0),
        Range(1, 2),
        Range(4, null),
      ]);

      var i = 0;
      for (var element in multirange) {
        expect(element, ranges[i++]);
      }
    });

    test('multirange 3', () {
      expect(
          MultiRange<int>([
            Range(1, 2),
            Range(4, null),
          ]).hashCode,
          MultiRange<int>([
            Range(1, 2),
            Range(4, null),
          ]).hashCode);
      expect(MultiRange<int>([Range(null, 2, incUpper: true)]).hashCode,
          MultiRange<int>([Range(null, 2, incUpper: true)]).hashCode);
    });

    test('multirange 4', () {
      expect(
        MultiRange<int>([
          Range(null, 2, incUpper: true),
          Range(5, 9),
          Range(5, 9),
          Range(5, 9),
          Range(null, 2, incUpper: true),
        ]),
        MultiRange<int>([
          Range(5, 9),
          Range(null, 2, incUpper: true),
        ]),
      );
    });
  });

  group('constructing ranges:', () {
    test('invalid', () {
      expect(() => Range('5', '10'), throwsA(isA<ArgumentError>()));
      expect(() => Range(5, '10'), throwsA(isA<ArgumentError>()));
      expect(() => Range('5', 10), throwsA(isA<ArgumentError>()));
      expect(() => Range(5.0, DateTime.now()), throwsA(isA<ArgumentError>()));
    });

    test('int', () {
      expect(Range(5, 10).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(Range(5, 10, incLower: false).toJSON(), {
        'lower': 6,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(Range(5, 10, incUpper: true).toJSON(), {
        'lower': 5,
        'upper': 11,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(Range(5, 10, incLower: false, incUpper: true).toJSON(), {
        'lower': 6,
        'upper': 11,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(Range(5, 5).toJSON(), {'empty': true});

      expect(Range(5, 5, incUpper: true).toJSON(), {
        'lower': 5,
        'upper': 6,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(Range(5, 5, incLower: false).toJSON(), {
        'empty': true,
      });

      expect(Range(4, 5, incLower: false).toJSON(), {
        'empty': true,
      });

      expect(Range(null, 10).toJSON(), {
        'lower': null,
        'upper': 10,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect(Range(5, null).toJSON(), {
        'lower': 5,
        'upper': null,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(Range(null, null).toJSON(), {
        'lower': null,
        'upper': null,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect(() => Range(10, 5), throwsA(isA<ArgumentError>()));
    });

    test('double', () {
      expect(Range(5.0, 10.0).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(Range(5.0, 10.0, incLower: false).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect(Range(5.0, 10.0, incUpper: true).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': true,
      });

      expect(Range(5.0, 10.0, incLower: false, incUpper: true).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': false,
        'inc_upper': true,
      });

      expect(Range(5.0, 5.0).toJSON(), {'empty': true});

      expect(Range(5.0, 5.0, incLower: true, incUpper: true).toJSON(), {
        'lower': 5.0,
        'upper': 5.0,
        'inc_lower': true,
        'inc_upper': true,
      });

      expect(Range(5.0, 5.0, incLower: false, incUpper: false).toJSON(), {
        'empty': true,
      });

      expect(Range(5.0, 5.0, incLower: false, incUpper: true).toJSON(), {
        'empty': true,
      });

      expect(Range(null, 10.0).toJSON(), {
        'lower': null,
        'upper': 10.0,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect(Range(5.0, null).toJSON(), {
        'lower': 5.0,
        'upper': null,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(Range(null, null).toJSON(), {
        'lower': null,
        'upper': null,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect(() => Range(10.0, 5.0), throwsA(isA<ArgumentError>()));
    });

    test('DateTime', () {
      final l = DateTime(2022, 08, 30);
      final u = DateTime(2022, 08, 31);

      expect(Range(l, u).toJSON(), {
        'lower': l,
        'upper': u,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(Range(l, u, incLower: false).toJSON(), {
        'lower': l,
        'upper': u,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect(Range(l, u, incUpper: true).toJSON(), {
        'lower': l,
        'upper': u,
        'inc_lower': true,
        'inc_upper': true,
      });

      expect(Range(l, u, incLower: false, incUpper: true).toJSON(), {
        'lower': l,
        'upper': u,
        'inc_lower': false,
        'inc_upper': true,
      });

      expect(Range(l, l).toJSON(), {'empty': true});

      expect(Range(l, l, incLower: true, incUpper: true).toJSON(), {
        'lower': l,
        'upper': l,
        'inc_lower': true,
        'inc_upper': true,
      });

      expect(Range(l, l, incLower: false, incUpper: false).toJSON(), {
        'empty': true,
      });

      expect(Range(l, l, incLower: false, incUpper: true).toJSON(), {
        'empty': true,
      });

      expect(Range(null, u).toJSON(), {
        'lower': null,
        'upper': u,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect(Range(l, null).toJSON(), {
        'lower': l,
        'upper': null,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(Range(null, null).toJSON(), {
        'lower': null,
        'upper': null,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect(() => Range(u, l), throwsA(isA<ArgumentError>()));
    });
  });

  group('range comparison:', () {
    test('int', () {
      final ranges = <Range<int>>[
        Range(5, 10),
        Range(5, 11),
        Range(5, 9),
        Range(4, 9),
        Range(4, 10),
        Range(4, 11),
        Range(6, 9),
        Range(6, 10),
        Range(6, 11),
        Range(null, 9),
        Range(null, 10),
        Range(null, 11),
        Range(4, null),
        Range(5, null),
        Range(6, null),
        Range(null, null),
        Range.empty(),
      ];
      expect(
          ranges.map((r1) => ranges.map((r2) => r1.compareTo(r2)).join(', ')), [
        '0, -1, 1, 1, 1, 1, -1, -1, -1, 1, 1, 1, 1, -1, -1, 1, 1',
        '1, 0, 1, 1, 1, 1, -1, -1, -1, 1, 1, 1, 1, -1, -1, 1, 1',
        '-1, -1, 0, 1, 1, 1, -1, -1, -1, 1, 1, 1, 1, -1, -1, 1, 1',
        '-1, -1, -1, 0, -1, -1, -1, -1, -1, 1, 1, 1, -1, -1, -1, 1, 1',
        '-1, -1, -1, 1, 0, -1, -1, -1, -1, 1, 1, 1, -1, -1, -1, 1, 1',
        '-1, -1, -1, 1, 1, 0, -1, -1, -1, 1, 1, 1, -1, -1, -1, 1, 1',
        '1, 1, 1, 1, 1, 1, 0, -1, -1, 1, 1, 1, 1, 1, -1, 1, 1',
        '1, 1, 1, 1, 1, 1, 1, 0, -1, 1, 1, 1, 1, 1, -1, 1, 1',
        '1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, -1, 1, 1',
        '-1, -1, -1, -1, -1, -1, -1, -1, -1, 0, -1, -1, -1, -1, -1, -1, 1',
        '-1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 0, -1, -1, -1, -1, -1, 1',
        '-1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 0, -1, -1, -1, -1, 1',
        '-1, -1, -1, 1, 1, 1, -1, -1, -1, 1, 1, 1, 0, -1, -1, 1, 1',
        '1, 1, 1, 1, 1, 1, -1, -1, -1, 1, 1, 1, 1, 0, -1, 1, 1',
        '1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1',
        '-1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, -1, -1, -1, 0, 1',
        '-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0'
      ]);
    });

    test('double', () {
      final ranges = <Range<double>>[
        Range(5.0, 10.0, incLower: true, incUpper: false),
        Range(5.0, 10.0, incLower: true, incUpper: true),
        Range(5.0, 10.0, incLower: false, incUpper: false),
        Range(5.0, 10.0, incLower: false, incUpper: true),
        Range(null, 10.0),
        Range(5.0, null),
        Range(null, null),
        Range.empty()
      ];
      expect(
          ranges.map((r1) => ranges.map((r2) => r1.compareTo(r2)).join(', ')), [
        '0, -1, -1, -1, 1, -1, 1, 1',
        '1, 0, -1, -1, 1, -1, 1, 1',
        '1, 1, 0, -1, 1, 1, 1, 1',
        '1, 1, 1, 0, 1, 1, 1, 1',
        '-1, -1, -1, -1, 0, -1, -1, 1',
        '1, 1, -1, -1, 1, 0, 1, 1',
        '-1, -1, -1, -1, 1, -1, 0, 1',
        '-1, -1, -1, -1, -1, -1, -1, 0'
      ]);
    });

    test('DateTime', () {
      final l = DateTime(2022, 08, 30);
      final u = DateTime(2022, 08, 31);
      final ranges = <Range<DateTime>>[
        Range(l, u, incLower: true, incUpper: false),
        Range(l, u, incLower: true, incUpper: true),
        Range(l, u, incLower: false, incUpper: false),
        Range(l, u, incLower: false, incUpper: true),
        Range(null, u),
        Range(l, null),
        Range(null, null),
        Range.empty()
      ];
      expect(
          ranges.map((r1) => ranges.map((r2) => r1.compareTo(r2)).join(', ')), [
        '0, -1, -1, -1, 1, -1, 1, 1',
        '1, 0, -1, -1, 1, -1, 1, 1',
        '1, 1, 0, -1, 1, 1, 1, 1',
        '1, 1, 1, 0, 1, 1, 1, 1',
        '-1, -1, -1, -1, 0, -1, -1, 1',
        '1, 1, -1, -1, 1, 0, 1, 1',
        '-1, -1, -1, -1, 1, -1, 0, 1',
        '-1, -1, -1, -1, -1, -1, -1, 0'
      ]);
    });
  });

  group('range union:', () {
    test('int', () {
      expect((Range(5, 10) + Range(7, 12)).toJSON(), {
        'lower': 5,
        'upper': 12,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, 10) + Range(10, 15)).toJSON(), {
        'lower': 5,
        'upper': 15,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(() => (Range(5, 10) + Range(10, 15, incLower: false)),
          throwsA(isA<StateError>()));

      expect(
          (Range(5, 10, incUpper: true) + Range(10, 15, incLower: false))
              .toJSON(),
          {
            'lower': 5,
            'upper': 15,
            'inc_lower': true,
            'inc_upper': false,
          });

      expect((Range(5, 9, incUpper: true) + Range(10, 15)).toJSON(), {
        'lower': 5,
        'upper': 15,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(null, 10) + Range(10, 15)).toJSON(), {
        'lower': null,
        'upper': 15,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(5, 10) + Range(10, null)).toJSON(), {
        'lower': 5,
        'upper': null,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, null) + Range(10, 15)).toJSON(), {
        'lower': 5,
        'upper': null,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range<int>(null, null) + Range(10, 15)).toJSON(), {
        'lower': null,
        'upper': null,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(5, 5) + Range(10, 15)).toJSON(), {
        'lower': 10,
        'upper': 15,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, null) + Range(null, 15)).toJSON(), {
        'lower': null,
        'upper': null,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(5, 15) + Range(8, 12)).toJSON(), {
        'lower': 5,
        'upper': 15,
        'inc_lower': true,
        'inc_upper': false,
      });
    });

    test('double', () {
      expect((Range(5.0, 10.0) + Range(7.0, 12.0)).toJSON(), {
        'lower': 5.0,
        'upper': 12.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, 10.0) + Range(10.0, 15.0)).toJSON(), {
        'lower': 5.0,
        'upper': 15.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(() => (Range(5.0, 10.0) + Range(10.0, 15.0, incLower: false)),
          throwsA(isA<StateError>()));

      expect(
          (Range(5.0, 10.0, incUpper: true) +
                  Range(10.0, 15.0, incLower: false))
              .toJSON(),
          {
            'lower': 5.0,
            'upper': 15.0,
            'inc_lower': true,
            'inc_upper': false,
          });

      expect(() => (Range(5.0, 9.0, incUpper: true) + Range(10.0, 15.0)),
          throwsA(isA<StateError>()));

      expect((Range(null, 10.0) + Range(10.0, 15.0)).toJSON(), {
        'lower': null,
        'upper': 15.0,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(5.0, 10.0) + Range(10.0, null)).toJSON(), {
        'lower': 5.0,
        'upper': null,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, null) + Range(10.0, 15.0)).toJSON(), {
        'lower': 5.0,
        'upper': null,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range<double>(null, null) + Range(10.0, 15.0)).toJSON(), {
        'lower': null,
        'upper': null,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(5.0, 5.0) + Range(10.0, 15.0)).toJSON(), {
        'lower': 10.0,
        'upper': 15.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, null) + Range(null, 15.0)).toJSON(), {
        'lower': null,
        'upper': null,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(5.0, 15.0) + Range(8.0, 12.0)).toJSON(), {
        'lower': 5.0,
        'upper': 15.0,
        'inc_lower': true,
        'inc_upper': false,
      });
    });

    test('DateTime', () {
      expect(
          (Range(DateTime(2022, 08, 30), DateTime(2022, 09, 04)) +
                  Range(DateTime(2022, 09, 01), DateTime(2022, 09, 06)))
              .toJSON(),
          {
            'lower': DateTime(2022, 08, 30),
            'upper': DateTime(2022, 09, 06),
            'inc_lower': true,
            'inc_upper': false,
          });

      expect(
          (Range(DateTime(2022, 08, 30), DateTime(2022, 09, 04)) +
                  Range(DateTime(2022, 09, 04), DateTime(2022, 09, 09)))
              .toJSON(),
          {
            'lower': DateTime(2022, 08, 30),
            'upper': DateTime(2022, 09, 09),
            'inc_lower': true,
            'inc_upper': false,
          });

      expect(
          () => (Range(DateTime(2022, 08, 30), DateTime(2022, 09, 04)) +
              Range(DateTime(2022, 09, 04), DateTime(2022, 09, 09),
                  incLower: false)),
          throwsA(isA<StateError>()));

      expect(
          (Range(DateTime(2022, 08, 30), DateTime(2022, 09, 04),
                      incUpper: true) +
                  Range(DateTime(2022, 09, 04), DateTime(2022, 09, 09),
                      incLower: false))
              .toJSON(),
          {
            'lower': DateTime(2022, 08, 30),
            'upper': DateTime(2022, 09, 09),
            'inc_lower': true,
            'inc_upper': false,
          });

      expect(
          () => (Range(DateTime(2022, 08, 30), DateTime(2022, 09, 03),
                  incUpper: true) +
              Range(DateTime(2022, 09, 04), DateTime(2022, 09, 09))),
          throwsA(isA<StateError>()));

      expect(
          (Range(null, DateTime(2022, 09, 04)) +
                  Range(DateTime(2022, 09, 04), DateTime(2022, 09, 09)))
              .toJSON(),
          {
            'lower': null,
            'upper': DateTime(2022, 09, 09),
            'inc_lower': false,
            'inc_upper': false,
          });

      expect(
          (Range(DateTime(2022, 08, 30), DateTime(2022, 09, 04)) +
                  Range(DateTime(2022, 09, 04), null))
              .toJSON(),
          {
            'lower': DateTime(2022, 08, 30),
            'upper': null,
            'inc_lower': true,
            'inc_upper': false,
          });

      expect(
          (Range(DateTime(2022, 08, 30), null) +
                  Range(DateTime(2022, 09, 04), DateTime(2022, 09, 09)))
              .toJSON(),
          {
            'lower': DateTime(2022, 08, 30),
            'upper': null,
            'inc_lower': true,
            'inc_upper': false,
          });

      expect(
          (Range<DateTime>(null, null) +
                  Range(DateTime(2022, 09, 04), DateTime(2022, 09, 09)))
              .toJSON(),
          {
            'lower': null,
            'upper': null,
            'inc_lower': false,
            'inc_upper': false,
          });

      expect(
          (Range(DateTime(2022, 08, 30), DateTime(2022, 08, 30)) +
                  Range(DateTime(2022, 09, 04), DateTime(2022, 09, 09)))
              .toJSON(),
          {
            'lower': DateTime(2022, 09, 04),
            'upper': DateTime(2022, 09, 09),
            'inc_lower': true,
            'inc_upper': false,
          });

      expect(
          (Range(DateTime(2022, 08, 30), null) +
                  Range(null, DateTime(2022, 09, 09)))
              .toJSON(),
          {
            'lower': null,
            'upper': null,
            'inc_lower': false,
            'inc_upper': false,
          });

      expect(
          (Range(DateTime(2022, 08, 30), DateTime(2022, 09, 09)) +
                  Range(DateTime(2022, 09, 02), DateTime(2022, 09, 06)))
              .toJSON(),
          {
            'lower': DateTime(2022, 08, 30),
            'upper': DateTime(2022, 09, 09),
            'inc_lower': true,
            'inc_upper': false,
          });
    });
  });

  group('range difference:', () {
    test('int', () {
      expect((Range(5, 10) - Range(7, 12)).toJSON(), {
        'lower': 5,
        'upper': 7,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(7, 12) - Range(5, 10)).toJSON(), {
        'lower': 10,
        'upper': 12,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, 10) - Range(10, 15)).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, 10) - Range(5, 10)).toJSON(), {'empty': true});

      expect((Range(5, 10) - Range(4, 11)).toJSON(), {
        'empty': true,
      });

      expect((Range(5, 10) - Range.empty()).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range.empty() - Range(5, 10)).toJSON(), {
        'empty': true,
      });

      expect(() => (Range(5, 10) - Range(6, 9)), throwsA(isA<StateError>()));

      expect((Range(5, 10) - Range(5, 10, incLower: false)).toJSON(), {
        'lower': 5,
        'upper': 6,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(
          () => (Range(5, 10, incUpper: true) - Range(5, 10, incLower: false)),
          throwsA(isA<StateError>()));

      expect((Range(5, 10, incUpper: true) - Range(5, 10)).toJSON(), {
        'lower': 10,
        'upper': 11,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(null, 10) - Range(5, 10)).toJSON(), {
        'lower': null,
        'upper': 5,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(5, null) - Range(5, 10)).toJSON(), {
        'lower': 10,
        'upper': null,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(() => (Range<int>(null, null) - Range(5, 10)),
          throwsA(isA<StateError>()));

      expect((Range(5, 10) - Range(null, null)).toJSON(), {
        'empty': true,
      });

      expect((Range(null, null) - Range(null, null)).toJSON(), {
        'empty': true,
      });

      expect((Range(5, 15) - Range(10, null)).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, 15) - Range(null, 10)).toJSON(), {
        'lower': 10,
        'upper': 15,
        'inc_lower': true,
        'inc_upper': false,
      });
    });

    test('double', () {
      expect((Range(5.0, 10.0) - Range(7.0, 12.0)).toJSON(), {
        'lower': 5.0,
        'upper': 7.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(7.0, 12.0) - Range(5.0, 10.0)).toJSON(), {
        'lower': 10.0,
        'upper': 12.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, 10.0) - Range(10.0, 15.0)).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, 10.0) - Range(5.0, 10.0)).toJSON(), {'empty': true});

      expect((Range(5.0, 10.0) - Range(4.0, 11.0)).toJSON(), {
        'empty': true,
      });

      expect((Range(5.0, 10.0) - Range.empty()).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range.empty() - Range(5.0, 10.0)).toJSON(), {
        'empty': true,
      });

      expect(() => (Range(5.0, 10.0) - Range(6.0, 9.0)),
          throwsA(isA<StateError>()));

      expect((Range(5.0, 10.0) - Range(5.0, 10.0, incLower: false)).toJSON(), {
        'lower': 5.0,
        'upper': 5.0,
        'inc_lower': true,
        'inc_upper': true,
      });

      expect(
          () => (Range(5.0, 10.0, incUpper: true) -
              Range(5.0, 10.0, incLower: false)),
          throwsA(isA<StateError>()));

      expect((Range(5.0, 10.0, incUpper: true) - Range(5.0, 10.0)).toJSON(), {
        'lower': 10.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': true,
      });

      expect((Range(null, 10.0) - Range(5.0, 10.0)).toJSON(), {
        'lower': null,
        'upper': 5.0,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(5.0, null) - Range(5.0, 10.0)).toJSON(), {
        'lower': 10.0,
        'upper': null,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(() => (Range<double>(null, null) - Range(5.0, 10.0)),
          throwsA(isA<StateError>()));

      expect((Range(5.0, 10.0) - Range(null, null)).toJSON(), {
        'empty': true,
      });

      expect((Range(null, null) - Range(null, null)).toJSON(), {
        'empty': true,
      });

      expect((Range(5.0, 15.0) - Range(10.0, null)).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, 15.0) - Range(null, 10.0)).toJSON(), {
        'lower': 10.0,
        'upper': 15.0,
        'inc_lower': true,
        'inc_upper': false,
      });
    });

    test('DateTime', () {
      final l = DateTime(2022, 08, 30);
      final m = DateTime(2022, 09, 04);
      final u = DateTime(2022, 09, 09);

      expect(
          (Range(l, m) - Range(DateTime(2022, 09, 01), DateTime(2022, 09, 06)))
              .toJSON(),
          {
            'lower': l,
            'upper': DateTime(2022, 09, 01),
            'inc_lower': true,
            'inc_upper': false,
          });

      expect(
          (Range(DateTime(2022, 09, 01), DateTime(2022, 09, 06)) - Range(l, m))
              .toJSON(),
          {
            'lower': m,
            'upper': DateTime(2022, 09, 06),
            'inc_lower': true,
            'inc_upper': false,
          });

      expect((Range(l, m) - Range(m, u)).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(l, m) - Range(l, m)).toJSON(), {'empty': true});

      expect(
          (Range(l, m) - Range(DateTime(2022, 08, 29), DateTime(2022, 09, 05)))
              .toJSON(),
          {
            'empty': true,
          });

      expect((Range(l, m) - Range.empty()).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range.empty() - Range(l, m)).toJSON(), {
        'empty': true,
      });

      expect(
          () => (Range(l, m) -
              Range(DateTime(2022, 08, 31), DateTime(2022, 09, 03))),
          throwsA(isA<StateError>()));

      expect((Range(l, m) - Range(l, m, incLower: false)).toJSON(), {
        'lower': l,
        'upper': l,
        'inc_lower': true,
        'inc_upper': true,
      });

      expect(() => (Range(l, m, incUpper: true) - Range(l, m, incLower: false)),
          throwsA(isA<StateError>()));

      expect((Range(l, m, incUpper: true) - Range(l, m)).toJSON(), {
        'lower': m,
        'upper': m,
        'inc_lower': true,
        'inc_upper': true,
      });

      expect((Range(null, m) - Range(l, m)).toJSON(), {
        'lower': null,
        'upper': l,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(l, null) - Range(l, m)).toJSON(), {
        'lower': m,
        'upper': null,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect(() => (Range<DateTime>(null, null) - Range(l, m)),
          throwsA(isA<StateError>()));

      expect((Range(l, m) - Range(null, null)).toJSON(), {
        'empty': true,
      });

      expect((Range(null, null) - Range(null, null)).toJSON(), {
        'empty': true,
      });

      expect((Range(l, u) - Range(m, null)).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(l, u) - Range(null, m)).toJSON(), {
        'lower': m,
        'upper': u,
        'inc_lower': true,
        'inc_upper': false,
      });
    });
  });

  group('range intersection:', () {
    test('int', () {
      expect((Range(5, 10) * Range(7, 12)).toJSON(), {
        'lower': 7,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(7, 12) * Range(5, 10)).toJSON(), {
        'lower': 7,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, 10) * Range(10, 15)).toJSON(), {
        'empty': true,
      });

      expect((Range(5, 10, incUpper: true) * Range(10, 15)).toJSON(), {
        'lower': 10,
        'upper': 11,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, 10) * Range(5, 12)).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, 10) * Range(5, 10)).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, 10) * Range(5, 10, incUpper: true)).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, 10) * Range(5, 10, incLower: false)).toJSON(), {
        'lower': 6,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(0, 15) * Range(5, 10)).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5, 10) * Range.empty()).toJSON(), {'empty': true});

      expect((Range(5, 10) * Range(5, null)).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(null, 10) * Range(5, 10, incUpper: true)).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range.empty() * Range(null, null)).toJSON(), {
        'empty': true,
      });

      expect((Range<int>(null, null) * Range(5, 10)).toJSON(), {
        'lower': 5,
        'upper': 10,
        'inc_lower': true,
        'inc_upper': false,
      });
    });

    test('double', () {
      expect((Range(5.0, 10.0) * Range(7.0, 12.0)).toJSON(), {
        'lower': 7.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(7.0, 12.0) * Range(5.0, 10.0)).toJSON(), {
        'lower': 7.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, 10.0) * Range(10.0, 15.0)).toJSON(), {
        'empty': true,
      });

      expect((Range(5.0, 10.0, incUpper: true) * Range(10.0, 15.0)).toJSON(), {
        'lower': 10.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': true,
      });

      expect((Range(5.0, 10.0) * Range(5.0, 12.0)).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, 10.0) * Range(5.0, 10.0)).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, 10.0) * Range(5.0, 10.0, incUpper: true)).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, 10.0) * Range(5.0, 10.0, incLower: false)).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(0.0, 15.0) * Range(5.0, 10.0)).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(5.0, 10.0) * Range.empty()).toJSON(), {'empty': true});

      expect((Range(5.0, 10.0) * Range(5.0, null)).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(null, 10.0) * Range(5.0, 10.0, incUpper: true)).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range.empty() * Range(null, null)).toJSON(), {
        'empty': true,
      });

      expect((Range<double>(null, null) * Range(5.0, 10.0)).toJSON(), {
        'lower': 5.0,
        'upper': 10.0,
        'inc_lower': true,
        'inc_upper': false,
      });
    });

    test('DateTime', () {
      final l = DateTime(2022, 08, 30);
      final m = DateTime(2022, 09, 04);
      final u = DateTime(2022, 09, 09);

      expect(
          (Range(l, m) * Range(DateTime(2022, 09, 01), DateTime(2022, 09, 06)))
              .toJSON(),
          {
            'lower': DateTime(2022, 09, 01),
            'upper': m,
            'inc_lower': true,
            'inc_upper': false,
          });

      expect(
          (Range(DateTime(2022, 09, 01), DateTime(2022, 09, 06)) * Range(l, m))
              .toJSON(),
          {
            'lower': DateTime(2022, 09, 01),
            'upper': m,
            'inc_lower': true,
            'inc_upper': false,
          });

      expect((Range(l, m) * Range(m, u)).toJSON(), {
        'empty': true,
      });

      expect((Range(l, m, incUpper: true) * Range(m, u)).toJSON(), {
        'lower': m,
        'upper': m,
        'inc_lower': true,
        'inc_upper': true,
      });

      expect((Range(l, m) * Range(l, DateTime(2022, 09, 06))).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(l, m) * Range(l, m)).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(l, m) * Range(l, m, incUpper: true)).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(l, m) * Range(l, m, incLower: false)).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': false,
        'inc_upper': false,
      });

      expect((Range(DateTime(2022, 08, 25), u) * Range(l, m)).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(l, m) * Range.empty()).toJSON(), {'empty': true});

      expect((Range(l, m) * Range(l, null)).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range(null, m) * Range(l, m, incUpper: true)).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': true,
        'inc_upper': false,
      });

      expect((Range.empty() * Range(null, null)).toJSON(), {
        'empty': true,
      });

      expect((Range<DateTime>(null, null) * Range(l, m)).toJSON(), {
        'lower': l,
        'upper': m,
        'inc_lower': true,
        'inc_upper': false,
      });
    });
  });

  group('range unpack:', () {
    test('int', () {
      expect(Range(5, 10).unpack().toList(), [5, 6, 7, 8, 9]);

      expect(Range(5, 10, incLower: false).unpack().toList(), [6, 7, 8, 9]);

      expect(
          Range(5, 10, incUpper: true).unpack().toList(), [5, 6, 7, 8, 9, 10]);

      expect(Range(5, 10).unpack(step: 2).toList(), [5, 7, 9]);

      expect(Range(5, 5).unpack().toList(), []);

      expect(
          () => Range(5, 10).unpack(step: 0.5), throwsA(isA<ArgumentError>()));

      expect(() => Range(5, 10).unpack(step: 0), throwsA(isA<ArgumentError>()));

      expect(
          () => Range(5, 10).unpack(step: -1), throwsA(isA<ArgumentError>()));

      expect(() => Range(null, 10).unpack(), throwsA(isA<StateError>()));
      expect(() => Range(5, null).unpack(), throwsA(isA<StateError>()));
      expect(() => Range(null, null).unpack(), throwsA(isA<StateError>()));
    });

    test('double', () {
      expect(() => Range(5.0, 10.0).unpack(), throwsA(isA<ArgumentError>()));

      expect(
          Range(5.0, 10.0).unpack(step: 1).toList(), [5.0, 6.0, 7.0, 8.0, 9.0]);

      expect(Range(5.0, 10.0, incLower: false).unpack(step: 1.0).toList(),
          [6.0, 7.0, 8.0, 9.0]);

      expect(Range(5.0, 10.0, incUpper: true).unpack(step: 1).toList(),
          [5.0, 6.0, 7.0, 8.0, 9.0, 10.0]);

      expect(Range(5.0, 10.0).unpack(step: 2.0).toList(), [5.0, 7.0, 9.0]);

      expect(Range(5.0, 5.0).unpack().toList(), []);

      expect(Range(5.0, 10.0).unpack(step: 0.5).toList(),
          [5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5]);

      expect(() => Range(5.0, 10.0).unpack(step: 0),
          throwsA(isA<ArgumentError>()));

      expect(() => Range(5.0, 10.0).unpack(step: -1),
          throwsA(isA<ArgumentError>()));

      expect(() => Range(null, 10.0).unpack(), throwsA(isA<StateError>()));
      expect(() => Range(5.0, null).unpack(), throwsA(isA<StateError>()));
    });

    test('DateTime', () {
      final l = DateTime(2022, 08, 30);
      final u = DateTime(2022, 09, 02);

      expect(() => Range(l, u).unpack(), throwsA(isA<ArgumentError>()));

      expect(() => Range(l, u).unpack(step: 1), throwsA(isA<ArgumentError>()));

      expect(Range(l, u).unpack(step: Duration(days: 1)).toList(), [
        DateTime(2022, 08, 30),
        DateTime(2022, 08, 31),
        DateTime(2022, 09, 01)
      ]);

      expect(
          Range(l, u, incLower: false).unpack(step: Duration(days: 1)).toList(),
          [DateTime(2022, 08, 31), DateTime(2022, 09, 01)]);

      expect(
          Range(l, u, incUpper: true).unpack(step: Duration(days: 1)).toList(),
          [
            DateTime(2022, 08, 30),
            DateTime(2022, 08, 31),
            DateTime(2022, 09, 01),
            DateTime(2022, 09, 02)
          ]);

      expect(Range(l, u).unpack(step: Duration(days: 2)).toList(),
          [DateTime(2022, 08, 30), DateTime(2022, 09, 01)]);

      expect(Range(l, l).unpack().toList(), []);

      expect(Range(l, u).unpack(step: Duration(hours: 12)).toList(), [
        DateTime(2022, 08, 30),
        DateTime(2022, 08, 30, 12),
        DateTime(2022, 08, 31),
        DateTime(2022, 08, 31, 12),
        DateTime(2022, 09, 01),
        DateTime(2022, 09, 01, 12),
      ]);

      expect(() => Range(l, u).unpack(step: 0), throwsA(isA<ArgumentError>()));

      expect(() => Range(l, u).unpack(step: -1), throwsA(isA<ArgumentError>()));

      expect(() => Range(null, u).unpack(), throwsA(isA<StateError>()));
      expect(() => Range(l, null).unpack(), throwsA(isA<StateError>()));
    });
  });

  group('range contains:', () {
    test('int', () {
      final ranges = <Range<int>>[
        Range(5, 10, incLower: true, incUpper: false),
        Range(5, 10, incLower: true, incUpper: true),
        Range(5, 10, incLower: false, incUpper: false),
        Range(5, 10, incLower: false, incUpper: true),
        Range(5, null),
        Range(null, 10),
        Range(null, null),
        Range.empty()
      ];

      final elements = [
        pow(2, 63) as int,
        4,
        5,
        6,
        9,
        10,
        11,
        (pow(2, 63) - 1) as int
      ];

      expect(ranges.map((range) => elements.map((el) => range.contains(el))), [
        [false, false, true, true, true, false, false, false],
        [false, false, true, true, true, true, false, false],
        [false, false, false, true, true, false, false, false],
        [false, false, false, true, true, true, false, false],
        [false, false, true, true, true, true, true, true],
        [true, true, true, true, true, false, false, false],
        [true, true, true, true, true, true, true, true],
        [false, false, false, false, false, false, false, false]
      ]);
    });

    test('double', () {
      final ranges = <Range<double>>[
        Range(5.0, 10.0, incLower: true, incUpper: false),
        Range(5.0, 10.0, incLower: true, incUpper: true),
        Range(5.0, 10.0, incLower: false, incUpper: false),
        Range(5.0, 10.0, incLower: false, incUpper: true),
        Range(5.0, null),
        Range(null, 10.0),
        Range(null, null),
        Range.empty()
      ];

      final elements = [
        double.negativeInfinity,
        4.0,
        5.0,
        6.0,
        9.0,
        10.0,
        11.0,
        double.infinity
      ];

      expect(ranges.map((range) => elements.map((el) => range.contains(el))), [
        [false, false, true, true, true, false, false, false],
        [false, false, true, true, true, true, false, false],
        [false, false, false, true, true, false, false, false],
        [false, false, false, true, true, true, false, false],
        [false, false, true, true, true, true, true, true],
        [true, true, true, true, true, false, false, false],
        [true, true, true, true, true, true, true, true],
        [false, false, false, false, false, false, false, false]
      ]);
    });

    test('DateTime', () {
      final l = DateTime(2022, 08, 30);
      final u = DateTime(2022, 09, 02);

      final ranges = <Range<DateTime>>[
        Range(l, u, incLower: true, incUpper: false),
        Range(l, u, incLower: true, incUpper: true),
        Range(l, u, incLower: false, incUpper: false),
        Range(l, u, incLower: false, incUpper: true),
        Range(l, null),
        Range(null, u),
        Range(null, null),
        Range.empty()
      ];

      final elements = [
        DateTime(-271821, 04, 21),
        l.subtract(Duration(days: 1)),
        l,
        l.add(Duration(days: 1)),
        u.subtract(Duration(days: 1)),
        u,
        u.add(Duration(days: 1)),
        DateTime(275760, 09, 13)
      ];

      expect(ranges.map((range) => elements.map((el) => range.contains(el))), [
        [false, false, true, true, true, false, false, false],
        [false, false, true, true, true, true, false, false],
        [false, false, false, true, true, false, false, false],
        [false, false, false, true, true, true, false, false],
        [false, false, true, true, true, true, true, true],
        [true, true, true, true, true, false, false, false],
        [true, true, true, true, true, true, true, true],
        [false, false, false, false, false, false, false, false]
      ]);
    });
  });

  group('range containsRange:', () {
    test('int', () {
      final ranges = <Range<int>>[
        Range(5, 10, incLower: true, incUpper: false),
        Range(5, 10, incLower: true, incUpper: true),
        Range(5, 10, incLower: false, incUpper: false),
        Range(5, 10, incLower: false, incUpper: true),
        Range(5, null),
        Range(null, 10),
        Range(null, null),
        Range.empty()
      ];

      final containsRanges = <Range<int>>[
        Range(5, 10, incLower: true, incUpper: false),
        Range(5, 10, incLower: true, incUpper: true),
        Range(5, 10, incLower: false, incUpper: false),
        Range(5, 10, incLower: false, incUpper: true),
        Range(6, 9),
        Range(4, 11),
        Range(1, 4),
        Range(11, 15),
        Range(null, 5),
        Range(10, null),
        Range(null, null),
        Range.empty(),
      ];

      expect(
          ranges.map((range) => containsRanges
              .map((other) => range.containsRange(other))
              .join(', ')),
          [
            'true, false, true, false, true, false, false, false, false, false, false, true',
            'true, true, true, true, true, false, false, false, false, false, false, true',
            'false, false, true, false, true, false, false, false, false, false, false, true',
            'false, false, true, true, true, false, false, false, false, false, false, true',
            'true, true, true, true, true, false, false, true, false, true, false, true',
            'true, false, true, false, true, false, true, false, true, false, false, true',
            'true, true, true, true, true, true, true, true, true, true, true, true',
            'false, false, false, false, false, false, false, false, false, false, false, true'
          ]);
    });

    test('double', () {
      final ranges = <Range<double>>[
        Range(5.0, 10.0, incLower: true, incUpper: false),
        Range(5.0, 10.0, incLower: true, incUpper: true),
        Range(5.0, 10.0, incLower: false, incUpper: false),
        Range(5.0, 10.0, incLower: false, incUpper: true),
        Range(5.0, null),
        Range(null, 10.0),
        Range(null, null),
        Range.empty()
      ];

      final containsRanges = <Range<double>>[
        Range(5.0, 10.0, incLower: true, incUpper: false),
        Range(5.0, 10.0, incLower: true, incUpper: true),
        Range(5.0, 10.0, incLower: false, incUpper: false),
        Range(5.0, 10.0, incLower: false, incUpper: true),
        Range(6.0, 9.0),
        Range(4.0, 11.0),
        Range(1.0, 4.0),
        Range(11.0, 15.0),
        Range(null, 5.0),
        Range(10.0, null),
        Range(null, null),
        Range.empty(),
      ];

      expect(
          ranges.map((range) => containsRanges
              .map((other) => range.containsRange(other))
              .join(', ')),
          [
            'true, false, true, false, true, false, false, false, false, false, false, true',
            'true, true, true, true, true, false, false, false, false, false, false, true',
            'false, false, true, false, true, false, false, false, false, false, false, true',
            'false, false, true, true, true, false, false, false, false, false, false, true',
            'true, true, true, true, true, false, false, true, false, true, false, true',
            'true, false, true, false, true, false, true, false, true, false, false, true',
            'true, true, true, true, true, true, true, true, true, true, true, true',
            'false, false, false, false, false, false, false, false, false, false, false, true'
          ]);
    });

    test('DateTime', () {
      final l = DateTime(2022, 08, 30);
      final u = DateTime(2022, 09, 02);
      final min = DateTime(-271821, 04, 21);
      final max = DateTime(275760, 09, 13);

      final ranges = <Range<DateTime>>[
        Range(l, u, incLower: true, incUpper: false),
        Range(l, u, incLower: true, incUpper: true),
        Range(l, u, incLower: false, incUpper: false),
        Range(l, u, incLower: false, incUpper: true),
        Range(l, null),
        Range(null, u),
        Range(null, null),
        Range.empty()
      ];

      final containsRanges = <Range<DateTime>>[
        Range(l, u, incLower: true, incUpper: false),
        Range(l, u, incLower: true, incUpper: true),
        Range(l, u, incLower: false, incUpper: false),
        Range(l, u, incLower: false, incUpper: true),
        Range(l.add(Duration(days: 1)), u.subtract(Duration(days: 1))),
        Range(l.subtract(Duration(days: 1)), u.add(Duration(days: 1))),
        Range(l.subtract(Duration(days: 3)), l.subtract(Duration(days: 1))),
        Range(u.add(Duration(days: 1)), u.add(Duration(days: 3))),
        Range(min, l),
        Range(u, max),
        Range(min, max),
        Range.empty(),
      ];

      expect(
          ranges.map((range) => containsRanges
              .map((other) => range.containsRange(other))
              .join(', ')),
          [
            'true, false, true, false, true, false, false, false, false, false, false, true',
            'true, true, true, true, true, false, false, false, false, false, false, true',
            'false, false, true, false, true, false, false, false, false, false, false, true',
            'false, false, true, true, true, false, false, false, false, false, false, true',
            'true, true, true, true, true, false, false, true, false, true, false, true',
            'true, false, true, false, true, false, true, false, true, false, false, true',
            'true, true, true, true, true, true, true, true, true, true, true, true',
            'false, false, false, false, false, false, false, false, false, false, false, true'
          ]);
    });
  });

  group('range overlaps:', () {
    test('int', () {
      final ranges = <Range<int>>[
        Range(5, 10, incLower: true, incUpper: false),
        Range(5, 10, incLower: true, incUpper: true),
        Range(5, 10, incLower: false, incUpper: false),
        Range(5, 10, incLower: false, incUpper: true),
        Range(5, null),
        Range(null, 10),
        Range(null, null),
        Range.empty()
      ];

      final overlaps = <Range<int>>[
        Range(0, 5, incUpper: false),
        Range(0, 5, incUpper: true),
        Range(10, 15, incLower: false),
        Range(10, 15, incLower: true),
        Range(0, 4),
        Range(11, 15),
        Range(0, 8),
        Range(8, 15),
        Range(7, 9),
        Range(0, 15),
        Range(null, null),
        Range.empty()
      ];

      expect(
          ranges.map((range) =>
              overlaps.map((other) => range.overlaps(other)).join(', ')),
          [
            'false, true, false, false, false, false, true, true, true, true, true, false',
            'false, true, false, true, false, false, true, true, true, true, true, false',
            'false, false, false, false, false, false, true, true, true, true, true, false',
            'false, false, false, true, false, false, true, true, true, true, true, false',
            'false, true, true, true, false, true, true, true, true, true, true, false',
            'true, true, false, false, true, false, true, true, true, true, true, false',
            'true, true, true, true, true, true, true, true, true, true, true, false',
            'false, false, false, false, false, false, false, false, false, false, false, false'
          ]);
    });

    test('double', () {
      final ranges = <Range<double>>[
        Range(5.0, 10.0, incLower: true, incUpper: false),
        Range(5.0, 10.0, incLower: true, incUpper: true),
        Range(5.0, 10.0, incLower: false, incUpper: false),
        Range(5.0, 10.0, incLower: false, incUpper: true),
        Range(5.0, null),
        Range(null, 10.0),
        Range(null, null),
        Range.empty()
      ];

      final overlaps = <Range<double>>[
        Range(0, 5.0, incUpper: false),
        Range(0, 5.0, incUpper: true),
        Range(10.0, 15.0, incLower: false),
        Range(10.0, 15.0, incLower: true),
        Range(0, 4.0),
        Range(11.0, 15.0),
        Range(0, 8.0),
        Range(8.0, 15.0),
        Range(7.0, 9.0),
        Range(0, 15.0),
        Range(null, null),
        Range.empty()
      ];

      expect(
          ranges.map((range) =>
              overlaps.map((other) => range.overlaps(other)).join(', ')),
          [
            'false, true, false, false, false, false, true, true, true, true, true, false',
            'false, true, false, true, false, false, true, true, true, true, true, false',
            'false, false, false, false, false, false, true, true, true, true, true, false',
            'false, false, false, true, false, false, true, true, true, true, true, false',
            'false, true, true, true, false, true, true, true, true, true, true, false',
            'true, true, false, false, true, false, true, true, true, true, true, false',
            'true, true, true, true, true, true, true, true, true, true, true, false',
            'false, false, false, false, false, false, false, false, false, false, false, false'
          ]);
    });

    test('DateTime', () {
      final l = DateTime(2022, 08, 30);
      final u = DateTime(2022, 09, 02);

      final ranges = <Range<DateTime>>[
        Range(l, u, incLower: true, incUpper: false),
        Range(l, u, incLower: true, incUpper: true),
        Range(l, u, incLower: false, incUpper: false),
        Range(l, u, incLower: false, incUpper: true),
        Range(l, null),
        Range(null, u),
        Range(null, null),
        Range.empty()
      ];

      final overlaps = <Range<DateTime>>[
        Range(DateTime(2022, 08, 25), l, incUpper: false),
        Range(DateTime(2022, 08, 25), l, incUpper: true),
        Range(u, DateTime(2022, 09, 07), incLower: false),
        Range(u, DateTime(2022, 09, 07), incLower: true),
        Range(DateTime(2022, 08, 25), DateTime(2022, 08, 29)),
        Range(DateTime(2022, 09, 03), DateTime(2022, 09, 07)),
        Range(DateTime(2022, 08, 25), DateTime(2022, 08, 31)),
        Range(DateTime(2022, 08, 31), DateTime(2022, 09, 07)),
        Range(DateTime(2022, 08, 31), DateTime(2022, 09, 01)),
        Range(DateTime(2022, 08, 25), DateTime(2022, 09, 07)),
        Range(null, null),
        Range.empty()
      ];

      expect(
          ranges.map((range) =>
              overlaps.map((other) => range.overlaps(other)).join(', ')),
          [
            'false, true, false, false, false, false, true, true, true, true, true, false',
            'false, true, false, true, false, false, true, true, true, true, true, false',
            'false, false, false, false, false, false, true, true, true, true, true, false',
            'false, false, false, true, false, false, true, true, true, true, true, false',
            'false, true, true, true, false, true, true, true, true, true, true, false',
            'true, true, false, false, true, false, true, true, true, true, true, false',
            'true, true, true, true, true, true, true, true, true, true, true, false',
            'false, false, false, false, false, false, false, false, false, false, false, false'
          ]);
    });
  });
}
