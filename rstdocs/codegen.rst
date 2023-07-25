
Codegen
=======

:edb-alt-title: EdgeQL Codegen Library

This library provides a `build_runner <https://pub.dev/packages/build_runner>`__
builder: `edgeqlCodegenBuilder <https://pub.dev/documentation/edgedb/latest/edgeql_codegen/edgeqlCodegenBuilder.html>`__, for generating fully typed query methods
from ``.edgeql`` files.

For each ``.edgeql`` file in your project, this builder generates a
corresponding ``.edgeql.dart`` file containing:


* An extension for the `Executor <https://pub.dev/documentation/edgedb/latest/edgedb/Executor-class.html>`__ class, which adds a method to run
  the query in the ``.edgeql`` file and return a fully typed result. This
  method is named from the filename of the ``.edgeql`` file.
  If query parameters are used, these will be reflected in the generated
  method, either as named arguments for named query parameters, or
  positional arguments for positional query parameters.

* Classes for each shape in the query return, where each field of the shape
  will be reflected to a instance variable of the same name, and of the
  correct type. (Note: When selecting link properties, the ``@`` prefix of
  the property name, will be replaced with a ``$`` prefix in the generated
  class, due to ``@`` not being valid in Dart variable names).
  Objects of these classes will be returned in the query result, instead of
  the ``Map<String, dynamic>`` type returned by the normal ``execute()`` and
  ``query*()`` methods.

* Similarly, classes will be generated for any tuple and named tuple types
  in the query. In the case of unnamed tuples, the instance variable names
  will be in the form ``$n``, where ``n`` is the tuple element index. All
  other types will be decoded the same as for the ``execute()`` and
  ``query*()`` methods. (See the :ref:`Client <edgedb-dart-Client>` docs for details)

Usage
-----

To use ``edgeql_codegen``, first add
`build_runner <https://pub.dev/packages/build_runner>`__ as a (dev) dependency
in your ``pubspec.yaml`` file:

.. code-block:: sh

    dart pub add build_runner -d
    
Then just run ``build_runner`` as documented in the
```build_runner`` docs <https://dart.dev/tools/build_runner>`__:

.. code-block:: sh

    dart run build_runner build
    # or
    dart run build_runner watch
    
Example
-------

.. code-block:: dart

    # getUserByName.edgeql
    
    select User {
      name,
      email,
      is_admin
    } filter .name = <str>$0
    
.. code-block:: dart

    import 'package:edgedb/edgedb.dart';
    import 'getUserByName.edgeql.dart';
    
    // ...
    
    final user = await client.getUserByName('exampleuser');
    
    print(user?.email); // `email` has `String` type
    
See the 'example' directory for more examples using ``edgeql_codegen``.
