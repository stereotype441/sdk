// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/dart/resolver/flow_analysis.dart';
import 'package:test/test.dart';

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
