// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:nnbd_migration/src/edit_plan.dart';
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
  String code;

  Future<void> analyze(String code) async {
    this.code = code;
    await resolveTestUnit(code);
  }

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

  Future<EditPlan> makeInnerPlan() async {
    await analyze('void f(a, b, c, d) => a = b + c << d;');
    expr = findNode.binary('b + c');
    outerExpr = findNode.assignment('a = b + c << d');
    return EditPlan.passThrough(expr);
  }

  Future<EditPlan> makeInnerPlan_cascaded() async {
    await analyze('''
void f(a, b) => a = b..c;
''');
    expr = findNode.cascade('b..c');
    outerExpr = findNode.assignment('a = b..c');
    return EditPlan.passThrough(expr);
  }

  EditPlan makeOuterPlan(EditPlan innerPlan) {
    return EditPlan.extract(outerExpr, innerPlan);
  }

  test_endsInCascade_false() async {
    expect(makeOuterPlan(await makeInnerPlan()).endsInCascade, false);
  }

  test_endsInCascade_true() async {
    expect(makeOuterPlan(await makeInnerPlan_cascaded()).endsInCascade, true);
  }

  test_getChanges_extractLeft() async {
    await analyze('void f(a, b, c) => a + b << c;');
    expr = findNode.binary('+');
    outerExpr = findNode.binary('<<');
    var innerPlan = EditPlan.passThrough(expr);
    expect(makeOuterPlan(innerPlan).getChanges(false).applyTo(code),
        'void f(a, b, c) => a + b;');
  }

  test_getChanges_extractRight() async {
    await analyze('void f(a, b, c) => a << b + c;');
    expr = findNode.binary('+');
    outerExpr = findNode.binary('<<');
    var innerPlan = EditPlan.passThrough(expr);
    expect(makeOuterPlan(innerPlan).getChanges(false).applyTo(code),
        'void f(a, b, c) => b + c;');
  }

  test_getChanges_innerChanges() async {
    expect(
        makeOuterPlan(EditPlan.surround(await makeInnerPlan(),
            suffix: [const AddText(' + d')])).getChanges(false).applyTo(code),
        'void f(a, b, c, d) => b + c + d;');
  }

  test_getChanges_innerChanges_add_parens() async {
    expect(
        makeOuterPlan(EditPlan.surround(await makeInnerPlan(),
            suffix: [const AddText(' + d')])).getChanges(true).applyTo(code),
        'void f(a, b, c, d) => (b + c + d);');
  }

  test_getChanges_no_innerChanges() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(false).applyTo(code),
        'void f(a, b, c, d) => b + c;');
  }

  test_getChanges_no_innerChanges_add_parens() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(true).applyTo(code),
        'void f(a, b, c, d) => (b + c);');
  }

  test_parensNeeded() async {
    checkParensNeeded_additive(makeOuterPlan(await makeInnerPlan()));
  }

  test_parensNeeded_allowCascade() async {
    checkParensNeeded_cascaded(makeOuterPlan(await makeInnerPlan_cascaded()));
  }
}

@reflectiveTest
class ExtractEditPlanWithParensTest extends EditPlanTestBase {
  Expression expr;
  ParenthesizedExpression parens;
  Expression outerExpr;

  Future<EditPlan> makeInnerPlan() async {
    await analyze('void f(a, b, c, d) => a = (b + c) * d;');
    expr = findNode.binary('b + c');
    parens = findNode.parenthesized('(b + c)');
    outerExpr = findNode.assignment('a = (b + c) * d');
    return EditPlan.passThrough(expr);
  }

  Future<EditPlan> makeInnerPlan_cascaded() async {
    await analyze('void f(a, b, d) => a = (b..c) * d;');
    expr = findNode.cascade('b..c');
    parens = findNode.parenthesized('(b..c)');
    outerExpr = findNode.assignment('a = (b..c) * d');
    return EditPlan.passThrough(expr);
  }

  EditPlan makeOuterPlan(EditPlan innerPlan) {
    return EditPlan.extract(
        outerExpr, EditPlan.provisionalParens(parens, innerPlan));
  }

  test_endsInCascade_false() async {
    expect(makeOuterPlan(await makeInnerPlan()).endsInCascade, false);
  }

  test_endsInCascade_true() async {
    expect(makeOuterPlan(await makeInnerPlan_cascaded()).endsInCascade, true);
  }

  test_getChanges_extractLeft() async {
    await analyze('void f(a, b, c) => (a + b) * c;');
    expr = findNode.binary('+');
    parens = findNode.parenthesized('+');
    outerExpr = findNode.binary('*');
    var innerPlan = EditPlan.passThrough(expr);
    expect(makeOuterPlan(innerPlan).getChanges(true).applyTo(code),
        'void f(a, b, c) => (a + b);');
  }

  test_getChanges_extractRight() async {
    await analyze('void f(a, b, c) => a * (b + c);');
    expr = findNode.binary('+');
    parens = findNode.parenthesized('+');
    outerExpr = findNode.binary('*');
    var innerPlan = EditPlan.passThrough(expr);
    expect(makeOuterPlan(innerPlan).getChanges(true).applyTo(code),
        'void f(a, b, c) => (b + c);');
  }

  test_getChanges_innerChanges() async {
    expect(
        makeOuterPlan(EditPlan.surround(await makeInnerPlan(),
            suffix: [const AddText(' + d')])).getChanges(true).applyTo(code),
        'void f(a, b, c, d) => (b + c + d);');
  }

  test_getChanges_innerChanges_strip_parens() async {
    expect(
        makeOuterPlan(EditPlan.surround(await makeInnerPlan(),
            suffix: [const AddText(' + d')])).getChanges(false).applyTo(code),
        'void f(a, b, c, d) => b + c + d;');
  }

  test_getChanges_no_innerChanges() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(true).applyTo(code),
        'void f(a, b, c, d) => (b + c);');
  }

  test_getChanges_no_innerChanges_strip_parens() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(false).applyTo(code),
        'void f(a, b, c, d) => b + c;');
  }

  test_parensNeeded() async {
    checkParensNeeded_additive(makeOuterPlan(await makeInnerPlan()));
  }

  test_parensNeeded_allowCascade() async {
    checkParensNeeded_cascaded(makeOuterPlan(await makeInnerPlan_cascaded()));
  }
}

@reflectiveTest
class ProvisionalParenEditPlanTest extends EditPlanTestBase {
  Expression expr;
  ParenthesizedExpression parens;

  Future<EditPlan> makeInnerPlan() async {
    await analyze('void f(a, b) => (a + b);');
    expr = findNode.binary('a + b');
    parens = findNode.parenthesized('a + b');
    return EditPlan.passThrough(expr);
  }

  Future<EditPlan> makeInnerPlan_cascaded() async {
    await analyze('void f(a) => (a..b);');
    expr = findNode.cascade('a..b');
    parens = findNode.parenthesized('a..b');
    return EditPlan.passThrough(expr);
  }

  EditPlan makeOuterPlan(EditPlan innerPlan) {
    return EditPlan.provisionalParens(parens, innerPlan);
  }

  test_endsInCascade_false() async {
    expect(makeOuterPlan(await makeInnerPlan()).endsInCascade, false);
  }

  test_endsInCascade_true() async {
    expect(makeOuterPlan(await makeInnerPlan_cascaded()).endsInCascade, true);
  }

  test_getChanges_innerChanges() async {
    expect(
        makeOuterPlan(EditPlan.surround(await makeInnerPlan(),
            suffix: [const AddText(' + c')])).getChanges(true).applyTo(code),
        'void f(a, b) => (a + b + c);');
  }

  test_getChanges_innerChanges_strip_parens() async {
    expect(
        makeOuterPlan(EditPlan.surround(await makeInnerPlan(),
            suffix: [const AddText(' + c')])).getChanges(false).applyTo(code),
        'void f(a, b) => a + b + c;');
  }

  test_getChanges_none() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(true), null);
  }

  test_getChanges_none_strip_parens() async {
    expect(makeOuterPlan(await makeInnerPlan()).getChanges(false).applyTo(code),
        'void f(a, b) => a + b;');
  }

  test_parensNeeded() async {
    checkParensNeeded_additive(makeOuterPlan(await makeInnerPlan()));
  }

  test_parensNeeded_allowCascade() async {
    checkParensNeeded_cascaded(makeOuterPlan(await makeInnerPlan_cascaded()));
  }
}

/// TODO(paulberry): reorganize these tests
@reflectiveTest
class SimpleEditPlanTest extends EditPlanTestBase {
  test_forExpression() async {
    // TODO(paulberry): is this test bogus now?
    await analyze('''
void f(a, b) => a + b;
''');
    var plan = EditPlan.passThrough(findNode.binary('a + b'));
    checkParensNeeded_additive(plan);
  }

  test_getChanges_addParens_no_other_changes() async {
    await analyze('void f(a) => a;');
    var aRef = findNode.simple('a;');
    var plan = EditPlan.passThrough(aRef);
    expect(plan.getChanges(true).applyTo(code), 'void f(a) => (a);');
  }

  test_getChanges_addParens_other_changes() async {
    await analyze('void f(a) => a;');
    var aRef = findNode.simple('a;');
    var innerPlan = EditPlan.passThrough(aRef);
    var plan = EditPlan.surround(innerPlan,
        prefix: [const AddText('0 + ')], suffix: [const AddText(' + 0')]);
    expect(plan.getChanges(true).applyTo(code), 'void f(a) => (0 + a + 0);');
  }

  test_parensNeeded_allowCascade() async {
    await analyze('''
void f(a) => a..b;
''');
    var plan = EditPlan.passThrough(findNode.cascade('a..b'));
    checkParensNeeded_cascaded(plan);
  }
}
