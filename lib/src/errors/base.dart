import 'tags.dart';

class EdgeDBError extends Error {
  final String message;
  EdgeDBError(this.message);

  final tags = <EdgeDBErrorTag>{};

  bool hasTag(EdgeDBErrorTag tag) {
    return tags.contains(tag);
  }

  @override
  String toString() {
    return '$runtimeType: $message';
  }
}
