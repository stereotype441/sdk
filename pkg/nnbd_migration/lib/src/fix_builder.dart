// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
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
import 'package:analyzer_plugin/protocol/protocol_common.dart' show SourceEdit;

class _VisitResult {
  final int offset;

  final int end;

  bool needsParens;

  List<SourceEdit> edits = [];

  _VisitResult(this.offset, this.end, this.needsParens);

  void prefix(String s) {
    if (edits.first.offset == offset) {
      edits.first.replacement = s + edits.first.replacement;
    } else {
      edits.insert(0, SourceEdit(offset, 0, s));
    }
  }

  void suffix(String s) {
    if (edits.last.end == end) {
      edits.last.replacement += s;
    } else {
      edits.add(SourceEdit(end, 0, s));
    }
  }

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
}

class FixBuilder extends GeneralizingAstVisitor<_VisitResult>
    with
        PermissiveModeVisitor<_VisitResult>,
        AnnotationTracker<_VisitResult> {
  @override
  final NullabilityMigrationListener listener;

  @override
  final Source source;

  FixBuilder(this.listener, this.source);

  @override
  _VisitResult visitExpression(Expression node) {
    var result = super.visitExpression(node);
    if (_needsNullCheck(node)) {
      if (result.needsParens) {
        result.prefix('(');
        result.suffix(')!');
        result.needsParens = false;
      } else {
        result.suffix('!');
      }
    }
    return result;
  }

  @override
  _VisitResult visitNode(AstNode node) {
    var result = _VisitResult(node.offset, node.end, true);
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        var subResult = entity.accept(this);
        result.merge(subResult);
      }
    }
    return result;
  }

  @override
  _VisitResult visitIfStatement(IfStatement node) {
    var conditionalDiscard = _getConditionalDiscard(node);
    // keep  pure  hasFalse behavior
    // both  DC    DC       unchanged
    // true  true  true     keep true only
    // true  true  false    keep true only
    // true  false true     keep condition and true
    // true  false false    keep condition and true
    // false true  true     keep
    if (conditionalDiscard.pu)
  }

  bool _needsNullCheck(Expression node) {
    throw UnimplementedError('TODO(paulberry)');
  }

  ConditionalDiscard _getConditionalDiscard(AstNode node) {}
}