// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:nnbd_migration/src/edit_plan.dart';

class AddAs extends PreviewInfo {
  final String type;

  const AddAs(this.type);

  @override
  bool operator ==(Object other) => other is AddAs && type == other.type;
}

class AddBang extends PreviewInfo {
  const AddBang();
}

class AddQuestion extends PreviewInfo {
  const AddQuestion();
}

abstract class Change {
  const Change();

  EditPlan apply(AstNode node, FixPlanner planner);
}

class FixPlanner extends UnifyingAstVisitor<EditPlan> {
  final Map<AstNode, Change> _changes;

  final bool allowRedundantParens;

  FixPlanner._(this._changes, this.allowRedundantParens);

  EditPlan visitNode(AstNode node) {
    var plan = node is Expression
        ? SimpleEditPlan.forExpression(node)
        : SimpleEditPlan.forNonExpression(node);
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        plan.addInnerPlans(this, entity);
      }
    }
    return plan;
  }

  EditPlan visitParenthesizedExpression(ParenthesizedExpression node) {
    var change = _changes[node.expression] ?? NoChange();
    var innerPlan = change.apply(node.expression, this);
    return ProvisionalParenEditPlan(node, innerPlan);
  }

  static Map<int, List<PreviewInfo>> run(
      CompilationUnit unit, Map<AstNode, Change> changes,
      {bool allowRedundantParens = true}) {
    var planner = FixPlanner._(changes, allowRedundantParens);
    var change = changes[unit] ?? NoChange();
    return change.apply(unit, planner).getChanges(false);
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
    var innerChanges = innerPlan
        .getChanges(innerPlan.parensNeeded(threshold: Precedence.relational));
    return SimpleEditPlan.withPrecedence(node, Precedence.relational)
      ..addInnerChanges(innerChanges)
      ..addInnerChanges({
        node.end: [AddAs(type)]
      });
  }
}

class MakeNullable extends _NestableChange {
  const MakeNullable([Change inner = const NoChange()]) : super(inner);

  @override
  EditPlan apply(AstNode node, FixPlanner planner) {
    var innerPlan = _inner.apply(node, planner);
    var innerChanges = innerPlan.getChanges(false);
    return SimpleEditPlan.forNonExpression(node)
      ..addInnerChanges(innerChanges)
      ..addInnerChanges({
        node.end: [const AddQuestion()]
      });
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
    var innerChanges = innerPlan.getChanges(innerPlan.parensNeeded(
        threshold: Precedence.postfix, associative: true));
    return SimpleEditPlan.withPrecedence(node, Precedence.postfix)
      ..addInnerChanges(innerChanges)
      ..addInnerChanges({
        node.end: [const AddBang()]
      });
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

extension on SimpleEditPlan {
  void addInnerPlans(FixPlanner planner, AstNode node,
      {Precedence threshold = Precedence.none,
      bool associative = false,
      bool allowCascade = true}) {
    // TODO(paulberry): inline this method
    if (node == null) return;
    var change = planner._changes[node] ?? NoChange();
    var innerPlan = change.apply(node, planner);
    bool parensNeeded = innerPlan.parensNeededFromContext(node);
    assert(_checkParenLogic(planner, innerPlan, parensNeeded));
    if (!parensNeeded && innerPlan is ProvisionalParenEditPlan) {
      var innerInnerPlan = innerPlan.innerPlan;
      if (innerInnerPlan is SimpleEditPlan && innerInnerPlan.isPassThrough) {
        // Input source code had redundant parens, so keep them.
        parensNeeded = true;
      }
    }
    var innerChanges = innerPlan.getChanges(parensNeeded);
    addInnerChanges(innerChanges);
    if (!parensNeeded &&
        node.end == sourceNode.end &&
        innerPlan.endsInCascade) {
      endsInCascade = true;
    }
  }

  bool _checkParenLogic(
      FixPlanner planner, EditPlan innerPlan, bool parensNeeded) {
    if (innerPlan is SimpleEditPlan && innerPlan.isEmpty) {
      assert(
          !parensNeeded,
          "Code prior to fixes didn't need parens here, "
          "shouldn't need parens now.");
    }
    if (innerPlan is ProvisionalParenEditPlan) {
      var innerInnerPlan = innerPlan.innerPlan;
      if (innerInnerPlan is SimpleEditPlan &&
          innerInnerPlan.isEmpty &&
          !planner.allowRedundantParens) {
        assert(
            parensNeeded,
            "Code prior to fixes had parens here, but we think they aren't "
            "needed now.");
      }
    }
    return true;
  }
}
