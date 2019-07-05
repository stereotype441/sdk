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
  false ? /*unreachable*/ 1 : 2;
}
''');
  }

  test_conditional_true() async {
    await trackCode(r'''
void f() {
  true ? 1 : /*unreachable*/ 2;
}
''');
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
  }

  test_do_true() async {
    await trackCode(r'''
void f() /*functionBody: doesNotComplete*/ { // f
  do {
    1;
  } while (true);
  /*statement: unreachable*/ 2;
}
''');
  }

  test_exit_beforeSplitStatement() async {
    await trackCode(r'''
void f(bool b, int i) /*functionBody: doesNotComplete*/ { // f
  return;
  /*statement: unreachable*/ Object _;
  /*statement: unreachable*/ do {} while (b);
  /*statement: unreachable*/ for (;;) {}
  /*statement: unreachable*/ for (_ in []) {}
  /*statement: unreachable*/ if (b) {}
  /*statement: unreachable*/ switch (i) {}
  /*statement: unreachable*/ try {} finally {}
  /*statement: unreachable*/ while (b) {}
}
''');
  }

  test_for_condition_true() async {
    await trackCode(r'''
void f() /*functionBody: doesNotComplete*/ { // f
  for (; true;) {
    1;
  }
  /*statement: unreachable*/ 2;
}
''');
  }

  test_for_condition_true_implicit() async {
    await trackCode(r'''
void f() /*functionBody: doesNotComplete*/ { // f
  for (;;) {
    1;
  }
  /*statement: unreachable*/ 2;
}
''');
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
  }

  test_functionBody_hasReturn() async {
    await trackCode(r'''
int f() /*functionBody: doesNotComplete*/ { // f
  return 42;
}
''');
  }

  test_functionBody_noReturn() async {
    await trackCode(r'''
void f() {
  1;
}
''');
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
  }

  test_if_false_then_else() async {
    await trackCode(r'''
void f() {
  if (false) /*statement: unreachable*/ { // 1
    1;
  } else { // 2
  }
  3;
}
''');
  }

  test_if_true_return() async {
    await trackCode(r'''
void f() /*functionBody: doesNotComplete*/ { // f
  1;
  if (true) {
    return;
  }
  /*statement: unreachable*/ 2;
}
''');
  }

  test_if_true_then_else() async {
    await trackCode(r'''
void f() {
  if (true) { // 1
  } else /*statement: unreachable*/ { // 2
    2;
  }
  3;
}
''');
  }

  test_logicalAnd_leftFalse() async {
    await trackCode(r'''
void f(int x) {
  false && /*unreachable*/ (x == 1);
}
''');
  }

  test_logicalOr_leftTrue() async {
    await trackCode(r'''
void f(int x) {
  true || /*unreachable*/ (x == 1);
}
''');
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
      /*statement: unreachable*/ 2;
  }
  3;
}
''');
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
  }

  test_tryCatch_return_body() async {
    await trackCode(r'''
void f() {
  try {
    1;
    return;
    /*statement: unreachable*/ 2;
  } catch (_) {
    3;
  }
  4;
}
''');
  }

  test_tryCatch_return_catch() async {
    await trackCode(r'''
void f() {
  try {
    1;
  } catch (_) {
    2;
    return;
    /*statement: unreachable*/ 3;
  }
  4;
}
''');
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
  }

  test_tryCatchFinally_return_bodyCatch() async {
    await trackCode(r'''
void f() /*functionBody: doesNotComplete*/ { // f
  try {
    1;
    return;
  } catch (_) {
    2;
    return;
  } finally {
    3;
  }
  /*statement: unreachable*/ 4;
}
''');
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
  }

  test_tryFinally_return_body() async {
    await trackCode(r'''
void f() /*functionBody: doesNotComplete*/ { // f
  try {
    1;
    return;
  } finally {
    2;
  }
  /*statement: unreachable*/ 3;
}
''');
  }

  test_while_false() async {
    await trackCode(r'''
void f() {
  while (false) /*statement: unreachable*/ { // 1
    1;
  }
  2;
}
''');
  }

  test_while_true() async {
    await trackCode(r'''
void f() /*functionBody: doesNotComplete*/ { // f
  while (true) {
    1;
  }
  /*statement: unreachable*/ 2;
  /*statement: unreachable*/ 3;
}
''');
  }

  test_while_true_break() async {
    await trackCode(r'''
void f() {
  while (true) {
    1;
    break;
    /*statement: unreachable*/ 2;
  }
  3;
}
''');
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
  }

  test_while_true_continue() async {
    await trackCode(r'''
void f() /*functionBody: doesNotComplete*/ { // f
  while (true) {
    1;
    continue;
    /*statement: unreachable*/ 2;
  }
  /*statement: unreachable*/ 3;
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
