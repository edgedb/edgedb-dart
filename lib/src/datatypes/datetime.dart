final _localDateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Represents a calendar date without any associated time or timezone.
///
class LocalDate extends Comparable<LocalDate> {
  final DateTime _date;

  LocalDate(
    int year, [
    int month = 1,
    int day = 1,
  ]) : _date = DateTime.utc(year, month, day);

  /// Creates a new [LocalDate] from the `year`, `month` and `day` properties
  /// of the given [DateTime].
  ///
  /// Note: Any time component of the [DateTime] is ignored.
  ///
  LocalDate.fromDateTime(DateTime date)
      : _date = DateTime.utc(date.year, date.month, date.day);

  /// Creates a new [LocalDate] from a [formattedString].
  ///
  /// Expects a string in the format `YYYY-MM-DD`, without any timezone.
  /// Throws a [FormatException] is the string cannot be parsed.
  ///
  static LocalDate parse(String formattedString) {
    if (!_localDateRegex.hasMatch(formattedString)) {
      throw FormatException("invalid LocalDate format", formattedString);
    }
    return LocalDate.fromDateTime(DateTime.parse(formattedString));
  }

  /// Creates a new [LocalDate] from a [formattedString], or `null` if the
  /// string is not a valid date.
  ///
  /// Expects a string in the format `YYYY-MM-DD`, without any timezone.
  ///
  static LocalDate? tryParse(String formattedString) {
    try {
      return parse(formattedString);
    } on FormatException {
      return null;
    }
  }

  /// The year.
  int get year {
    return _date.year;
  }

  /// The month `[1..12]`.
  int get month {
    return _date.month;
  }

  /// The day of the month `[1..31]`.
  int get day {
    return _date.day;
  }

  /// The day of the week [DateTime.monday]..[DateTime.sunday].
  ///
  /// In accordance with ISO 8601 a week starts with Monday, which has the value 1.
  int get weekday {
    return _date.weekday;
  }

  /// Returns true if `other` is a [LocalDate] with the same date.
  @override
  bool operator ==(Object other) {
    return other is LocalDate && _date == other._date;
  }

  @override
  int get hashCode {
    return _date.hashCode;
  }

  @override
  int compareTo(LocalDate other) {
    return _date.compareTo(other._date);
  }

  /// Returns the date in the format `YYYY-MM-DD`.
  @override
  String toString() {
    return _date.toString().split(' ').first;
  }
}

DateTime getDateTimeFromLocalDate(LocalDate date) {
  return date._date;
}

final _localTimeRegex = RegExp(r'^\d{1,2}:\d{2}:\d{2}(\.\d{1,6})?$');

/// Represents a 'wall-clock' time, without any associated date or timezone.
///
class LocalTime extends Comparable<LocalTime> {
  final DateTime _date;

  LocalTime(
      [int hour = 0,
      int minute = 0,
      int second = 0,
      int millisecond = 0,
      int microsecond = 0])
      : _date = DateTime.utc(
            1970, 1, 1, hour, minute, second, millisecond, microsecond);

  /// Creates a new [LocalTime] from the `hour`, `minute`, `second`,
  /// `millisecond` and `microsecond` properties of the given [DateTime].
  ///
  /// Note: Any date component of the [DateTime] is ignored.
  ///
  LocalTime.fromDateTime(DateTime date)
      : _date = DateTime.utc(1970, 1, 1, date.hour, date.minute, date.second,
            date.millisecond, date.microsecond);

  /// Creates a new [LocalTime] from a [formattedString].
  ///
  /// Expects a string in the format `HH:MM:SS[.ssssss]`, without any timezone.
  /// Throws a [FormatException] is the string cannot be parsed.
  ///
  static LocalTime parse(String formattedString) {
    if (!_localTimeRegex.hasMatch(formattedString)) {
      throw FormatException("invalid LocalTime format", formattedString);
    }
    return LocalTime.fromDateTime(
        DateTime.parse('1970-01-01T${formattedString}Z'));
  }

  /// Creates a new [LocalTime] from a [formattedString], or `null` if the
  /// string is not a valid time.
  ///
  /// Expects a string in the format `HH:MM:SS[.ssssss]`, without any timezone.
  ///
  static LocalTime? tryParse(String formattedString) {
    try {
      return parse(formattedString);
    } on FormatException {
      return null;
    }
  }

  /// The hour of the day, expressed as in a 24-hour clock `[0..23]`.
  int get hour {
    return _date.hour;
  }

  /// The minute `[0...59]`.
  int get minute {
    return _date.minute;
  }

  /// The second `[0...59]`.
  int get second {
    return _date.second;
  }

  /// The millisecond `[0...999]`.
  int get millisecond {
    return _date.millisecond;
  }

  /// The microsecond `[0...999]`.
  int get microsecond {
    return _date.microsecond;
  }

  /// Returns true if `other` is a [LocalTime] with the same time.
  @override
  bool operator ==(Object other) {
    return other is LocalTime && _date == other._date;
  }

  @override
  int get hashCode {
    return _date.hashCode;
  }

  @override
  int compareTo(LocalTime other) {
    return _date.compareTo(other._date);
  }

  /// Returns the time in the format `HH:MM:SS[.ssssss]`.
  @override
  String toString() {
    final time = _date.toString().split(' ').last;
    return time.substring(0, time.length - 1);
  }
}

DateTime getDateTimeFromLocalTime(LocalTime date) {
  return date._date;
}

final _localDateTimeRegex =
    RegExp(r'^\d{4}-\d{2}-\d{2}T\d{1,2}:\d{2}:\d{2}(\.\d{1,6})?$');

/// Represents a calendar date and time without a timezone.
///
/// Unlike [DateTime], which represents an instant in time where a timezone is
/// needed to convert to a 'calendar' date, [LocalDateTime] directly represents
/// a calendar date without a timezone, so doesn't repesent any specific
/// instant in time.
///
class LocalDateTime extends Comparable<LocalDateTime> {
  final DateTime _date;

  LocalDateTime(int year,
      [int month = 1,
      int day = 1,
      int hour = 0,
      int minute = 0,
      int second = 0,
      int millisecond = 0,
      int microsecond = 0])
      : _date = DateTime.utc(
            year, month, day, hour, minute, second, millisecond, microsecond);

  /// Creates a new [LocalDateTime] from the `year`, `month`, `day`, `hour`,
  /// `minute`, `second`, `millisecond` and `microsecond` properties of the
  /// given [DateTime].
  ///
  LocalDateTime.fromDateTime(DateTime date)
      : _date = DateTime.utc(date.year, date.month, date.day, date.hour,
            date.minute, date.second, date.millisecond, date.microsecond);

  /// Creates a new [LocalDateTime] from a [formattedString].
  ///
  /// Expects a string in the format `YYYY-MM-DD'T'HH:MM:SS[.ssssss]`,
  /// without any timezone.
  /// Throws a [FormatException] is the string cannot be parsed.
  ///
  static LocalDateTime parse(String formattedString) {
    if (!_localDateTimeRegex.hasMatch(formattedString)) {
      throw FormatException("invalid LocalDateTime format", formattedString);
    }
    return LocalDateTime.fromDateTime(DateTime.parse('${formattedString}Z'));
  }

  /// Creates a new [LocalDateTime] from a [formattedString], or `null` if the
  /// string is not a valid time.
  ///
  /// Expects a string in the format `YYYY-MM-DD'T'HH:MM:SS[.ssssss]`,
  /// without any timezone.
  ///
  static LocalDateTime? tryParse(String formattedString) {
    try {
      return parse(formattedString);
    } on FormatException {
      return null;
    }
  }

  /// The year.
  int get year {
    return _date.year;
  }

  /// The month `[1..12]`.
  int get month {
    return _date.month;
  }

  /// The day of the month `[1..31]`.
  int get day {
    return _date.day;
  }

  /// The day of the week [DateTime.monday]..[DateTime.sunday].
  ///
  /// In accordance with ISO 8601 a week starts with Monday, which has the value 1.
  int get weekday {
    return _date.weekday;
  }

  /// The hour of the day, expressed as in a 24-hour clock `[0..23]`.
  int get hour {
    return _date.hour;
  }

  /// The minute `[0...59]`.
  int get minute {
    return _date.minute;
  }

  /// The second `[0...59]`.
  int get second {
    return _date.second;
  }

  /// The millisecond `[0...999]`.
  int get millisecond {
    return _date.millisecond;
  }

  /// The microsecond `[0...999]`.
  int get microsecond {
    return _date.microsecond;
  }

  /// Returns true if `other` is a [LocalDateTime] with the same date and time.
  @override
  bool operator ==(Object other) {
    return other is LocalDateTime && _date == other._date;
  }

  @override
  int get hashCode {
    return _date.hashCode;
  }

  @override
  int compareTo(LocalDateTime other) {
    return _date.compareTo(other._date);
  }

  /// Returns the date in the format `YYYY-MM-DD'T'HH:MM:SS[.ssssss]`.
  @override
  String toString() {
    final dateStr = _date.toString().replaceFirst(' ', 'T');
    return dateStr.substring(0, dateStr.length - 1);
  }
}

DateTime getDateTimeFromLocalDateTime(LocalDateTime date) {
  return date._date;
}

/// Represents an interval of time. [RelativeDuration] can contain both
/// absolute components (`hours`, `minutes`, `seconds`, `milliseconds` and
/// `microseconds`) as in the [Duration] type, and also components which need
/// to be interpreted relative to a date (`years`, `months`, `days`).
///
/// The absolute components are represented as single integer number of
/// microseconds (same as [Duration]), with days and months being represented
/// separately as their own integer numbers. (Years are converted and added
/// to months). Each of the three components of the [RelativeDuration] may
/// have its own sign.
///
class RelativeDuration {
  final int _months;
  final int _days;
  final int _microseconds;

  RelativeDuration({
    int years = 0,
    int months = 0,
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
    int milliseconds = 0,
    int microseconds = 0,
  })  : _months = years * 12 + months,
        _days = days,
        _microseconds = hours * Duration.microsecondsPerHour +
            minutes * Duration.microsecondsPerMinute +
            seconds * Duration.microsecondsPerSecond +
            milliseconds * Duration.microsecondsPerMillisecond +
            microseconds;

  /// The number of whole years spanned by the `months` component of this
  /// [RelativeDuration].
  int get years {
    return _months ~/ 12;
  }

  /// The number of months spanned by the `months` component of this
  /// [RelativeDuration].
  int get months {
    return _months;
  }

  /// The number of days spanned by the `days` component of this
  /// [RelativeDuration].
  int get days {
    return _days;
  }

  /// The number of whole hours spanned by the absolute component of this
  /// [RelativeDuration].
  int get hours {
    return _microseconds ~/ Duration.microsecondsPerHour;
  }

  /// The number of whole minutes spanned by the absolute component of this
  /// [RelativeDuration].
  int get minutes {
    return _microseconds ~/ Duration.microsecondsPerMinute;
  }

  /// The number of whole seconds spanned by the absolute component of this
  /// [RelativeDuration].
  int get seconds {
    return _microseconds ~/ Duration.microsecondsPerSecond;
  }

  /// The number of whole milliseconds spanned by the absolute component of this
  /// [RelativeDuration].
  int get milliseconds {
    return _microseconds ~/ Duration.microsecondsPerMillisecond;
  }

  /// The number of whole microseconds spanned by the absolute component of this
  /// [RelativeDuration].
  int get microseconds {
    return _microseconds;
  }

  /// Whether all components of `this` [RelativeDuration] are equal to the
  /// respective components of the `other` [RelativeDuration].
  @override
  bool operator ==(Object other) {
    return other is RelativeDuration &&
        _months == other._months &&
        _days == other._days &&
        _microseconds == other._microseconds;
  }

  @override
  int get hashCode {
    return Object.hash(_months, _days, _microseconds);
  }

  /// Returns the duration in
  /// [ISO 8601 duration](https://en.wikipedia.org/wiki/ISO_8601#Durations) format.
  @override
  String toString() {
    if (_days == 0 && _months == 0 && _microseconds == 0) {
      return 'PT0S';
    }

    final y = years;
    final m = _months - y;
    final d = _days;
    var str =
        'P${y != 0 ? '${y}Y' : ''}${m != 0 ? '${m}M' : ''}${d != 0 ? '${d}D' : ''}';
    if (_microseconds != 0) {
      var us = _microseconds;
      final h = us ~/ Duration.microsecondsPerHour;
      us -= h * Duration.microsecondsPerHour;
      final min = us ~/ Duration.microsecondsPerMinute;
      us -= min * Duration.microsecondsPerMinute;
      final s = us ~/ Duration.millisecondsPerSecond;
      us -= s * Duration.microsecondsPerSecond;
      str += 'T${h != 0 ? '${h}H' : ''}${min != 0 ? '${min}M' : ''}';
      if (s != 0 || us != 0) {
        str += '${s.isNegative || us.isNegative ? '-' : ''}${s.abs()}'
            '${us != 0 ? '.${us.abs().toString().padLeft(6, '0').replaceFirst(RegExp(r'0+$'), '')}' : ''}S';
      }
    }
    return str;
  }
}

/// Represents an interval of time in days and months. [DateDuration] unlike
/// [RelativeDuration] does not contain an absolute time component. (ie.
/// `hours`, `minutes`, `seconds`, `milliseconds` and `microseconds`).
///
/// Days and months are represented separately as their own integer numbers.
/// (Years are converted and added to months). Each of the the components of
/// the [DateDuration] may have its own sign.
///
class DateDuration {
  final int _months;
  final int _days;

  DateDuration({
    int years = 0,
    int months = 0,
    int days = 0,
  })  : _months = years * 12 + months,
        _days = days;

  /// The number of whole years spanned by the `months` component of this
  /// [DateDuration].
  int get years {
    return _months ~/ 12;
  }

  /// The number of months spanned by the `months` component of this
  /// [DateDuration].
  int get months {
    return _months;
  }

  /// The number of days spanned by the `days` component of this
  /// [DateDuration].
  int get days {
    return _days;
  }

  /// Whether all components of `this` [DateDuration] are equal to the
  /// respective components of the `other` [DateDuration].
  @override
  bool operator ==(Object other) {
    return other is DateDuration &&
        _months == other._months &&
        _days == other._days;
  }

  @override
  int get hashCode {
    return Object.hash(_months, _days);
  }

  /// Returns the duration in
  /// [ISO 8601 duration](https://en.wikipedia.org/wiki/ISO_8601#Durations) format.
  @override
  String toString() {
    if (_days == 0 && _months == 0) {
      return 'PT0S';
    }

    final y = years;
    final m = _months - y;
    final d = _days;
    return 'P${y != 0 ? '${y}Y' : ''}${m != 0 ? '${m}M' : ''}${d != 0 ? '${d}D' : ''}';
  }
}
