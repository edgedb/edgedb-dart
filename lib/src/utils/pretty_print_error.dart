import '../errors/base.dart';

String prettyPrintError(EdgeDBError err, String query) {
  final attrs = getErrorAttrs(err);

  if (attrs == null) {
    return err.toString();
  }

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
    return err.toString();
  }

  final queryLines = query.split('\n');

  final lineNoWidth = lineEnd.toString().length;
  final errMessage = StringBuffer()
    ..writeln(err.toString())
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
