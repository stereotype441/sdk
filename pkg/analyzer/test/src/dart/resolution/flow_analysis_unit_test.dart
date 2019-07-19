// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/src/dart/analysis/experiments.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis_visitor.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/util/ast_data_extractor.dart';
import 'package:front_end/src/testing/id.dart' show ActualData, Id;
import 'package:front_end/src/testing/id_testing.dart' show DataInterpreter;
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../../util/id_testing_helper.dart';
import 'driver_resolution.dart';

class _Statement {}

class _Expression {}

class _Element {}

class _Type {}

class _NodeOperations implements NodeOperations<_Expression> {
  @override
  _Expression unwrapParenthesized(_Expression node) {
    throw UnimplementedError('TODO(paulberry)');
  }
}

class _TypeOperations implements TypeOperations<_Element, _Type> {
  @override
  _Type elementType(_Element element) {
    throw UnimplementedError('TODO(paulberry)');
  }

  @override
  bool isLocalVariable(_Element element) {
    throw UnimplementedError('TODO(paulberry)');
  }

  @override
  bool isSubtypeOf(_Type leftType, _Type rightType) {
    throw UnimplementedError('TODO(paulberry)');
  }

  @override
  _Type promoteToNonNull(_Type type) {
    throw UnimplementedError('TODO(paulberry)');
  }
}

class _FunctionBodyAccess implements FunctionBodyAccess<_Expression> {
  @override
  bool isPotentiallyMutatedInClosure(_Expression variable) {
    throw UnimplementedError('TODO(paulberry)');
  }

  @override
  bool isPotentiallyMutatedInScope(_Expression variable) {
    throw UnimplementedError('TODO(paulberry)');
  }
}

main() {
  group('Flow analysis unit tests', () {
    test('foo', () {
      var nodeOperations = _NodeOperations();
      var typeOperations = _TypeOperations();
      var functionBodyAccess = _FunctionBodyAccess();
      var flow = FlowAnalysis<_Statement, _Expression, _Element, _Type>(nodeOperations, typeOperations, functionBodyAccess);
      var x = _Element();
      flow.add(x, assigned: true);
      var xNotEqNull = _Expression();
      flow.conditionNotEqNull(xNotEqNull, x);
      flow.ifStatement_thenBegin(xNotEqNull);
      flow.handleExit();
      flow.ifStatement_end(false);
      var xPromotedType = flow.promotedType(x);
      fail('$xPromotedType');
      flow.verifyStackEmpty();
    });
  });
}