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
}
