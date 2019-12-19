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
    defineReflectiveTests(ExtractEditPlanWithoutParensTest);
    defineReflectiveTests(ExtractEditPlanWithParensTest);
    defineReflectiveTests(ProvisionalParenEditPlanTest);
    defineReflectiveTests(SimpleEditPlanTest);
  });
}

class EditPlanTestBase extends AbstractSingleUnitTest {
  void checkParensNeeded_additive(EditPlan plan) {
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

  void checkParensNeeded_cascaded(EditPlan plan) {
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
}

@reflectiveTest
class ExtractEditPlanWithoutParensTest extends EditPlanTestBase {
  Expression expr;
  Expression outerExpr;

  Future<SimpleEditPlan> makeInnerPlan(
      [Precedence precedence = Precedence.additive]) async {
    await resolveTestUnit('''
void f(a, b, c, d) => a = b + c << d;
''');
    expr = findNode.binary('b + c');
    outerExpr = findNode.assignment('a = b + c << d');
    return SimpleEditPlan.withPrecedence(expr, precedence);
  }

  EditPlan makeOuterPlan(EditPlan innerPlan) {
    return EditPlan.extract(outerExpr, innerPlan);
  }

  test_endsInCascade_false() async {
    expect(makeOuterPlan(await makeInnerPlan()).endsInCascade, false);
  }

  test_endsInCascade_true() async {
    expect(
        makeOuterPlan(await makeInnerPlan()
              ..endsInCascade = true)
            .endsInCascade,
        true);
  }

  test_getChanges_extractLeft() async {
    await resolveTestUnit('''
void f(a, b, c) => a + b << c;
''');
    expr = findNode.binary('+');
    outerExpr = findNode.binary('<<');
    var innerPlan = PassThroughEditPlan(expr);
    expect(makeOuterPlan(innerPlan).getChanges(false), {
      expr.end: [RemoveText(outerExpr.end - expr.end)]
    });
  }

  test_getChanges_extractRight() async {
    await resolveTestUnit('''
void f(a, b, c) => a << b + c;
''');
    expr = findNode.binary('+');
    outerExpr = findNode.binary('<<');
    var innerPlan = PassThroughEditPlan(expr);
    expect(makeOuterPlan(innerPlan).getChanges(false), {
      outerExpr.offset: [RemoveText(expr.offset - outerExpr.offset)]
    });
  }

  test_getChanges_innerChanges() async {
    expect(
        makeOuterPlan(await makeInnerPlan()
              ..addInnerChanges({
                expr.end: [const AddBang()]
              }))
            .getChanges(false),
        {
          outerExpr.offset: [RemoveText(expr.offset - outerExpr.offset)],
          expr.end: [const AddBang(), RemoveText(outerExpr.end - expr.end)]
        });
  }

  test_getChanges_innerChanges_add_parens() async {
    expect(
        makeOuterPlan(await makeInnerPlan()
              ..addInnerChanges({
                expr.end: [const AddBang()]
              }))
            .getChanges(true),
        {
          outerExpr.offset: [
            const AddOpenParen(),
            RemoveText(expr.offset - outerExpr.offset)
          ],
          expr.end: [const AddBang(), RemoveText(outerExpr.end - expr.end)],
          outerExpr.end: [const AddCloseParen()]
        });
  }

  test_getChanges_no_innerChanges() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(false), {
      outerExpr.offset: [RemoveText(expr.offset - outerExpr.offset)],
      expr.end: [RemoveText(outerExpr.end - expr.end)]
    });
  }

  test_getChanges_no_innerChanges_add_parens() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(true), {
      outerExpr.offset: [
        const AddOpenParen(),
        RemoveText(expr.offset - outerExpr.offset)
      ],
      expr.end: [RemoveText(outerExpr.end - expr.end)],
      outerExpr.end: [const AddCloseParen()]
    });
  }

  test_parensNeeded() async {
    checkParensNeeded_additive(makeOuterPlan(await makeInnerPlan()));
  }

  test_parensNeeded_allowCascade() async {
    checkParensNeeded_cascaded(
        makeOuterPlan(await makeInnerPlan(Precedence.cascade)
          ..endsInCascade = true));
  }
}

@reflectiveTest
class ExtractEditPlanWithParensTest extends EditPlanTestBase {
  Expression expr;
  ParenthesizedExpression parens;
  Expression outerExpr;

  Future<SimpleEditPlan> makeInnerPlan(
      [Precedence precedence = Precedence.additive]) async {
    await resolveTestUnit('''
void f(a, b, c, d) => a = (b + c) * d;
''');
    expr = findNode.binary('b + c');
    parens = findNode.parenthesized('(b + c)');
    outerExpr = findNode.assignment('a = (b + c) * d');
    return SimpleEditPlan.withPrecedence(expr, precedence);
  }

  EditPlan makeOuterPlan(EditPlan innerPlan) {
    return EditPlan.extract(
        outerExpr, ProvisionalParenEditPlan(parens, innerPlan));
  }

  test_endsInCascade_false() async {
    expect(makeOuterPlan(await makeInnerPlan()).endsInCascade, false);
  }

  test_endsInCascade_true() async {
    expect(
        makeOuterPlan(await makeInnerPlan()
              ..endsInCascade = true)
            .endsInCascade,
        true);
  }

  test_getChanges_extractLeft() async {
    await resolveTestUnit('''
void f(a, b, c) => (a + b) * c;
''');
    expr = findNode.binary('+');
    parens = findNode.parenthesized('+');
    outerExpr = findNode.binary('*');
    var innerPlan = PassThroughEditPlan(expr);
    expect(makeOuterPlan(innerPlan).getChanges(true), {
      parens.end: [RemoveText(outerExpr.end - parens.end)]
    });
  }

  test_getChanges_extractRight() async {
    await resolveTestUnit('''
void f(a, b, c) => a * (b + c);
''');
    expr = findNode.binary('+');
    parens = findNode.parenthesized('+');
    outerExpr = findNode.binary('*');
    var innerPlan = PassThroughEditPlan(expr);
    expect(makeOuterPlan(innerPlan).getChanges(true), {
      outerExpr.offset: [RemoveText(parens.offset - outerExpr.offset)]
    });
  }

  test_getChanges_innerChanges() async {
    expect(
        makeOuterPlan(await makeInnerPlan()
              ..addInnerChanges({
                expr.end: [const AddBang()]
              }))
            .getChanges(true),
        {
          outerExpr.offset: [RemoveText(parens.offset - outerExpr.offset)],
          expr.end: [const AddBang()],
          parens.end: [RemoveText(outerExpr.end - parens.end)]
        });
  }

  test_getChanges_innerChanges_strip_parens() async {
    expect(
        makeOuterPlan(await makeInnerPlan()
              ..addInnerChanges({
                expr.end: [const AddBang()]
              }))
            .getChanges(false),
        {
          outerExpr.offset: [RemoveText(parens.offset - outerExpr.offset)],
          parens.offset: [RemoveText(1)],
          expr.end: [const AddBang(), RemoveText(1)],
          parens.end: [RemoveText(outerExpr.end - parens.end)]
        });
  }

  test_getChanges_no_innerChanges() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(true), {
      outerExpr.offset: [RemoveText(parens.offset - outerExpr.offset)],
      parens.end: [RemoveText(outerExpr.end - parens.end)]
    });
  }

  test_getChanges_no_innerChanges_strip_parens() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(false), {
      outerExpr.offset: [RemoveText(parens.offset - outerExpr.offset)],
      parens.offset: [RemoveText(1)],
      expr.end: [RemoveText(1)],
      parens.end: [RemoveText(outerExpr.end - parens.end)]
    });
  }

  test_parensNeeded() async {
    checkParensNeeded_additive(makeOuterPlan(await makeInnerPlan()));
  }

  test_parensNeeded_allowCascade() async {
    checkParensNeeded_cascaded(
        makeOuterPlan(await makeInnerPlan(Precedence.cascade)
          ..endsInCascade = true));
  }
}

@reflectiveTest
class ProvisionalParenEditPlanTest extends EditPlanTestBase {
  Expression expr;
  ParenthesizedExpression parens;

  Future<SimpleEditPlan> makeInnerPlan(
      [Precedence precedence = Precedence.additive]) async {
    await resolveTestUnit('''
void f(a) => (a);
''');
    expr = findNode.simple('a);');
    parens = findNode.parenthesized('(a);');
    return SimpleEditPlan.withPrecedence(expr, precedence);
  }

  ProvisionalParenEditPlan makeOuterPlan(SimpleEditPlan innerPlan) {
    return ProvisionalParenEditPlan(parens, innerPlan);
  }

  test_endsInCascade_false() async {
    expect(makeOuterPlan(await makeInnerPlan()).endsInCascade, false);
  }

  test_endsInCascade_true() async {
    expect(
        makeOuterPlan(await makeInnerPlan()
              ..endsInCascade = true)
            .endsInCascade,
        true);
  }

  test_getChanges_innerChanges() async {
    expect(
        makeOuterPlan(await makeInnerPlan()
              ..addInnerChanges({
                expr.end: [const AddBang()]
              }))
            .getChanges(true),
        {
          expr.end: [const AddBang()]
        });
  }

  test_getChanges_innerChanges_strip_parens() async {
    expect(
        makeOuterPlan(await makeInnerPlan()
              ..addInnerChanges({
                expr.end: [const AddBang()]
              }))
            .getChanges(false),
        {
          parens.offset: [const RemoveText(1)],
          expr.end: [const AddBang(), const RemoveText(1)]
        });
  }

  test_getChanges_none() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(true), null);
  }

  test_getChanges_none_strip_parens() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(false), {
      parens.offset: [const RemoveText(1)],
      expr.end: [const RemoveText(1)]
    });
  }

  test_parensNeeded() async {
    checkParensNeeded_additive(makeOuterPlan(await makeInnerPlan()));
  }

  test_parensNeeded_allowCascade() async {
    checkParensNeeded_cascaded(
        makeOuterPlan(await makeInnerPlan(Precedence.cascade)
          ..endsInCascade = true));
  }
}

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
    // TODO(paulberry): is this test bogus now?
    await resolveTestUnit('''
void f(a, b) => a + b;
''');
    var plan = PassThroughEditPlan(findNode.binary('a + b'));
    checkParensNeeded_additive(plan);
  }

  test_forNonExpression() async {
    await resolveTestUnit('''
class C {}
''');
    var plan =
        SimpleEditPlan.forNonExpression(findNode.classDeclaration('class C'));
    expect(
        plan.parensNeeded(
            threshold: Precedence.postfix,
            associative: false,
            allowCascade: false),
        false);
  }

  test_getChanges_addParens_no_other_changes() async {
    await resolveTestUnit('''
void f(a) => a;
''');
    var aRef = findNode.simple('a;');
    var plan = PassThroughEditPlan(aRef);
    expect(plan.getChanges(true), {
      aRef.offset: [const AddOpenParen()],
      aRef.end: [const AddCloseParen()]
    });
  }

  test_getChanges_addParens_other_changes() async {
    await resolveTestUnit('''
void f(a) => a;
''');
    var aRef = findNode.simple('a;');
    var plan = SimpleEditPlan.withPrecedence(aRef, Precedence.primary);
    plan.addInnerChanges({
      aRef.offset: [const AddBang()],
      aRef.end: [const AddBang()]
    });
    expect(plan.getChanges(true), {
      aRef.offset: [const AddOpenParen(), const AddBang()],
      aRef.end: [const AddBang(), const AddCloseParen()]
    });
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
    // TODO(paulberry): I shouldn't have to set endsInCascade here.
    var plan = SimpleEditPlan.withPrecedence(
        findNode.cascade('a..b'), Precedence.cascade)
      ..endsInCascade = true;
    checkParensNeeded_cascaded(plan);
  }

  test_withPrecedence() async {
    await resolveTestUnit('''
void f(a) => a;
''');
    var plan = SimpleEditPlan.withPrecedence(
        findNode.simple('a;'), Precedence.additive);
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
