enum Cardinality {
  noResult(0x6e),
  atMostOne(0x6f),
  one(0x41),
  many(0x6d),
  atLeastOne(0x4d);

  final int value;
  const Cardinality(this.value);
}

final cardinalitiesByValue = {
  for (var card in Cardinality.values) card.value: card
};

enum OutputFormat {
  binary(0x62),
  json(0x6a),
  none(0x6e);

  final int value;
  const OutputFormat(this.value);
}

class ProtocolVersion {
  final int hi;
  final int lo;

  const ProtocolVersion(this.hi, this.lo);

  bool operator >(ProtocolVersion other) {
    if (hi == other.hi) {
      return lo > other.lo;
    }
    return hi > other.hi;
  }

  bool operator >=(ProtocolVersion other) {
    if (hi == other.hi) {
      return lo >= other.lo;
    }
    return hi > other.hi;
  }
}
