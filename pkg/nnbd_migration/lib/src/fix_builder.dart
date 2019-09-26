// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:nnbd_migration/src/utilities/edit_planner.dart';

abstract class FixBuilder extends EditPlanner {
  IfBehavior getIfBehavior(IfStatement node);

  bool needsNullCheck(Expression node);

  @override
  ExpressionPlan visitExpression(Expression node) {
    var plan = super.visitExpression(node);
    if (needsNullCheck(node)) {
      plan = _NullCheckExpressionPlan(plan);
    }
    return plan;
  }

  @override
  EditPlan visitIfStatement(IfStatement node) {
    switch (getIfBehavior(node)) {
      case IfBehavior.keepAll:
        return super.visitIfStatement(node);
      case IfBehavior.keepConditionAndThen:
        return _UnwrapStatementsPlan(node.offset, node.end, [
          _ExpressionStatementPlan(node.condition.accept(this)),
          node.thenStatement.accept(this)
        ]);
      case IfBehavior.keepConditionAndElse:
        if (node.elseStatement != null) {
          return _UnwrapStatementsPlan(node.offset, node.end, [
            _ExpressionStatementPlan(node.condition.accept(this)),
            node.elseStatement.accept(this)
          ]);
        } else {
          return _ExpressionStatementPlan(
              _UnwrapPlan(node.offset, node.end, node.condition.accept(this)));
        }
        break;
      case IfBehavior.keepThen:
        return _UnwrapPlan(
            node.offset, node.end, node.thenStatement.accept(this));
      case IfBehavior.keepElse:
        if (node.elseStatement != null) {
          return _UnwrapPlan(
              node.offset, node.end, node.thenStatement.accept(this));
        } else {
          return DropStatementPlan(node.offset, node.end);
        }
        break;
    }
    throw StateError('Unexpected if behavior');
  }
}

enum IfBehavior {
  keepAll,
  keepConditionAndThen,
  keepConditionAndElse,
  keepThen,
  keepElse
}

class _ExpressionStatementPlan extends WrapPlan with StatementsPlan {
  _ExpressionStatementPlan(EditPlan inner) : super(inner);

  @override
  bool get isSingleStatement => true;

  void execute(EditAccumulator accumulator) {
    inner.execute(accumulator);
    accumulator.insert(end, ';');
  }
}

class _NullCheckExpressionPlan extends WrapPlan with ExpressionPlan {
  _NullCheckExpressionPlan(ExpressionPlan inner)
      : super(inner.parenthesizeFor(Precedence.postfix));

  @override
  Precedence get precedence => Precedence.postfix;

  @override
  void execute(EditAccumulator accumulator) {
    inner.execute(accumulator);
    accumulator.insert(end, '!');
  }
}

class _UnwrapPlan implements EditPlan {
  final int offset;

  final int end;

  final EditPlan _inner;

  _UnwrapPlan(this.offset, this.end, this._inner);

  @override
  void execute(EditAccumulator accumulator) {
    accumulator.delete(offset, _inner.offset);
    _inner.execute(accumulator);
    accumulator.delete(_inner.end, end);
  }
}

class _UnwrapStatementsPlan extends EditPlan with StatementsPlan {
  @override
  final int offset;

  @override
  final int end;

  final List<EditPlan> _innerPlans;

  _UnwrapStatementsPlan(this.offset, this.end, this._innerPlans);

  @override
  bool get isSingleStatement => false;

  @override
  void execute(EditAccumulator accumulator) {
    var pos = offset;
    for (var inner in _innerPlans) {
      accumulator.delete(pos, inner.offset);
      inner.execute(accumulator);
      pos = inner.end;
    }
    accumulator.delete(pos, end);
  }
}
