
Datatypes
=========

:edb-alt-title: Custom Datatypes


.. _edgedb-dart-Range:

*class* Range
-------------

Represents an interval between values.

The ``Range`` type behaves the same as the EdgeDB ``range`` type.
Ranges can have a lower and upper boundary, which can be inclusive or
exclusive, or omitted completely (``null``). By default, the lower boundary
is inclusive, and the upper boundary exclusive.

Depending on the type of the range, ``T``, the range is either discrete or
continuous.
Discrete range types: ``Range<int>``
Continuous range types: ``Range<double>``, ``Range<DateTime>``
Discrete ranges are normalised upon creation, such that the lower boundary
becomes inclusive, and the upper boundary becomes exclusive.

If a range can contain no values, it is considered 'empty'. Empty ranges
are all considered equal to each other. An empty range can be created
either by the ``Range.empty()`` constructor, creating a range where the lower
and upper boundaries are equal, and at least one boundary is exclusive, or
as the result of some operation on a range.

.. _edgedb-dart-Range-Range:

*constructor* ``Range<T>()``
............................


.. code-block:: dart

    Range<T>(
      T? lower, 
      T? upper, 
      {bool? incLower, 
      bool? incUpper}
    )

Creates a new :ref:`Range <edgedb-dart-Range>`.

If not given, ``incLower`` and ``incUpper`` default to ``true`` and ``false``
respectively.

.. _edgedb-dart-Range-Range.empty:

*constructor* ``Range<T>.empty()``
..................................


.. code-block:: dart

    Range<T>.empty()

Creates a new empty :ref:`Range <edgedb-dart-Range>` of type ``T``.

.. _edgedb-dart-Range-hashCode:

*property* ``.hashCode``
........................


.. code-block:: dart

    int get hashCode

The hash code for this object.

.. _edgedb-dart-Range-incLower:

*property* ``.incLower``
........................


.. code-block:: dart

    bool get incLower

Whether the lower boundary is inclusive. Is always ``false`` for unspecified
boundaries and empty ranges.

.. _edgedb-dart-Range-incUpper:

*property* ``.incUpper``
........................


.. code-block:: dart

    bool get incUpper

Whether the upper boundary is inclusive. Is always ``false`` for unspecified
boundaries and empty ranges.

.. _edgedb-dart-Range-isEmpty:

*property* ``.isEmpty``
.......................


.. code-block:: dart

    bool get isEmpty

Whether the range is empty.

.. _edgedb-dart-Range-lower:

*property* ``.lower``
.....................


.. code-block:: dart

    T? get lower

The lower boundary of the range, if it exists.

.. _edgedb-dart-Range-upper:

*property* ``.upper``
.....................


.. code-block:: dart

    T? get upper

The upper boundary of the range, if it exists.

.. _edgedb-dart-Range-compareTo:

*method* ``.compareTo()``
.........................


.. code-block:: dart

    int compareTo(
      Range<T> other
    )

Compares this object to another object.

Returns a value like a `Comparator <https://api.dart.dev/stable/3.0.6/dart-core/Comparator.html>`__ when comparing ``this`` to ``other``.
That is, it returns a negative integer if ``this`` is ordered before ``other``,
a positive integer if ``this`` is ordered after ``other``,
and zero if ``this`` and ``other`` are ordered together.

The ``other`` argument must be a value that is comparable to this object.

.. _edgedb-dart-Range-contains:

*method* ``.contains()``
........................


.. code-block:: dart

    bool contains(
      T element
    )

Checks whether ``element`` is within this range.

.. _edgedb-dart-Range-containsRange:

*method* ``.containsRange()``
.............................


.. code-block:: dart

    bool containsRange(
      Range<T> range
    )

Checks whether ``range`` is entirely within this range.

.. _edgedb-dart-Range-overlaps:

*method* ``.overlaps()``
........................


.. code-block:: dart

    bool overlaps(
      Range<T> other
    )

Checks whether ``other`` range overlaps this range.

.. _edgedb-dart-Range-toJSON:

*method* ``.toJSON()``
......................


.. code-block:: dart

    dynamic toJSON()


.. _edgedb-dart-Range-toString:

*method* ``.toString()``
........................


.. code-block:: dart

    String toString()

String representation of the range.

Inclusive boundaries are denoted by ``[]`` brackets, and exclusive
boundaries by ``()``. If the range is empty, returns the string ``'empty'``.

.. _edgedb-dart-Range-unpack:

*method* ``.unpack()``
......................


.. code-block:: dart

    Iterable<T> unpack(
      {Object? step}
    )

If the range is discrete and no ``step`` is provided, returns an ``Iterable``
of all values in the range. Otherwise returns an ``Iterable`` of each
value starting at the lower bound, increasing by ``step`` up to the
upper bound.

An error is thrown if the range is unbounded (ie. either ``lower`` or
``upper`` are ``null``), or the ``step`` parameter is not given for
non-discrete ranges.

.. _edgedb-dart-Range-operator_multiply:

*operator* ``\*``
.................


.. code-block:: dart

    Range<T> operator *(
      Range<T> other
    )

Returns the intersection of two ranges.

.. _edgedb-dart-Range-operator_plus:

*operator* ``+``
................


.. code-block:: dart

    Range<T> operator +(
      Range<T> other
    )

Returns the union of two ranges.

Throws an error if the result is not a single continuous range.

.. _edgedb-dart-Range-operator_minus:

*operator* ``-``
................


.. code-block:: dart

    Range<T> operator -(
      Range<T> other
    )

Subtracts one range from another.

Throws an error if the result is not a single continuous range.

.. _edgedb-dart-Range-operator_less:

*operator* ``<``
................


.. code-block:: dart

    bool operator <(
      Range<T> other
    )

Returns whether this range is before the ``other`` range.

A range is considered to be ordered before another range if its
lower bound is lower than the other. If the lower bounds are equal, the
upper bounds are checked. An empty range is considered lower than a
non-empty range, and unspecified lower/upper bounds are considered
lower/greater than specified lower/upper bounds respectively.

.. _edgedb-dart-Range-operator_less_equal:

*operator* ``<=``
.................


.. code-block:: dart

    bool operator <=(
      Range<T> other
    )

Returns whether this range is before or equal to the ``other`` range.

A range is considered to be ordered before another range if its
lower bound is lower than the other. If the lower bounds are equal, the
upper bounds are checked. An empty range is considered lower than a
non-empty range, and unspecified lower/upper bounds are considered
lower/greater than specified lower/upper bounds respectively.

.. _edgedb-dart-Range-operator_equals:

*operator* ``==``
.................


.. code-block:: dart

    bool operator ==(
      Object other
    )

Returns whether two ranges are equal.

.. _edgedb-dart-Range-operator_greater:

*operator* ``>``
................


.. code-block:: dart

    bool operator >(
      Range<T> other
    )

Returns whether this range is after the ``other`` range.

A range is considered to be ordered after another range if its
lower bound is greater than the other. If the lower bounds are equal, the
upper bounds are checked. An empty range is considered lower than a
non-empty range, and unspecified lower/upper bounds are considered
lower/greater than specified lower/upper bounds respectively.

.. _edgedb-dart-Range-operator_greater_equal:

*operator* ``>=``
.................


.. code-block:: dart

    bool operator >=(
      Range<T> other
    )

Returns whether this range is after or equal to the ``other`` range.

A range is considered to be ordered after another range if its
lower bound is greater than the other. If the lower bounds are equal, the
upper bounds are checked. An empty range is considered lower than a
non-empty range, and unspecified lower/upper bounds are considered
lower/greater than specified lower/upper bounds respectively.

.. _edgedb-dart-ConfigMemory:

*class* ConfigMemory
--------------------

Represents an amount of memory in bytes.

Uses the base-2 ``KiB`` notation (1024 bytes), instead of the more
ambiguous 'kB', which can mean 1000 or 1024 bytes.

.. _edgedb-dart-ConfigMemory-ConfigMemory:

*constructor* ``ConfigMemory()``
................................


.. code-block:: dart

    ConfigMemory(
      int _bytes
    )


.. _edgedb-dart-ConfigMemory-ConfigMemory.parse:

*constructor* ``ConfigMemory.parse()``
......................................


.. code-block:: dart

    ConfigMemory.parse(
      String mem
    )


.. _edgedb-dart-ConfigMemory-bytes:

*property* ``.bytes``
.....................


.. code-block:: dart

    int get bytes


.. _edgedb-dart-ConfigMemory-gibibytes:

*property* ``.gibibytes``
.........................


.. code-block:: dart

    num get gibibytes


.. _edgedb-dart-ConfigMemory-kibibytes:

*property* ``.kibibytes``
.........................


.. code-block:: dart

    num get kibibytes


.. _edgedb-dart-ConfigMemory-mebibytes:

*property* ``.mebibytes``
.........................


.. code-block:: dart

    num get mebibytes


.. _edgedb-dart-ConfigMemory-pebibytes:

*property* ``.pebibytes``
.........................


.. code-block:: dart

    num get pebibytes


.. _edgedb-dart-ConfigMemory-tebibytes:

*property* ``.tebibytes``
.........................


.. code-block:: dart

    num get tebibytes


.. _edgedb-dart-ConfigMemory-toString:

*method* ``.toString()``
........................


.. code-block:: dart

    String toString()

A string representation of this object.

Some classes have a default textual representation,
often paired with a static ``parse`` function (like `int.parse <https://api.dart.dev/stable/3.0.6/dart-core/int/parse.html>`__).
These classes will provide the textual representation as
their string representation.

Other classes have no meaningful textual representation
that a program will care about.
Such classes will typically override ``toString`` to provide
useful information when inspecting the object,
mainly for debugging or logging.
