import 'dart:math';

final _isoDurationRegex = RegExp(
    r'^(?<sign>-|\+)?P(?:(?<years>\d+)Y)?(?:(?<months>\d+)M)?(?:(?<weeks>\d+)W)?(?:(?<days>\d+)D)?(?:T(?:(?<hours>\d+)H)?(?:(?<mins>\d+)M)?(?:(?<secs>\d+)S)?)?$');

Duration parseISODurationString(String durationStr) {
  final match = _isoDurationRegex.firstMatch(durationStr);
  if (match == null) {
    throw FormatException('invalid ISO duration string', durationStr);
  }

  if (match.namedGroup('years') != null || match.namedGroup('months') != null) {
    throw FormatException(
        "'years' and 'months' are not supported in ISO duration strings",
        durationStr);
  }

  return Duration(
      days: int.parse(match.namedGroup('weeks') ?? '0', radix: 10) * 7 +
          int.parse(match.namedGroup('days') ?? '0', radix: 10),
      hours: int.parse(match.namedGroup('hours') ?? '0', radix: 10),
      minutes: int.parse(match.namedGroup('mins') ?? '0', radix: 10),
      seconds: int.parse(match.namedGroup('secs') ?? '0', radix: 10));
}

const _humanDurationPrefixes = {
  'h': 3600000,
  'hou': 3600000,
  'm': 60000,
  'min': 60000,
  's': 1000,
  'sec': 1000,
  'ms': 1,
  'mil': 1,
};

final _humanDurationRegex = RegExp(
    r'(\d+|\d+\.\d+|\.\d+)\s*(hours?|minutes?|seconds?|milliseconds?|ms|h|m|s)\s*');

Duration parseHumanDurationString(String durationStr) {
  double duration = 0;
  final seen = <int>{};

  var lastIndex = 0;
  for (var match in _humanDurationRegex.allMatches(durationStr)) {
    if (match.start != lastIndex) {
      throw FormatException('invalid duration string', durationStr);
    }
    final mult = _humanDurationPrefixes[
        match.group(2)!.substring(0, min(match.group(2)!.length, 3))]!;
    if (seen.contains(mult)) {
      throw FormatException(
          'invalid duration: multiple "${match.group(2)}" values', durationStr);
    }
    duration += double.parse(match.group(1)!) * mult;
    seen.add(mult);
    lastIndex = match.end;
  }
  if (lastIndex != durationStr.length) {
    throw FormatException('invalid duration', durationStr);
  }
  return Duration(milliseconds: duration.round());
}
