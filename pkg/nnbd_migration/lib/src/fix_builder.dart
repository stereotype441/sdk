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

abstract class FixBuilder extends GeneralizingAstVisitor<_Plan> {
  IfBehavior getIfBehavior(IfStatement node);

  bool needsNullCheck(Expression node);

  List<SourceEdit> run(CompilationUnit unit) {
    var editAccumulator = _EditAccumulator();
    unit.accept(this).execute(editAccumulator);
    return editAccumulator.edits;
  }

  @override
  _ExpressionPlan visitExpression(Expression node) {
    var innerPlan = super.visitExpression(node);
    var expressionPlan = _ExpressionPlan(innerPlan.offset, innerPlan.end, innerPlan.execute, node.precedence);
    if (needsNullCheck(node)) {
      expressionPlan = _ExpressionPlan.nullCheck(expressionPlan);
    }
    return expressionPlan;
  }

  @override
  _Plan visitIfStatement(IfStatement node) {
    switch (getIfBehavior(node)) {
      case IfBehavior.keepAll:
        return super.visitIfStatement(node);
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

  @override
  _Plan visitNode(AstNode node) {
    return _Plan(execute: (edits) {
      for (var entity in node.childEntities) {
        if (entity is AstNode) {
          entity.accept(this).execute(edits);
        }
      }
    });
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

class _ExpressionPlan extends _Plan {
  final Precedence precedence;

  _ExpressionPlan(int offset, int end, _PlanExecutor execute, this.precedence) : super(offset, end, execute);

  _ExpressionPlan.nullCheck(_ExpressionPlan inner) : this(inner.offset, inner.end, (editAccumulator) {
    if (inner.precedence < Precedence.postfix) {
      editAccumulator.insert(inner.offset, '(');
            inner.execute(editAccumulator);
            editAccumulator.insert(inner.end, ')!');
    } else {
      inner.execute(editAccumulator);
      editAccumulator.insert(inner.end, '!');
    }
  }, Precedence.postfix);
}

class _StatementPlan extends _Plan {
  _StatementPlan(int offset, int end, _PlanExecutor execute) : super(offset, end, execute);

  _StatementPlan.expressionStatement(_ExpressionPlan inner) : this(inner.offset, inner.end, (editAccumulator) {
    inner.execute(editAccumulator);
    editAccumulator.insert(inner.end, ';');
  });

  _StatementPlan.liftStatement(int offset, int end, _ExpressionPlan inner) : this(offset, end, (editAccumulator) {
    editAccumulator.delete(offset, inner.offset);
    inner.execute(editAccumulator);
    editAccumulator.delete(inner.end, end);
  });
}

typedef void _PlanExecutor(_EditAccumulator editAccumulator);

class _Plan {
  final int offset;

  final int end;

  final _PlanExecutor execute;

  _Plan(this.offset, this.end, this.execute);
}
