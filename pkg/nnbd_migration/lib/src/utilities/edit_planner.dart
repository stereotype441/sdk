// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' show SourceEdit;

class DropStatementPlan extends EditPlan with StatementsPlan {
  @override
  final int offset;

  @override
  final int end;

  DropStatementPlan(this.offset, this.end);

  @override
  bool get isSingleStatement => false;

  @override
  void execute(EditAccumulator accumulator) {
    accumulator.delete(offset, end);
  }
}

class EditAccumulator {
  final List<SourceEdit> edits = [];

  void delete(int offset, int end) {
    replace(offset, end, '');
  }

  void insert(int offset, String s) {
    replace(offset, offset, s);
  }

  void replace(int offset, int end, String s) {
    if (edits.isNotEmpty) {
      assert(edits.last.end <= offset);
      if (edits.last.end == offset) {
        edits.last.length += end - offset;
        edits.last.replacement += s;
        return;
      }
    }
    edits.add(SourceEdit(offset, end - offset, s));
  }

  bool _hasNoOverlap() {
    int acceptableNextOffset = 0;
    for (var edit in edits) {
      if (edit.offset < acceptableNextOffset) return false;
      if (edit.offset == edit.end) {
        acceptableNextOffset = edit.offset + 1;
      } else {
        acceptableNextOffset = edit.end;
      }
    }
    return true;
  }
}

abstract class EditPlan {
  int get end;

  int get offset;

  void execute(EditAccumulator accumulator);
}

/// TODO(paulberry): defunct.  Use _RecursivePlanner instead.
///
/// Note: this class overrides [visitExpression] and [visitStatement] to ensure
/// that they return the appropriate subtype of [EditPlan].  So clients that
/// override the behavior of [visitNode] should make sure to replicate the
/// behavior of their override in [visitExpression] and [visitStatement] if
/// necessary.
class EditPlanner extends GeneralizingAstVisitor<EditPlan> {
  List<SourceEdit> run(CompilationUnit unit) {
    var editAccumulator = EditAccumulator();
    unit.accept(this).execute(editAccumulator);
    assert(editAccumulator._hasNoOverlap());
    return editAccumulator.edits;
  }

  @override
  ExpressionPlan visitExpression(Expression node) {
    return RecursiveExpressionPlan._(
        node.offset, node.end, _collectSubPlans(node), node.precedence);
  }

  @override
  EditPlan visitNode(AstNode node) {
    return RecursivePlan._(node.offset, node.end, _collectSubPlans(node));
  }

  @override
  StatementsPlan visitStatement(Statement node) {
    return RecursiveStatementsPlan._(
        node.offset, node.end, _collectSubPlans(node), true);
  }

  List<EditPlan> _collectSubPlans(AstNode node) {
    var subPlans = <EditPlan>[];
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        var subPlan = entity.accept(this);
        if (subPlan is RecursivePlan) {
          subPlans.addAll(subPlan.subPlans);
        } else if (subPlan is StatementsPlan) {
          if (node is Block) {
            subPlans.add(subPlan);
          } else {
            subPlans.add(subPlan.toSingleStatement());
          }
        } else if (node is Expression &&
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

class RecursiveExpressionPlan extends RecursivePlan with ExpressionPlan {
  @override
  final Precedence precedence;

  factory RecursiveExpressionPlan(AstNode node, EditPlan subPlanner(AstNode)) =>
      node.accept(_RecursivePlanner(subPlanner)) as RecursiveExpressionPlan;

  RecursiveExpressionPlan._(
      int offset, int end, List<EditPlan> subPlans, this.precedence)
      : super._(offset, end, subPlans);
}

class RecursivePlan implements EditPlan {
  final int offset;

  final int end;

  final List<EditPlan> subPlans;

  factory RecursivePlan(AstNode node, EditPlan subPlanner(AstNode)) =>
      node.accept(_RecursivePlanner(subPlanner));

  RecursivePlan._(this.offset, this.end, this.subPlans);

  @override
  void execute(EditAccumulator accumulator) {
    for (var subPlan in subPlans) {
      subPlan.execute(accumulator);
    }
  }
}

class RecursiveStatementsPlan extends RecursivePlan with StatementsPlan {
  @override
  final bool isSingleStatement;

  factory RecursiveStatementsPlan(AstNode node, EditPlan subPlanner(AstNode)) =>
      node.accept(_RecursivePlanner(subPlanner)) as RecursiveStatementsPlan;

  RecursiveStatementsPlan._(
      int offset, int end, List<EditPlan> subPlans, this.isSingleStatement)
      : super._(offset, end, subPlans);
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

class _RecursivePlanner extends GeneralizingAstVisitor<RecursivePlan> {
  final EditPlan Function(AstNode) _subPlanner;

  _RecursivePlanner(this._subPlanner);

  @override
  RecursiveExpressionPlan visitExpression(Expression node) {
    return RecursiveExpressionPlan._(
        node.offset, node.end, _collectSubPlans(node), node.precedence);
  }

  @override
  RecursivePlan visitNode(AstNode node) {
    return RecursivePlan._(node.offset, node.end, _collectSubPlans(node));
  }

  @override
  RecursiveStatementsPlan visitStatement(Statement node) {
    return RecursiveStatementsPlan._(
        node.offset, node.end, _collectSubPlans(node), true);
  }

  List<EditPlan> _collectSubPlans(AstNode node) {
    var subPlans = <EditPlan>[];
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        var subPlan = _subPlanner(node);
        if (subPlan is RecursivePlan) {
          subPlans.addAll(subPlan.subPlans);
        } else if (subPlan is StatementsPlan) {
          if (node is Block) {
            subPlans.add(subPlan);
          } else {
            subPlans.add(subPlan.toSingleStatement());
          }
        } else if (node is Expression &&
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
