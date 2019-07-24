// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/util/ast_data_extractor.dart';
import 'package:front_end/src/testing/id.dart' show ActualData, Id;
import 'package:front_end/src/testing/id_testing.dart' show DataInterpreter;
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../../util/id_testing_helper.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TypePromotionTest);
  });
}

@reflectiveTest
class TypePromotionTest {
  Future<void> resolveCode(String code) async {
    if (await checkTests(
        code,
        const _TypePromotionDataComputer(),
        FeatureSet.forTesting(
            sdkVersion: '2.2.2', additionalFeatures: [Feature.non_nullable]))) {
      fail('Failure(s)');
    }
  }

  test_assignment() async {
    await resolveCode(r'''
''');
  }

  test_binaryExpression_ifNull() async {
    await resolveCode(r'''
''');
  }

  test_binaryExpression_ifNull_rightUnPromote() async {
    await resolveCode(r'''
''');
  }

  test_conditional_both() async {
    await resolveCode(r'''
''');
  }

  test_conditional_else() async {
    await resolveCode(r'''
''');
  }

  test_conditional_then() async {
    await resolveCode(r'''
''');
  }

  test_do_condition_isNotType() async {
    await resolveCode(r'''
''');
  }

  test_do_condition_isType() async {
    await resolveCode(r'''
''');
  }

  test_do_outerIsType() async {
    await resolveCode(r'''
''');
  }

  test_do_outerIsType_loopAssigned_body() async {
    await resolveCode(r'''
''');
  }

  test_do_outerIsType_loopAssigned_condition() async {
    await resolveCode(r'''
''');
  }

  test_do_outerIsType_loopAssigned_condition2() async {
    await resolveCode(r'''
''');
  }

  test_for_declaredVar() async {
    await resolveCode(r'''
''');
  }

  test_for_outerIsType() async {
    await resolveCode(r'''
''');
  }

  test_for_outerIsType_loopAssigned_body() async {
    await resolveCode(r'''
''');
  }

  test_for_outerIsType_loopAssigned_condition() async {
    await resolveCode(r'''
''');
  }

  test_for_outerIsType_loopAssigned_updaters() async {
    await resolveCode(r'''
''');
  }

  test_forEach_outerIsType_loopAssigned() async {
    await resolveCode(r'''
''');
  }

  test_functionExpression_isType() async {
    await resolveCode(r'''
''');
  }

  test_functionExpression_isType_mutatedInClosure2() async {
    await resolveCode(r'''
''');
  }

  test_functionExpression_outerIsType_assignedOutside() async {
    await resolveCode(r'''
''');
  }

  test_if_combine_empty() async {
    await resolveCode(r'''
''');
  }

  test_if_conditional_isNotType() async {
    await resolveCode(r'''
''');
  }

  test_if_conditional_isType() async {
    await resolveCode(r'''
''');
  }

  test_if_isNotType() async {
    await resolveCode(r'''
''');
  }

  test_if_isNotType_return() async {
    await resolveCode(r'''
''');
  }

  test_if_isNotType_throw() async {
    await resolveCode(r'''
''');
  }

  test_if_isType() async {
    await resolveCode(r'''
''');
  }

  test_if_isType_thenNonBoolean() async {
    await resolveCode(r'''
''');
  }

  test_if_logicalNot_isType() async {
    await resolveCode(r'''
''');
  }

  test_if_then_isNotType_return() async {
    await resolveCode(r'''
''');
  }

  test_logicalOr_throw() async {
    await resolveCode(r'''
''');
  }

  test_null_check_does_not_promote_non_nullable_type() async {
    await resolveCode(r'''
''');
  }

  test_null_check_promotes_nullable_type() async {
    await resolveCode(r'''
''');
  }

  test_potentiallyMutatedInClosure() async {
    await resolveCode(r'''
''');
  }

  test_potentiallyMutatedInScope() async {
    await resolveCode(r'''
''');
  }

  test_switch_outerIsType_assignedInCase() async {
    await resolveCode(r'''
''');
  }

  test_tryCatch_assigned_body() async {
    await resolveCode(r'''
''');
  }

  test_tryCatch_isNotType_exit_body() async {
    await resolveCode(r'''
''');
  }

  test_tryCatch_isNotType_exit_body_catch() async {
    await resolveCode(r'''
''');
  }

  test_tryCatch_isNotType_exit_body_catchRethrow() async {
    await resolveCode(r'''
''');
  }

  test_tryCatch_isNotType_exit_catch() async {
    await resolveCode(r'''
''');
  }

  test_tryCatchFinally_outerIsType() async {
    await resolveCode(r'''
''');
  }

  test_tryCatchFinally_outerIsType_assigned_body() async {
    await resolveCode(r'''
''');
  }

  test_tryCatchFinally_outerIsType_assigned_catch() async {
    await resolveCode(r'''
''');
  }

  test_tryFinally_outerIsType_assigned_body() async {
    await resolveCode(r'''
''');
  }

  test_tryFinally_outerIsType_assigned_finally() async {
    await resolveCode(r'''
''');
  }

  test_while_condition_false() async {
    await resolveCode(r'''
''');
  }

  test_while_condition_true() async {
    await resolveCode(r'''
''');
  }

  test_while_outerIsType() async {
    await resolveCode(r'''
''');
  }

  test_while_outerIsType_loopAssigned_body() async {
    await resolveCode(r'''
''');
  }

  test_while_outerIsType_loopAssigned_condition() async {
    await resolveCode(r'''
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
      if (element is LocalVariableElement || element is ParameterElement) {
        TypeImpl promotedType = node.staticType;
        TypeImpl declaredType = (element as VariableElement).type;
        // TODO(paulberry): once type equality has been updated to account for
        // nullability, isPromoted should just be
        // `promotedType != declaredType`.  See dartbug.com/37587.
        var isPromoted = promotedType != declaredType ||
            promotedType.nullabilitySuffix != declaredType.nullabilitySuffix;
        if (isPromoted) {
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
