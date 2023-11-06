/*!
 * This source file is part of the EdgeDB open source project.
 *
 * Copyright 2019-present MagicStack Inc. and the EdgeDB authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:collection';

_add(dynamic a, dynamic b) {
  if (a is DateTime) {
    return a.add(b);
  }
  return (a as dynamic) + b;
}

bool _lt(dynamic a, dynamic b) {
  return a.compareTo(b) < 0;
}

bool _gt(dynamic a, dynamic b) {
  return a.compareTo(b) > 0;
}

bool _lte(dynamic a, dynamic b) {
  return a.compareTo(b) <= 0;
}

bool _gte(dynamic a, dynamic b) {
  return a.compareTo(b) >= 0;
}

/// Represents an interval between values.
///
/// The `Range` type behaves the same as the EdgeDB `range` type.
/// Ranges can have a lower and upper boundary, which can be inclusive or
/// exclusive, or omitted completely (`null`). By default, the lower boundary
/// is inclusive, and the upper boundary exclusive.
///
/// Depending on the type of the range, `T`, the range is either discrete or
/// continuous.
/// Discrete range types: `Range<int>`
/// Continuous range types: `Range<double>`, `Range<DateTime>`
/// Discrete ranges are normalised upon creation, such that the lower boundary
/// becomes inclusive, and the upper boundary becomes exclusive.
///
/// If a range can contain no values, it is considered 'empty'. Empty ranges
/// are all considered equal to each other. An empty range can be created
/// either by the `Range.empty()` constructor, creating a range where the lower
/// and upper boundaries are equal, and at least one boundary is exclusive, or
/// as the result of some operation on a range.
///
class Range<T> extends Comparable<Range<T>> {
  final bool _isEmpty;
  final T? _lower;
  final T? _upper;
  final bool _incLower;
  final bool _incUpper;

  Range._(this._lower, this._upper, this._incLower, this._incUpper)
      : _isEmpty = false;

  /// Creates a new [Range].
  ///
  /// If not given, [incLower] and [incUpper] default to `true` and `false`
  /// respectively.
  ///
  factory Range(T? lower, T? upper, {bool? incLower, bool? incUpper}) {
    if (lower == null && upper == null) {
      return Range._(null, null, false, false);
    }
    if ((lower != null && lower is! num && lower is! DateTime) ||
        (upper != null && upper is! num && upper is! DateTime)) {
      throw ArgumentError('range must be of type num or DateTime, got $T');
    }
    if (lower != null && upper != null) {
      if (lower.runtimeType != upper.runtimeType) {
        throw ArgumentError('upper and lower bounds must of of the same type');
      }
      if (_gt(lower, upper)) {
        throw ArgumentError(
            'range lower bound must be less than or equal to range upper bound');
      }
    }
    if ((lower is int?) && (upper is int?)) {
      if (lower != null && incLower == false) {
        lower = (lower as dynamic) + 1;
      }
      if (upper != null && incUpper == true) {
        upper = (upper as dynamic) + 1;
      }
      if (lower != null && upper != null && lower as dynamic >= upper) {
        return Range.empty();
      }
      return Range._(lower, upper, lower != null, false);
    } else {
      if (lower != null &&
          lower == upper &&
          (!(incLower ?? true) || !(incUpper ?? false))) {
        return Range.empty();
      }
      return Range._(lower, upper, lower == null ? false : incLower ?? true,
          upper == null ? false : incUpper ?? false);
    }
  }

  /// Creates a new empty [Range] of type `T`.
  Range.empty()
      : _lower = null,
        _upper = null,
        _incLower = false,
        _incUpper = false,
        _isEmpty = true;

  /// The lower boundary of the range, if it exists.
  T? get lower {
    return _lower;
  }

  /// The upper boundary of the range, if it exists.
  T? get upper {
    return _upper;
  }

  /// Whether the lower boundary is inclusive. Is always `false` for unspecified
  /// boundaries and empty ranges.
  bool get incLower {
    return _incLower;
  }

  /// Whether the upper boundary is inclusive. Is always `false` for unspecified
  /// boundaries and empty ranges.
  bool get incUpper {
    return _incUpper;
  }

  /// Whether the range is empty.
  bool get isEmpty {
    return _isEmpty;
  }

  /// String representation of the range.
  ///
  /// Inclusive boundaries are denoted by `[]` brackets, and exclusive
  /// boundaries by `()`. If the range is empty, returns the string `'empty'`.
  @override
  String toString() {
    return _isEmpty
        ? 'empty'
        : '${_incLower ? '[' : '('}'
            '${_lower == null ? '' : _lower.toString()},'
            '${_upper == null ? '' : _upper.toString()}'
            '${_incUpper ? ']' : ')'}';
  }

  toJSON() {
    return _isEmpty
        ? {'empty': true}
        : {
            'lower': _lower,
            'upper': _upper,
            'inc_lower': _incLower,
            'inc_upper': _incUpper,
          };
  }

  /// Returns whether two ranges are equal.
  @override
  bool operator ==(Object other) {
    if (other is! Range<T>) {
      return false;
    }

    return _isEmpty == other._isEmpty &&
        (_isEmpty ||
            (_lower == other._lower &&
                _incLower == other._incLower &&
                _upper == other._upper &&
                _incUpper == other._incUpper));
  }

  /// The hash code for this object.
  @override
  int get hashCode =>
      Object.hash(_isEmpty, _lower, _upper, _incLower, _incUpper);

  @override
  int compareTo(Range<T> other) {
    if (this == other) {
      return 0;
    }
    return this < other ? -1 : 1;
  }

  /// Returns whether this range is before the [other] range.
  ///
  /// A range is considered to be ordered before another range if its
  /// lower bound is lower than the other. If the lower bounds are equal, the
  /// upper bounds are checked. An empty range is considered lower than a
  /// non-empty range, and unspecified lower/upper bounds are considered
  /// lower/greater than specified lower/upper bounds respectively.
  bool operator <(Range<T> other) {
    if (_isEmpty || other._isEmpty) {
      return !other._isEmpty;
    }
    if (_lower == other._lower && _incLower == other._incLower) {
      if (_upper == null) {
        return false;
      }
      if (other._upper == null) {
        return true;
      }
      return (!_incUpper && other._incUpper)
          ? _lte(_upper, other._upper)
          : _lt(_upper, other._upper);
    }
    if (_lower == null) {
      return true;
    }
    if (other._lower == null) {
      return false;
    }
    return (_incLower && !other._incLower)
        ? _lte(_lower, other._lower)
        : _lt(_lower, other._lower);
  }

  /// Returns whether this range is after the [other] range.
  ///
  /// A range is considered to be ordered after another range if its
  /// lower bound is greater than the other. If the lower bounds are equal, the
  /// upper bounds are checked. An empty range is considered lower than a
  /// non-empty range, and unspecified lower/upper bounds are considered
  /// lower/greater than specified lower/upper bounds respectively.
  bool operator >(Range<T> other) {
    if (_isEmpty || other._isEmpty) {
      return !_isEmpty;
    }
    if (_lower == other._lower && _incLower == other._incLower) {
      if (other._upper == null) {
        return false;
      }
      if (_upper == null) {
        return true;
      }
      return (_incUpper && !other._incUpper)
          ? _gte(_upper, other._upper)
          : _gt(_upper, other._upper);
    }
    if (_lower == null) {
      return false;
    }
    if (other._lower == null) {
      return true;
    }
    return (!_incLower && other._incLower)
        ? _gte(_lower, other._lower)
        : _gt(_lower, other._lower);
  }

  /// Returns whether this range is before or equal to the [other] range.
  ///
  /// A range is considered to be ordered before another range if its
  /// lower bound is lower than the other. If the lower bounds are equal, the
  /// upper bounds are checked. An empty range is considered lower than a
  /// non-empty range, and unspecified lower/upper bounds are considered
  /// lower/greater than specified lower/upper bounds respectively.
  bool operator <=(Range<T> other) {
    return this == other || this < other;
  }

  /// Returns whether this range is after or equal to the [other] range.
  ///
  /// A range is considered to be ordered after another range if its
  /// lower bound is greater than the other. If the lower bounds are equal, the
  /// upper bounds are checked. An empty range is considered lower than a
  /// non-empty range, and unspecified lower/upper bounds are considered
  /// lower/greater than specified lower/upper bounds respectively.
  bool operator >=(Range<T> other) {
    return this == other || this < other;
  }

  /// Returns the union of two ranges.
  ///
  /// Throws an error if the result is not a single continuous range.
  Range<T> operator +(Range<T> other) {
    if (_isEmpty) {
      return other;
    }
    if (other._isEmpty || this == other) {
      return this;
    }
    final thisLower = this < other;
    final lower = thisLower ? this : other;
    final upper = thisLower ? other : this;
    if (lower._upper != null &&
        upper._lower != null &&
        (!lower._incUpper && !upper._incLower
            ? _lte(lower._upper, upper._lower)
            : _lt(lower._upper, upper._lower))) {
      throw StateError('result of range union would not be contiguous');
    }
    if (lower._upper == null ||
        (upper._upper != null && _lt(upper._upper, lower._upper))) {
      return lower;
    } else {
      return Range(lower._lower, upper._upper,
          incLower: lower._incLower,
          incUpper: upper._incUpper ||
              (lower._upper == upper._upper ? lower._incUpper : false));
    }
  }

  /// Subtracts one range from another.
  ///
  /// Throws an error if the result is not a single continuous range.
  Range<T> operator -(Range<T> other) {
    if (_isEmpty || other._isEmpty) {
      return this;
    }
    if (this == other) {
      return Range.empty();
    }
    if (this < other) {
      if (_lower == other._lower && _incLower == other._incLower) {
        return Range(_upper, other._upper,
            incLower: !_incUpper, incUpper: other._incUpper);
      }
      if (other._upper != null &&
          (_upper == null ||
              (_incUpper && !other._incUpper
                  ? _lte(other._upper, _upper)
                  : _lt(other._upper, _upper)))) {
        throw StateError('result of range subtraction would not be contiguous');
      }
      return Range(_lower, other._lower,
          incLower: _incLower, incUpper: !other._incLower);
    } else {
      if (_upper != null &&
          (other._upper == null ||
              (_incUpper && !other._incUpper
                  ? _lt(_upper, other._upper)
                  : _lte(_upper, other._upper)))) {
        return Range.empty();
      }
      return Range(other._upper, _upper,
          incLower: !other._incUpper, incUpper: _incUpper);
    }
  }

  /// Returns the intersection of two ranges.
  Range<T> operator *(Range<T> other) {
    if (_isEmpty || other._isEmpty) {
      return Range.empty();
    }
    final thisLower = this < other;
    final lower = thisLower ? this : other;
    final upper = thisLower ? other : this;
    if (lower._upper != null &&
        upper._lower != null &&
        (!lower._incUpper && !upper._incLower
            ? _lte(lower._upper, upper._lower)
            : _lt(lower._upper, upper._lower))) {
      return Range.empty();
    }
    if (lower._upper == null ||
        (upper._upper != null &&
            (lower._incUpper && !upper._incUpper
                ? _lte(upper._upper, lower._upper)
                : _lt(upper._upper, lower._upper)))) {
      return upper;
    }
    return Range(upper._lower, lower._upper,
        incLower: upper._incLower, incUpper: lower._incUpper);
  }

  /// If the range is discrete and no [step] is provided, returns an `Iterable`
  /// of all values in the range. Otherwise returns an `Iterable` of each
  /// value starting at the lower bound, increasing by [step] up to the
  /// upper bound.
  ///
  /// An error is thrown if the range is unbounded (ie. either `lower` or
  /// `upper` are `null`), or the [step] parameter is not given for
  /// non-discrete ranges.
  Iterable<T> unpack({Object? step}) sync* {
    if (_isEmpty) {
      return;
    }
    if (_lower == null || _upper == null) {
      throw StateError('cannot unpack an unbounded range');
    }
    if (step == null) {
      if (_lower is double || _lower is DateTime) {
        throw ArgumentError('step required for contiguous range');
      }
      step = 1 as dynamic;
    } else {
      if (_lower is int && step is! int) {
        throw ArgumentError("step type was expected to be 'int', "
            "provided step is of type '${step.runtimeType}'");
      } else if (_lower is num && step is! num) {
        throw ArgumentError("step type was expected to be 'num', "
            "provided step is of type '${step.runtimeType}'");
      } else if (_lower is DateTime && step is! Duration) {
        throw ArgumentError("step type was expected to be 'Duration', "
            "provided step is of type '${step.runtimeType}'");
      }
    }
    if (_lte(step, step is Duration ? Duration.zero : 0)) {
      throw ArgumentError('step cannot be less than or equal to 0');
    }
    var val = _incLower ? _lower : _add(_lower as dynamic, step);
    while (true) {
      yield val as T;
      val = _add(val as dynamic, step);
      if (_incUpper ? _gt(val, _upper) : _gte(val, _upper)) {
        return;
      }
    }
  }

  /// Checks whether [element] is within this range.
  bool contains(T element) {
    if (_isEmpty) {
      return false;
    }
    if (_lower != null &&
        (_incLower ? _lt(element, _lower) : _lte(element, _lower))) {
      return false;
    }
    if (_upper != null &&
        (_incUpper ? _gt(element, _upper) : _gte(element, _upper))) {
      return false;
    }
    return true;
  }

  /// Checks whether [range] is entirely within this range.
  bool containsRange(Range<T> range) {
    if (range._isEmpty) {
      return true;
    }
    if (_isEmpty) {
      return false;
    }
    if (_lower != null &&
        (range._lower == null ||
            (!_incLower && range._incLower
                ? _lte(range._lower, _lower)
                : _lt(range._lower, _lower)))) {
      return false;
    }
    if (_upper != null &&
        (range._upper == null ||
            (!_incUpper && range._incUpper
                ? _gte(range._upper, _upper)
                : _gt(range._upper, _upper)))) {
      return false;
    }
    return true;
  }

  /// Checks whether [other] range overlaps this range.
  bool overlaps(Range<T> other) {
    if (_isEmpty || other._isEmpty) {
      return false;
    }
    final thisLower = this < other;
    final lower = thisLower ? this : other;
    final upper = thisLower ? other : this;
    if (lower._upper != null &&
        upper._lower != null &&
        (!lower._incUpper || !upper._incLower
            ? _lte(lower._upper, upper._lower)
            : _lt(lower._upper, upper._lower))) {
      return false;
    }
    return true;
  }
}

class MultiRange<T> with SetBase<Range<T>> implements Set<Range<T>> {
  final SplayTreeSet<Range<T>> _ranges;

  MultiRange(Iterable<Range<T>> ranges) : _ranges = SplayTreeSet.from(ranges);

  @override
  int get length {
    return _ranges.length;
  }

  @override
  bool add(Range<T> value) {
    return _ranges.add(value);
  }

  @override
  bool contains(Object? element) {
    return _ranges.contains(element);
  }

  @override
  Iterator<Range<T>> get iterator => _ranges.iterator;

  @override
  Range<T>? lookup(Object? element) {
    return _ranges.lookup(element);
  }

  @override
  bool remove(Object? value) {
    return _ranges.remove(value);
  }

  @override
  Set<Range<T>> toSet() {
    return _ranges.toSet();
  }

  /// Returns whether two multiranges are equal.
  @override
  bool operator ==(Object other) {
    if (other is! MultiRange<T>) {
      return false;
    }

    return _ranges == other._ranges;
  }

  /// The hash code for this object.
  @override
  int get hashCode => Object.hashAll(_ranges);

  @override
  String toString() {
    return '[${_ranges.join(', ')}]';
  }

  toJSON() {
    return _ranges.map((range) => range.toJSON());
  }
}
