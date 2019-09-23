// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' show SourceEdit;

class EditAccumulator {
  List<SourceEdit> edits;

  void delete(int offset, int end) {
    edits.add(SourceEdit(offset, end - offset, ''));
  }

  void insert(int offset, String s) {
    edits.add(SourceEdit(offset, 0, s));
  }
}

abstract class EditPlan {
  int get end;

  int get offset;

  void execute(EditAccumulator accumulator);
}

class EditPlanner extends GeneralizingAstVisitor<EditPlan> {
  List<SourceEdit> run(CompilationUnit unit) {
    var editAccumulator = EditAccumulator();
    unit.accept(this).execute(editAccumulator);
    return editAccumulator.edits;
  }

  @override
  ExpressionPlan visitExpression(Expression node) {
    return _RecursiveExpressionPlan._(
        node.offset, node.end, _collectSubPlans(node), node.precedence);
  }

  @override
  EditPlan visitNode(AstNode node) {
    return _RecursivePlan._(node.offset, node.end, _collectSubPlans(node));
  }

  @override
  StatementsPlan visitStatement(Statement node) {
    return _RecursiveStatementsPlan._(
        node.offset, node.end, _collectSubPlans(node), true);
  }

  List<EditPlan> _collectSubPlans(AstNode node) {
    var subPlans = <EditPlan>[];
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        var subPlan = entity.accept(this);
        if (subPlan is _RecursivePlan) {
          subPlans.addAll(subPlan.subPlans);
        } else if (subPlan is StatementsPlan) {
          subPlans.add(subPlan.toSingleStatement());
        } else if (this is Expression &&
            entity is Expression &&
            subPlan is ExpressionPlan) {
          // We know that [entity] was allowed here, so parenthesize the
          // replacement if it has lower precedence than entity's precedence.
          // TODO(paulberry): this is a conservative approximation.  Really we
          // should have separate overrides for each expression type that know
          // precisely what precedence is allowed for each subexpression.
          subPlans.add(subPlan.parenthesizeFor(entity.precedence));
        } else {
          subPlans.add(subPlan);
        }
      }
    }
    return subPlans;
  }
}

mixin ExpressionPlan on EditPlan {
  Precedence get precedence;

  ExpressionPlan parenthesizeFor(Precedence precedence) {
    if (this.precedence < precedence) {
      return _ParenthesesPlan(this);
    } else {
      return this;
    }
  }
}

mixin StatementsPlan on EditPlan {
  bool get isSingleStatement;

  StatementsPlan toSingleStatement() {
    if (!this.isSingleStatement) {
      return _BlockPlan(this);
    } else {
      return this;
    }
  }
}

abstract class WrapPlan implements EditPlan {
  final EditPlan inner;

  WrapPlan(this.inner);

  int get end => inner.end;

  int get offset => inner.offset;
}

class _BlockPlan extends WrapPlan with StatementsPlan {
  _BlockPlan(EditPlan inner) : super(inner);

  @override
  bool get isSingleStatement => true;

  @override
  void execute(EditAccumulator accumulator) {
    accumulator.insert(offset, '{');
    inner.execute(accumulator);
    accumulator.insert(end, '}');
  }
}

class _ParenthesesPlan extends WrapPlan with ExpressionPlan {
  _ParenthesesPlan(EditPlan inner) : super(inner);

  @override
  Precedence get precedence => Precedence.primary;

  @override
  void execute(EditAccumulator accumulator) {
    accumulator.insert(offset, '(');
    inner.execute(accumulator);
    accumulator.insert(end, ')');
  }
}

class _RecursiveExpressionPlan extends _RecursivePlan with ExpressionPlan {
  @override
  final Precedence precedence;

  _RecursiveExpressionPlan._(
      int offset, int end, List<EditPlan> subPlans, this.precedence)
      : super._(offset, end, subPlans);
}

class _RecursivePlan implements EditPlan {
  final int offset;

  final int end;

  final List<EditPlan> subPlans;

  _RecursivePlan._(this.offset, this.end, this.subPlans);

  @override
  void execute(EditAccumulator accumulator) {
    for (var subPlan in subPlans) {
      subPlan.execute(accumulator);
    }
  }
}

class _RecursiveStatementsPlan extends _RecursivePlan with StatementsPlan {
  @override
  final bool isSingleStatement;

  _RecursiveStatementsPlan._(
      int offset, int end, List<EditPlan> subPlans, this.isSingleStatement)
      : super._(offset, end, subPlans);
}
