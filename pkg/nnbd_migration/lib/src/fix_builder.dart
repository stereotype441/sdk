// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/handle.dart';
import 'package:analyzer/src/dart/element/inheritance_manager3.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis_visitor.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' show SourceEdit;
import 'package:front_end/src/fasta/flow_analysis/flow_analysis.dart';
import 'package:meta/meta.dart';
import 'package:nnbd_migration/instrumentation.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:nnbd_migration/src/conditional_discard.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/decorated_type.dart';
import 'package:nnbd_migration/src/edge_origin.dart';
import 'package:nnbd_migration/src/expression_checks.dart';
import 'package:nnbd_migration/src/node_builder.dart';
import 'package:nnbd_migration/src/nullability_node.dart';
import 'package:nnbd_migration/src/utilities/annotation_tracker.dart';
import 'package:nnbd_migration/src/utilities/permissive_mode.dart';
import 'package:nnbd_migration/src/utilities/scoped_set.dart';

class _EditAccumulator {
  List<SourceEdit> edits;

  void insert(int offset, String s) {
    edits.add(SourceEdit(offset, 0, s));
  }

  void delete(int offset, int end) {
    edits.add(SourceEdit(offset, end - offset, ''));
  }
}

class _RecursivePlanVisitor extends GeneralizingAstVisitor<_RecursivePlan> {
  final _Planner _subPlanner;

  _RecursivePlanVisitor(this._subPlanner);
  
  @override
  _RecursivePlan visitExpression(Expression node) {
    assert(false);
    var subPlans = <_Plan>[];
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        var subPlan = _subPlanner(entity);
        if (subPlan is _RecursivePlan) {
          subPlans.addAll(subPlan.subPlans);
        } else if (entity is Expression && subPlan is _ExpressionPlan) {
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
    return _RecursiveExpressionPlan._(node.offset, node.end, subPlans, node.precedence);
  }

  @override
  _RecursivePlan visitBlock(Block node) {
    var subPlans = <_Plan>[];
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        var subPlan = _subPlanner(entity);
        if (subPlan is _RecursivePlan) {
          subPlans.addAll(subPlan.subPlans);
        } else {
          subPlans.add(subPlan);
        }
      }
    }
    return _RecursiveStatementsPlan._(node.offset, node.end, subPlans, true);
  }

  @override
  _RecursivePlan visitNode(AstNode node) {
    var subPlans = <_Plan>[];
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        var subPlan = _subPlanner(entity);
        if (subPlan is _RecursivePlan) {
          subPlans.addAll(subPlan.subPlans);
        } else if (subPlan is _StatementsPlan) {
          subPlans.add(subPlan.toBlock());
        } else {
          subPlans.add(subPlan);
        }
      }
    }
    if (node is Statement) {
      return _RecursiveStatementsPlan._(node.offset, node.end, subPlans, false);
    } else {
      return _RecursivePlan._(node.offset, node.end, subPlans);
    }
  }
}

typedef _Plan _Planner(AstNode node);

abstract class FixBuilder extends GeneralizingAstVisitor<_Plan> {
  IfBehavior getIfBehavior(IfStatement node);

  bool needsNullCheck(Expression node);

  List<SourceEdit> run(CompilationUnit unit) {
    var editAccumulator = _EditAccumulator();
    unit.accept(this).execute(editAccumulator);
    return editAccumulator.edits;
  }

  @override
  _Plan visitNode(AstNode node) {
    return _RecursivePlan(node, (subNode) => subNode.accept(this));
  }

  @override
  _Plan visitExpression(Expression node) {
    var plan = visitNode(node);
    if (needsNullCheck(node)) {
      plan = _NullCheckExpressionPlan(plan);
    }
    return plan;
  }

  @override
  _Plan visitIfStatement(IfStatement node) {
    switch (getIfBehavior(node)) {
      case IfBehavior.keepAll:
        return visitNode(node);
      case IfBehavior.keepConditionAndThen:
        return _sequenceStatements([node.condition, node.thenStatement]);
      case IfBehavior.keepConditionAndElse:
        if (node.elseStatement != null) {
          return _sequenceStatements([node.condition, node.elseStatement]);
        } else {
          return _extractStatement(_expressionToStatement(node.condition));
        }
        break;
      case IfBehavior.keepThen:
        return _extractStatement(node.thenStatement);
      case IfBehavior.keepElse:
        if (node.elseStatement != null) {
          return _extractStatement(node.elseStatement);
        } else {
          return _discardStatement();
        }
        break;
    }
    throw StateError('Unexpected if behavior');
  }



  _Plan _discardStatement() {
    throw UnimplementedError('TODO(paulberry)');
  }

  _StatementPlan _extractStatement(AstNode node) {
    var innerPlan =
    return _Plan(execute: (edits) {

    });
    throw UnimplementedError('TODO(paulberry)');
  }

  _Plan _sequenceStatements(List<AstNode> nodes) {
    throw UnimplementedError('TODO(paulberry)');
  }

  _StatementPlan _expressionToStatement(_ExpressionPlan inner) {
    return _StatementPlan(execute: (edits) {
      inner.execute(edits);
      edits.add(SourceEdit(inner.end, 0, ';'));
    });
  }
}

enum IfBehavior {
  keepAll,
  keepConditionAndThen,
  keepConditionAndElse,
  keepThen,
  keepElse
}

abstract class _Plan {
  int get offset;

  int get end;

  void execute(_EditAccumulator accumulator);
}

mixin _ExpressionPlan on _Plan {
  Precedence get precedence;

  _ExpressionPlan parenthesizeFor(Precedence precedence) {
    if (this.precedence < precedence) {
      return _ParenthesesPlan(this);
    } else {
      return this;
    }
  }
}

mixin _StatementsPlan on _Plan {
  bool get isBlock;

  _StatementsPlan toBlock() {
    if (!this.isBlock) {
      return _BlockPlan(this);
    } else {
      return this;
    }
  }
}

abstract class _WrapPlan implements _Plan {
  final _Plan _inner;

  _WrapPlan(this._inner);

  int get offset => _inner.offset;

  int get end => _inner.end;
}

class _ParenthesesPlan extends _WrapPlan with _ExpressionPlan {
  _ParenthesesPlan(_Plan inner) : super(inner);

  @override
  void execute(_EditAccumulator accumulator) {
    accumulator.insert(offset, '(');
    _inner.execute(accumulator);
    accumulator.insert(end, ')');
  }

  @override
  Precedence get precedence => Precedence.primary;
}

class _BlockPlan extends _WrapPlan with _StatementsPlan {
  _BlockPlan(_Plan inner) : super(inner);

  @override
  void execute(_EditAccumulator accumulator) {
    accumulator.indent(2);
    accumulator.insert(offset, '{\n' + accumulator.indentation(offset));
    _inner.execute(accumulator);
    accumulator.indent(-2);
    accumulator.insert(end, '\n' + accumulator.indentation(end) + '}');
  }

  @override
  bool get isBlock => true;
}

class _NullCheckExpressionPlan extends _WrapPlan with _ExpressionPlan {
  _NullCheckExpressionPlan(_ExpressionPlan inner) : super(inner.parenthesizeFor(Precedence.postfix));

  @override
  void execute(_EditAccumulator accumulator) {
    _inner.execute(accumulator);
    accumulator.insert(end, '!');
  }

  @override
  Precedence get precedence => Precedence.postfix;
}

abstract class _UnwrapPlan implements _Plan {
  final _Plan _inner;

  final int offset;

  final int end;

  _UnwrapPlan(this._inner, this.offset, this.end);

  @override
  void execute(_EditAccumulator accumulator) {
    accumulator.delete(offset, _inner.offset);
    _inner.execute(accumulator);
    accumulator.delete(_inner.end, end);
  }
}

class _ExpressionStatementPlan extends _WrapPlan with _StatementsPlan {
  _ExpressionStatementPlan(_Plan inner) : super(inner);

  void execute(_EditAccumulator accumulator) {
    _inner.execute(accumulator);
    accumulator.insert(end, ';');
  }

  @override
  bool get isBlock => false;
}

class _RecursivePlan implements _Plan {
  final int offset;

  final int end;

  final List<_Plan> subPlans;

  _RecursivePlan._(this.offset, this.end, this.subPlans);

  @override
  void execute(_EditAccumulator accumulator) {
    for (var subPlan in subPlans) {
      subPlan.execute(accumulator);
    }
  }
  
  factory _RecursivePlan(AstNode node, _Planner subPlanner) {
    return node.accept(_RecursivePlanVisitor(subPlanner));
  }
}

class _RecursiveExpressionPlan extends _RecursivePlan with _ExpressionPlan {
  _RecursiveExpressionPlan._(int offset, int end, List<_Plan> subPlans, this.precedence) : super._(offset, end, subPlans);

  @override
  final Precedence precedence;
}

class _RecursiveStatementsPlan extends _RecursivePlan with _StatementsPlan {
  _RecursiveStatementsPlan._(int offset, int end, List<_Plan> subPlans, this.isBlock) : super._(offset, end, subPlans);

  @override
  final bool isBlock;
}

/// TODO(paulberry): maybe not needed?
class _IdentityPlan implements _Plan {
  final int offset;

  final int end;

  _IdentityPlan(this.offset, this.end);

  @override
  void execute(_EditAccumulator accumulator) {}
}
