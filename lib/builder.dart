import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:edgedb/src/codecs/codecs.dart';
import 'package:edgedb/src/codecs/object.dart';
import 'package:edgedb/src/codecs/registry.dart';
import 'package:edgedb/src/codecs/set.dart';
import 'package:edgedb/src/connect_config.dart';
import 'package:edgedb/src/errors/errors.dart';
import 'package:edgedb/src/options.dart';
import 'package:edgedb/src/primitives/types.dart';
import 'package:edgedb/src/retry_connect.dart';
import 'package:edgedb/src/tcp_proto.dart';
import 'package:path/path.dart';

Builder edgeDBBuilder(BuilderOptions options) =>
    EdgeDBBuilder(options.config['debug'] as bool? ?? false);

class EdgeDBBuilder implements Builder {
  final bool debug;

  EdgeDBBuilder(this.debug);

  @override
  final buildExtensions = const {
    '.edgeql': ['.edgeql.dart', '.edgeql.debug']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;

    final conn = await buildStep.fetchResource(connectionResource);

    final query = await buildStep.readAsString(inputId);

    final parseResult = await conn.parse(
        query: query,
        outputFormat: OutputFormat.binary,
        expectedCardinality: Cardinality.many,
        state: Session.defaults(),
        privilegedMode: false);

    if (debug) {
      await buildStep.writeAsString(
          inputId.addExtension('.debug'), parseResult.toString());
    }

    final fileName = basenameWithoutExtension(buildStep.inputId.path);
    final typeName = fileName[0].toUpperCase() + fileName.substring(1);

    final file = LibraryBuilder();

    final returnType = walkCodec(
        parseResult.outCodec, parseResult.cardinality, typeName, file);

    file.body.add(declareConst('_query').assign(queryString(query)).statement);

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
          .assign(walkCodec(inCodec, Cardinality.one).codecExpr)
          .statement);
    }

    file.body.add(Extension((builder) => builder
      ..name = '${typeName}Extension'
      ..on = Reference('Client', 'package:edgedb/src/client.dart')
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
                    Reference('_outCodec'),
                    inCodec != null
                        ? Reference('_inCodec')
                        : Reference('nullCodec',
                            'package:edgedb/src/codecs/codecs.dart'),
                    Reference('Cardinality',
                            'package:edgedb/src/primitives/types.dart')
                        .property(parseResult.cardinality.name),
                    Reference('_query'),
                    literalMap({
                      for (var field in inCodec?.fields ?? [])
                        literalString(field.name): Reference(field.name)
                    }, Reference('String'), Reference('dynamic'))
                  ], {}, [
                    returnType.typeRef
                  ])
                  .awaited
                  .returned
                  .statement;
      }))));

    await buildStep.writeAsString(
        inputId.addExtension('.dart'),
        DartFormatter().format(file
            .build()
            .accept(DartEmitter.scoped(useNullSafetySyntax: true))
            .toString()));
  }
}

Expression queryString(String value) {
  final escaped = value.replaceAll("'''", "\\'''").replaceAll('\$', '\\\$');
  return CodeExpression(Code("'''$escaped'''"));
}

class WalkCodecReturn {
  final Reference typeRef;
  final Expression codecExpr;

  WalkCodecReturn(this.typeRef, this.codecExpr);
}

WalkCodecReturn walkCodec(Codec codec, Cardinality card,
    [String? typeName, LibraryBuilder? file]) {
  if (codec is ScalarCodec) {
    return WalkCodecReturn(
        TypeReference((ref) => ref
          ..symbol = codec.returnType
          ..isNullable = card == Cardinality.atMostOne),
        Reference('scalarCodecs', 'package:edgedb/src/codecs/codecs.dart')
            .index(literalString(codec.tid))
            .nullChecked);
  }
  if (codec is ObjectCodec) {
    final typeClass = file != null ? (ClassBuilder()..name = typeName) : null;
    final typeConstructor = ConstructorBuilder()
      ..name = '_fromMap'
      ..requiredParameters.add(Parameter((builder) => builder
        ..name = 'map'
        ..type = Reference('Map<String, dynamic>')));
    final codecs = <Expression>[];
    final names = <Expression>[];
    final cards = <Expression>[];
    for (var field in codec.fields) {
      final child = walkCodec(
          field.codec, field.cardinality, '${typeName}_${field.name}', file);
      final typeField = FieldBuilder()
        ..name = field.name
        ..modifier = FieldModifier.final$
        ..type = child.typeRef;
      typeClass?.fields.add(typeField.build());
      typeConstructor.initializers.add(Reference(field.name)
          .assign(Reference('map').index(literalString(field.name)))
          .code);
      codecs.add(child.codecExpr);
      names.add(literalString(field.name));
      cards.add(literalNum(field.cardinality.value));
    }
    typeClass?.constructors.add(typeConstructor.build());
    if (file != null) {}
    file?.body.add(typeClass!.build());
    return WalkCodecReturn(
        Reference(typeName),
        Reference('ObjectCodec', 'package:edgedb/src/codecs/object.dart')
            .newInstance([
          literalString(codec.tid),
          literalList(codecs),
          literalList(names),
          literalList(cards),
        ], {
          if (typeName != null)
            'returnType': Reference(typeName).property('_fromMap')
        }));
  }
  if (codec is SetCodec) {
    final child = walkCodec(codec.subCodec, Cardinality.one, typeName, file);
    return WalkCodecReturn(
        TypeReference((builder) => builder
          ..symbol = 'List'
          ..types.add(child.typeRef)),
        Reference('SetCodec', 'package:edgedb/src/codecs/set.dart').newInstance(
            [literalString(codec.tid), child.codecExpr], {}, [child.typeRef]));
  }
  throw EdgeDBError('cannot generate type for codec ${codec.runtimeType}');
}

final connectionResource = Resource(() async {
  final config = await parseConnectConfig(
      ConnectConfig(host: 'localhost', database: '_example'));
  return retryingConnect(TCPProtocol.create, config, CodecsRegistry());
});
