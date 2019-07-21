// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/dart/resolver/flow_analysis.dart';
import 'package:test/test.dart';

main() {
  group('API', () {
    test('conditionNotEqNull promotes true branch', () {
      var flow = _Harness().flow;
      var x = _Var('x', _Type('int?'));
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
      var x = _Var('x', _Type('int?'));
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
      var x = _Var('x', _Type('int?'));
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

  group('join variables', () {
    group('should re-use an input if possible', () {
      var x = _Var('x', null);
      var y = _Var('y', null);
      var intState = VariableState<_Type>(true, _Type('int'));
      var intQState = VariableState<_Type>(true, _Type('int?'));
      var stringState = VariableState<_Type>(true, _Type('String'));
      const emptyMap = <Null, VariableState<Null>>{};

      test('identical inputs', () {
        var flow = _Harness().flow;
        var p = {x: intState, y: stringState};
        expect(flow.joinVariables(p, p), same(p));
      });

      test('one input empty', () {
        var flow = _Harness().flow;
        var p1 = {x: intState, y: stringState};
        var p2 = emptyMap;
        expect(flow.joinVariables(p1, p2), same(emptyMap));
        expect(flow.joinVariables(p2, p1), same(emptyMap));
      });

      test('related types', () {
        var flow = _Harness().flow;
        var p1 = {x: intState};
        var p2 = {x: intQState};
        expect(flow.joinVariables(p1, p2), same(p2));
        expect(flow.joinVariables(p2, p1), same(p2));
      });

      test('unrelated types', () {
        var flow = _Harness().flow;
        var p1 = {x: intState};
        var p2 = {x: stringState};
        expect(flow.joinVariables(p1, p2), same(emptyMap));
        expect(flow.joinVariables(p2, p1), same(emptyMap));
      });

      test('sub-map', () {
        var flow = _Harness().flow;
        var p1 = {x: intState, y: stringState};
        var p2 = {x: intState};
        expect(flow.joinVariables(p1, p2), same(p2));
        expect(flow.joinVariables(p2, p1), same(p2));
      });

      test('sub-map with matched subtype', () {
        var flow = _Harness().flow;
        var p1 = {x: intState, y: stringState};
        var p2 = {x: intQState};
        expect(flow.joinVariables(p1, p2), same(p2));
        expect(flow.joinVariables(p2, p1), same(p2));
      });

      test('sub-map with mismatched subtype', () {
        var flow = _Harness().flow;
        var p1 = {x: intQState, y: stringState};
        var p2 = {x: intState};
        var join12 = flow.joinVariables(p1, p2);
        _Type.allowComparisons(() => expect(join12, {x: intQState}));
        var join21 = flow.joinVariables(p2, p1);
        _Type.allowComparisons(() => expect(join21, {x: intQState}));
      });
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
    const Map<String, bool> _subtypes = const {
      'int <: int?': true,
      'int <: String': false,
      'int? <: int': false,
      'String <: int': false,
    };

    if (leftType.type == rightType.type) return true;
    var query = '$leftType <: $rightType';
    return _subtypes[query] ?? fail('Unknown subtype query: $query');
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
  static bool _allowingTypeComparisons = false;

  final String type;

  _Type(this.type);

  @override
  bool operator ==(Object other) {
    if (_allowingTypeComparisons) {
      return other is _Type && other.type == this.type;
    } else {
      // The flow analysis engine should not compare types using operator==.  It
      // should compare them using TypeOperations.
      fail('Unexpected use of operator== on types');
    }
  }

  @override
  String toString() => type;

  static T allowComparisons<T>(T callback()) {
    var oldAllowingTypeComparisons = _allowingTypeComparisons;
    _allowingTypeComparisons = true;
    try {
      return callback();
    } finally {
      _allowingTypeComparisons = oldAllowingTypeComparisons;
    }
  }
}

class _Var {
  final String name;

  final _Type type;

  _Var(this.name, this.type);

  @override
  String toString() => '$type $name';
}
