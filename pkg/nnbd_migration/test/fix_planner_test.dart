// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:nnbd_migration/src/edit_plan.dart';
import 'package:nnbd_migration/src/fix_applier.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_single_unit.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FixPlannerTest);
  });
}

@reflectiveTest
class FixPlannerTest extends AbstractSingleUnitTest {
  void test_adjacentFixes() async {
    await resolveTestUnit('''
f(a, b) => a + b;
''');
    var aRef = findNode.simple('a +');
    var bRef = findNode.simple('b;');
    var previewInfo = _run({
      aRef: const NullCheck(),
      bRef: const NullCheck(),
      findNode.binary('a + b'): const NullCheck()
    });
    expect(previewInfo, {
      aRef.offset: [const AddOpenParen()],
      aRef.end: [const AddBang()],
      bRef.end: [const AddBang(), const AddCloseParen(), const AddBang()]
    });
  }

  void test_introduceAs_no_parens() async {
    await resolveTestUnit('''
f(a, b) => a | b;
''');
    var expr = findNode.binary('a | b');
    var previewInfo = _run({expr: const IntroduceAs('int')});
    expect(previewInfo, {
      expr.end: [const AddAs('int')]
    });
  }

  void test_introduceAs_parens() async {
    await resolveTestUnit('''
f(a, b) => a < b;
''');
    var expr = findNode.binary('a < b');
    var previewInfo = _run({expr: const IntroduceAs('bool')});
    expect(previewInfo, {
      expr.offset: [const AddOpenParen()],
      expr.end: [const AddCloseParen(), const AddAs('bool')]
    });
  }

  void test_keep_redundant_parens() async {
    await resolveTestUnit('''
f(a, b, c) => a + (b * c);
''');
    var previewInfo = _run({}, allowRedundantParens: true);
    expect(previewInfo, isNull);
  }

  void test_nullCheck_no_parens() async {
    await resolveTestUnit('''
f(a) => a++;
''');
    var expr = findNode.postfix('a++');
    var previewInfo = _run({expr: const NullCheck()});
    expect(previewInfo, {
      expr.end: [const AddBang()]
    });
  }

  void test_nullCheck_parens() async {
    await resolveTestUnit('''
f(a) => -a;
''');
    var expr = findNode.prefix('-a');
    var previewInfo = _run({expr: const NullCheck()});
    expect(previewInfo, {
      expr.offset: [const AddOpenParen()],
      expr.end: [const AddCloseParen(), const AddBang()]
    });
  }

  void test_precedence_as() async {
    await resolveTestUnit('''
f(a) => (a as num) as int;
g(a, b) => a | b as int;
''');
    var previewInfo = _run({});
    expect(previewInfo, isNull);
  }

  void test_precedence_binary_equality() async {
    await resolveTestUnit('''
f(a, b, c) => (a == b) == c;
g(a, b, c) => a == (b == c);
''');
    var previewInfo = _run({});
    expect(previewInfo, isNull);
  }

  void test_precedence_binary_left_associative() async {
    // Associativity logic is the same for all operators except relational and
    // equality, so we just test `+` as a stand-in for all the others.
    await resolveTestUnit('''
f(a, b, c) => a + b + c;
g(a, b, c) => a + (b + c);
''');
    var previewInfo = _run({});
    expect(previewInfo, isNull);
  }

  void test_precedence_binary_relational() async {
    await resolveTestUnit('''
f(a, b, c) => (a < b) < c;
g(a, b, c) => a < (b < c);
''');
    var previewInfo = _run({});
    expect(previewInfo, isNull);
  }

  void test_precedence_postfix_and_index() async {
    await resolveTestUnit('''
f(a, b, c) => a[b][c];
g(a, b) => a[b]++;
h(a, b) => (-a)[b];
''');
    var previewInfo = _run({});
    expect(previewInfo, isNull);
  }

  void test_precedence_prefix() async {
    await resolveTestUnit('''
f(a) => ~-a;
g(a, b) => -(a*b);
''');
    var previewInfo = _run({});
    expect(previewInfo, isNull);
  }

  void test_removeAs_in_cascade_target_no_parens_needed_cascade() async {
    await resolveTestUnit('''
f(a) => ((a..b) as dynamic)..c;
''');
    var cascade = findNode.cascade('a..b');
    var cast = cascade.parent.parent;
    var previewInfo = _run({cast: const RemoveAs()});
    expect(previewInfo, {
      cast.parent.offset: [const RemoveText(1)],
      cascade.parent.offset: [const RemoveText(1)],
      cascade.end: [const RemoveText(1)],
      cascade.parent.end: [RemoveText(cast.end - cascade.parent.end)],
      cast.end: [const RemoveText(1)]
    });
  }

  void test_removeAs_in_cascade_target_no_parens_needed_conditional() async {
    // TODO(paulberry): would it be better to keep the parens in this case for
    // clarity, even though they're not needed?
    await resolveTestUnit('''
f(a, b, c) => ((a ? b : c) as dynamic)..d;
''');
    var conditional = findNode.conditionalExpression('a ? b : c');
    var cast = conditional.parent.parent;
    var previewInfo = _run({cast: const RemoveAs()});
    expect(previewInfo, {
      cast.parent.offset: [const RemoveText(1)],
      conditional.parent.offset: [const RemoveText(1)],
      conditional.end: [const RemoveText(1)],
      conditional.parent.end: [RemoveText(cast.end - conditional.parent.end)],
      cast.end: [const RemoveText(1)]
    });
  }

  void test_removeAs_in_cascade_target_parens_needed_assignment() async {
    await resolveTestUnit('''
f(a, b) => ((a = b) as dynamic)..c;
''');
    var assignment = findNode.assignment('a = b');
    var cast = assignment.parent.parent;
    var previewInfo = _run({cast: const RemoveAs()});
    expect(previewInfo, {
      assignment.parent.offset: [const RemoveText(1)],
      assignment.end: [const RemoveText(1)],
      assignment.parent.end: [RemoveText(cast.end - assignment.parent.end)]
    });
  }

  void test_removeAs_in_cascade_target_parens_needed_throw() async {
    await resolveTestUnit('''
f(a) => ((throw a) as dynamic)..b;
''');
    var throw_ = findNode.throw_('throw a');
    var cast = throw_.parent.parent;
    var previewInfo = _run({cast: const RemoveAs()});
    expect(previewInfo, {
      throw_.parent.offset: [const RemoveText(1)],
      throw_.end: [const RemoveText(1)],
      throw_.parent.end: [RemoveText(cast.end - throw_.parent.end)]
    });
  }

  void test_removeAs_lower_precedence_do_not_remove_inner_parens() async {
    await resolveTestUnit('''
f(a, b, c) => (a == b) as Null == c;
''');
    var expr = findNode.binary('a == b');
    var previewInfo = _run({expr.parent.parent: const RemoveAs()});
    expect(previewInfo, {
      expr.parent.end: [RemoveText(expr.parent.parent.end - expr.parent.end)]
    });
  }

  void test_removeAs_lower_precedence_remove_inner_parens() async {
    await resolveTestUnit('''
f(a, b) => (a == b) as Null;
''');
    var expr = findNode.binary('a == b');
    var previewInfo = _run({expr.parent.parent: const RemoveAs()});
    expect(previewInfo, {
      expr.parent.offset: [RemoveText(1)],
      expr.end: [RemoveText(1)],
      expr.parent.end: [RemoveText(expr.parent.parent.end - expr.parent.end)]
    });
  }

  void test_removeAs_parens_needed_due_to_cascade() async {
    await resolveTestUnit('''
f(a, c) => a..b = throw (c..d) as int;
''');
    var cd = findNode.cascade('c..d');
    var cast = cd.parent.parent;
    var throw_ = cast.parent;
    var previewInfo = _run({cast: const RemoveAs()});
    expect(previewInfo, {
      throw_.offset: [const AddOpenParen()],
      cd.parent.offset: [const RemoveText(1)],
      cd.end: [const RemoveText(1)],
      cd.parent.end: [RemoveText(cast.end - cd.parent.end)],
      throw_.end: [const AddCloseParen()]
    });
  }

  void test_removeAs_parens_needed_due_to_cascade_in_conditional_else() async {
    await resolveTestUnit('''
f(a, b, c) => a ? b : (c..d) as int;
''');
    var cd = findNode.cascade('c..d');
    var cast = cd.parent.parent;
    var previewInfo = _run({cast: const RemoveAs()});
    expect(previewInfo, {
      cd.parent.end: [RemoveText(cast.end - cd.parent.end)],
    });
  }

  void test_removeAs_parens_needed_due_to_cascade_in_conditional_then() async {
    await resolveTestUnit('''
f(a, b, d) => a ? (b..c) as int : d;
''');
    var bc = findNode.cascade('b..c');
    var cast = bc.parent.parent;
    var previewInfo = _run({cast: const RemoveAs()});
    expect(previewInfo, {
      bc.parent.end: [RemoveText(cast.end - bc.parent.end)],
    });
  }

  void test_removeAs_raise_precedence_do_not_remove_parens() async {
    await resolveTestUnit('''
f(a, b, c) => a | (b | c as int);
''');
    var expr = findNode.binary('b | c');
    var previewInfo = _run({expr.parent: const RemoveAs()});
    expect(previewInfo, {
      expr.end: [RemoveText(expr.parent.end - expr.end)]
    });
  }

  void test_removeAs_raise_precedence_no_parens_to_remove() async {
    await resolveTestUnit('''
f(a, b, c) => a = b | c as int;
''');
    var expr = findNode.binary('b | c');
    var previewInfo = _run({expr.parent: const RemoveAs()});
    expect(previewInfo, {
      expr.end: [RemoveText(expr.parent.end - expr.end)]
    });
  }

  void test_removeAs_raise_precedence_remove_parens() async {
    await resolveTestUnit('''
f(a, b, c) => a < (b | c as int);
''');
    var expr = findNode.binary('b | c');
    var previewInfo = _run({expr.parent: const RemoveAs()});
    expect(previewInfo, {
      expr.parent.parent.offset: [RemoveText(1)],
      expr.end: [RemoveText(expr.parent.end - expr.end)],
      expr.parent.end: [RemoveText(1)]
    });
  }

  Object _run(Map<AstNode, Change> changes,
      {bool allowRedundantParens = false}) {
    // TODO(paulberry): test that redundant parens are allowed in certain
    //  circumstances.
    return FixPlanner.run(testUnit, changes,
        allowRedundantParens: allowRedundantParens);
  }
}
