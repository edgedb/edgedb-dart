/// This library provides a [build_runner](https://pub.dev/packages/build_runner)
/// builder: [edgeqlCodegenBuilder], for generating fully typed query methods
/// from `.edgeql` files.
///
/// For each `.edgeql` file in your project, this builder generates a
/// corresponding `.edgeql.dart` file containing:
/// - An extension for the [Executor] class, which adds a method to run
///   the query in the `.edgeql` file and return a fully typed result. This
///   method is named from the filename of the `.edgeql` file.
///   If query parameters are used, these will be reflected in the generated
///   method, either as named arguments for named query parameters, or
///   positional arguments for positional query parameters.
/// - Classes for each shape in the query return, where each field of the shape
///   will be reflected to a instance variable of the same name, and of the
///   correct type. (Note: When selecting link properties, the `@` prefix of
///   the property name, will be replaced with a `$` prefix in the generated
///   class, due to `@` not being valid in Dart variable names).
///   Objects of these classes will be returned in the query result, instead of
///   the `Map<String, dynamic>` type returned by the normal `execute()` and
///   `query*()` methods.
/// - Similarly, classes will be generated for any tuple and named tuple types
///   in the query. In the case of unnamed tuples, the instance variable names
///   will be in the form `$n`, where `n` is the tuple element index. All
///   other types will be decoded the same as for the `execute()` and
///   `query*()` methods. (See the [Client] docs for details)
///
/// ## Usage
///
/// To use `edgeql_codegen`, first add
/// [build_runner](https://pub.dev/packages/build_runner) as a (dev) dependency
/// in your `pubspec.yaml` file:
///
/// ```sh
/// dart pub add build_runner -d
/// ```
///
/// Then just run `build_runner` as documented in the
/// [`build_runner` docs](https://dart.dev/tools/build_runner):
///
/// ```sh
/// dart run build_runner build
/// # or
/// dart run build_runner watch
/// ```
///
/// ## Example
///
/// ```
/// # getUserByName.edgeql
///
/// select User {
///   name,
///   email,
///   is_admin
/// } filter .name = <str>$0
/// ```
///
/// ```dart
/// import 'package:edgedb/edgedb.dart';
/// import 'getUserByName.edgeql.dart';
///
/// // ...
///
/// final user = await client.getUserByName('exampleuser');
///
/// print(user?.email); // `email` has `String` type
/// ```
///
/// See the 'example' directory for more examples using `edgeql_codegen`.

import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:edgedb/src/base_proto.dart';
import 'package:edgedb/src/client.dart';
import 'package:edgedb/src/codecs/codecs.dart';
import 'package:edgedb/src/connect_config.dart';
import 'package:edgedb/src/errors/base.dart';
import 'package:edgedb/src/options.dart';
import 'package:edgedb/src/primitives/types.dart';
import 'package:edgedb/src/tcp_proto.dart';
import 'package:edgedb/src/utils/pretty_print_error.dart';
import 'package:path/path.dart';

Builder edgeqlCodegenBuilder(BuilderOptions options) =>
    EdgeqlCodegenBuilder(options.config['debug'] as bool? ?? false);

class EdgeqlCodegenBuilder implements Builder {
  final bool debug;

  EdgeqlCodegenBuilder(this.debug);

  @override
  final buildExtensions = const {
    '.edgeql': ['.edgeql.dart', '.edgeql.debug']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;

    final connPool = await buildStep.fetchResource(_connPoolResource);

    final query = await buildStep.readAsString(inputId);

    ParseResult parseResult;

    final holder = await connPool.acquireHolder(Options.defaults());
    try {
      parseResult = await (await holder.getConnection()).parse(
          query: query,
          outputFormat: OutputFormat.binary,
          expectedCardinality: Cardinality.many,
          state: Session.defaults(),
          privilegedMode: false);
    } on EdgeDBError catch (err) {
      throw prettyPrintError(err, query);
    } finally {
      await holder.release();
    }

    if (debug) {
      await buildStep.writeAsString(
          inputId.addExtension('.debug'), parseResult.toString());
    }

    final fileName = basenameWithoutExtension(buildStep.inputId.path);
    final typeName = fileName[0].toUpperCase() + fileName.substring(1);

    final file = LibraryBuilder();

    final returnType = _walkCodec(
        parseResult.outCodec, parseResult.cardinality, typeName, file);

    file.body.add(declareConst('_query').assign(_queryString(query)).statement);

    file.body
        .add(declareFinal('_outCodec').assign(returnType.codecExpr).statement);

    if (parseResult.inCodec is! ObjectCodec &&
        parseResult.inCodec is! NullCodec) {
      throw EdgeDBError(
          'expected inCodec to be ObjectCodec or NullCodec, got ${parseResult.inCodec.runtimeType}');
    }
    final ObjectCodec? inCodec = parseResult.inCodec is ObjectCodec
        ? parseResult.inCodec as ObjectCodec
        : null;

    final namedArgs = inCodec != null && inCodec.fields[0].name != '0';

    if (inCodec != null) {
      file.body.add(declareFinal('_inCodec')
          .assign(_walkCodec(inCodec, Cardinality.one).codecExpr)
          .statement);
    }

    file.body.add(Extension((builder) => builder
      ..name = '${typeName}Extension'
      ..on = Reference('Executor', 'package:edgedb/src/client.dart')
      ..methods.add(Method((builder) {
        builder
          ..name = fileName
          ..returns = TypeReference((ref) => ref
            ..symbol = 'Future'
            ..types.add(parseResult.cardinality == Cardinality.many
                ? TypeReference((ref) => ref
                  ..symbol = 'List'
                  ..types.add(returnType.typeRef))
                : TypeReference((ref) => ref
                  ..symbol = returnType.typeRef.symbol
                  ..isNullable =
                      parseResult.cardinality == Cardinality.atMostOne)));
        if (inCodec != null) {
          final params = inCodec.fields.map((field) => Parameter((builder) =>
              builder
                ..name = field.name
                ..type = Reference((field.codec as ScalarCodec).returnType)
                ..named = namedArgs
                ..required =
                    namedArgs && field.cardinality == Cardinality.one));
          namedArgs
              ? builder.optionalParameters.addAll(params)
              : builder.requiredParameters.addAll(params);
        }
        builder
          ..modifier = MethodModifier.async
          ..body =
              Reference('executeWithCodec', 'package:edgedb/src/client.dart')
                  .call([
                    Reference('this'),
                    literalString(fileName),
                    Reference('_outCodec'),
                    inCodec != null
                        ? Reference('_inCodec')
                        : Reference('nullCodec',
                            'package:edgedb/src/codecs/codecs.dart'),
                    Reference('Cardinality',
                            'package:edgedb/src/primitives/types.dart')
                        .property(parseResult.cardinality.name),
                    Reference('_query'),
                    inCodec != null
                        ? literalMap({
                            for (var field in inCodec.fields)
                              literalString(field.name): Reference(field.name)
                          }, Reference('String'), Reference('dynamic'))
                        : literalNull
                  ], {}, [
                    returnType.typeRef
                  ])
                  .awaited
                  .returned
                  .statement;
      }))));

    final generatedCode = DartFormatter().format(file
        .build()
        .accept(DartEmitter.scoped(useNullSafetySyntax: true))
        .toString());

    await buildStep.writeAsString(
        inputId.addExtension('.dart'),
        '// AUTOGENERATED by \'edgeql_codegen\' builder\n'
        '// To re-generate use `dart run build_runner`\n\n'
        '$generatedCode');
  }
}

Expression _queryString(String value) {
  final escaped = value.replaceAll("'''", "\\'''").replaceAll('\$', '\\\$');
  return CodeExpression(Code("'''$escaped'''"));
}

class _WalkCodecReturn {
  final Reference typeRef;
  final Expression codecExpr;

  _WalkCodecReturn(this.typeRef, this.codecExpr);
}

_WalkCodecReturn _walkCodec(Codec codec, Cardinality card,
    [String? typeName, LibraryBuilder? file]) {
  if (codec is ScalarCodec) {
    return _WalkCodecReturn(
        TypeReference((ref) => ref
          ..symbol = codec.returnType
          ..isNullable = card == Cardinality.atMostOne
          ..url = codec.returnTypeImport),
        codec is EnumCodec
            ? Reference('EnumCodec', 'package:edgedb/src/codecs/codecs.dart')
                .newInstance([literalString(codec.tid)])
            : Reference('scalarCodecs', 'package:edgedb/src/codecs/codecs.dart')
                .index(literalString(codec.tid))
                .nullChecked);
  }
  if (codec is ObjectCodec || codec is NamedTupleCodec) {
    final typeClass = file != null ? (ClassBuilder()..name = typeName) : null;
    final typeConstructor = ConstructorBuilder()
      ..name = '_fromMap'
      ..requiredParameters.add(Parameter((builder) => builder
        ..name = 'map'
        ..type = Reference('Map<String, dynamic>')));
    final codecs = <Expression>[];
    final names = <Expression>[];
    final cards = <Expression>[];

    void visitField(String name, Codec subcodec, Cardinality cardinality) {
      final validName = name.replaceFirst(RegExp('^@'), '\$');
      final child =
          _walkCodec(subcodec, cardinality, '${typeName}_$validName', file);
      final typeField = FieldBuilder()
        ..name = validName
        ..modifier = FieldModifier.final$
        ..type = child.typeRef;
      typeClass?.fields.add(typeField.build());
      typeConstructor.initializers.add(Reference(validName)
          .assign(Reference('map').index(literalString(name)))
          .code);
      codecs.add(child.codecExpr);
      names.add(literalString(name));
      cards.add(literalNum(cardinality.value));
    }

    if (codec is ObjectCodec) {
      for (var field in codec.fields) {
        visitField(field.name, field.codec, field.cardinality);
      }
    } else {
      for (var field in (codec as NamedTupleCodec).fields) {
        visitField(field.name, field.codec, Cardinality.one);
      }
    }

    typeClass?.constructors.add(typeConstructor.build());
    file?.body.add(typeClass!.build());
    return _WalkCodecReturn(
        Reference(typeName),
        Reference(codec is ObjectCodec ? 'ObjectCodec' : 'NamedTupleCodec',
                'package:edgedb/src/codecs/codecs.dart')
            .newInstance([
          literalString(codec.tid),
          literalList(codecs),
          literalList(names),
          if (codec is ObjectCodec) literalList(cards),
        ], {
          if (typeName != null)
            'returnType': Reference(typeName).property('_fromMap')
        }));
  }
  if (codec is SetCodec || codec is ArrayCodec || codec is RangeCodec) {
    final child = _walkCodec(
        (codec is SetCodec)
            ? codec.subCodec
            : (codec is ArrayCodec)
                ? codec.subCodec
                : (codec as RangeCodec).subCodec,
        Cardinality.one,
        typeName,
        file);
    return _WalkCodecReturn(
        TypeReference((builder) => builder
          ..symbol = (codec is RangeCodec)
              ? Reference('Range', 'package:edgedb/edgedb.dart').symbol
              : 'List'
          ..types.add(child.typeRef)),
        Reference(
                codec is SetCodec
                    ? 'SetCodec'
                    : codec is ArrayCodec
                        ? 'ArrayCodec'
                        : 'RangeCodec',
                'package:edgedb/src/codecs/codecs.dart')
            .newInstance([
          literalString(codec.tid),
          child.codecExpr,
          if (codec is ArrayCodec) literalNum(codec.length)
        ], {}, [
          child.typeRef
        ]));
  }
  if (codec is TupleCodec) {
    final typeClass = ClassBuilder()..name = typeName;
    final typeConstructor = ConstructorBuilder()
      ..name = '_fromList'
      ..requiredParameters.add(Parameter((builder) => builder
        ..name = 'list'
        ..type = Reference('List<dynamic>')));
    final codecs = <Expression>[];
    var i = 0;
    for (var subCodec in codec.subCodecs) {
      final name = '\$$i';
      final child =
          _walkCodec(subCodec, Cardinality.one, '${typeName}_$i', file);
      final typeField = FieldBuilder()
        ..name = name
        ..modifier = FieldModifier.final$
        ..type = child.typeRef;
      typeClass.fields.add(typeField.build());
      typeConstructor.initializers.add(Reference(name)
          .assign(Reference('list').index(literalNum(i++)))
          .code);
      codecs.add(child.codecExpr);
    }
    typeClass.constructors.add(typeConstructor.build());
    file!.body.add(typeClass.build());
    return _WalkCodecReturn(
        Reference(typeName),
        Reference('TupleCodec', 'package:edgedb/src/codecs/codecs.dart')
            .newInstance([
          literalString(codec.tid),
          literalList(codecs),
        ], {
          'returnType': Reference(typeName).property('_fromList')
        }));
  }
  throw EdgeDBError('cannot generate type for codec ${codec.runtimeType}');
}

ClientPool? _connPool;
final _connPoolResource = Resource(() async {
  return _connPool ??= ClientPool(TCPProtocol.create, ConnectConfig(),
      concurrency: 5, exposeErrorAttrs: true);
}, beforeExit: () => _connPool?.close());
