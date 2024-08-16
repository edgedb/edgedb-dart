import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html;
import 'package:args/args.dart';

const outDir = 'rstdocs';

class PageRef {
  final String page;
  final String type;
  final String name;

  const PageRef({required this.page, required this.type, required this.name});
}

const hrefToRefMapping = {
  '/docs/quickstart': 'ref_quickstart',
  '/docs/edgeql/parameters#parameter-types-and-json': 'ref_eql_params_types',
  '/docs/reference/connection': 'ref_reference_connection',
  '/docs/stdlib/cfg#client-connections': 'ref_std_cfg_client_connections',
  '/docs/reference/edgeql/tx_start#parameters': 'ref_eql_statements_start_tx'
};

const pageRefs = [
  PageRef(page: "api", type: "function", name: "createClient"),
  PageRef(page: "api", type: "class", name: "Client"),
  PageRef(page: "api", type: "class", name: "Options"),
  PageRef(page: "api", type: "class", name: "Session"),
  PageRef(page: "api", type: "class", name: "RetryOptions"),
  PageRef(page: "api", type: "class", name: "TransactionOptions"),
  PageRef(page: "datatypes", type: "class", name: "Range"),
  PageRef(page: "datatypes", type: "class", name: "MultiRange"),
  PageRef(page: "datatypes", type: "class", name: "ConfigMemory"),
];

final argsParser = ArgParser()..addFlag('lintMode', negatable: false);

void main(List<String> args) async {
  final parsedArgs = argsParser.parse(args);
  final lintMode = parsedArgs['lintMode'] as bool;

  final genPath = "doc/api";

  print('Generating docs...');
  final genRes = await Process.run('dart', ['doc', '--output=$genPath']);
  print(genRes.stderr + genRes.stdout);

  final docs = await generateFileMapping(genPath);

  await Directory(outDir).create();

  await Future.wait([
    processIndexPage(genPath, outDir, lintMode),
    processClientPage(genPath, outDir, lintMode),
    processAPIPage(outDir, docs['api']!, lintMode),
    processDatatypesPage(outDir, docs['datatypes']!, lintMode),
    processCodegenPage(genPath, outDir, lintMode),
  ]);

  // ignore: prefer_interpolation_to_compose_strings
  print('Done! ' +
      (lintMode
          ? 'Docs in $outDir match generated docs'
          : 'Docs generated into $outDir'));
}

final fileRefMapping = <String, String>{};

class RefChildData {
  final String name;
  final Future<html.Document> doc;
  final String sourcePath;

  RefChildData(
      {required this.name, required this.doc, required this.sourcePath});
}

class RefData {
  final String name;
  final String type;
  final Future<html.Document> doc;
  final String sourcePath;
  final List<RefChildData> children;

  RefData(
      {required this.name,
      required this.type,
      required this.doc,
      required this.sourcePath,
      required this.children});
}

Future<html.Document> parseHtmlFile(String path) async {
  final file = await File(path).readAsString();

  return html_parser.parse(file);
}

Future<Map<String, List<RefData>>> generateFileMapping(String basePath) async {
  final docs = {
    'api': <RefData>[],
    'datatypes': <RefData>[],
  };

  for (var pageRef in pageRefs) {
    final pagePath =
        'edgedb/${pageRef.name}${pageRef.type == "class" ? "-class" : ""}.html';
    fileRefMapping[pagePath] = 'edgedb-dart-${pageRef.name}';

    final item = RefData(
        name: pageRef.name,
        type: pageRef.type,
        doc: parseHtmlFile(p.join(basePath, pagePath)),
        sourcePath: pagePath,
        children: []);
    docs[pageRef.page]!.add(item);

    if (item.type == "class") {
      await for (var entry
          in Directory(p.join(basePath, "edgedb", item.name)).list()) {
        final docPath = p.join("edgedb", item.name, p.basename(entry.path));
        fileRefMapping[docPath] =
            'edgedb-dart-${item.name}-${p.basenameWithoutExtension(docPath)}';

        item.children.add(RefChildData(
          name: p.basenameWithoutExtension(entry.path),
          doc: parseHtmlFile(p.join(basePath, docPath)),
          sourcePath: docPath,
        ));
      }
    }
  }

  return docs;
}

Future<void> writeOrValidateFile(
    String path, String content, bool lintMode) async {
  final file = File(path);

  if (lintMode) {
    if (await file.readAsString() != content) {
      throw Exception('Content of "$path" does not match generated docs, '
          'Run "dart run tool/gen_docs.dart" to update docs');
    }
  } else {
    await file.writeAsString(content);
  }
}

Future<void> processIndexPage(
    String basePath, String outDir, bool lintMode) async {
  final doc = await parseHtmlFile(p.join(basePath, "index.html"));

  final page =
      nodeToRst(doc.querySelector("#dartdoc-main-content section.desc")!)
          .split("Contributing\n------------")[0];

  final pageParts = page.split(RegExp(r'(?<=={3,})\n'));
  final heading = pageParts[0];
  final content = pageParts[1];

  final indexPage = '''.. edb:tag:: dart
  .. _edgedb-dart-intro:

$heading

.. toctree::
  :maxdepth: 3
  :hidden:

  client
  api
  datatypes
  codegen

$content''';

  await writeOrValidateFile(p.join(outDir, 'index.rst'), indexPage, lintMode);
}

Future<void> processClientPage(
    String basePath, String outDir, bool lintMode) async {
  final doc =
      await parseHtmlFile(p.join(basePath, "edgedb/edgedb-library.html"));

  final page = '''

Client
======

:edb-alt-title: Client Library

${nodeToRst(doc.querySelector("#dartdoc-main-content section.desc")!)}''';

  await writeOrValidateFile(p.join(outDir, "client.rst"), page, lintMode);
}

const classFields = ['constructor', 'property', 'method', 'operator'];

class ClassFieldItem {
  final String name;
  final String kind;
  final String fragment;

  ClassFieldItem(
      {required this.name, required this.kind, required this.fragment});
}

Future<String> renderRefItems(List<RefData> items) async {
  var page = "";

  for (var item in items) {
    final doc = await item.doc;
    switch (item.type) {
      case "function":
        {
          page += '''

.. _${fileRefMapping[item.sourcePath]}:

*function* ${item.name}()
-----------${"".padLeft(item.name.length, '-')}--

.. code-block:: dart

    ${indent(sigToString(doc.querySelector("#dartdoc-main-content section.multi-line-signature")!), 4)}

${nodeToRst(doc.querySelector("#dartdoc-main-content section.desc")!)}''';
          break;
        }
      case "class":
        {
          final content =
              doc.querySelector("#dartdoc-main-content section.desc");

          page += '''

.. _${fileRefMapping[item.sourcePath]}:

*class* ${item.name}
--------${"".padLeft(item.name.length, '-')}\n\n''';
          if (content != null) {
            page += '${nodeToRst(content)}\n';
          }

          final childItems = <ClassFieldItem>[];
          for (var childItem in item.children) {
            final childDoc = await childItem.doc;
            final childContent =
                childDoc.querySelector("#dartdoc-main-content section.desc");

            var fragment = '';

            final nameNode =
                childDoc.querySelector("#dartdoc-main-content h1 > span")!;
            var name = nodeListToRst(nameNode.nodes);
            var kind = nameNode.className.replaceFirst(RegExp(r'^kind-'), "");

            if (kind == "method" && name.startsWith("operator")) {
              kind = "operator";
              name = name
                  .replaceFirst(RegExp(r'^operator'), "")
                  .replaceFirst(RegExp(r'method$'), "")
                  .trim();
            }

            final heading =
                '*$kind* ``${kind == "method" || kind == "property" ? "." : ""}${name.replaceAll(RegExp(r'\\\*|(\*)'), "\\*")}${kind == "method" || kind == "constructor" ? "()" : ""}``';
            fragment +=
                '.. _${fileRefMapping[childItem.sourcePath]}:\n\n$heading\n${"".padLeft(heading.length, '.')}\n';
            if (kind == "method" ||
                kind == "constructor" ||
                kind == "operator") {
              fragment += '''


.. code-block:: dart

    ${indent(sigToString(childDoc.querySelector("#dartdoc-main-content section.multi-line-signature")!), 4)}

''';
            }
            if (kind == "property") {
              final code = nodeListToRst(childDoc
                      .querySelector(
                          "#dartdoc-main-content section.source-code pre code")!
                      .nodes)
                  .split(RegExp(r'{\n|='))[0]
                  .replaceFirst("@override", "")
                  .trim();
              fragment += '''


.. code-block:: dart

    $code

''';
            }
            if (childContent != null) {
              fragment += nodeToRst(childContent);
            }

            childItems.add(
                ClassFieldItem(name: name, kind: kind, fragment: fragment));
          }

          page += (childItems
                ..sort((a, b) {
                  if (a.kind == b.kind) {
                    return a.name.compareTo(b.name);
                  }
                  return classFields.indexOf(a.kind) -
                      classFields.indexOf(b.kind);
                }))
              .map((item) => item.fragment)
              .join('\n');

          break;
        }
    }
  }

  return page;
}

Future<void> processAPIPage(
    String outDir, List<RefData> items, bool lintMode) async {
  var page = '''

API
===

:edb-alt-title: Client API Reference

''';

  page += await renderRefItems(items);

  await writeOrValidateFile(p.join(outDir, "api.rst"), page, lintMode);
}

Future<void> processDatatypesPage(
    String outDir, List<RefData> items, bool lintMode) async {
  var page = '''

Datatypes
=========

:edb-alt-title: Custom Datatypes

''';

  page += await renderRefItems(items);

  await writeOrValidateFile(p.join(outDir, "datatypes.rst"), page, lintMode);
}

Future<void> processCodegenPage(
    String basePath, String outDir, bool lintMode) async {
  final doc = await parseHtmlFile(
      p.join(basePath, "edgeql_codegen/edgeql_codegen-library.html"));

  final page = '''

Codegen
=======

:edb-alt-title: EdgeQL Codegen Library

${nodeToRst(doc.querySelector("#dartdoc-main-content section.desc")!)}''';

  await writeOrValidateFile(p.join(outDir, "codegen.rst"), page, lintMode);
}

const headingUnderlines = {'h1': '=', 'h2': '-', 'h3': '.'};

String nodeListToRst(List<html.Node> nodes) {
  return nodes.map((child) => nodeToRst(child)).join("");
}

String nodeToRst(html.Node node, {bool skipEmptyText = false}) {
  if (node is html.Text) {
    return skipEmptyText ? node.text.trim() : node.text;
  }
  if (node is html.Element) {
    switch (node.localName) {
      case "div":
      case "section":
        return node.nodes
            .map((child) => nodeToRst(child, skipEmptyText: true))
            .where((frag) => frag.isNotEmpty)
            .join("\n");
      case "h1":
      case "h2":
      case "h3":
        final heading = nodeListToRst(node.nodes).trim();
        return '$heading\n${''.padLeft(heading.length, headingUnderlines[node.localName]!)}\n';
      case "p":
        return '${nodeListToRst(node.nodes)}\n';
      case "a":
        var href = node.attributes['href']!;
        final label = nodeListToRst(node.nodes)
            .replaceAllMapped(RegExp(r'\<|\>'), (m) => "\\${m[0]}");

        final parsedUrl = Uri.tryParse(href);
        if (parsedUrl != null && parsedUrl.host.isNotEmpty) {
          if (RegExp(r'^(www\.)?edgedb\.com').hasMatch(parsedUrl.host)) {
            href = parsedUrl.path +
                (parsedUrl.hasFragment ? '#${parsedUrl.fragment}' : '');
            if (hrefToRefMapping.containsKey(href)) {
              return ':ref:`$label <${hrefToRefMapping[href]}>`';
            }
          }
        } else {
          // href is relative
          final path = href.replaceAll(RegExp(r'\.\.\/'), "");
          final ref = fileRefMapping[path];
          if (ref != null) {
            return ':ref:`$label <$ref>`';
          } else {
            href = 'https://pub.dev/documentation/edgedb/latest/$path';
          }
        }
        return '`$label <$href>`__';
      case "code":
        return '``${nodeListToRst(node.nodes)}``';
      case "em":
        return '*${nodeListToRst(node.nodes)}*';
      case "span":
        return nodeListToRst(node.nodes);
      case "pre":
        final code = nodeListToRst((node.nodes[0]).nodes);
        return '.. code-block:: ${node.className.replaceFirst(RegExp(r'^language-'), "")}\n\n    ${indent(code, 4)}';
      case "blockquote":
        final quote = nodeListToRst(node.nodes);
        if (RegExp(r'^\s*note: ', caseSensitive: false).hasMatch(quote)) {
          return '.. note::\n    ${indent(quote.replaceFirstMapped(RegExp(r'^(\s*)note: ', caseSensitive: false), (m) => m[1]!), 4)}';
        }
        return '.. pull-quote::\n    ${indent(quote, 4)}';
      case "ul":
        final list = node.children.map((child) {
          if (child.localName != "li") {
            throw Exception('expected only "li" tags in "ul"');
          }
          return '* ${indent(nodeListToRst(child.nodes).split("\n").map((line) => line.trimLeft()).join("\n"), 2)}';
        });
        return '\n${list.join("\n\n")}\n';
      case "table":
        final rows = node.children
            .map((child) => child.children)
            .expand((element) => element);

        return '.. list-table::\n  :header-rows: 1\n\n${rows.map((row) {
          if (row.localName != "tr") {
            throw Exception('expected "tr" tag');
          }
          return '  * ${row.children.map((child) => '- ${nodeListToRst(child.nodes)}').join("\n    ")}';
        }).join("\n")}\n';
      default:
        break;
    }
  }
  return "";
}

String sigToString(html.Node node) {
  final code = _sigToString(node, true)
      .trim()
      .replaceAll(RegExp(r'^@override|override$'), "")
      .trim();

  return code.contains("\n") ? code.replaceFirst(RegExp(r'\)$'), "\n)") : code;
}

String _sigToString(html.Node node, bool linebreakParams) {
  if (node is html.Text) {
    return node.text.replaceFirst('\n', "");
  }
  if (node is html.Element) {
    return ((linebreakParams && node.className == "parameter" ? "\n  " : "") +
        node.nodes
            .map((child) => _sigToString(
                child, linebreakParams && node.className != "parameter"))
            .join("") +
        (node.className == "returntype" ? " " : ""));
  }
  return "";
}

String indent(String text, int indent) {
  return text.split("\n").join('\n'.padRight(indent + 1, ' '));
}
