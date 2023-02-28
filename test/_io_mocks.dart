import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

class FileMock implements File {
  final String _path;
  final String? _content;

  FileMock(this._path, this._content);

  @override
  File get absolute => throw UnimplementedError();

  @override
  Future<File> copy(String newPath) {
    throw UnimplementedError();
  }

  @override
  File copySync(String newPath) {
    throw UnimplementedError();
  }

  @override
  Future<File> create({bool exclusive = false, bool recursive = false}) {
    throw UnimplementedError();
  }

  @override
  void createSync({bool exclusive = false, bool recursive = false}) {}

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) {
    throw UnimplementedError();
  }

  @override
  void deleteSync({bool recursive = false}) {}

  @override
  Future<bool> exists() async {
    return _content != null;
  }

  @override
  bool existsSync() {
    throw UnimplementedError();
  }

  @override
  bool get isAbsolute => throw UnimplementedError();

  @override
  Future<DateTime> lastAccessed() {
    throw UnimplementedError();
  }

  @override
  DateTime lastAccessedSync() {
    throw UnimplementedError();
  }

  @override
  Future<DateTime> lastModified() {
    throw UnimplementedError();
  }

  @override
  DateTime lastModifiedSync() {
    throw UnimplementedError();
  }

  @override
  Future<int> length() {
    throw UnimplementedError();
  }

  @override
  int lengthSync() {
    throw UnimplementedError();
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    throw UnimplementedError();
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) {
    throw UnimplementedError();
  }

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    throw UnimplementedError();
  }

  @override
  Directory get parent => throw UnimplementedError();

  @override
  String get path => throw UnimplementedError();

  @override
  Future<Uint8List> readAsBytes() {
    throw UnimplementedError();
  }

  @override
  Uint8List readAsBytesSync() {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) {
    throw UnimplementedError();
  }

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    throw UnimplementedError();
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async {
    if (_content != null) {
      return _content!;
    }
    throw FileSystemException('Cannot open file', _path);
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    throw UnimplementedError();
  }

  @override
  Future<File> rename(String newPath) {
    throw UnimplementedError();
  }

  @override
  File renameSync(String newPath) {
    throw UnimplementedError();
  }

  @override
  Future<String> resolveSymbolicLinks() {
    throw UnimplementedError();
  }

  @override
  String resolveSymbolicLinksSync() {
    throw UnimplementedError();
  }

  @override
  Future setLastAccessed(DateTime time) {
    throw UnimplementedError();
  }

  @override
  void setLastAccessedSync(DateTime time) {}

  @override
  Future setLastModified(DateTime time) {
    throw UnimplementedError();
  }

  @override
  void setLastModifiedSync(DateTime time) {}

  @override
  Future<FileStat> stat() {
    throw UnimplementedError();
  }

  @override
  FileStat statSync() {
    throw UnimplementedError();
  }

  @override
  Uri get uri => throw UnimplementedError();

  @override
  Stream<FileSystemEvent> watch(
      {int events = FileSystemEvent.all, bool recursive = false}) {
    throw UnimplementedError();
  }

  @override
  Future<File> writeAsBytes(List<int> bytes,
      {FileMode mode = FileMode.write, bool flush = false}) {
    throw UnimplementedError();
  }

  @override
  void writeAsBytesSync(List<int> bytes,
      {FileMode mode = FileMode.write, bool flush = false}) {}

  @override
  Future<File> writeAsString(String contents,
      {FileMode mode = FileMode.write,
      Encoding encoding = utf8,
      bool flush = false}) {
    throw UnimplementedError();
  }

  @override
  void writeAsStringSync(String contents,
      {FileMode mode = FileMode.write,
      Encoding encoding = utf8,
      bool flush = false}) {}
}

class DirectoryMock implements Directory {
  final String _path;

  DirectoryMock(this._path);

  @override
  Directory get absolute => throw UnimplementedError();

  @override
  Future<Directory> create({bool recursive = false}) {
    throw UnimplementedError();
  }

  @override
  void createSync({bool recursive = false}) {}

  @override
  Future<Directory> createTemp([String? prefix]) {
    throw UnimplementedError();
  }

  @override
  Directory createTempSync([String? prefix]) {
    throw UnimplementedError();
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) {
    throw UnimplementedError();
  }

  @override
  void deleteSync({bool recursive = false}) {}

  @override
  Future<bool> exists() {
    throw UnimplementedError();
  }

  @override
  bool existsSync() {
    throw UnimplementedError();
  }

  @override
  bool get isAbsolute => p.isAbsolute(_path);

  @override
  Stream<FileSystemEntity> list(
      {bool recursive = false, bool followLinks = true}) {
    throw UnimplementedError();
  }

  @override
  List<FileSystemEntity> listSync(
      {bool recursive = false, bool followLinks = true}) {
    throw UnimplementedError();
  }

  @override
  Directory get parent {
    final parts = p.split(_path);
    return Directory(
        parts.length == 1 ? parts[0] : p.joinAll(parts..removeLast()));
  }

  @override
  String get path => _path;

  @override
  Future<Directory> rename(String newPath) {
    throw UnimplementedError();
  }

  @override
  Directory renameSync(String newPath) {
    throw UnimplementedError();
  }

  @override
  Future<String> resolveSymbolicLinks() async {
    return _path;
  }

  @override
  String resolveSymbolicLinksSync() {
    throw UnimplementedError();
  }

  @override
  Future<FileStat> stat() {
    throw UnimplementedError();
  }

  @override
  FileStat statSync() {
    throw UnimplementedError();
  }

  @override
  Uri get uri => throw UnimplementedError();

  @override
  Stream<FileSystemEvent> watch(
      {int events = FileSystemEvent.all, bool recursive = false}) {
    throw UnimplementedError();
  }
}
