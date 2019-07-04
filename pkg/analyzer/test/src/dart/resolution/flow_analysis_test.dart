// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/dart/analysis/experiments.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis_visitor.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../../equivalence/id_equivalence.dart';
import '../../../equivalence/id_equivalence_helper.dart';
import 'driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NullableFlowTest);
    defineReflectiveTests(ReachableFlowTest);
    defineReflectiveTests(TypePromotionFlowTest);
  });
}

class FlowTestBase extends DriverResolutionTest {
  FlowAnalysisResult flowResult;

  /// Resolve the given [code] and track nullability in the unit.
  Future<void> trackCode(String code) async {
    if (await checkTests(
        code, _resultComputer, const _FlowAnalysisDataComputer())) {
      fail('Failure(s)');
    }
  }

  Future<ResolvedUnitResult> _resultComputer(String code) async {
    addTestFile(code);
    await resolveTestFile();
    var unit = result.unit;
    flowResult = FlowAnalysisResult.getFromNode(unit);
    return result;
  }
}

@reflectiveTest
class NullableFlowTest extends FlowTestBase {
  @override
  AnalysisOptionsImpl get analysisOptions =>
      AnalysisOptionsImpl()..enabledExperiments = [EnableString.non_nullable];

  test_assign_toNonNull() async {
    await trackCode(r'''
void f(int x) {
  if (x != null) return;
  /*nullable*/ x; // 1
  x = 0;
  /*nonNullable*/ x; // 2
}
''');
  }

  test_assign_toNull() async {
    await trackCode(r'''
void f(int x) {
  if (x == null) return;
  /*nonNullable*/ x; // 1
  x = null;
  /*nullable*/ x; // 2
}
''');
  }

  test_assign_toUnknown_fromNotNull() async {
    await trackCode(r'''
void f(int a, int b) {
  if (a == null) return;
  /*nonNullable*/ a; // 1
  a = b;
  a; // 2
}
''');
  }

  test_assign_toUnknown_fromNull() async {
    await trackCode(r'''
void f(int a, int b) {
  if (a != null) return;
  /*nullable*/ a; // 1
  a = b;
  a; // 2
}
''');
  }

  test_binaryExpression_logicalAnd() async {
    await trackCode(r'''
void f(int x) {
  x == null && /*nullable*/ x.isEven;
}
''');
  }

  test_binaryExpression_logicalOr() async {
    await trackCode(r'''
void f(int x) {
  x == null || /*nonNullable*/ x.isEven;
}
''');
  }

  test_constructor_if_then_else() async {
    await trackCode(r'''
class C {
  C(int x) {
    if (x == null) {
      /*nullable*/ x; // 1
    } else {
      /*nonNullable*/ x; // 2
    }
  }
}
''');
  }

  test_if_joinThenElse_ifNull() async {
    await trackCode(r'''
void f(int a, int b) {
  if (a == null) {
    /*nullable*/ a; // 1
    if (b == null) return;
    /*nonNullable*/ b; // 2
  } else {
    /*nonNullable*/ a; // 3
    if (b == null) return;
    /*nonNullable*/ b; // 4
  }
  a; // 5
  /*nonNullable*/ b; // 6
}
''');
  }

  test_if_notNull_thenExit_left() async {
    await trackCode(r'''
void f(int x) {
  if (null != x) return;
  /*nullable*/ x; // 1
}
''');
  }

  test_if_notNull_thenExit_right() async {
    await trackCode(r'''
void f(int x) {
  if (x != null) return;
  /*nullable*/ x; // 1
}
''');
  }

  test_if_null_thenExit_left() async {
    await trackCode(r'''
void f(int x) {
  if (null == x) return;
  /*nonNullable*/ x; // 1
}
''');
  }

  test_if_null_thenExit_right() async {
    await trackCode(r'''
void f(int x) {
  if (x == null) return;
  /*nonNullable*/ x; // 1
}
''');
  }

  test_if_then_else() async {
    await trackCode(r'''
void f(int x) {
  if (x == null) {
    /*nullable*/ x; // 1
  } else {
    /*nonNullable*/ x; // 2
  }
}
''');
  }

  test_method_if_then_else() async {
    await trackCode(r'''
class C {
  void f(int x) {
    if (x == null) {
      /*nullable*/ x; // 1
    } else {
      /*nonNullable*/ x; // 2
    }
  }
}
''');
  }

  test_potentiallyMutatedInClosure() async {
    await trackCode(r'''
f(int a, int b) {
  localFunction() {
    a = b;
  }

  if (a == null) {
    a; // 1
    localFunction();
    a; // 2
  }
}
''');
  }

  test_tryFinally_eqNullExit_body() async {
    await trackCode(r'''
void f(int x) {
  try {
    if (x == null) return;
    /*nonNullable*/ x; // 1
  } finally {
    x; // 2
  }
  /*nonNullable*/ x; // 3
}
''');
  }

  test_tryFinally_eqNullExit_finally() async {
    await trackCode(r'''
void f(int x) {
  try {
    x; // 1
  } finally {
    if (x == null) return;
    /*nonNullable*/ x; // 2
  }
  /*nonNullable*/ x; // 3
}
''');
  }

  test_tryFinally_outerEqNotNullExit_assignUnknown_body() async {
    await trackCode(r'''
void f(int a, int b) {
  if (a != null) return;
  try {
    /*nullable*/ a; // 1
    a = b;
    a; // 2
  } finally {
    a; // 3
  }
  a; // 4
}
''');
  }

  test_tryFinally_outerEqNullExit_assignUnknown_body() async {
    await trackCode(r'''
void f(int a, int b) {
  if (a == null) return;
  try {
    /*nonNullable*/ a; // 1
    a = b;
    a; // 2
  } finally {
    a; // 3
  }
  a; // 4
}
''');
  }

  test_tryFinally_outerEqNullExit_assignUnknown_finally() async {
    await trackCode(r'''
void f(int a, int b) {
  if (a == null) return;
  try {
    /*nonNullable*/ a; // 1
  } finally {
    /*nonNullable*/ a; // 2
    a = b;
    a; // 3
  }
  a; // 4
}
''');
  }

  test_while_eqNull() async {
    await trackCode(r'''
void f(int x) {
  while (x == null) {
    /*nullable*/ x; // 1
  }
  /*nonNullable*/ x; // 2
}
''');
  }

  test_while_notEqNull() async {
    await trackCode(r'''
void f(int x) {
  while (x != null) {
    /*nonNullable*/ x; // 1
  }
  /*nullable*/ x; // 2
}
''');
  }
}

@reflectiveTest
class ReachableFlowTest extends FlowTestBase {
  @override
  AnalysisOptionsImpl get analysisOptions =>
      AnalysisOptionsImpl()..enabledExperiments = [EnableString.non_nullable];

  test_conditional_false() async {
    await trackCode(r'''
void f() {
  false ? 1 : 2;
}
''');
    verify(unreachableExpressions: ['1']);
  }

  test_conditional_true() async {
    await trackCode(r'''
void f() {
  true ? 1 : 2;
}
''');
    verify(unreachableExpressions: ['2']);
  }

  test_do_false() async {
    await trackCode(r'''
void f() {
  do {
    1;
  } while (false);
  2;
}
''');
    verify();
  }

  test_do_true() async {
    await trackCode(r'''
void f() { // f
  do {
    1;
  } while (true);
  2;
}
''');
    verify(
      unreachableStatements: ['2;'],
      functionBodiesThatDontComplete: ['{ // f'],
    );
  }

  test_exit_beforeSplitStatement() async {
    await trackCode(r'''
void f(bool b, int i) { // f
  return;
  Object _;
  do {} while (b);
  for (;;) {}
  for (_ in []) {}
  if (b) {}
  switch (i) {}
  try {} finally {}
  while (b) {}
}
''');
    verify(
      unreachableStatements: [
        'Object _',
        'do {}',
        'for (;;',
        'for (_',
        'if (b)',
        'try {',
        'switch (i)',
        'while (b) {}'
      ],
      functionBodiesThatDontComplete: ['{ // f'],
    );
  }

  test_for_condition_true() async {
    await trackCode(r'''
void f() { // f
  for (; true;) {
    1;
  }
  2;
}
''');
    verify(
      unreachableStatements: ['2;'],
      functionBodiesThatDontComplete: ['{ // f'],
    );
  }

  test_for_condition_true_implicit() async {
    await trackCode(r'''
void f() { // f
  for (;;) {
    1;
  }
  2;
}
''');
    verify(
      unreachableStatements: ['2;'],
      functionBodiesThatDontComplete: ['{ // f'],
    );
  }

  test_forEach() async {
    await trackCode(r'''
void f() {
  Object _;
  for (_ in [0, 1, 2]) {
    1;
    return;
  }
  2;
}
''');
    verify();
  }

  test_functionBody_hasReturn() async {
    await trackCode(r'''
int f() { // f
  return 42;
}
''');
    verify(functionBodiesThatDontComplete: ['{ // f']);
  }

  test_functionBody_noReturn() async {
    await trackCode(r'''
void f() {
  1;
}
''');
    verify();
  }

  test_if_condition() async {
    await trackCode(r'''
void f(bool b) {
  if (b) {
    1;
  } else {
    2;
  }
  3;
}
''');
    verify();
  }

  test_if_false_then_else() async {
    await trackCode(r'''
void f() {
  if (false) { // 1
    1;
  } else { // 2
  }
  3;
}
''');
    verify(unreachableStatements: ['{ // 1']);
  }

  test_if_true_return() async {
    await trackCode(r'''
void f() { // f
  1;
  if (true) {
    return;
  }
  2;
}
''');
    verify(
      unreachableStatements: ['2;'],
      functionBodiesThatDontComplete: ['{ // f'],
    );
  }

  test_if_true_then_else() async {
    await trackCode(r'''
void f() {
  if (true) { // 1
  } else { // 2
    2;
  }
  3;
}
''');
    verify(unreachableStatements: ['{ // 2']);
  }

  test_logicalAnd_leftFalse() async {
    await trackCode(r'''
void f(int x) {
  false && (x == 1);
}
''');
    verify(unreachableExpressions: ['(x == 1)']);
  }

  test_logicalOr_leftTrue() async {
    await trackCode(r'''
void f(int x) {
  true || (x == 1);
}
''');
    verify(unreachableExpressions: ['(x == 1)']);
  }

  test_switch_case_neverCompletes() async {
    await trackCode(r'''
void f(bool b, int i) {
  switch (i) {
    case 1:
      1;
      if (b) {
        return;
      } else {
        return;
      }
      2;
  }
  3;
}
''');
    verify(unreachableStatements: ['2;']);
  }

  test_tryCatch() async {
    await trackCode(r'''
void f() {
  try {
    1;
  } catch (_) {
    2;
  }
  3;
}
''');
    verify();
  }

  test_tryCatch_return_body() async {
    await trackCode(r'''
void f() {
  try {
    1;
    return;
    2;
  } catch (_) {
    3;
  }
  4;
}
''');
    verify(unreachableStatements: ['2;']);
  }

  test_tryCatch_return_catch() async {
    await trackCode(r'''
void f() {
  try {
    1;
  } catch (_) {
    2;
    return;
    3;
  }
  4;
}
''');
    verify(unreachableStatements: ['3;']);
  }

  test_tryCatchFinally_return_body() async {
    await trackCode(r'''
void f() {
  try {
    1;
    return;
  } catch (_) {
    2;
  } finally {
    3;
  }
  4;
}
''');
    verify();
  }

  test_tryCatchFinally_return_bodyCatch() async {
    await trackCode(r'''
void f() { // f
  try {
    1;
    return;
  } catch (_) {
    2;
    return;
  } finally {
    3;
  }
  4;
}
''');
    verify(
      unreachableStatements: ['4;'],
      functionBodiesThatDontComplete: ['{ // f'],
    );
  }

  test_tryCatchFinally_return_catch() async {
    await trackCode(r'''
void f() {
  try {
    1;
  } catch (_) {
    2;
    return;
  } finally {
    3;
  }
  4;
}
''');
    verify();
  }

  test_tryFinally_return_body() async {
    await trackCode(r'''
void f() { // f
  try {
    1;
    return;
  } finally {
    2;
  }
  3;
}
''');
    verify(
      unreachableStatements: ['3;'],
      functionBodiesThatDontComplete: ['{ // f'],
    );
  }

  test_while_false() async {
    await trackCode(r'''
void f() {
  while (false) { // 1
    1;
  }
  2;
}
''');
    verify(unreachableStatements: ['{ // 1']);
  }

  test_while_true() async {
    await trackCode(r'''
void f() { // f
  while (true) {
    1;
  }
  2;
  3;
}
''');
    verify(
      unreachableStatements: ['2;', '3;'],
      functionBodiesThatDontComplete: ['{ // f'],
    );
  }

  test_while_true_break() async {
    await trackCode(r'''
void f() {
  while (true) {
    1;
    break;
    2;
  }
  3;
}
''');
    verify(unreachableStatements: ['2;']);
  }

  test_while_true_breakIf() async {
    await trackCode(r'''
void f(bool b) {
  while (true) {
    1;
    if (b) break;
    2;
  }
  3;
}
''');
    verify();
  }

  test_while_true_continue() async {
    await trackCode(r'''
void f() { // f
  while (true) {
    1;
    continue;
    2;
  }
  3;
}
''');
    verify(
      unreachableStatements: ['2;', '3;'],
      functionBodiesThatDontComplete: ['{ // f'],
    );
  }

  void verify({
    List<String> unreachableExpressions = const [],
    List<String> unreachableStatements = const [],
    List<String> functionBodiesThatDontComplete = const [],
  }) {
    var expectedUnreachableNodes = <AstNode>[];
    expectedUnreachableNodes.addAll(
      unreachableStatements.map((search) => findNode.statement(search)),
    );
    expectedUnreachableNodes.addAll(
      unreachableExpressions.map((search) => findNode.expression(search)),
    );

    expect(
      flowResult.unreachableNodes,
      unorderedEquals(expectedUnreachableNodes),
    );
    expect(
      flowResult.functionBodiesThatDontComplete,
      unorderedEquals(
        functionBodiesThatDontComplete
            .map((search) => findNode.functionBody(search))
            .toList(),
      ),
    );
  }
}

@reflectiveTest
class TypePromotionFlowTest extends FlowTestBase {
  @override
  AnalysisOptionsImpl get analysisOptions =>
      AnalysisOptionsImpl()..enabledExperiments = [EnableString.non_nullable];

  test_assignment() async {
    await trackCode(r'''
f(Object x) {
  if (x is String) {
    x = 42;
    /*nonNullable*/ x; // 1
  }
}
''');
  }

  test_binaryExpression_ifNull() async {
    await trackCode(r'''
void f(Object x) {
  ((x is num) || (throw 1)) ?? ((/*promoted*/ x is int) || (throw 2));
  /*promoted*/ x; // 1
}
''');
  }

  test_binaryExpression_ifNull_rightUnPromote() async {
    await trackCode(r'''
void f(Object x, Object y, Object z) {
  if (x is int) {
    /*promoted*/ x; // 1
    y ?? (x = z);
    x; // 2
  }
}
''');
  }

  test_conditional_both() async {
    await trackCode(r'''
void f(bool b, Object x) {
  b ? ((x is num) || (throw 1)) : ((x is int) || (throw 2));
  /*promoted*/ x; // 1
}
''');
  }

  test_conditional_else() async {
    await trackCode(r'''
void f(bool b, Object x) {
  b ? 0 : ((x is int) || (throw 2));
  x; // 1
}
''');
  }

  test_conditional_then() async {
    await trackCode(r'''
void f(bool b, Object x) {
  b ? ((x is num) || (throw 1)) : 0;
  x; // 1
}
''');
  }

  test_do_condition_isNotType() async {
    await trackCode(r'''
void f(Object x) {
  do {
    x; // 1
    x = '';
  } while (/*nonNullable*/ x is! String);
  /*nonNullable,promoted*/ x; // 2
}
''');
  }

  test_do_condition_isType() async {
    await trackCode(r'''
void f(Object x) {
  do {
    x; // 1
  } while (x is String);
  x; // 2
}
''');
  }

  test_do_outerIsType() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (x is String) {
    do {
      /*promoted*/ x; // 1
    } while (b);
    /*promoted*/ x; // 2
  }
}
''');
  }

  test_do_outerIsType_loopAssigned_body() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (x is String) {
    do {
      x; // 1
      x = x.length;
    } while (b);
    x; // 2
  }
}
''');
  }

  test_do_outerIsType_loopAssigned_condition() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (x is String) {
    do {
      x; // 1
      x = x.length;
    } while (x != 0);
    x; // 2
  }
}
''');
  }

  test_do_outerIsType_loopAssigned_condition2() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (x is String) {
    do {
      x; // 1
    } while ((x = 1) != 0);
    /*nonNullable*/ x; // 2
  }
}
''');
  }

  test_for_outerIsType() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (x is String) {
    for (; b;) {
      /*promoted*/ x; // 1
    }
    /*promoted*/ x; // 2
  }
}
''');
  }

  test_for_outerIsType_loopAssigned_body() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (x is String) {
    for (; b;) {
      x; // 1
      x = 42;
    }
    x; // 2
  }
}
''');
  }

  test_for_outerIsType_loopAssigned_condition() async {
    await trackCode(r'''
void f(Object x) {
  if (x is String) {
    for (; (x = 42) > 0;) {
      /*nonNullable*/ x; // 1
    }
    /*nonNullable*/ x; // 2
  }
}
''');
  }

  test_for_outerIsType_loopAssigned_updaters() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (x is String) {
    for (; b; x = 42) {
      x; // 1
    }
    x; // 2
  }
}
''');
  }

  test_forEach_outerIsType_loopAssigned() async {
    await trackCode(r'''
void f(Object x) {
  Object v1;
  if (x is String) {
    for (var _ in (v1 = [0, 1, 2])) {
      x; // 1
      x = 42;
    }
    x; // 2
  }
}
''');
  }

  test_functionExpression_isType() async {
    await trackCode(r'''
void f() {
  void g(Object x) {
    if (x is String) {
      /*promoted*/ x; // 1
    }
    x = 42;
  }
}
''');
  }

  test_functionExpression_isType_mutatedInClosure2() async {
    await trackCode(r'''
void f() {
  void g(Object x) {
    if (x is String) {
      x; // 1
    }
    
    void h() {
      x = 42;
    }
  }
}
''');
  }

  test_functionExpression_outerIsType_assignedOutside() async {
    await trackCode(r'''
void f(Object x) {
  void Function() g;
  
  if (x is String) {
    /*promoted*/ x; // 1

    g = () {
      x; // 2
    };
  }

  x = 42;
  /*nonNullable*/ x; // 3
  g();
}
''');
  }

  test_if_combine_empty() async {
    await trackCode(r'''
main(bool b, Object v) {
  if (b) {
    v is int || (throw 1);
  } else {
    v is String || (throw 2);
  }
  v; // 3
}
''');
  }

  test_if_conditional_isNotType() async {
    await trackCode(r'''
f(bool b, Object v) {
  if (b ? (v is! int) : (v is! num)) {
    v; // 1
  } else {
    /*promoted*/ v; // 2
  }
  v; // 3
}
''');
  }

  test_if_conditional_isType() async {
    await trackCode(r'''
f(bool b, Object v) {
  if (b ? (v is int) : (v is num)) {
    /*promoted*/ v; // 1
  } else {
    v; // 2
  }
  v; // 3
}
''');
  }

  test_if_isNotType() async {
    await trackCode(r'''
main(v) {
  if (v is! String) {
    v; // 1
  } else {
    /*promoted*/ v; // 2
  }
  v; // 3
}
''');
  }

  test_if_isNotType_return() async {
    await trackCode(r'''
main(v) {
  if (v is! String) return;
  /*promoted*/ v; // ref
}
''');
  }

  test_if_isNotType_throw() async {
    await trackCode(r'''
main(v) {
  if (v is! String) throw 42;
  /*promoted*/ v; // ref
}
''');
  }

  test_if_isType() async {
    await trackCode(r'''
main(v) {
  if (v is String) {
    /*promoted*/ v; // 1
  } else {
    v; // 2
  }
  v; // 3
}
''');
  }

  test_if_isType_thenNonBoolean() async {
    await trackCode(r'''
f(Object x) {
  if ((x is String) != 3) {
    x; // 1
  }
}
''');
  }

  test_if_logicalNot_isType() async {
    await trackCode(r'''
main(v) {
  if (!(v is String)) {
    v; // 1
  } else {
    /*promoted*/ v; // 2
  }
  v; // 3
}
''');
  }

  test_if_then_isNotType_return() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (b) {
    if (x is! String) return;
  }
  x; // 1
}
''');
  }

  test_logicalOr_throw() async {
    await trackCode(r'''
main(v) {
  v is String || (throw 42);
  /*promoted*/ v; // ref
}
''');
  }

  test_potentiallyMutatedInClosure() async {
    await trackCode(r'''
f(Object x) {
  localFunction() {
    x = 42;
  }

  if (x is String) {
    localFunction();
    x; // 1
  }
}
''');
  }

  test_potentiallyMutatedInScope() async {
    await trackCode(r'''
f(Object x) {
  if (x is String) {
    /*promoted*/ x; // 1
  }

  x = 42;
}
''');
  }

  test_switch_outerIsType_assignedInCase() async {
    await trackCode(r'''
void f(int e, Object x) {
  if (x is String) {
    switch (e) {
      L: case 1:
        x; // 1
        break;
      case 2: // no label
        /*promoted*/ x; // 2
        break;
      case 3:
        x = 42;
        continue L;
    }
    x; // 3
  }
}
''');
  }

  test_tryCatch_assigned_body() async {
    await trackCode(r'''
void f(Object x) {
  if (x is! String) return;
  /*promoted*/ x; // 1
  try {
    x = 42;
    g(); // might throw
    if (/*nonNullable*/ x is! String) return;
    /*nonNullable,promoted*/ x; // 2
  } catch (_) {}
  x; // 3
}

void g() {}
''');
  }

  test_tryCatch_isNotType_exit_body() async {
    await trackCode(r'''
void f(Object x) {
  try {
    if (x is! String) return;
    /*promoted*/ x; // 1
  } catch (_) {}
  x; // 2
}

void g() {}
''');
  }

  test_tryCatch_isNotType_exit_body_catch() async {
    await trackCode(r'''
void f(Object x) {
  try {
    if (x is! String) return;
    /*promoted*/ x; // 1
  } catch (_) {
    if (x is! String) return;
    /*promoted*/ x; // 2
  }
  /*promoted*/ x; // 3
}

void g() {}
''');
  }

  test_tryCatch_isNotType_exit_body_catchRethrow() async {
    await trackCode(r'''
void f(Object x) {
  try {
    if (x is! String) return;
    /*promoted*/ x; // 1
  } catch (_) {
    x; // 2
    rethrow;
  }
  /*promoted*/ x; // 3
}

void g() {}
''');
  }

  test_tryCatch_isNotType_exit_catch() async {
    await trackCode(r'''
void f(Object x) {
  try {
  } catch (_) {
    if (x is! String) return;
    /*promoted*/ x; // 1
  }
  x; // 2
}

void g() {}
''');
  }

  test_tryCatchFinally_outerIsType() async {
    await trackCode(r'''
void f(Object x) {
  if (x is String) {
    try {
      /*promoted*/ x; // 1
    } catch (_) {
      /*promoted*/ x; // 2
    } finally {
      /*promoted*/ x; // 3
    }
    /*promoted*/ x; // 4
  }
}

void g() {}
''');
  }

  test_tryCatchFinally_outerIsType_assigned_body() async {
    await trackCode(r'''
void f(Object x) {
  if (x is String) {
    try {
      /*promoted*/ x; // 1
      x = 42;
      g();
    } catch (_) {
      x; // 2
    } finally {
      x; // 3
    }
    x; // 4
  }
}

void g() {}
''');
  }

  test_tryCatchFinally_outerIsType_assigned_catch() async {
    await trackCode(r'''
void f(Object x) {
  if (x is String) {
    try {
      /*promoted*/ x; // 1
    } catch (_) {
      /*promoted*/ x; // 2
      x = 42;
    } finally {
      x; // 3
    }
    x; // 4
  }
}
''');
  }

  test_tryFinally_outerIsType_assigned_body() async {
    await trackCode(r'''
void f(Object x) {
  if (x is String) {
    try {
      /*promoted*/ x; // 1
      x = 42;
    } finally {
      x; // 2
    }
    /*nonNullable*/ x; // 3
  }
}
''');
  }

  test_tryFinally_outerIsType_assigned_finally() async {
    await trackCode(r'''
void f(Object x) {
  if (x is String) {
    try {
      /*promoted*/ x; // 1
    } finally {
      /*promoted*/ x; // 2
      x = 42;
    }
    /*nonNullable*/ x; // 3
  }
}
''');
  }

  test_while_condition_false() async {
    await trackCode(r'''
void f(Object x) {
  while (x is! String) {
    x; // 1
  }
  /*promoted*/ x; // 2
}
''');
  }

  test_while_condition_true() async {
    await trackCode(r'''
void f(Object x) {
  while (x is String) {
    /*promoted*/ x; // 1
  }
  x; // 2
}
''');
  }

  test_while_outerIsType() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (x is String) {
    while (b) {
      /*promoted*/ x; // 1
    }
    /*promoted*/ x; // 2
  }
}
''');
  }

  test_while_outerIsType_loopAssigned_body() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (x is String) {
    while (b) {
      x; // 1
      x = x.length;
    }
    x; // 2
  }
}
''');
  }

  test_while_outerIsType_loopAssigned_condition() async {
    await trackCode(r'''
void f(bool b, Object x) {
  if (x is String) {
    while (x != 0) {
      x; // 1
      x = x.length;
    }
    x; // 2
  }
}
''');
  }
}

class _FlowAnalysisDataComputer extends DataComputer<Set<_FlowAssertion>> {
  const _FlowAnalysisDataComputer();

  @override
  DataInterpreter<Set<_FlowAssertion>> get dataValidator =>
      const _FlowAnalysisDataInterpreter();

  @override
  void computeUnitData(CompilationUnit unit,
      Map<Id, ActualData<Set<_FlowAssertion>>> actualMap) {
    var flowResult = FlowAnalysisResult.getFromNode(unit);
    _FlowAnalysisDataExtractor(
            unit.declaredElement.source.uri, actualMap, flowResult)
        .run(unit);
  }
}

class _FlowAnalysisDataExtractor extends AstDataExtractor<Set<_FlowAssertion>> {
  FlowAnalysisResult _flowResult;

  _FlowAnalysisDataExtractor(Uri uri,
      Map<Id, ActualData<Set<_FlowAssertion>>> actualMap, this._flowResult)
      : super(uri, actualMap);

  @override
  Set<_FlowAssertion> computeNodeValue(Id id, AstNode node) {
    Set<_FlowAssertion> result = {};
    if (_flowResult.nullableNodes.contains(node)) {
      // We sometimes erroneously annotate a node as both nullable and
      // non-nullable.  Ignore for now.  TODO(paulberry): fix this.
      if (!_flowResult.nonNullableNodes.contains(node)) {
        result.add(_FlowAssertion.nullable);
      }
    }
    if (_flowResult.nonNullableNodes.contains(node)) {
      // We sometimes erroneously annotate a node as both nullable and
      // non-nullable.  Ignore for now.  TODO(paulberry): fix this.
      if (!_flowResult.nullableNodes.contains(node)) {
        result.add(_FlowAssertion.nonNullable);
      }
    }
    if (_flowResult.unreachableNodes.contains(node)) {
      result.add(_FlowAssertion.unreachable);
    }
    if (_flowResult.functionBodiesThatDontComplete.contains(node)) {
      result.add(_FlowAssertion.doesNotComplete);
    }
    if (_flowResult.promotedTypes.containsKey(node)) {
      result.add(_FlowAssertion.promoted);
    }
    return result.isEmpty ? null : result;
  }
}

class _FlowAnalysisDataInterpreter
    implements DataInterpreter<Set<_FlowAssertion>> {
  const _FlowAnalysisDataInterpreter();

  @override
  String getText(Set<_FlowAssertion> actualData) =>
      _sortedRepresentation(_toStrings(actualData));

  @override
  String isAsExpected(Set<_FlowAssertion> actualData, String expectedData) {
    var actualStrings = _toStrings(actualData);
    var actualSorted = _sortedRepresentation(actualStrings);
    var expectedSorted = _sortedRepresentation(expectedData?.split(','));
    if (actualSorted == expectedSorted) {
      return null;
    } else {
      return 'Expected $expectedData, got $actualSorted';
    }
  }

  @override
  bool isEmpty(Set<_FlowAssertion> actualData) => actualData.isEmpty;

  String _sortedRepresentation(Iterable<String> values) {
    var list = values == null || values.isEmpty ? ['none'] : values.toList();
    list.sort();
    return list.join(',');
  }

  List<String> _toStrings(Set<_FlowAssertion> actualData) => actualData
      .map((flowAssertion) => flowAssertion.toString().split('.')[1])
      .toList();
}

enum _FlowAssertion {
  doesNotComplete,
  nonNullable,
  nullable,
  promoted,
  unreachable,
}
