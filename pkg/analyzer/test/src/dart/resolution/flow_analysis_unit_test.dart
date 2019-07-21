// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/dart/resolver/flow_analysis.dart';
import 'package:test/test.dart';

main() {
  group('API', () {
    test('conditionNotEqNull promotes true branch', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      var expr = _Expression();
      h.flow.conditionNotEqNull(expr, x);
      h.flow.ifStatement_thenBegin(expr);
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.ifStatement_elseBegin();
      expect(h.flow.promotedType(x), isNull);
      h.flow.ifStatement_end(true);
      h.flow.verifyStackEmpty();
    });

    test('conditionEqNull promotes false branch', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      var expr = _Expression();
      h.flow.conditionEqNull(expr, x);
      h.flow.ifStatement_thenBegin(expr);
      expect(h.flow.promotedType(x), isNull);
      h.flow.ifStatement_elseBegin();
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.ifStatement_end(true);
      h.flow.verifyStackEmpty();
    });

    test('ifStatement_end(false) keeps else branch if then branch exits', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      var expr = _Expression();
      h.flow.conditionEqNull(expr, x);
      h.flow.ifStatement_thenBegin(expr);
      h.flow.handleExit();
      h.flow.ifStatement_end(false);
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.verifyStackEmpty();
    });

    test('write unpromotes variable', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'Object');
      h.promote(x, 'int', () {
        expect(h.flow.promotedType(x).type, 'int');
        h.flow.write(x);
        expect(h.flow.promotedType(x), null);
      });
    });

    void _checkIs(String declaredType, String tryPromoteType,
        String expectedPromotedType) {
      var h = _Harness();
      var x = h.addAssignedVar('x', declaredType);
      var expr = _Expression();
      h.flow.isExpression_end(expr, x, false, _Type(tryPromoteType));
      h.flow.ifStatement_thenBegin(expr);
      if (expectedPromotedType == null) {
        expect(h.flow.promotedType(x), isNull);
      } else {
        expect(h.flow.promotedType(x).type, 'int');
      }
      h.flow.ifStatement_elseBegin();
      expect(h.flow.promotedType(x), isNull);
      h.flow.ifStatement_end(true);
      h.flow.verifyStackEmpty();
    }

    test('isExpression_end promotes to a subtype', () {
      _checkIs('int?', 'int', 'int');
    });

    test('isExpression_end does not promote to a supertype', () {
      _checkIs('int', 'int?', null);
    });

    test('isExpression_end does not promote to an unrelated type', () {
      _checkIs('int', 'String', null);
    });
  });

  group('VariableState', () {
    test('operator==', () {
      expect(VariableState(true, 'Object') == VariableState(true, 'Object'),
          isTrue);
      expect(VariableState(true, 'Object') == VariableState(false, 'Object'),
          isFalse);
      expect(
          VariableState(true, 'Object') == VariableState(true, 'int'), isFalse);
      expect(VariableState(true, 'Object') == 'Object', isFalse);
    });

    test('setDefinitelyAssigned', () {
      expect(VariableState(true, 'Object').setDefinitelyAssigned(false),
          VariableState(false, 'Object'));
    });

    test('setPromotedType', () {
      expect(VariableState(true, 'Object').setPromotedType('int'),
          VariableState(true, 'int'));
    });

    group('join', () {
      var assignedState = VariableState<_Type>(true, null);
      var unassignedState = VariableState<_Type>(false, null);
      var intState = VariableState<_Type>(true, _Type('int'));
      var intQState = VariableState<_Type>(true, _Type('int?'));
      var stringState = VariableState<_Type>(true, _Type('String'));

      test('identical inputs', () {
        var h = _Harness();
        expect(VariableState.join(h, intState, intState), same(intState));
      });

      test('null handling', () {
        var h = _Harness();
        expect(VariableState.join(h, intState, null), isNull);
        expect(VariableState.join(h, null, intState), isNull);
      });

      test('assigned vs unassigned', () {
        var h = _Harness();
        expect(VariableState.join(h, unassignedState, assignedState),
            same(unassignedState));
        expect(VariableState.join(h, assignedState, unassignedState),
            same(unassignedState));
      });

      test('unpromoted vs promoted', () {
        var h = _Harness();
        expect(VariableState.join(h, intState, assignedState),
            same(assignedState));
        expect(VariableState.join(h, assignedState, intState),
            same(assignedState));
      });

      test('related types', () {
        var h = _Harness();
        expect(VariableState.join(h, intState, intQState), same(intQState));
        expect(VariableState.join(h, intQState, intState), same(intQState));
      });

      test('unrelated types', () {
        var h = _Harness();
        expect(VariableState.join(h, intState, stringState), assignedState);
        expect(VariableState.join(h, stringState, intState), assignedState);
      });

      test('mixed assignment and promotion', () {
        var h = _Harness();
        _Type.allowComparisons(() {
          expect(
              VariableState.join(h, VariableState<_Type>(true, _Type('int?')),
                  VariableState<_Type>(false, _Type('int'))),
              VariableState<_Type>(false, _Type('int?')));
        });
      });
    });
  });

  group('join variables', () {
    group('should re-use an input if possible', () {
      var x = _Var('x', null);
      var y = _Var('y', null);
      var intState = VariableState<_Type>(true, _Type('int'));
      var intQState = VariableState<_Type>(true, _Type('int?'));
      var stringState = VariableState<_Type>(true, _Type('String'));
      var unpromotedState = VariableState<_Type>(true, null);
      const emptyMap = <Null, VariableState<Null>>{};

      test('identical inputs', () {
        var flow = _Harness().flow;
        var p = {x: intState, y: stringState};
        expect(flow.joinVariables(p, p), same(p));
      });

      test('two empty inputs', () {
        var flow = _Harness().flow;
        expect(flow.joinVariables({}, {}), same(emptyMap));
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
        expect(flow.joinVariables(p1, p2), {x: unpromotedState});
        expect(flow.joinVariables(p2, p1), {x: unpromotedState});
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

  addAssignedVar(String name, String type) {
    var v = _Var(name, _Type(type));
    flow.add(v, assigned: true);
    return v;
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
  bool isSameType(_Type type1, _Type type2) {
    return type1.type == type2.type;
  }

  @override
  bool isSubtypeOf(_Type leftType, _Type rightType) {
    const Map<String, bool> _subtypes = const {
      'int <: int?': true,
      'int <: Object': true,
      'int <: String': false,
      'int? <: int': false,
      'String <: int': false,
    };

    if (leftType.type == rightType.type) return true;
    var query = '$leftType <: $rightType';
    return _subtypes[query] ?? fail('Unknown subtype query: $query');
  }

  void promote(_Var variable, String type, void Function() callback) {
    var expr = _Expression();
    flow.isExpression_end(expr, variable, false, _Type(type));
    flow.ifStatement_thenBegin(expr);
    callback();
    flow.ifStatement_end(false);
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
