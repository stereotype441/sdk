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

abstract class FixBuilder extends GeneralizingAstVisitor<_Plan> {
  IfBehavior getIfBehavior(IfStatement node);

  bool needsNullCheck(Expression node);

  List<SourceEdit> run(CompilationUnit unit) {
    var edits = <SourceEdit>[];
    unit.accept(this).execute(edits);
    return edits;
  }

  @override
  _Plan visitExpression(Expression node) {
    var innerPlan = super.visitExpression(node)..precedence = node.precedence;
    if (needsNullCheck(node)) {
      if (innerPlan.precedence < Precedence.postfix) {
        return _Plan(
            precedence: Precedence.postfix,
            execute: (edits) {
              edits.add(SourceEdit(node.offset, 0, '('));
              innerPlan.execute(edits);
              edits.add(SourceEdit(node.end, 0, ')!'));
            });
      } else {
        return _Plan(
            precedence: Precedence.postfix,
            execute: (edits) {
              innerPlan.execute(edits);
              edits.add(SourceEdit(node.end, 0, '!'));
            });
      }
    } else {
      return innerPlan;
    }
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
          return _extractStatement(node.condition);
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

  _Plan _extractStatement(AstNode node) {
    throw UnimplementedError('TODO(paulberry)');
  }

  _Plan _sequenceStatements(List<AstNode> nodes) {
    throw UnimplementedError('TODO(paulberry)');
  }
}

enum IfBehavior {
  keepAll,
  keepConditionAndThen,
  keepConditionAndElse,
  keepThen,
  keepElse
}

class _Plan {
  final void Function(List<SourceEdit> edits) execute;

  Precedence precedence;

  _Plan({@required this.execute, this.precedence});
}
