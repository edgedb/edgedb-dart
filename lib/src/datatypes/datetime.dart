final _localDateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

class LocalDate extends Comparable<LocalDate> {
  final DateTime _date;

  LocalDate(
    int year, [
    int month = 1,
    int day = 1,
  ]) : _date = DateTime.utc(year, month, day);

  LocalDate.fromDateTime(DateTime date)
      : _date = DateTime.utc(date.year, date.month, date.day);

  static LocalDate parse(String formattedString) {
    if (!_localDateRegex.hasMatch(formattedString)) {
      throw FormatException("invalid LocalDate format", formattedString);
    }
    return LocalDate.fromDateTime(DateTime.parse(formattedString));
  }

  static LocalDate? tryParse(String formattedString) {
    try {
      return parse(formattedString);
    } on FormatException {
      return null;
    }
  }

  int get year {
    return _date.year;
  }

  int get month {
    return _date.month;
  }

  int get day {
    return _date.day;
  }

  int get weekday {
    return _date.weekday;
  }

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

  @override
  String toString() {
    return _date.toString().split(' ').first;
  }
}

DateTime getDateTimeFromLocalDate(LocalDate date) {
  return date._date;
}

final _localTimeRegex = RegExp(r'^\d{1,2}:\d{2}:\d{2}(\.\d{1,6})?$');

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

  LocalTime.fromDateTime(DateTime date)
      : _date = DateTime.utc(1970, 1, 1, date.hour, date.minute, date.second,
            date.millisecond, date.microsecond);

  static LocalTime parse(String formattedString) {
    if (!_localTimeRegex.hasMatch(formattedString)) {
      throw FormatException("invalid LocalTime format", formattedString);
    }
    return LocalTime.fromDateTime(
        DateTime.parse('1970-01-01T${formattedString}Z'));
  }

  static LocalTime? tryParse(String formattedString) {
    try {
      return parse(formattedString);
    } on FormatException {
      return null;
    }
  }

  int get hour {
    return _date.hour;
  }

  int get minute {
    return _date.minute;
  }

  int get second {
    return _date.second;
  }

  int get millisecond {
    return _date.millisecond;
  }

  int get microsecond {
    return _date.microsecond;
  }

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

  LocalDateTime.fromDateTime(DateTime date)
      : _date = DateTime.utc(date.year, date.month, date.day, date.hour,
            date.minute, date.second, date.millisecond, date.microsecond);

  static LocalDateTime parse(String formattedString) {
    if (!_localDateTimeRegex.hasMatch(formattedString)) {
      throw FormatException("invalid LocalDateTime format", formattedString);
    }
    return LocalDateTime.fromDateTime(DateTime.parse('${formattedString}Z'));
  }

  static LocalDateTime? tryParse(String formattedString) {
    try {
      return parse(formattedString);
    } on FormatException {
      return null;
    }
  }

  int get year {
    return _date.year;
  }

  int get month {
    return _date.month;
  }

  int get day {
    return _date.day;
  }

  int get weekday {
    return _date.weekday;
  }

  int get hour {
    return _date.hour;
  }

  int get minute {
    return _date.minute;
  }

  int get second {
    return _date.second;
  }

  int get millisecond {
    return _date.millisecond;
  }

  int get microsecond {
    return _date.microsecond;
  }

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

  @override
  String toString() {
    final dateStr = _date.toString().replaceFirst(' ', 'T');
    return dateStr.substring(0, dateStr.length - 1);
  }
}

DateTime getDateTimeFromLocalDateTime(LocalDateTime date) {
  return date._date;
}

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

  int get years {
    return _months ~/ 12;
  }

  int get months {
    return _months;
  }

  int get days {
    return _days;
  }

  int get hours {
    return _microseconds ~/ Duration.microsecondsPerHour;
  }

  int get minutes {
    return _microseconds ~/ Duration.microsecondsPerMinute;
  }

  int get seconds {
    return _microseconds ~/ Duration.microsecondsPerSecond;
  }

  int get milliseconds {
    return _microseconds ~/ Duration.microsecondsPerMillisecond;
  }

  int get microseconds {
    return _microseconds;
  }
}

class DateDuration {
  final int _months;
  final int _days;

  DateDuration({
    int years = 0,
    int months = 0,
    int days = 0,
  })  : _months = years * 12 + months,
        _days = days;

  int get years {
    return _months ~/ 12;
  }

  int get months {
    return _months;
  }

  int get days {
    return _days;
  }
}
