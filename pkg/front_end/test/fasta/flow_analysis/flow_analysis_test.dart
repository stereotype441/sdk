// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:front_end/src/fasta/flow_analysis/flow_analysis.dart';
import 'package:test/test.dart';

main() {
  group('API', () {
    void _promote(_Harness h, _Var variable, String type) {
      // if (variable is! type) {
      var isExpression = _Expression();
      h.flow.isExpression_end(isExpression, variable, true, _Type(type));
      h.flow.ifStatement_thenBegin(isExpression);
      //   return;
      h.flow.handleExit();
      // }
      h.flow.ifStatement_end(false);
    }

    test('conditional_thenBegin promotes true branch', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      h.flow.conditional_thenBegin(h.notNull(x)());
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.conditional_elseBegin(_Expression());
      expect(h.flow.promotedType(x), isNull);
      h.flow.conditional_end(_Expression(), _Expression());
      expect(h.flow.promotedType(x), isNull);
      h.flow.finish();
    });

    test('conditional_elseBegin promotes false branch', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      h.flow.conditional_thenBegin(h.eqNull(x)());
      expect(h.flow.promotedType(x), isNull);
      h.flow.conditional_elseBegin(_Expression());
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.conditional_end(_Expression(), _Expression());
      expect(h.flow.promotedType(x), isNull);
      h.flow.finish();
    });

    test('conditional_end keeps promotions common to true and false branches',
        () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      var y = h.addAssignedVar('x', 'int?');
      var z = h.addAssignedVar('x', 'int?');
      h.flow.conditional_thenBegin(_Expression());
      _promote(h, x, 'int');
      _promote(h, y, 'int');
      h.flow.conditional_elseBegin(_Expression());
      _promote(h, x, 'int');
      _promote(h, z, 'int');
      h.flow.conditional_end(_Expression(), _Expression());
      expect(h.flow.promotedType(x).type, 'int');
      expect(h.flow.promotedType(y), isNull);
      expect(h.flow.promotedType(z), isNull);
      h.flow.finish();
    });

    test('conditional joins true states', () {
      // if (... ? (x != null && y != null) : (x != null && z != null)) {
      //   promotes x, but not y or z
      // }
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      var y = h.addAssignedVar('y', 'int?');
      var z = h.addAssignedVar('z', 'int?');
      h.if_(
          h.conditional(h.expr, h.and(h.notNull(x), h.notNull(y)),
              h.and(h.notNull(x), h.notNull(z))), () {
        expect(h.flow.promotedType(x).type, 'int');
        expect(h.flow.promotedType(y), isNull);
        expect(h.flow.promotedType(z), isNull);
      });
      h.flow.finish();
    });

    test('conditional joins false states', () {
      // if (... ? (x == null || y == null) : (x == null || z == null)) {
      // } else {
      //   promotes x, but not y or z
      // }
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      var y = h.addAssignedVar('y', 'int?');
      var z = h.addAssignedVar('z', 'int?');
      h.ifElse(
          h.conditional(h.expr, h.or(h.eqNull(x), h.eqNull(y)),
              h.or(h.eqNull(x), h.eqNull(z))),
          () {}, () {
        expect(h.flow.promotedType(x).type, 'int');
        expect(h.flow.promotedType(y), isNull);
        expect(h.flow.promotedType(z), isNull);
      });
      h.flow.finish();
    });

    test('conditionEqNull(notEqual: true) promotes true branch', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      var expr = _Expression();
      h.flow.conditionEqNull(expr, x, notEqual: true);
      h.flow.ifStatement_thenBegin(expr);
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.ifStatement_elseBegin();
      expect(h.flow.promotedType(x), isNull);
      h.flow.ifStatement_end(true);
      h.flow.finish();
    });

    test('conditionEqNull(notEqual: false) promotes false branch', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      var expr = _Expression();
      h.flow.conditionEqNull(expr, x, notEqual: false);
      h.flow.ifStatement_thenBegin(expr);
      expect(h.flow.promotedType(x), isNull);
      h.flow.ifStatement_elseBegin();
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.ifStatement_end(true);
      h.flow.finish();
    });

    test('finish checks proper nesting', () {
      var h = _Harness();
      var expr = _Expression();
      h.flow.ifStatement_thenBegin(expr);
      expect(() => h.flow.finish(), _asserts);
    });

    test('finish checks for un-added variables', () {
      var h = _Harness();
      var x = _Var('x', _Type('int'));
      h.flow.isAssigned(x);
      expect(() => h.flow.finish(), _asserts);
    });

    test('ifStatement_end(false) keeps else branch if then branch exits', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      h.flow.ifStatement_thenBegin(h.eqNull(x)());
      h.flow.handleExit();
      h.flow.ifStatement_end(false);
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.finish();
    });

    test('logicalBinaryOp_rightBegin(isAnd: true) promotes in RHS', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      h.flow.logicalBinaryOp_rightBegin(h.notNull(x)(), isAnd: true);
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.logicalBinaryOp_end(_Expression(), _Expression(), isAnd: true);
      h.flow.finish();
    });

    test('logicalBinaryOp_rightEnd(isAnd: true) keeps promotions from RHS', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      h.flow.logicalBinaryOp_rightBegin(_Expression(), isAnd: true);
      var wholeExpr = _Expression();
      h.flow.logicalBinaryOp_end(wholeExpr, h.notNull(x)(), isAnd: true);
      h.flow.ifStatement_thenBegin(wholeExpr);
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.ifStatement_end(false);
      h.flow.finish();
    });

    test('logicalBinaryOp_rightEnd(isAnd: false) keeps promotions from RHS',
        () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      h.flow.logicalBinaryOp_rightBegin(_Expression(), isAnd: false);
      var wholeExpr = _Expression();
      h.flow.logicalBinaryOp_end(wholeExpr, h.eqNull(x)(), isAnd: false);
      h.flow.ifStatement_thenBegin(wholeExpr);
      h.flow.ifStatement_elseBegin();
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.ifStatement_end(true);
      h.flow.finish();
    });

    test('logicalBinaryOp_rightBegin(isAnd: false) promotes in RHS', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      h.flow.logicalBinaryOp_rightBegin(h.eqNull(x)(), isAnd: false);
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.logicalBinaryOp_end(_Expression(), _Expression(), isAnd: false);
      h.flow.finish();
    });

    test('logicalBinaryOp(isAnd: true) joins promotions', () {
      // if (x != null && y != null) {
      //   promotes x and y
      // }
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      var y = h.addAssignedVar('y', 'int?');
      h.if_(h.and(h.notNull(x), h.notNull(y)), () {
        expect(h.flow.promotedType(x).type, 'int');
        expect(h.flow.promotedType(y).type, 'int');
      });
      h.flow.finish();
    });

    test('logicalBinaryOp(isAnd: false) joins promotions', () {
      // if (x == null || y == null) {} else {
      //   promotes x and y
      // }
      var h = _Harness();
      var x = h.addAssignedVar('x', 'int?');
      var y = h.addAssignedVar('y', 'int?');
      h.ifElse(h.or(h.eqNull(x), h.eqNull(y)), () {}, () {
        expect(h.flow.promotedType(x).type, 'int');
        expect(h.flow.promotedType(y).type, 'int');
      });
      h.flow.finish();
    });

    test('Infinite loop does not implicitly assign variables', () {
      var h = _Harness();
      var x = h.addUnassignedVar('x', 'int');
      var trueCondition = _Expression();
      h.flow.whileStatement_conditionBegin({x});
      h.flow.booleanLiteral(trueCondition, true);
      h.flow.whileStatement_bodyBegin(_Statement(), trueCondition);
      h.flow.whileStatement_end();
      expect(h.flow.isAssigned(x), false);
    });

    test('If(false) does not discard promotions', () {
      var h = _Harness();
      var x = h.addAssignedVar('x', 'Object');
      _promote(h, x, 'int');
      expect(h.flow.promotedType(x).type, 'int');
      // if (false) {
      var falseExpression = _Expression();
      h.flow.booleanLiteral(falseExpression, false);
      h.flow.ifStatement_thenBegin(falseExpression);
      expect(h.flow.promotedType(x).type, 'int');
      h.flow.ifStatement_end(false);
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
        expect(h.flow.promotedType(x).type, expectedPromotedType);
      }
      h.flow.ifStatement_elseBegin();
      expect(h.flow.promotedType(x), isNull);
      h.flow.ifStatement_end(true);
      h.flow.finish();
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

  group('State', () {
    var emptySet = FlowModel<_Var, _Type>(true).notAssigned;
    var intVar = _Var('x', _Type('int'));
    var intQVar = _Var('x', _Type('int?'));
    var objectQVar = _Var('x', _Type('Object?'));
    group('setReachable', () {
      var unreachable = FlowModel<_Var, _Type>(false);
      var reachable = FlowModel<_Var, _Type>(true);
      test('unchanged', () {
        expect(unreachable.setReachable(false), same(unreachable));
        expect(reachable.setReachable(true), same(reachable));
      });

      test('changed', () {
        void _check(FlowModel<_Var, _Type> initial, bool newReachability) {
          var s = initial.setReachable(newReachability);
          expect(s, isNot(same(initial)));
          expect(s.reachable, newReachability);
          expect(s.notAssigned, same(initial.notAssigned));
          expect(s.promoted, same(initial.promoted));
        }

        _check(unreachable, true);
        _check(reachable, false);
      });
    });

    group('add', () {
      test('default', () {
        // By default, added variables are considered unassigned.
        var s1 = FlowModel<_Var, _Type>(true);
        var s2 = s1.add(intVar);
        expect(s2.notAssigned.contains(intVar), true);
        expect(s2.reachable, true);
        expect(s2.promoted, {intVar: null});
      });

      test('unassigned', () {
        var s1 = FlowModel<_Var, _Type>(true);
        var s2 = s1.add(intVar, assigned: false);
        expect(s2.notAssigned.contains(intVar), true);
        expect(s2.reachable, true);
        expect(s2.promoted, {intVar: null});
      });

      test('assigned', () {
        var s1 = FlowModel<_Var, _Type>(true);
        var s2 = s1.add(intVar, assigned: true);
        expect(s2.notAssigned.contains(intVar), false);
        expect(s2.promoted, {intVar: null});
      });
    });

    group('promote', () {
      test('unpromoted -> unchanged (same)', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true).add(intVar);
        var s2 = s1.promote(h, intVar, _Type('int'));
        expect(s2, same(s1));
      });

      test('unpromoted -> unchanged (supertype)', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true).add(intVar);
        var s2 = s1.promote(h, intVar, _Type('Object'));
        expect(s2, same(s1));
      });

      test('unpromoted -> unchanged (unrelated)', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true).add(intVar);
        var s2 = s1.promote(h, intVar, _Type('String'));
        expect(s2, same(s1));
      });

      test('unpromoted -> subtype', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true).add(intQVar);
        var s2 = s1.promote(h, intQVar, _Type('int'));
        expect(s2.reachable, true);
        expect(s2.notAssigned, same(s1.notAssigned));
        _Type.allowComparisons(() {
          expect(s2.promoted, {intQVar: _Type('int')});
        });
      });

      test('promoted -> unchanged (same)', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int'));
        var s2 = s1.promote(h, objectQVar, _Type('int'));
        expect(s2, same(s1));
      });

      test('promoted -> unchanged (supertype)', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int'));
        var s2 = s1.promote(h, objectQVar, _Type('Object'));
        expect(s2, same(s1));
      });

      test('promoted -> unchanged (unrelated)', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int'));
        var s2 = s1.promote(h, objectQVar, _Type('String'));
        expect(s2, same(s1));
      });

      test('promoted -> subtype', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int?'));
        var s2 = s1.promote(h, objectQVar, _Type('int'));
        expect(s2.reachable, true);
        expect(s2.notAssigned, same(s1.notAssigned));
        _Type.allowComparisons(() {
          expect(s2.promoted, {objectQVar: _Type('int')});
        });
      });
    });

    group('write', () {
      var objectQVar = _Var('x', _Type('Object?'));
      test('unchanged', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true).add(objectQVar, assigned: true);
        var s2 = s1.write(h, emptySet, objectQVar);
        expect(s2, same(s1));
      });

      test('marks as assigned', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true).add(objectQVar, assigned: false);
        var s2 = s1.write(h, emptySet, objectQVar);
        expect(s2.reachable, true);
        expect(s2.notAssigned.contains(objectQVar), false);
        expect(s2.promoted, same(s1.promoted));
      });

      test('un-promotes', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true)
            .add(objectQVar, assigned: true)
            .promote(h, objectQVar, _Type('int'));
        expect(s1.promoted, contains(objectQVar));
        var s2 = s1.write(h, emptySet, objectQVar);
        expect(s2.reachable, true);
        expect(s2.notAssigned, same(s1.notAssigned));
        expect(s2.promoted, {objectQVar: null});
      });
    });

    group('markNonNullable', () {
      test('unpromoted -> unchanged', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true).add(intVar);
        var s2 = s1.markNonNullable(h, intVar);
        expect(s2, same(s1));
      });

      test('unpromoted -> promoted', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true).add(intQVar);
        var s2 = s1.markNonNullable(h, intQVar);
        expect(s2.reachable, true);
        expect(s2.notAssigned, same(s1.notAssigned));
        expect(s2.promoted[intQVar].type, 'int');
      });

      test('promoted -> unchanged', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int'));
        var s2 = s1.markNonNullable(h, objectQVar);
        expect(s2, same(s1));
      });

      test('promoted -> re-promoted', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true)
            .add(objectQVar)
            .promote(h, objectQVar, _Type('int?'));
        var s2 = s1.markNonNullable(h, objectQVar);
        expect(s2.reachable, true);
        expect(s2.notAssigned, same(s1.notAssigned));
        _Type.allowComparisons(() {
          expect(s2.promoted, {objectQVar: _Type('int')});
        });
      });
    });

    group('removePromotedAll', () {
      test('unchanged', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true)
            .add(objectQVar)
            .add(intQVar)
            .promote(h, objectQVar, _Type('int'));
        var s2 = s1.removePromotedAll([intQVar].toSet());
        expect(s2, same(s1));
      });

      test('changed', () {
        var h = _Harness();
        var s1 = FlowModel<_Var, _Type>(true)
            .add(objectQVar)
            .add(intQVar)
            .promote(h, objectQVar, _Type('int'))
            .promote(h, intQVar, _Type('int'));
        var s2 = s1.removePromotedAll([intQVar].toSet());
        expect(s2.reachable, true);
        expect(s2.notAssigned, same(s1.notAssigned));
        _Type.allowComparisons(() {
          expect(s2.promoted, {objectQVar: _Type('int'), intQVar: null});
        });
      });
    });

    group('restrict', () {
      test('reachability', () {
        var h = _Harness();
        var reachable = FlowModel<_Var, _Type>(true);
        var unreachable = reachable.setReachable(false);
        expect(
            reachable.restrict(h, emptySet, reachable, Set()), same(reachable));
        expect(reachable.restrict(h, emptySet, unreachable, Set()),
            same(unreachable));
        expect(unreachable.restrict(h, emptySet, unreachable, Set()),
            same(unreachable));
        expect(unreachable.restrict(h, emptySet, unreachable, Set()),
            same(unreachable));
      });

      test('assignments', () {
        var h = _Harness();
        var a = _Var('a', _Type('int'));
        var b = _Var('b', _Type('int'));
        var c = _Var('c', _Type('int'));
        var d = _Var('d', _Type('int'));
        var s0 = FlowModel<_Var, _Type>(true).add(a).add(b).add(c).add(d);
        var s1 = s0.write(h, emptySet, a).write(h, emptySet, b);
        var s2 = s0.write(h, emptySet, a).write(h, emptySet, c);
        var result = s1.restrict(h, emptySet, s2, Set());
        expect(result.notAssigned.contains(a), false);
        expect(result.notAssigned.contains(b), false);
        expect(result.notAssigned.contains(c), false);
        expect(result.notAssigned.contains(d), true);
      });

      test('promotion', () {
        void _check(String thisType, String otherType, bool unsafe,
            String expectedType) {
          var h = _Harness();
          var x = _Var('x', _Type('Object?'));
          var s0 = FlowModel<_Var, _Type>(true).add(x, assigned: true);
          var s1 = thisType == null ? s0 : s0.promote(h, x, _Type(thisType));
          var s2 = otherType == null ? s0 : s0.promote(h, x, _Type(otherType));
          var result =
              s1.restrict(h, emptySet, s2, unsafe ? [x].toSet() : Set());
          if (expectedType == null) {
            expect(result.promoted, contains(x));
            expect(result.promoted[x], isNull);
          } else {
            expect(result.promoted[x].type, expectedType);
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

      test('variable present in one state but not the other', () {
        var h = _Harness();
        var x = _Var('x', _Type('Object?'));
        var s0 = FlowModel<_Var, _Type>(true);
        var s1 = s0.add(x, assigned: true);
        expect(s0.restrict(h, emptySet, s1, {}), same(s0));
        expect(s0.restrict(h, emptySet, s1, {x}), same(s0));
        expect(s1.restrict(h, emptySet, s0, {}), same(s1));
        expect(s1.restrict(h, emptySet, s0, {x}), same(s1));
      });
    });
  });

  group('join', () {
    group('should re-use an input if possible', () {
      var x = _Var('x', null);
      var y = _Var('y', null);
      var intType = _Type('int');
      var intQType = _Type('int?');
      var stringType = _Type('String');
      const emptyMap = <Null, Null>{};

      test('identical inputs', () {
        var h = _Harness();
        var p = {x: intType, y: stringType};
        expect(FlowModel.joinPromoted(h, p, p), same(p));
      });

      test('one input empty', () {
        var h = _Harness();
        var p1 = {x: intType, y: stringType};
        var p2 = <_Var, _Type>{};
        expect(FlowModel.joinPromoted(h, p1, p2), same(emptyMap));
        expect(FlowModel.joinPromoted(h, p2, p1), same(emptyMap));
      });

      test('related types', () {
        var h = _Harness();
        var p1 = {x: intType};
        var p2 = {x: intQType};
        expect(FlowModel.joinPromoted(h, p1, p2), same(p2));
        expect(FlowModel.joinPromoted(h, p2, p1), same(p2));
      });

      test('unrelated types', () {
        var h = _Harness();
        var p1 = {x: intType};
        var p2 = {x: stringType};
        expect(FlowModel.joinPromoted(h, p1, p2), {x: null});
        expect(FlowModel.joinPromoted(h, p2, p1), {x: null});
      });

      test('sub-map', () {
        var h = _Harness();
        var p1 = {x: intType, y: stringType};
        var p2 = {x: intType};
        expect(FlowModel.joinPromoted(h, p1, p2), same(p2));
        expect(FlowModel.joinPromoted(h, p2, p1), same(p2));
      });

      test('sub-map with matched subtype', () {
        var h = _Harness();
        var p1 = {x: intType, y: stringType};
        var p2 = {x: intQType};
        expect(FlowModel.joinPromoted(h, p1, p2), same(p2));
        expect(FlowModel.joinPromoted(h, p2, p1), same(p2));
      });

      test('sub-map with mismatched subtype', () {
        var h = _Harness();
        var p1 = {x: intQType, y: stringType};
        var p2 = {x: intType};
        var join12 = FlowModel.joinPromoted(h, p1, p2);
        _Type.allowComparisons(() => expect(join12, {x: intQType}));
        var join21 = FlowModel.joinPromoted(h, p2, p1);
        _Type.allowComparisons(() => expect(join21, {x: intQType}));
      });
    });
  });
}

/// Returns the appropriate matcher for expecting an assertion error to be
/// thrown or not, based on whether assertions are enabled.
Matcher get _asserts {
  var matcher = throwsA(TypeMatcher<AssertionError>());
  bool assertionsEnabled = false;
  assert(assertionsEnabled = true);
  if (!assertionsEnabled) {
    matcher = isNot(matcher);
  }
  return matcher;
}

/// Representation of an expression to be visited by the test harness.  Calling
/// the function causes the expression to be "visited" (in other words, the
/// appropriate methods in [FlowAnalysis] are called in the appropriate order),
/// and the [_Expression] object representing the whole expression is returned.
///
/// This is used by methods in [_Harness] as a lightweight way of building up
/// complex sequences of calls to [FlowAnalysis] that represent large
/// expressions.
typedef _Expression LazyExpression();

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

  /// Returns a [LazyExpression] representing an expression with now special
  /// flow analysis semantics.
  LazyExpression get expr => () => _Expression();

  _Var addAssignedVar(String name, String type) {
    var v = _Var(name, _Type(type));
    flow.add(v, assigned: true);
    return v;
  }

  _Var addUnassignedVar(String name, String type) {
    var v = _Var(name, _Type(type));
    flow.add(v, assigned: false);
    return v;
  }

  /// Given two [LazyExpression]s, produces a new [LazyExpression] representing
  /// the result of combining them with `&&`.
  LazyExpression and(LazyExpression lhs, LazyExpression rhs) {
    return () {
      var expr = _Expression();
      flow.logicalBinaryOp_rightBegin(lhs(), isAnd: true);
      flow.logicalBinaryOp_end(expr, rhs(), isAnd: true);
      return expr;
    };
  }

  /// Given three [LazyExpression]s, produces a new [LazyExpression]
  /// representing the result of combining them with `?` and `:`.
  LazyExpression conditional(
      LazyExpression cond, LazyExpression ifTrue, LazyExpression ifFalse) {
    return () {
      var expr = _Expression();
      flow.conditional_thenBegin(cond());
      flow.conditional_elseBegin(ifTrue());
      flow.conditional_end(expr, ifFalse());
      return expr;
    };
  }

  /// Creates a [LazyExpression] representing an `== null` check performed on
  /// [variable].
  LazyExpression eqNull(_Var variable) {
    return () {
      var expr = _Expression();
      flow.conditionEqNull(expr, variable, notEqual: false);
      return expr;
    };
  }

  /// Invokes flow analysis of an `if` statement with no `else` part.
  void if_(LazyExpression cond, void ifTrue()) {
    flow.ifStatement_thenBegin(cond());
    ifTrue();
    flow.ifStatement_end(false);
  }

  /// Invokes flow analysis of an `if` statement with an `else` part.
  void ifElse(LazyExpression cond, void ifTrue(), void ifFalse()) {
    flow.ifStatement_thenBegin(cond());
    ifTrue();
    flow.ifStatement_elseBegin();
    ifFalse();
    flow.ifStatement_end(false);
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

  /// Creates a [LazyExpression] representing a `!= null` check performed on
  /// [variable].
  LazyExpression notNull(_Var variable) {
    return () {
      var expr = _Expression();
      flow.conditionEqNull(expr, variable, notEqual: true);
      return expr;
    };
  }

  /// Given two [LazyExpression]s, produces a new [LazyExpression] representing
  /// the result of combining them with `||`.
  LazyExpression or(LazyExpression lhs, LazyExpression rhs) {
    return () {
      var expr = _Expression();
      flow.logicalBinaryOp_rightBegin(lhs(), isAnd: false);
      flow.logicalBinaryOp_end(expr, rhs(), isAnd: false);
      return expr;
    };
  }

  @override
  _Type promoteToNonNull(_Type type) {
    if (type.type.endsWith('?')) {
      return _Type(type.type.substring(0, type.type.length - 1));
    } else {
      return type;
    }
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
