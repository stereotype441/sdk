// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type_provider.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/type_system.dart';
import 'package:analyzer/src/task/strong/checker.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/edit_plan.dart';
import 'package:nnbd_migration/src/fix_applier.dart';
import 'package:nnbd_migration/src/variables.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_single_unit.dart';
import 'migration_visitor_test_base.dart';

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

  void test_extractNode_lower_precedence_remove_inner_parens() async {
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

  void test_extractNode_raise_precedence_do_not_remove_parens() async {
    await resolveTestUnit('''
f(a, b, c) => a | (b | c as int);
''');
    var expr = findNode.binary('b | c');
    var previewInfo = _run({expr.parent: const RemoveAs()});
    expect(previewInfo, {
      expr.end: [RemoveText(expr.parent.end - expr.end)]
    });
  }

  void test_extractNode_raise_precedence_no_parens_to_remove() async {
    await resolveTestUnit('''
f(a, b, c) => a = b | c as int;
''');
    var expr = findNode.binary('b | c');
    var previewInfo = _run({expr.parent: const RemoveAs()});
    expect(previewInfo, {
      expr.end: [RemoveText(expr.parent.end - expr.end)]
    });
  }

  void test_extractNode_raise_precedence_remove_parens() async {
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
    _run({});
  }

  void test_precedence_binary_equality() async {
    await resolveTestUnit('''
f(a, b, c) => (a == b) == c;
g(a, b, c) => a == (b == c);
''');
    _run({});
  }

  void test_precedence_binary_left_associative() async {
    // Associativity logic is the same for all operators except relational and
    // equality, so we just test `+` as a stand-in for all the others.
    await resolveTestUnit('''
f(a, b, c) => a + b + c;
g(a, b, c) => a + (b + c);
''');
    _run({});
  }

  void test_precedence_binary_relational() async {
    await resolveTestUnit('''
f(a, b, c) => (a < b) < c;
g(a, b, c) => a < (b < c);
''');
    _run({});
  }

  void test_precedence_postfix_and_index() async {
    await resolveTestUnit('''
f(a, b, c) => a[b][c];
g(a, b) => a[b]++;
h(a, b) => (-a)[b];
''');
    _run({});
  }

  void test_precedence_prefix() async {
    await resolveTestUnit('''
f(a) => ~-a;
g(a, b) => -(a*b);
''');
    _run({});
  }

  Object _run(Map<AstNode, Change> changes) {
    // TODO(paulberry): test that redundant parens are allowed in certain
    //  circumstances.
    return FixPlanner.run(testUnit, changes, allowRedundantParens: false);
  }
}
