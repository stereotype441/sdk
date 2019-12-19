// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:nnbd_migration/src/edit_plan.dart';

abstract class Change {
  const Change();

  EditPlan apply(AstNode node, FixPlanner planner);
}

class FixPlanner extends UnifyingAstVisitor<EditPlan> {
  final Map<AstNode, Change> _changes;

  final bool allowRedundantParens;

  FixPlanner._(this._changes, this.allowRedundantParens);

  EditPlan visitNode(AstNode node) {
    return EditPlan.passThrough(node,
        innerPlans: <EditPlan>[
          for (var entity in node.childEntities)
            if (entity is AstNode)
              (_changes[entity] ?? NoChange()).apply(entity, this)
        ],
        allowRedundantParens: allowRedundantParens);
  }

  EditPlan visitParenthesizedExpression(ParenthesizedExpression node) {
    var change = _changes[node.expression] ?? NoChange();
    var innerPlan = change.apply(node.expression, this);
    return EditPlan.provisionalParens(node, innerPlan);
  }

  static Map<int, List<PreviewInfo>> run(
      CompilationUnit unit, Map<AstNode, Change> changes,
      {bool allowRedundantParens = true}) {
    var planner = FixPlanner._(changes, allowRedundantParens);
    var change = changes[unit] ?? NoChange();
    return change.apply(unit, planner).finalize();
  }
}

class IntroduceAs extends _NestableChange {
  /// TODO(paulberry): shouldn't be a String
  final String type;

  const IntroduceAs(this.type, [Change inner = const NoChange()])
      : super(inner);

  @override
  EditPlan apply(AstNode node, FixPlanner planner) {
    var innerPlan = _inner.apply(node, planner);
    return EditPlan.surround(innerPlan,
        suffix: [AddText(' as $type')],
        precedence: Precedence.relational,
        threshold: Precedence.relational);
  }
}

class MakeNullable extends _NestableChange {
  const MakeNullable([Change inner = const NoChange()]) : super(inner);

  @override
  EditPlan apply(AstNode node, FixPlanner planner) {
    var innerPlan = _inner.apply(node, planner);
    return EditPlan.surround(innerPlan, suffix: [const AddText('?')]);
  }
}

class NoChange extends Change {
  const NoChange();

  @override
  EditPlan apply(AstNode node, FixPlanner planner) {
    return node.accept(planner);
  }
}

class NullCheck extends _NestableChange {
  const NullCheck([Change inner = const NoChange()]) : super(inner);

  @override
  EditPlan apply(AstNode node, FixPlanner planner) {
    var innerPlan = _inner.apply(node, planner);
    return EditPlan.surround(innerPlan,
        suffix: [const AddText('!')],
        precedence: Precedence.postfix,
        threshold: Precedence.postfix,
        associative: true);
  }
}

class RemoveAs extends _NestableChange {
  const RemoveAs([Change inner = const NoChange()]) : super(inner);

  @override
  EditPlan apply(AstNode node, FixPlanner planner) {
    return EditPlan.extract(
        node, _inner.apply((node as AsExpression).expression, planner));
  }
}

abstract class _NestableChange extends Change {
  final Change _inner;

  const _NestableChange(this._inner);
}
