// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:nnbd_migration/src/edit_plan.dart';
import 'package:nnbd_migration/src/fix_planner.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_single_unit.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FixPlannerPrecedenceTest);
    defineReflectiveTests(FixPlannerTest);
  });
}

@reflectiveTest
class FixPlannerPrecedenceTest extends FixPlannerTestBase {
  void test_precedence_as() async {
    await _checkPrecedence('''
f(a) => (a as num) as int;
g(a, b) => a | b as int;
''');
  }

  void test_precedence_assignment() async {
    await _checkPrecedence('f(a, b, c) => a = b = c;');
  }

  void test_precedence_binary_equality() async {
    await _checkPrecedence('''
f(a, b, c) => (a == b) == c;
g(a, b, c) => a == (b == c);
''');
  }

  void test_precedence_binary_left_associative() async {
    // Associativity logic is the same for all operators except relational and
    // equality, so we just test `+` as a stand-in for all the others.
    await _checkPrecedence('''
f(a, b, c) => a + b + c;
g(a, b, c) => a + (b + c);
''');
  }

  void test_precedence_binary_relational() async {
    await _checkPrecedence('''
f(a, b, c) => (a < b) < c;
g(a, b, c) => a < (b < c);
''');
  }

  void test_precedence_conditional() async {
    await _checkPrecedence('''
g(a, b, c, d, e, f) => a ?? b ? c = d : e = f;
h(a, b, c, d, e) => (a ? b : c) ? d : e;
''');
  }

  void test_precedence_postfix_and_index() async {
    await _checkPrecedence('''
f(a, b, c) => a[b][c];
g(a, b) => a[b]++;
h(a, b) => (-a)[b];
''');
  }

  void test_precedence_prefix() async {
    await _checkPrecedence('''
f(a) => ~-a;
g(a, b) => -(a*b);
''');
  }

  void test_precedence_property_access() async {
    await _checkPrecedence('''
f(a) => a?.b?.c;
g(a) => (-a)?.b;
''');
  }

  void test_precedence_throw() async {
    await _checkPrecedence('f(a, b) => throw a = b;');
  }

  void _checkPrecedence(String content) async {
    // Note: assertions will fire if the fix planner thinks it needs to add or
    // remove parens to code that is not being otherwise modified, so we can
    // verify correct precedence by simply running the fix planner over the
    // code with no changes requested.
    await analyze(content);
    var previewInfo = run({});
    expect(previewInfo, isNull);
  }
}

@reflectiveTest
class FixPlannerTest extends FixPlannerTestBase {
  void test_adjacentFixes() async {
    await analyze('f(a, b) => a + b;');
    var aRef = findNode.simple('a +');
    var bRef = findNode.simple('b;');
    var previewInfo = run({
      aRef: const NullCheck(),
      bRef: const NullCheck(),
      findNode.binary('a + b'): const NullCheck()
    });
    expect(previewInfo.applyTo(code), 'f(a, b) => (a! + b!)!;');
  }

  void test_introduceAs_distant_parens_no_longer_needed() async {
    // Note: in principle it would be nice to delete the outer parens, but it's
    // difficult to see that they used to be necessary and aren't anymore, so we
    // leave them.
    await analyze('f(a, c) => a..b = (throw c..d);');
    var cd = findNode.cascade('c..d');
    var previewInfo = run({cd: const IntroduceAs('int')});
    expect(
        previewInfo.applyTo(code), 'f(a, c) => a..b = (throw (c..d) as int);');
  }

  void test_introduceAs_no_parens() async {
    await analyze('f(a, b) => a | b;');
    var expr = findNode.binary('a | b');
    var previewInfo = run({expr: const IntroduceAs('int')});
    expect(previewInfo.applyTo(code), 'f(a, b) => a | b as int;');
  }

  void test_introduceAs_parens() async {
    await analyze('f(a, b) => a < b;');
    var expr = findNode.binary('a < b');
    var previewInfo = run({expr: const IntroduceAs('bool')});
    expect(previewInfo.applyTo(code), 'f(a, b) => (a < b) as bool;');
  }

  void test_keep_redundant_parens() async {
    await analyze('f(a, b, c) => a + (b * c);');
    var previewInfo = run({}, allowRedundantParens: true);
    expect(previewInfo, isNull);
  }

  void test_makeNullable() async {
    await analyze('f(int x) {}');
    var typeName = findNode.typeName('int');
    var previewInfo = run({typeName: const MakeNullable()});
    expect(previewInfo.applyTo(code), 'f(int? x) {}');
  }

  void test_nullCheck_no_parens() async {
    await analyze('f(a) => a++;');
    var expr = findNode.postfix('a++');
    var previewInfo = run({expr: const NullCheck()});
    expect(previewInfo.applyTo(code), 'f(a) => a++!;');
  }

  void test_nullCheck_parens() async {
    await analyze('f(a) => -a;');
    var expr = findNode.prefix('-a');
    var previewInfo = run({expr: const NullCheck()});
    expect(previewInfo.applyTo(code), 'f(a) => (-a)!;');
  }

  void test_removeAs_in_cascade_target_no_parens_needed_cascade() async {
    await analyze('f(a) => ((a..b) as dynamic)..c;');
    var cascade = findNode.cascade('a..b');
    var cast = cascade.parent.parent;
    var previewInfo = run({cast: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a) => a..b..c;');
  }

  void test_removeAs_in_cascade_target_no_parens_needed_conditional() async {
    // TODO(paulberry): would it be better to keep the parens in this case for
    // clarity, even though they're not needed?
    await analyze('f(a, b, c) => ((a ? b : c) as dynamic)..d;');
    var conditional = findNode.conditionalExpression('a ? b : c');
    var cast = conditional.parent.parent;
    var previewInfo = run({cast: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a, b, c) => a ? b : c..d;');
  }

  void test_removeAs_in_cascade_target_parens_needed_assignment() async {
    await analyze('f(a, b) => ((a = b) as dynamic)..c;');
    var assignment = findNode.assignment('a = b');
    var cast = assignment.parent.parent;
    var previewInfo = run({cast: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a, b) => (a = b)..c;');
  }

  void test_removeAs_in_cascade_target_parens_needed_throw() async {
    await analyze('f(a) => ((throw a) as dynamic)..b;');
    var throw_ = findNode.throw_('throw a');
    var cast = throw_.parent.parent;
    var previewInfo = run({cast: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a) => (throw a)..b;');
  }

  void test_removeAs_lower_precedence_do_not_remove_inner_parens() async {
    await analyze('f(a, b, c) => (a == b) as Null == c;');
    var expr = findNode.binary('a == b');
    var previewInfo = run({expr.parent.parent: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a, b, c) => (a == b) == c;');
  }

  void test_removeAs_lower_precedence_remove_inner_parens() async {
    await analyze('f(a, b) => (a == b) as Null;');
    var expr = findNode.binary('a == b');
    var previewInfo = run({expr.parent.parent: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a, b) => a == b;');
  }

  void test_removeAs_parens_needed_due_to_cascade() async {
    await analyze('f(a, c) => a..b = throw (c..d) as int;');
    var cd = findNode.cascade('c..d');
    var cast = cd.parent.parent;
    var previewInfo = run({cast: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a, c) => a..b = (throw c..d);');
  }

  void test_removeAs_parens_needed_due_to_cascade_in_conditional_else() async {
    await analyze('f(a, b, c) => a ? b : (c..d) as int;');
    var cd = findNode.cascade('c..d');
    var cast = cd.parent.parent;
    var previewInfo = run({cast: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a, b, c) => a ? b : (c..d);');
  }

  void test_removeAs_parens_needed_due_to_cascade_in_conditional_then() async {
    await analyze('f(a, b, d) => a ? (b..c) as int : d;');
    var bc = findNode.cascade('b..c');
    var cast = bc.parent.parent;
    var previewInfo = run({cast: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a, b, d) => a ? (b..c) : d;');
  }

  void test_removeAs_raise_precedence_do_not_remove_parens() async {
    await analyze('f(a, b, c) => a | (b | c as int);');
    var expr = findNode.binary('b | c');
    var previewInfo = run({expr.parent: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a, b, c) => a | (b | c);');
  }

  void test_removeAs_raise_precedence_no_parens_to_remove() async {
    await analyze('f(a, b, c) => a = b | c as int;');
    var expr = findNode.binary('b | c');
    var previewInfo = run({expr.parent: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a, b, c) => a = b | c;');
  }

  void test_removeAs_raise_precedence_remove_parens() async {
    await analyze('f(a, b, c) => a < (b | c as int);');
    var expr = findNode.binary('b | c');
    var previewInfo = run({expr.parent: const RemoveAs()});
    expect(previewInfo.applyTo(code), 'f(a, b, c) => a < b | c;');
  }
}

class FixPlannerTestBase extends AbstractSingleUnitTest {
  String code;

  Future<void> analyze(String code) async {
    this.code = code;
    await resolveTestUnit(code);
  }

  Map<int, List<PreviewInfo>> run(Map<AstNode, Change> changes,
      {bool allowRedundantParens = false}) {
    return FixPlanner.run(testUnit, changes,
        allowRedundantParens: allowRedundantParens);
  }
}
