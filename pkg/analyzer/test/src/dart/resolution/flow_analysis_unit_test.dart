// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/dart/resolver/flow_analysis.dart';
import 'package:test/test.dart';

main() {
  group('Flow analysis unit tests', () {
    test('conditionNotEqNull promotes true branch', () {
      var flow = _Harness().flow;
      var x = _Var(_Type('int?'));
      flow.add(x, assigned: true);
      var expr = _Expression();
      flow.conditionNotEqNull(expr, x);
      flow.ifStatement_thenBegin(expr);
      expect(flow.promotedType(x).type, 'int');
      flow.ifStatement_elseBegin();
      expect(flow.promotedType(x), isNull);
      flow.ifStatement_end(true);
      flow.verifyStackEmpty();
    });

    test('conditionEqNull promotes false branch', () {
      var flow = _Harness().flow;
      var x = _Var(_Type('int?'));
      flow.add(x, assigned: true);
      var expr = _Expression();
      flow.conditionEqNull(expr, x);
      flow.ifStatement_thenBegin(expr);
      expect(flow.promotedType(x), isNull);
      flow.ifStatement_elseBegin();
      expect(flow.promotedType(x).type, 'int');
      flow.ifStatement_end(true);
      flow.verifyStackEmpty();
    });

    test('ifStatement_end(false) keeps else branch if then branch exits', () {
      var flow = _Harness().flow;
      var x = _Var(_Type('int?'));
      flow.add(x, assigned: true);
      var expr = _Expression();
      flow.conditionEqNull(expr, x);
      flow.ifStatement_thenBegin(expr);
      flow.handleExit();
      flow.ifStatement_end(false);
      expect(flow.promotedType(x).type, 'int');
      flow.verifyStackEmpty();
    });
  });
}

class _Expression {}

class _Harness
    implements
        NodeOperations<_Expression>,
        TypeOperations<_Var, _Type>,
        FunctionBodyAccess<_Var> {
  FlowAnalysis<_Statement, _Expression, _Var, _Type> flow;

  _Harness() {
    flow = FlowAnalysis<_Statement, _Expression, _Var, _Type>(this, this, this);
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
  bool isSubtypeOf(_Type leftType, _Type rightType) {
    throw UnimplementedError('TODO(paulberry)');
  }

  @override
  _Type tryPromoteToNonNull(_Type type) {
    if (type.type.endsWith('?')) {
      return _Type(type.type.substring(0, type.type.length - 1));
    }
    return null;
  }

  @override
  _Expression unwrapParenthesized(_Expression node) {
    // TODO(paulberry): test cases where this matters
    return node;
  }

  @override
  _Type variableType(_Var variable) {
    return variable.type;
  }
}

class _Statement {}

class _Type {
  final String type;

  _Type(this.type);

  @override
  bool operator ==(Object other) {
    // The flow analysis engine should not compare types using operator==.  It
    // should compare them using TypeOperations.
    fail('Unexpected use of operator== on types');
  }
}

class _Var {
  final _Type type;

  _Var(this.type);
}
