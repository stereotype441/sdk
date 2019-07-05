// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/analysis/experiments.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../../equivalence/id_equivalence.dart';
import '../../../equivalence/id_equivalence_helper.dart';
import 'driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TypePromotionTest);
  });
}

class FlowTestBase extends DriverResolutionTest {
  FlowAnalysisResult flowResult;

  /// Resolve the given [code] and track assignments in the unit.
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
class TypePromotionTest extends FlowTestBase {
  @override
  AnalysisOptionsImpl get analysisOptions =>
      AnalysisOptionsImpl()..enabledExperiments = [EnableString.non_nullable];

  Future<void> resolveCode(String code) async {
    addTestFile(code);
    await resolveTestFile();
  }

  test_assignment() async {
    await resolveCode(r'''
f(Object x) {
  if (x is String) {
    x = 42;
    /*nonNullable*/ x; // 1
  }
}
''');
  }

  test_binaryExpression_ifNull() async {
    await resolveCode(r'''
void f(Object x) {
  ((x is num) || (throw 1)) ?? ((/*promoted*/ x is int) || (throw 2));
  /*promoted*/ x; // 1
}
''');
  }

  test_binaryExpression_ifNull_rightUnPromote() async {
    await resolveCode(r'''
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
    await resolveCode(r'''
void f(bool b, Object x) {
  b ? ((x is num) || (throw 1)) : ((x is int) || (throw 2));
  /*promoted*/ x; // 1
}
''');
  }

  test_conditional_else() async {
    await resolveCode(r'''
void f(bool b, Object x) {
  b ? 0 : ((x is int) || (throw 2));
  x; // 1
}
''');
  }

  test_conditional_then() async {
    await resolveCode(r'''
void f(bool b, Object x) {
  b ? ((x is num) || (throw 1)) : 0;
  x; // 1
}
''');
  }

  test_do_condition_isNotType() async {
    await resolveCode(r'''
void f(Object x) {
  do {
    x; // 1
  } while (/*nonNullable*/ x is! String);
  /*nonNullable,promoted*/ x; // 2
}
''');
  }

  test_do_condition_isType() async {
    await resolveCode(r'''
void f(Object x) {
  do {
    x; // 1
  } while (x is String);
  x; // 2
}
''');
  }

  test_do_outerIsType() async {
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
main(v) {
  if (v is! String) return;
  /*promoted*/ v; // ref
}
''');
  }

  test_if_isNotType_throw() async {
    await resolveCode(r'''
main(v) {
  if (v is! String) throw 42;
  /*promoted*/ v; // ref
}
''');
  }

  test_if_isType() async {
    await resolveCode(r'''
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
    await resolveCode(r'''
f(Object x) {
  if ((x is String) != 3) {
    x; // 1
  }
}
''');
  }

  test_if_logicalNot_isType() async {
    await resolveCode(r'''
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
    await resolveCode(r'''
void f(bool b, Object x) {
  if (b) {
    if (x is! String) return;
  }
  x; // 1
}
''');
  }

  test_logicalOr_throw() async {
    await resolveCode(r'''
main(v) {
  v is String || (throw 42);
  /*promoted*/ v; // ref
}
''');
  }

  test_potentiallyMutatedInClosure() async {
    await resolveCode(r'''
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
    await resolveCode(r'''
f(Object x) {
  if (x is String) {
    /*promoted*/ x; // 1
  }

  x = 42;
}
''');
  }

  test_switch_outerIsType_assignedInCase() async {
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
void f(Object x) {
  while (x is! String) {
    x; // 1
  }
  /*promoted*/ x; // 2
}
''');
  }

  test_while_condition_true() async {
    await resolveCode(r'''
void f(Object x) {
  while (x is String) {
    /*promoted*/ x; // 1
  }
  x; // 2
}
''');
  }

  test_while_outerIsType() async {
    await resolveCode(r'''
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
    await resolveCode(r'''
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
    await resolveCode(r'''
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
