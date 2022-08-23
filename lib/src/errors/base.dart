enum EdgeDBErrorTag {
  shouldReconnect,
  shouldRetry;
}

class EdgeDBError extends Error {
  final String message;
  final Object? source;
  Map<ErrorAttr, String>? _attrs;

  EdgeDBError(this.message, [this.source]);

  final tags = <EdgeDBErrorTag>{};

  bool hasTag(EdgeDBErrorTag tag) {
    return tags.contains(tag);
  }

  @override
  String toString() {
    return '$runtimeType: $message';
  }
}

void setErrorAttrs(EdgeDBError error, Map<ErrorAttr, String> attrs) {
  error._attrs = attrs;
}

Map<ErrorAttr, String>? getErrorAttrs(EdgeDBError error) {
  return error._attrs;
}

enum ErrorAttr {
  hint(0x0001),
  details(0x0002),
  serverTraceback(0x0101),
  positionStart(0xfff1),
  positionEnd(0xfff2),
  lineStart(0xfff3),
  columnStart(0xfff4),
  utf16ColumnStart(0xfff5),
  lineEnd(0xfff6),
  columnEnd(0xfff7),
  utf16ColumnEnd(0xfff8),
  characterStart(0xfff9),
  characterEnd(0xfffa),
  unknown(-1);

  final int code;
  const ErrorAttr(this.code);
}

final errorAttrsByCode = {for (var attr in ErrorAttr.values) attr.code: attr};
