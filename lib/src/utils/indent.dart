String indent(String str) {
  final parts = str.split('\n');
  return [parts[0], ...parts.skip(1).map((line) => '  $line')].join('\n');
}
