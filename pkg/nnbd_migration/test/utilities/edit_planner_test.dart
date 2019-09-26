// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/testing/test_type_provider.dart';
import 'package:analyzer/src/test_utilities/find_node.dart';
import 'package:analyzer/src/test_utilities/resource_provider_mixin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:nnbd_migration/instrumentation.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:nnbd_migration/nullability_state.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/decorated_type.dart';
import 'package:nnbd_migration/src/edge_builder.dart';
import 'package:nnbd_migration/src/edge_origin.dart';
import 'package:nnbd_migration/src/expression_checks.dart';
import 'package:nnbd_migration/src/fix_builder.dart';
import 'package:nnbd_migration/src/nullability_node.dart';
import 'package:nnbd_migration/src/utilities/edit_planner.dart';
import 'package:nnbd_migration/src/utilities/scoped_set.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test/test.dart';
import 'package:test/test.dart';
import 'package:test/test.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(EditPlannerTest);
  });
}

@reflectiveTest
class EditPlannerTest {
  String content;

  FindNode findNode;

  final editPlanner = TestEditPlanner();

  CompilationUnit unit;

  void checkResult(String expected) {
    var edits = editPlanner.run(unit);
    expect(SourceEdit.applySequence(content, edits.reversed), expected);
  }

  void parse(String content) {
    this.content = content;
    var parseResult = parseString(content: content);
    findNode = FindNode(content, parseResult.unit);
    unit = parseResult.unit;
  }

  void test_accumulate_sub_plans() {
    parse('''
void f() {
  1;
  2;
  3;
}
''');
    var plan1 = _replaceStatement(
        findNode.integerLiteral('1').parent as Statement, '4;', true);
    var plan3 = _replaceStatement(
        findNode.integerLiteral('3').parent as Statement, '5', Precedence.primary);
    var plan = RecursivePlan()
    var plan = findNode.block('{').accept(editPlanner) as RecursivePlan;
    expect(plan.subPlans, hasLength(2));
    expect(plan.subPlans[0], same(plan1));
    expect(plan.subPlans[1], same(plan3));
  }

  void test_drop_statement_in_block() {
    parse('''
void f() {
  1;
  2;
  3;
}
''');
    _dropStatement(findNode.integerLiteral('2').parent as Statement);
    checkResult('''
void f() {
  1;
  
  3;
}
''');
  }

  void test_drop_statement_in_if() {
    parse('''
void f() {
  if (true) 1;
}
''');
    _dropStatement(findNode.integerLiteral('1').parent as Statement);
    checkResult('''
void f() {
  if (true) {}
}
''');
  }

  void test_replace_expression_higher_precedence() {
    parse('''
int x = 1 << 2 + 3;
''');
    _replaceExpression(findNode.integerLiteral('2').parent as Expression,
        '4 * 1', Precedence.multiplicative);
    checkResult('''
int x = 1 << 4 * 1;
''');
  }

  void test_replace_expression_lower_precedence() {
    parse('''
int x = 1 * 2 * 3;
''');
    _replaceExpression(findNode.integerLiteral('2').parent as Expression,
        '4 + 5', Precedence.additive);
    checkResult('''
int x = (4 + 5) * 3;
''');
  }

  void test_replace_expression_same_precedence() {
    parse('''
int x = 1 << 2 + 3;
''');
    _replaceExpression(findNode.integerLiteral('2').parent as Expression,
        '5 - 4', Precedence.additive);
    checkResult('''
int x = 1 << 5 - 4;
''');
  }

  void test_replace_statement_in_block() {
    parse('''
void f() {
  1;
  2;
  3;
}
''');
    _replaceStatement(
        findNode.integerLiteral('2').parent as Statement, 'if (true) 2;', true);
    checkResult('''
void f() {
  1;
  if (true) 2;
  3;
}
''');
  }

  void test_replace_statement_in_if() {
    parse('''
void f() {
  if (false) 1;
}
''');
    _replaceStatement(
        findNode.integerLiteral('1').parent as Statement, 'if (true) 2;', true);
    checkResult('''
void f() {
  if (false) if (true) 2;
}
''');
  }

  void test_replace_statements_in_block() {
    parse('''
void f() {
  1;
  2;
  3;
}
''');
    _replaceStatement(
        findNode.integerLiteral('2').parent as Statement, '4;\n  5;', false);
    checkResult('''
void f() {
  1;
  4;
  5;
  3;
}
''');
  }

  void test_replace_statements_in_if() {
    parse('''
void f() {
  if (false) 1;
}
''');
    _replaceStatement(
        findNode.integerLiteral('1').parent as Statement, '2; 3;', false);
    checkResult('''
void f() {
  if (false) {2; 3;}
}
''');
  }

  void _dropStatement(Statement statement) {
    editPlanner._plans[statement] =
        DropStatementPlan(statement.offset, statement.end);
  }

  ReplaceExpressionPlan _replaceExpression(
      Expression node, String replacement, Precedence multiplicative) {
    return editPlanner._plans[node] = ReplaceExpressionPlan(
        node.offset, node.end, replacement, multiplicative);
  }

  void _replaceStatement(
      Statement node, String replacement, bool isSingleStatement) {
    editPlanner._plans[node] = ReplaceStatementPlan(
        node.offset, node.end, replacement, isSingleStatement);
  }
}

class ReplaceExpressionPlan extends ReplacePlan with ExpressionPlan {
  @override
  final Precedence precedence;

  ReplaceExpressionPlan(
      int offset, int end, String replacement, this.precedence)
      : super(offset, end, replacement);
}

class ReplacePlan extends EditPlan {
  @override
  final int offset;

  @override
  final int end;

  @override
  final String replacement;

  ReplacePlan(this.offset, this.end, this.replacement);

  @override
  void execute(EditAccumulator accumulator) {
    accumulator.replace(offset, end, replacement);
  }
}

class ReplaceStatementPlan extends ReplacePlan with StatementsPlan {
  @override
  final bool isSingleStatement;

  ReplaceStatementPlan(
      int offset, int end, String replacement, this.isSingleStatement)
      : super(offset, end, replacement);
}

class TestEditPlanner extends EditPlanner {
  final Map<AstNode, EditPlan> _plans = {};

  @override
  ExpressionPlan visitExpression(Expression node) {
    return _plans[node] as ExpressionPlan ?? super.visitExpression(node);
  }

  @override
  StatementsPlan visitStatement(Statement node) {
    return _plans[node] as StatementsPlan ?? super.visitStatement(node);
  }
}
