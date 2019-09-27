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

  test_binaryExpression_ampersand_ampersand() async {
    await analyze('''
f() {
  var x = true;
  var y = true;
  return x && y;
}
''');
    visitSubexpression(findNode.binary('&&'), 'bool');
  }

  test_binaryExpression_ampersand_ampersand_flow() async {
    await analyze('''
f() {
  bool x = null;
  return x != null && x;
}
''');
    visitSubexpression(findNode.binary('&&'), 'bool');
  }

  test_binaryExpression_ampersand_ampersand_nullChecked() async {
    await analyze('''
f() {
  var x = null;
  var y = null;
  return x && y;
}
''');
    var xRef = findNode.simple('x &&');
    var yRef = findNode.simple('y;');
    visitSubexpression(findNode.binary('&&'), 'bool',
        nullChecked: {xRef, yRef});
  }

  test_binaryExpression_bang_eq() async {
    await analyze('''
f() {
  var x = null;
  var y = null;
  return x != y;
}
''');
    visitSubexpression(findNode.binary('!='), 'bool');
  }

  test_binaryExpression_bar_bar() async {
    await analyze('''
f() {
  var x = true;
  var y = true;
  return x || y;
}
''');
    visitSubexpression(findNode.binary('||'), 'bool');
  }

  test_binaryExpression_bar_bar_flow() async {
    await analyze('''
f() {
  bool x = null;
  return x == null || x;
}
''');
    visitSubexpression(findNode.binary('||'), 'bool');
  }

  test_binaryExpression_bar_bar_nullChecked() async {
    await analyze('''
f() {
  var x = null;
  var y = null;
  return x || y;
}
''');
    var xRef = findNode.simple('x ||');
    var yRef = findNode.simple('y;');
    visitSubexpression(findNode.binary('||'), 'bool',
        nullChecked: {xRef, yRef});
  }

  test_binaryExpression_eq_eq() async {
    await analyze('''
f() {
  var x = null;
  var y = null;
  return x == y;
}
''');
    visitSubexpression(findNode.binary('=='), 'bool');
  }

  test_binaryExpression_question_question() async {
    await analyze('''
f() {
  int x = null;
  double y = null;
  return x ?? y;
}
''');
    visitSubexpression(findNode.binary('??'), 'num?');
  }

  test_binaryExpression_question_question_nullChecked() async {
    await analyze('''
f() {
  int x = null;
  double y = null;
  return x ?? y;
}
''');
    var yRef = findNode.simple('y;');
    // TODO(paulberry): the type should be `num` (not `num?`).  This should
    // start working once `??` support is added to flow analysis.
    visitSubexpression(findNode.binary('??'), 'num?',
        nullableContext: false, nullChecked: {yRef});
  }

  test_booleanLiteral() async {
    await analyze('''
f() => true;
''');
    visitSubexpression(findNode.booleanLiteral('true'), 'bool');
  }

  test_doubleLiteral() async {
    await analyze('''
f() => 1.0;
''');
    visitSubexpression(findNode.doubleLiteral('1.0'), 'double');
  }

  test_integerLiteral() async {
    await analyze('''
f() => 1;
''');
    visitSubexpression(findNode.integerLiteral('1'), 'int');
  }

  test_nullLiteral() async {
    await analyze('''
f() => null;
''');
    visitSubexpression(findNode.nullLiteral('null'), 'Null');
  }

  test_simpleIdentifier_localVariable_nonNullable() async {
    await analyze('''
f() {
  int x = 1;
  return x;
}
''');
    visitSubexpression(findNode.simple('x;'), 'int');
  }

  test_simpleIdentifier_localVariable_nullable() async {
    await analyze('''
f() {
  int x = null;
  return x;
}
''');
    visitSubexpression(findNode.simple('x;'), 'int?');
  }

  test_stringLiteral() async {
    await analyze('''
f() => 'foo';
''');
    visitSubexpression(findNode.stringLiteral("'foo'"), 'String');
  }

  test_symbolLiteral() async {
    await analyze('''
f() => #foo;
''');
    visitSubexpression(findNode.symbolLiteral('#foo'), 'Symbol');
  }

  DartType visitSubexpression(Expression node, String expectedType,
      {bool nullableContext = true,
      Set<Expression> nullChecked = const <Expression>{}}) {
    var fixBuilder = _FixBuilder(typeProvider, typeSystem, variables);
    fixBuilder.createFlowAnalysis(node.thisOrAncestorOfType<FunctionBody>());
    var type = fixBuilder.visitSubexpression(node, nullableContext);
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
