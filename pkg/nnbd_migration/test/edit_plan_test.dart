// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:nnbd_migration/src/edit_plan.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_single_unit.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(EditPlanTest);
    defineReflectiveTests(EndsInCascadeTest);
    defineReflectiveTests(PrecedenceTest);
  });
}

@reflectiveTest
class EditPlanTest extends AbstractSingleUnitTest {
  String code;

  Future<void> analyze(String code) async {
    this.code = code;
    await resolveTestUnit(code);
  }

  void checkPlan(EditPlan plan, String expected) {
    expect(plan.finalize().applyTo(code), expected);
  }

  EditPlan parenExtract(ParenthesizedExpression inner, AstNode outer) =>
      EditPlan.extract(
          outer,
          EditPlan.provisionalParens(
              inner, EditPlan.passThrough(inner.expression)));

  EditPlan simpleExtract(AstNode inner, AstNode outer) =>
      EditPlan.extract(outer, EditPlan.passThrough(inner));

  test_cascadeSearchLimit() async {
    // Ok, we have to ask each parent if it represents a cascade section.
    // If we create a passThrough at node N, then when we create an enclosing
    // passThrough, the first thing we'll check is N's parent.
    await analyze('f(a, c) => a..b = c = 1;');
    var cascade = findNode.cascade('..');
    var outerAssignment = findNode.assignment('= c');
    assert(identical(cascade, outerAssignment.parent));
    var innerAssignment = findNode.assignment('= 1');
    assert(identical(outerAssignment, innerAssignment.parent));
    var one = findNode.integerLiteral('1');
    assert(identical(innerAssignment, one.parent));
    // The tests below will be based on an inner plan that adds `..isEven` after
    // the `1`.
    EditPlan makeInnerPlan() => EditPlan.surround(EditPlan.passThrough(one),
        suffix: [AddText('..isEven')], endsInCascade: true);
    {
      // If we make a plan that passes through `c = 1`, containing a plan that
      // adds `..isEven` to `1`, then we don't necessarily want to add parens yet,
      // because we might not keep the cascade section above it.
      var plan =
          EditPlan.passThrough(innerAssignment, innerPlans: [makeInnerPlan()]);
      // `endsInCascade` returns true because we haven't committed to adding
      // parens, so we need to remember that the presence of `..isEven` may
      // require parens later.
      expect(plan.endsInCascade, true);
      checkPlan(EditPlan.extract(cascade, plan), 'f(a, c) => c = 1..isEven;');
    }
    {
      // If we make a plan that passes through `..b = c = 1`, containing a plan
      // that adds `..isEven` to `1`, then we do necessarily want to add parens,
      // because we're committed to keeping the cascade section.
      var plan =
          EditPlan.passThrough(outerAssignment, innerPlans: [makeInnerPlan()]);
      // We can tell that the parens have been finalized because `endsInCascade`
      // returns false now.
      expect(plan.endsInCascade, false);
      checkPlan(plan, 'f(a, c) => a..b = c = (1..isEven);');
    }
  }

  test_extract_add_parens() async {
    await analyze('f(g) => 1 * g(2, 3 + 4, 5);');
    checkPlan(
        simpleExtract(
            findNode.binary('+'), findNode.functionExpressionInvocation('+')),
        'f(g) => 1 * (3 + 4);');
  }

  test_extract_inner_endsInCascade() async {
    await analyze('f(a, g) => a..b = g(0, 1..isEven, 2);');
    expect(
        simpleExtract(findNode.cascade('1..isEven'),
                findNode.functionExpressionInvocation('g('))
            .endsInCascade,
        true);
    expect(
        simpleExtract(findNode.integerLiteral('1'),
                findNode.functionExpressionInvocation('g('))
            .endsInCascade,
        false);
  }

  test_extract_left() async {
    await analyze('var x = 1 + 2;');
    checkPlan(simpleExtract(findNode.integerLiteral('1'), findNode.binary('+')),
        'var x = 1;');
  }

  test_extract_no_parens_needed() async {
    await analyze('var x = 1 + 2 * 3;');
    checkPlan(simpleExtract(findNode.integerLiteral('2'), findNode.binary('*')),
        'var x = 1 + 2;');
  }

  test_extract_preserve_parens() async {
    // Note: extra spaces to verify that we are really preserving the parens
    // rather than removing them and adding new ones.
    await analyze('var x = ( 1 << 2 ) * 3 + 4;');
    checkPlan(parenExtract(findNode.parenthesized('<<'), findNode.binary('*')),
        'var x = ( 1 << 2 ) + 4;');
  }

  test_finalize_compilationUnit() async {
    // Verify that an edit plan referring to the entire compilation unit can be
    // finalized.  (This is an important corner case because the entire
    // compilation unit is an AstNode with no parent).
    await analyze('var x = 0;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(testUnit),
            suffix: [AddText(' var y = 0;')]),
        'var x = 0; var y = 0;');
  }

  test_surround_allowCascade() async {
    await analyze('f(x) => 1..isEven;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.cascade('..')),
            prefix: [AddText('x..y = ')]),
        'f(x) => x..y = (1..isEven);');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.cascade('..')),
            prefix: [AddText('x = ')], allowCascade: true),
        'f(x) => x = 1..isEven;');
  }

  test_surround_associative() async {
    await analyze('var x = 1 - 2;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.binary('-')),
            suffix: [AddText(' - 3')],
            threshold: Precedence.additive,
            associative: true),
        'var x = 1 - 2 - 3;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.binary('-')),
            prefix: [AddText('0 - ')], threshold: Precedence.additive),
        'var x = 0 - (1 - 2);');
  }

  test_surround_endsInCascade() async {
    await analyze('f(x) => x..y = 1;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.integerLiteral('1')),
            suffix: [AddText(' + 2')]),
        'f(x) => x..y = 1 + 2;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.integerLiteral('1')),
            suffix: [AddText('..isEven')], endsInCascade: true),
        'f(x) => x..y = (1..isEven);');
  }

  test_surround_endsInCascade_does_not_propagate_through_added_parens() async {
    await analyze('f(a) => a..b = 0;');
    checkPlan(
        EditPlan.surround(
            EditPlan.surround(EditPlan.passThrough(findNode.cascade('..')),
                prefix: [AddText('1 + ')], threshold: Precedence.additive),
            prefix: [AddText('true ? ')],
            suffix: [AddText(' : 2')]),
        'f(a) => true ? 1 + (a..b = 0) : 2;');
    checkPlan(
        EditPlan.surround(
            EditPlan.surround(EditPlan.passThrough(findNode.cascade('..')),
                prefix: [AddText('throw ')], allowCascade: true),
            prefix: [AddText('true ? ')],
            suffix: [AddText(' : 2')]),
        'f(a) => true ? (throw a..b = 0) : 2;');
  }

  test_surround_endsInCascade_propagates() async {
    await analyze('f(a) => a..b = 0;');
    checkPlan(
        EditPlan.surround(
            EditPlan.surround(EditPlan.passThrough(findNode.cascade('..')),
                prefix: [AddText('throw ')], allowCascade: true),
            prefix: [AddText('true ? ')],
            suffix: [AddText(' : 2')]),
        'f(a) => true ? (throw a..b = 0) : 2;');
    checkPlan(
        EditPlan.surround(
            EditPlan.surround(
                EditPlan.passThrough(findNode.integerLiteral('0')),
                prefix: [AddText('throw ')],
                allowCascade: true),
            prefix: [AddText('true ? ')],
            suffix: [AddText(' : 2')]),
        'f(a) => a..b = true ? throw 0 : 2;');
  }

  test_surround_precedence() async {
    await analyze('var x = 1 == true;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.integerLiteral('1')),
            suffix: [AddText(' < 2')], precedence: Precedence.relational),
        'var x = 1 < 2 == true;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.integerLiteral('1')),
            suffix: [AddText(' == 2')], precedence: Precedence.equality),
        'var x = (1 == 2) == true;');
  }

  test_surround_prefix() async {
    await analyze('var x = 1;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.integerLiteral('1')),
            prefix: [AddText('throw ')]),
        'var x = throw 1;');
  }

  test_surround_suffix() async {
    await analyze('var x = 1;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.integerLiteral('1')),
            suffix: [AddText('..isEven')]),
        'var x = 1..isEven;');
  }

  test_surround_threshold() async {
    await analyze('var x = 1 < 2;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.binary('<')),
            suffix: [AddText(' == true')], threshold: Precedence.equality),
        'var x = 1 < 2 == true;');
    checkPlan(
        EditPlan.surround(EditPlan.passThrough(findNode.binary('<')),
            suffix: [AddText(' as bool')], threshold: Precedence.relational),
        'var x = (1 < 2) as bool;');
  }
}

@reflectiveTest
class EndsInCascadeTest extends AbstractSingleUnitTest {
  test_ignore_subexpression_not_at_end() async {
    await resolveTestUnit('f(g) => g(0..isEven, 1);');
    expect(findNode.functionExpressionInvocation('g(').endsInCascade, false);
    expect(findNode.cascade('..').endsInCascade, true);
  }

  test_no_cascade() async {
    await resolveTestUnit('var x = 0;');
    expect(findNode.integerLiteral('0').endsInCascade, false);
  }

  test_stop_searching_when_parens_encountered() async {
    await resolveTestUnit('f(x) => x = (x = 0..isEven);');
    expect(findNode.assignment('= (x').endsInCascade, false);
    expect(findNode.parenthesized('(x =').endsInCascade, false);
    expect(findNode.assignment('= 0').endsInCascade, true);
    expect(findNode.cascade('..').endsInCascade, true);
  }
}

/// TODO(paulberry): document how these tests operate.
@reflectiveTest
class PrecedenceTest extends AbstractSingleUnitTest {
  void checkPrecedence(String content) async {
    await resolveTestUnit(content);
    testUnit.accept(_PrecedenceChecker());
  }

  void test_precedence_as() async {
    await checkPrecedence('''
f(a) => (a as num) as int;
g(a, b) => a | b as int;
''');
  }

  void test_precedence_assignment() async {
    await checkPrecedence('f(a, b, c) => a = b = c;');
  }

  void test_precedence_assignment_in_cascade_with_parens() async {
    await checkPrecedence('f(a, c, e) => a..b = (c..d = e);');
  }

  void test_precedence_await() async {
    await checkPrecedence('''
f(a) async => await -a;
g(a, b) async => await (a*b);
    ''');
  }

  void test_precedence_binary_equality() async {
    await checkPrecedence('''
f(a, b, c) => (a == b) == c;
g(a, b, c) => a == (b == c);
''');
  }

  void test_precedence_binary_left_associative() async {
    // Associativity logic is the same for all operators except relational and
    // equality, so we just test `+` as a stand-in for all the others.
    await checkPrecedence('''
f(a, b, c) => a + b + c;
g(a, b, c) => a + (b + c);
''');
  }

  void test_precedence_binary_relational() async {
    await checkPrecedence('''
f(a, b, c) => (a < b) < c;
g(a, b, c) => a < (b < c);
''');
  }

  void test_precedence_conditional() async {
    await checkPrecedence('''
g(a, b, c, d, e, f) => a ?? b ? c = d : e = f;
h(a, b, c, d, e) => (a ? b : c) ? d : e;
''');
  }

  void test_precedence_extension_override() async {
    await checkPrecedence('''
extension E on Object {
  void f() {}
}
void g(x) => E(x).f();
''');
  }

  void test_precedence_functionExpressionInvocation() async {
    await checkPrecedence('''
f(g) => g[0](1);
h(x) => (x + 2)(3);
''');
  }

  void test_precedence_is() async {
    await checkPrecedence('''
f(a) => (a as num) is int;
g(a, b) => a | b is int;
''');
  }

  void test_precedence_postfix_and_index() async {
    await checkPrecedence('''
f(a, b, c) => a[b][c];
g(a, b) => a[b]++;
h(a, b) => (-a)[b];
''');
  }

  void test_precedence_prefix() async {
    await checkPrecedence('''
f(a) => ~-a;
g(a, b) => -(a*b);
''');
  }

  void test_precedence_property_access() async {
    await checkPrecedence('''
f(a) => a?.b?.c;
g(a) => (-a)?.b;
''');
  }

  void test_precedence_throw() async {
    await checkPrecedence('f(a, b) => throw a = b;');
  }
}

class _EditPlanTestBase extends AbstractSingleUnitTest {
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
class _ExtractEditPlanWithoutParensTest extends _EditPlanTestBase {
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
class _ExtractEditPlanWithParensTest extends _EditPlanTestBase {
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

class _PrecedenceChecker extends UnifyingAstVisitor<void> {
  @override
  void visitNode(AstNode node) {
    var parent = node.parent;
    if (parent is ParenthesizedExpression) {
      expect(
          EditPlan.provisionalParens(parent, EditPlan.passThrough(node))
              .parensNeededFromContext(null),
          true);
    } else {
      expect(EditPlan.passThrough(node).parensNeededFromContext(null), false);
    }
    node.visitChildren(this);
  }
}

@reflectiveTest
class _ProvisionalParenEditPlanTest extends _EditPlanTestBase {
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
class _SimpleEditPlanTest extends _EditPlanTestBase {
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
