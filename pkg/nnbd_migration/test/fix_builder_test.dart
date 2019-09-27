// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:nnbd_migration/src/fix_builder.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'migration_visitor_test_base.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FixBuilderTest);
  });
}

@reflectiveTest
class FixBuilderTest extends EdgeBuilderTestBase {
  test_booleanLiteral() async {
    await analyze('''
f() => true;
''');
    visit(findNode.booleanLiteral('true'), 'bool');
  }

  test_doubleLiteral() async {
    await analyze('''
f() => 1.0;
''');
    visit(findNode.doubleLiteral('1.0'), 'double');
  }

  test_integerLiteral() async {
    await analyze('''
f() => 1;
''');
    visit(findNode.integerLiteral('1'), 'int');
  }

  test_stringLiteral() async {
    await analyze('''
f() => 'foo';
''');
    visit(findNode.stringLiteral('foo'), 'String');
  }

  DartType visit(AstNode node, String expectedType) {
    var type = node.accept(FixBuilder());
    expect((type as TypeImpl).toString(withNullability: true), expectedType);
    return type;
  }
}
