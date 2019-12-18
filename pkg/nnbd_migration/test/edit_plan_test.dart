// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:nnbd_migration/src/edit_plan.dart';
import 'package:nnbd_migration/src/fix_planner.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_single_unit.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SimpleEditPlanTest);
  });
}

class EditPlanTestBase extends AbstractSingleUnitTest {}

@reflectiveTest
class SimpleEditPlanTest extends EditPlanTestBase {
  test_addInnerChanges() async {
    await resolveTestUnit('''
void f(a) => a;
''');
    var expr = findNode.simple('a;');
    var plan = SimpleEditPlan.withPrecedence(expr, Precedence.additive);
    expect(plan.getChanges(false), null);
    plan.addInnerChanges({
      expr.end: [const AddBang()]
    });
    expect(plan.getChanges(false), {
      expr.end: [const AddBang()]
    });
    plan.addInnerChanges({
      expr.offset: [const AddOpenParen()],
      expr.end: [const AddCloseParen()]
    });
    expect(plan.getChanges(false), {
      expr.offset: [const AddOpenParen()],
      expr.end: [const AddBang(), const AddCloseParen()]
    });
  }

  test_forExpression() async {
    await resolveTestUnit('''
void f(a, b) => a + b;
''');
    var plan = SimpleEditPlan.forExpression(findNode.binary('a + b'));
    expect(plan.isPassThrough, true);
    expect(
        plan.parensNeeded(
            threshold: Precedence.additive,
            associative: true,
            allowCascade: true),
        false);
    expect(
        plan.parensNeeded(
            threshold: Precedence.multiplicative,
            associative: true,
            allowCascade: true),
        true);
    expect(
        plan.parensNeeded(
            threshold: Precedence.shift, associative: true, allowCascade: true),
        false);
    expect(
        plan.parensNeeded(
            threshold: Precedence.additive,
            associative: false,
            allowCascade: true),
        true);
    expect(
        plan.parensNeeded(
            threshold: Precedence.multiplicative,
            associative: false,
            allowCascade: true),
        true);
    expect(
        plan.parensNeeded(
            threshold: Precedence.shift, associative: true, allowCascade: true),
        false);
  }

  test_forNonExpression() async {
    await resolveTestUnit('''
class C {}
''');
    var plan =
        SimpleEditPlan.forNonExpression(findNode.classDeclaration('class C'));
    expect(plan.isPassThrough, true);
    expect(
        plan.parensNeeded(
            threshold: Precedence.postfix,
            associative: false,
            allowCascade: false),
        false);
  }

  test_isEmpty() async {
    await resolveTestUnit('''
void f(a) => a;
''');
    var expr = findNode.simple('a;');
    var plan = SimpleEditPlan.withPrecedence(expr, Precedence.additive);
    expect(plan.isEmpty, true);
    plan.addInnerChanges({
      expr.end: [const AddBang()]
    });
    expect(plan.isEmpty, false);
  }

  test_parensNeeded_allowCascade() async {
    await resolveTestUnit('''
void f(a) => a..b;
''');
    var plan = SimpleEditPlan.forExpression(findNode.cascade('a..b'))
      ..endsInCascade = true;
    expect(
        plan.parensNeeded(
            threshold: Precedence.assignment,
            associative: true,
            allowCascade: true),
        false);
    expect(
        plan.parensNeeded(
            threshold: Precedence.assignment,
            associative: true,
            allowCascade: false),
        true);
  }

  test_withPrecedence() async {
    await resolveTestUnit('''
void f(a) => a;
''');
    var plan = SimpleEditPlan.withPrecedence(
        findNode.simple('a;'), Precedence.additive);
    expect(plan.isPassThrough, false);
    expect(
        plan.parensNeeded(
            threshold: Precedence.additive,
            associative: true,
            allowCascade: true),
        false);
    expect(
        plan.parensNeeded(
            threshold: Precedence.multiplicative,
            associative: true,
            allowCascade: true),
        true);
    expect(
        plan.parensNeeded(
            threshold: Precedence.shift, associative: true, allowCascade: true),
        false);
    expect(
        plan.parensNeeded(
            threshold: Precedence.additive,
            associative: false,
            allowCascade: true),
        true);
    expect(
        plan.parensNeeded(
            threshold: Precedence.multiplicative,
            associative: false,
            allowCascade: true),
        true);
    expect(
        plan.parensNeeded(
            threshold: Precedence.shift, associative: true, allowCascade: true),
        false);
  }
}
