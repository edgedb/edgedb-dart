enum EdgeDBErrorTag {
  shouldReconnect,
  shouldRetry;
}

class EdgeDBError extends Error {
  final String message;
  final Object? source;
  Map<ErrorAttr, String>? _attrs;
  String? _query;

  EdgeDBError(this.message, [this.source]);

  final tags = <EdgeDBErrorTag>{};

  bool hasTag(EdgeDBErrorTag tag) {
    return tags.contains(tag);
  }

  @override
  String toString() {
    final msg = '$runtimeType: $message';
    if (_query != null && _attrs != null) {
      return prettyPrintError(msg, _attrs!, _query!);
    }
    return msg;
  }
}

void setErrorAttrs(EdgeDBError error, Map<ErrorAttr, String> attrs) {
  error._attrs = attrs;
}

Map<ErrorAttr, String>? getErrorAttrs(EdgeDBError error) {
  return error._attrs;
}

void setErrorQuery(EdgeDBError error, String query) {
  error._query = query;
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

String prettyPrintError(
    String msg, Map<ErrorAttr, String> attrs, String query) {
  final lineStart = attrs[ErrorAttr.lineStart] != null
      ? int.tryParse(attrs[ErrorAttr.lineStart]!)
      : null;
  final lineEnd = attrs[ErrorAttr.lineEnd] != null
      ? int.tryParse(attrs[ErrorAttr.lineEnd]!)
      : null;
  final colStart = attrs[ErrorAttr.utf16ColumnStart] != null
      ? int.tryParse(attrs[ErrorAttr.utf16ColumnStart]!)
      : null;
  final colEnd = attrs[ErrorAttr.utf16ColumnEnd] != null
      ? int.tryParse(attrs[ErrorAttr.utf16ColumnEnd]!)
      : null;

  if (lineStart == null ||
      lineEnd == null ||
      colStart == null ||
      colEnd == null) {
    return msg;
  }

  final queryLines = query.split('\n');

  final lineNoWidth = lineEnd.toString().length;
  final errMessage = StringBuffer()
    ..writeln(msg)
    ..writeln('|'.padLeft(lineNoWidth + 3));

  for (var i = lineStart; i < lineEnd + 1; i++) {
    final line = queryLines[i - 1];
    final start = i == lineStart ? colStart : 0;
    final end = i == lineEnd ? colEnd : line.length;
    errMessage.writeln(' ${i.toString().padLeft(lineNoWidth)} | $line');
    errMessage.writeln(
        '${'|'.padLeft(lineNoWidth + 3)} ${''.padLeft(end - start, '^').padLeft(end)}');
  }
  if (attrs[ErrorAttr.hint] != null) {
    errMessage.writeln('Hint: ${attrs[ErrorAttr.hint]}');
  }

  return errMessage.toString();
}
