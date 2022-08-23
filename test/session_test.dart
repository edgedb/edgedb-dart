import 'package:edgedb/src/errors/errors.dart';
import 'package:test/test.dart';

import 'testbase.dart';

void main() {
  test("with module", () async {
    final client = getClient(concurrency: 1);

    try {
      await expectLater(client.query('select get_version()'),
          throwsA(isA<InvalidReferenceError>()));

      expect(
          await client.withModuleAliases({'module': "sys"}).querySingle(
              'select get_version()'),
          isA<Map<String, dynamic>>());

      // make sure session state was reset
      await expectLater(client.query('select get_version()'),
          throwsA(isA<InvalidReferenceError>()));
    } finally {
      client.close();
    }
  });

  test("withGlobals", () async {
    final client = getClient(concurrency: 1);

    await client.execute('''
      create global userId -> uuid;
      create global currentTags -> array<str>;
      create required global reqTest -> str {
        set default := 'default value';
      };
      create global defaultTest -> str {
        set default := 'default value';
      };
      create module custom;
      create global custom::test -> str;
    ''');

    try {
      expect(await client.querySingle('''select {
          userId := global userId,
          currentTags := global currentTags,
        }'''), {'userId': null, 'currentTags': null});

      final clientWithUserId = client.withGlobals({
        'userId': "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      });

      expect(await clientWithUserId.querySingle('''select {
          userId := global userId,
          currentTags := global currentTags,
        }'''), {
        'userId': "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        'currentTags': null,
      });

      // make sure session state is reset
      expect(await client.querySingle('''select {
          userId := global userId,
          currentTags := global currentTags,
        }'''), {'userId': null, 'currentTags': null});

      // check session state gets merged
      expect(
          await clientWithUserId.withGlobals({
            'userId': "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            'currentTags': ["a", "b", "c"],
          }).querySingle('''select {
            userId := global userId,
            currentTags := global currentTags,
          }'''),
          {
            'userId': "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
            'currentTags': ["a", "b", "c"],
          });

      expect(
          await client
              .querySingle('select (global reqTest, global defaultTest)'),
          ["default value", "default value"]);
      expect(
          await client.withGlobals({
            'reqTest': "abc",
            'defaultTest': "def"
          }).querySingle('select (global reqTest, global defaultTest)'),
          ["abc", "def"]);
      expect(
          await client.withGlobals({
            'defaultTest': null,
          }).querySingle('select global defaultTest'),
          null);

      await expectLater(
          client.withGlobals({'unknownGlobal': 123}).query("select 1"),
          throwsA(isA<UnknownArgumentError>().having((e) => e.message,
              'message', contains('invalid global "default::unknownGlobal"'))));

      await expectLater(
          client.withGlobals({'test': "abc"}).querySingle(
              'select global custom::test'),
          throwsA(isA<UnknownArgumentError>().having((e) => e.message,
              'message', contains('invalid global "default::test"'))));

      expect(
          await client.withModuleAliases({'module': "custom"}).withGlobals(
              {'test': "abc"}).querySingle('select global custom::test'),
          'abc');
    } finally {
      await client.execute('''
        drop global userId;
        drop global currentTags;
        drop global custom::test;
      ''');

      client.close();
    }
  });

  test("withConfig", () async {
    final client = getClient(concurrency: 1);

    try {
      expect(
          await client.queryRequiredSingle(
              'select assert_single(cfg::Config.query_execution_timeout)'),
          Duration.zero);

      expect(
          await client.withConfig({
            'query_execution_timeout': Duration(seconds: 30),
          }).queryRequiredSingle(
              'select assert_single(cfg::Config.query_execution_timeout)'),
          Duration(seconds: 30));

      // make sure session state was reset
      expect(
          await client.queryRequiredSingle(
              'select assert_single(cfg::Config.query_execution_timeout)'),
          Duration.zero);
    } finally {
      client.close();
    }
  });

  test("reject session commands", () async {
    final client = getClient();

    await client.execute('''
      create global userId2 -> uuid;
    ''');

    try {
      await expectLater(client.execute('set module sys'),
          throwsA(isA<DisabledCapabilityError>()));

      await expectLater(client.execute('set alias foo as module sys'),
          throwsA(isA<DisabledCapabilityError>()));

      await expectLater(
          client.execute(
              'configure session set query_execution_timeout := <duration>"PT30S"'),
          throwsA(isA<DisabledCapabilityError>()));

      await expectLater(
          client.execute(
              'set global userId2 := <uuid>"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'),
          throwsA(isA<DisabledCapabilityError>()));
    } finally {
      await client.execute('drop global userId2');

      client.close();
    }
  });
}
