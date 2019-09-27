// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/type_system.dart';
import 'package:nnbd_migration/src/fix_builder.dart';
import 'package:nnbd_migration/src/variables.dart';
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
  @override
  Future<CompilationUnit> analyze(String code) async {
    var unit = await super.analyze(code);
    graph.propagate();
    return unit;
  }

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

  test_nullLiteral() async {
    await analyze('''
f() => null;
''');
    visit(findNode.nullLiteral('null'), 'Null');
  }

  test_simpleIdentifier_localVariable_nonNullable() async {
    await analyze('''
f() {
  int x = 1;
  return x;
}
''');
    visit(findNode.simple('x;'), 'int');
  }

  test_simpleIdentifier_localVariable_nullable() async {
    await analyze('''
f() {
  int x = null;
  return x;
}
''');
    visit(findNode.simple('x;'), 'int?');
  }

  test_simpleIdentifier_localVariable_nullable_checked() async {
    await analyze('''
int/*!*/ f() {
  int x = null;
  return x;
}
''');
    var xRef = findNode.simple('x;');
    visit(xRef, 'int', nullChecked: {xRef});
  }

  test_stringLiteral() async {
    await analyze('''
f() => 'foo';
''');
    visit(findNode.stringLiteral("'foo'"), 'String');
  }

  test_symbolLiteral() async {
    await analyze('''
f() => #foo;
''');
    visit(findNode.symbolLiteral('#foo'), 'Symbol');
  }

  DartType visit(AstNode node, String expectedType,
      {Set<Expression> nullChecked = const <Expression>{}}) {
    var fixBuilder = _FixBuilder(typeProvider, typeSystem, variables);
    var type = node.accept(fixBuilder);
    expect((type as TypeImpl).toString(withNullability: true), expectedType);
    expect(fixBuilder.nullCheckedExpressions, nullChecked);
    return type;
  }
}

class _FixBuilder extends FixBuilder {
  final Set<Expression> nullCheckedExpressions = {};

  _FixBuilder(
      TypeProvider typeProvider, TypeSystem typeSystem, Variables variables)
      : super(typeProvider, typeSystem, variables);

  @override
  void addNullCheck(Expression subexpression) {
    var newlyAdded = nullCheckedExpressions.add(subexpression);
    expect(newlyAdded, true);
  }
}
