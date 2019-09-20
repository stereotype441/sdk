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

abstract class FixBuilder extends GeneralizingAstVisitor<_VisitResult> {
  IfBehavior getIfBehavior(IfStatement node);

  bool needsNullCheck(Expression node);

  List<SourceEdit> run(CompilationUnit unit) {
    return unit.accept(this).edits;
  }

  @override
  _VisitResult visitExpression(Expression node) {
    var result = super.visitExpression(node)..precedence = node.precedence;
    if (needsNullCheck(node)) {
      if (result.precedence < Precedence.postfix) {
        result.prefix('(');
        result.suffix(')!');
        result.precedence = Precedence.postfix;
      } else {
        result.suffix('!');
      }
    }
    return result;
  }

  @override
  _VisitResult visitIfStatement(IfStatement node) {
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
  _VisitResult visitNode(AstNode node) {
    var result = _VisitResult(node.offset, node.end);
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        var subResult = entity.accept(this);
        result.merge(subResult);
      }
    }
    return result;
  }

  _VisitResult _discardStatement() {
    throw UnimplementedError('TODO(paulberry)');
  }

  _VisitResult _extractStatement(AstNode node) {
    throw UnimplementedError('TODO(paulberry)');
  }

  _VisitResult _sequenceStatements(List<AstNode> nodes) {
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

class _VisitResult {
  final int offset;

  final int end;

  List<SourceEdit> edits = [];

  Precedence precedence;

  _VisitResult(this.offset, this.end);

  void merge(_VisitResult subResult) {
    var subEdits = subResult.edits;
    if (subEdits.isEmpty) return;
    if (edits.isEmpty) {
      edits = subEdits;
      return;
    }
    if (subEdits.first.offset == edits.last.end) {
      edits.last.length += subEdits.first.length;
      edits.last.replacement += subEdits.first.replacement;
      edits.addAll(subEdits.skip(1));
    } else {
      assert(edits.last.end < subEdits.first.offset);
      edits.addAll(subEdits);
    }
  }

  void prefix(String s) {
    if (edits.isNotEmpty && edits.first.offset == offset) {
      edits.first.replacement = s + edits.first.replacement;
    } else {
      edits.insert(0, SourceEdit(offset, 0, s));
    }
  }

  void suffix(String s) {
    if (edits.isNotEmpty && edits.last.end == end) {
      edits.last.replacement += s;
    } else {
      edits.add(SourceEdit(end, 0, s));
    }
  }
}
