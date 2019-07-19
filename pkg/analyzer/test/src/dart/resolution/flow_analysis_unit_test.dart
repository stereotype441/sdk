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

main() {
  group('Flow analysis unit tests', () {
    test('conditionNotEqNull promotes true branch', () {
      var flow = _Harness().flow;
      var x = _Var('int?');
      flow.add(x, assigned: true);
      var expr = _Expression();
      flow.conditionNotEqNull(expr, x);
      flow.ifStatement_thenBegin(expr);
      expect(flow.promotedType(x), 'int');
      flow.ifStatement_elseBegin();
      expect(flow.promotedType(x), isNull);
      flow.ifStatement_end(true);
      flow.verifyStackEmpty();
    });
  });
}

class _Expression {}

class _Harness
    implements
        NodeOperations<_Expression>,
        TypeOperations<_Var, String>,
        FunctionBodyAccess<_Var> {
  FlowAnalysis<_Statement, _Expression, _Var, String> flow;

  _Harness() {
    flow =
        FlowAnalysis<_Statement, _Expression, _Var, String>(this, this, this);
  }

  @override
  bool isLocalVariable(_Var variable) {
    throw UnimplementedError('TODO(paulberry)');
  }

  @override
  bool isPotentiallyMutatedInClosure(_Var variable) {
    // TODO(paulberry): make tests where this returns true
    return false;
  }

  @override
  bool isPotentiallyMutatedInScope(_Var variable) {
    throw UnimplementedError('TODO(paulberry)');
  }

  @override
  bool isSubtypeOf(String leftType, String rightType) {
    throw UnimplementedError('TODO(paulberry)');
  }
  @override
  String promoteToNonNull(String type) {
    if (type.endsWith('?')) return type.substring(0, type.length - 1);
    return type;
  }

  @override
  _Expression unwrapParenthesized(_Expression node) {
    // TODO(paulberry): test cases where this matters
    return node;
  }

  @override
  String variableType(_Var variable) {
    return variable.type;
  }
}

class _Statement {}

class _Var {
  final String type;

  _Var(this.type);
}
