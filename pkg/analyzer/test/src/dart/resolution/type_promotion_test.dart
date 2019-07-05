// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
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
  /// Resolve the given [code] and track assignments in the unit.
  Future<void> trackCode(String code) async {
    if (await checkTests(
        code, _resultComputer, const _TypePromotionDataComputer())) {
      fail('Failure(s)');
    }
  }

  Future<ResolvedUnitResult> _resultComputer(String code) async {
    addTestFile(code);
    await resolveTestFile();
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

class _TypePromotionDataComputer extends DataComputer<DartType> {
  const _TypePromotionDataComputer();

  @override
  DataInterpreter<DartType> get dataValidator =>
      const _TypePromotionDataInterpreter();

  @override
  void computeUnitData(
      CompilationUnit unit, Map<Id, ActualData<DartType>> actualMap) {
    _TypePromotionDataExtractor(unit.declaredElement.source.uri, actualMap)
        .run(unit);
  }
}

class _TypePromotionDataExtractor extends AstDataExtractor<DartType> {
  _TypePromotionDataExtractor(Uri uri, Map<Id, ActualData<DartType>> actualMap)
      : super(uri, actualMap);

  @override
  DartType computeNodeValue(Id id, AstNode node) {
    if (node is SimpleIdentifier && node.inGetterContext()) {
      var element = node.staticElement;
      if (element is VariableElement &&
          (element is LocalVariableElement || element is ParameterElement)) {
        var promotedType = node.staticType;
        if (promotedType != element.type) {
          return promotedType;
        }
      }
    }
    return null;
  }
}

class _TypePromotionDataInterpreter implements DataInterpreter<DartType> {
  const _TypePromotionDataInterpreter();

  @override
  String getText(DartType actualData) => actualData.toString();

  @override
  String isAsExpected(DartType actualData, String expectedData) {
    if (actualData.toString() == expectedData) {
      return null;
    } else {
      return 'Expected $expectedData, got $actualData';
    }
  }

  @override
  bool isEmpty(DartType actualData) => actualData == null;
}
