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
      var x = h.addAssignedVar('x', 'int?');
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

  group('State', () {
    var intVar = _Var('x', _Type('int'));
    var intQVar = _Var('x', _Type('int?'));
    var objectQVar = _Var('x', _Type('Object?'));
    group('setReachable', () {
      var unreachable = State<_Var, _Type>(false);
      var reachable = State<_Var, _Type>(true);
      test('unchanged', () {
        expect(unreachable.setReachable(false), same(unreachable));
        expect(reachable.setReachable(true), same(reachable));
      });

      test('changed', () {
        void _check(State<_Var, _Type> initial, bool newReachability) {
          var s = initial.setReachable(newReachability);
          expect(s, isNot(same(initial)));
          expect(s.reachable, newReachability);
          expect(s.variables, same(initial.variables));
        }

        _check(unreachable, true);
        _check(reachable, false);
      });
    });

    group('add', () {
      test('default', () {
        // By default, added variables are considered unassigned.
        var s1 = State<_Var, _Type>(true);
        var s2 = s1.add(intVar);
        expect(s2.reachable, true);
        expect(s2.variables, {intVar: VariableState<_Type>(false, null)});
      });

      test('unassigned', () {
        var s1 = State<_Var, _Type>(true);
        var s2 = s1.add(intVar, assigned: false);
        expect(s2.reachable, true);
        expect(s2.variables, {intVar: VariableState<_Type>(false, null)});
      });

      test('assigned', () {
        var s1 = State<_Var, _Type>(true);
        var s2 = s1.add(intVar, assigned: true);
        expect(s2.reachable, true);
        expect(s2.variables, {intVar: VariableState<_Type>(true, null)});
      });
    });

    test('exit', () {
      var s1 = State<_Var, _Type>(true);
      var s2 = s1.exit();
      expect(s2.reachable, false);
      expect(s2.variables, same(s1.variables));
    });

    group('promote', () {
      test('unpromoted -> unchanged (same)', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true).add(intVar);
        var s2 = s1.promote(h, intVar, _Type('int'));
        expect(s2, same(s1));
      });

      test('unpromoted -> unchanged (supertype)', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true).add(intVar);
        var s2 = s1.promote(h, intVar, _Type('Object'));
        expect(s2, same(s1));
      });

      test('unpromoted -> unchanged (unrelated)', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true).add(intVar);
        var s2 = s1.promote(h, intVar, _Type('String'));
        expect(s2, same(s1));
      });

      test('unpromoted -> subtype', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true).add(intQVar);
        var s2 = s1.promote(h, intQVar, _Type('int'));
        expect(s2.reachable, true);
        _Type.allowComparisons(() {
          expect(s2.variables,
              {intQVar: VariableState<_Type>(false, _Type('int'))});
        });
      });

      test('promoted -> unchanged (same)', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int'));
        var s2 = s1.promote(h, objectQVar, _Type('int'));
        expect(s2, same(s1));
      });

      test('promoted -> unchanged (supertype)', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int'));
        var s2 = s1.promote(h, objectQVar, _Type('Object'));
        expect(s2, same(s1));
      });

      test('promoted -> unchanged (unrelated)', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int'));
        var s2 = s1.promote(h, objectQVar, _Type('String'));
        expect(s2, same(s1));
      });

      test('promoted -> subtype', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int?'));
        var s2 = s1.promote(h, objectQVar, _Type('int'));
        expect(s2.reachable, true);
        _Type.allowComparisons(() {
          expect(s2.variables,
              {objectQVar: VariableState<_Type>(false, _Type('int'))});
        });
      });
    });

    group('write', () {
      var objectQVar = _Var('x', _Type('Object?'));
      test('unchanged', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true).add(objectQVar, assigned: true);
        var s2 = s1.write(h, objectQVar);
        expect(s2, same(s1));
      });

      test('marks as assigned', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true).add(objectQVar, assigned: false);
        var s2 = s1.write(h, objectQVar);
        expect(s2.reachable, true);
        _Type.allowComparisons(() {
          expect(s2.variables, {objectQVar: VariableState<_Type>(true, null)});
        });
      });

      test('un-promotes', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true)
            .add(objectQVar, assigned: true)
            .promote(h, objectQVar, _Type('int'));
        expect(s1.variables[objectQVar].promotedType, isNotNull);
        var s2 = s1.write(h, objectQVar);
        expect(s2.reachable, true);
        expect(s1.variables[objectQVar].promotedType, isNull);
      });
    });

    group('markNonNullable', () {
      test('unpromoted -> unchanged', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true).add(intVar);
        var s2 = s1.markNonNullable(h, intVar);
        expect(s2, same(s1));
      });

      test('unpromoted -> promoted', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true).add(intQVar);
        var s2 = s1.markNonNullable(h, intQVar);
        expect(s2.reachable, true);
        expect(s2.variables[intQVar].promotedType.type, 'int');
      });

      test('promoted -> unchanged', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int'));
        var s2 = s1.markNonNullable(h, objectQVar);
        expect(s2, same(s1));
      });

      test('promoted -> re-promoted', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int?'));
        var s2 = s1.markNonNullable(h, objectQVar);
        expect(s2.reachable, true);
        _Type.allowComparisons(() {
          expect(s2.variables,
              {objectQVar: VariableState<_Type>(false, _Type('int'))});
        });
      });
    });

    group('removePromotedAll', () {
      test('unchanged', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true)
            .add(objectQVar)
            .add(intQVar)
            .promote(h, objectQVar, _Type('int'));
        var s2 = s1.removePromotedAll({intQVar});
        expect(s2, same(s1));
      });

      test('changed', () {
        var h = _Harness();
        var s1 = State<_Var, _Type>(true)
            .add(objectQVar)
            .add(intQVar)
            .promote(h, objectQVar, _Type('int'))
            .promote(h, intQVar, _Type('int'));
        var s2 = s1.removePromotedAll({intQVar});
        expect(s2.reachable, true);
        _Type.allowComparisons(() {
          expect(s2.variables,
              {objectQVar: VariableState<_Type>(false, _Type('int'))});
        });
      });
    });

    group('restrict', () {
      test('reachability', () {
        var h = _Harness();
        var reachable = State<_Var, _Type>(true);
        var unreachable = reachable.exit();
        expect(reachable.restrict(h, reachable, {}), same(reachable));
        expect(reachable.restrict(h, unreachable, {}), same(unreachable));
        expect(unreachable.restrict(h, unreachable, {}), same(unreachable));
        expect(unreachable.restrict(h, unreachable, {}), same(unreachable));
      });

      test('assignments', () {
        var h = _Harness();
        var a = _Var('a', _Type('int'));
        var b = _Var('b', _Type('int'));
        var c = _Var('c', _Type('int'));
        var d = _Var('d', _Type('int'));
        var s0 = State<_Var, _Type>(true).add(a).add(b).add(c).add(d);
        var s1 = s0.write(h, a).write(h, b);
        var s2 = s0.write(h, a).write(h, c);
        var result = s1.restrict(h, s2, {});
        expect(result.variables[a].definitelyAssigned, true);
        expect(result.variables[b].definitelyAssigned, true);
        expect(result.variables[c].definitelyAssigned, true);
        expect(result.variables[d].definitelyAssigned, false);
      });

      test('promotion', () {
        void _check(String thisType, String otherType, bool unsafe,
            String expectedType) {
          var h = _Harness();
          var x = _Var('x', _Type('Object?'));
          var s0 = State<_Var, _Type>(true).add(x, assigned: true);
          var s1 = thisType == null ? s0 : s0.promote(h, x, _Type(thisType));
          var s2 = otherType == null ? s0 : s0.promote(h, x, _Type(otherType));
          var result = s1.restrict(h, s2, unsafe ? {x} : {});
          if (expectedType == null) {
            expect(result.variables[x].promotedType, isNull);
          } else {
            expect(result.variables[x].promotedType.type, expectedType);
          }
        }

        _check(null, null, false, null);
        _check(null, null, true, null);
        _check('int', null, false, 'int');
        _check('int', null, true, 'int');
        _check(null, 'int', false, 'int');
        _check(null, 'int', true, null);
        _check('int?', 'int', false, 'int');
        _check('int', 'int?', false, 'int');
        _check('int', 'String', false, 'int');
        _check('int?', 'int', true, 'int?');
        _check('int', 'int?', true, 'int');
        _check('int', 'String', true, 'int');
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

  _Var addAssignedVar(String name, String type) {
    var v = _Var(name, _Type(type));
    flow.add(v, assigned: true);
    return v;
  }

  @override
  bool isLocalVariable(_Var variable) {
    // TODO(paulberry): make tests where this returns false
    return true;
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
      'int <: Object?': true,
      'int <: String': false,
      'int? <: int': false,
      'int? <: Object?': true,
      'Object <: int': false,
      'String <: int': false,
      'String <: int?': false,
      'String <: Object?': true,
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
