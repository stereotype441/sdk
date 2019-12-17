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

/// TODO(paulberry): rename file to fix_planner.dart?
class FixPlanner extends GeneralizingAstVisitor<EditPlan> {
  final Map<AstNode, Change> _changes;

  final bool allowRedundantParens;

  FixPlanner._(this._changes, this.allowRedundantParens);

  EditPlan visitAsExpression(AsExpression node) {
    // TODO(paulberry): test precedence/associativity
    return SimpleEditPlan.forExpression(node)
      ..addInnerPlans(this, node.expression, threshold: node.precedence)
      ..addInnerPlans(this, node.type);
  }

  EditPlan visitAssignmentExpression(AssignmentExpression node) {
    // TODO(paulberry): test
    // TODO(paulberry): RHS context
    // TODO(paulberry): ensure that cascades are properly handled
    return SimpleEditPlan.forExpression(node)
      ..addInnerPlans(this, node.leftHandSide)
      ..addInnerPlans(this, node.rightHandSide);
  }

  EditPlan visitBinaryExpression(BinaryExpression node) {
    // TODO(paulberry): test
    // TODO(paulberry): fix context
    var precedence = node.precedence;
    return SimpleEditPlan.forExpression(node)
      ..addInnerPlans(this, node.leftOperand,
          threshold: precedence,
          associative: precedence != Precedence.relational &&
              precedence != Precedence.equality)
      ..addInnerPlans(this, node.rightOperand, threshold: precedence);
  }

  EditPlan visitExpression(Expression node) {
    throw UnimplementedError('TODO(paulberry): ${node.runtimeType}');
  }

  EditPlan visitFunctionExpression(FunctionExpression node) {
    return SimpleEditPlan.forExpression(node)
      ..addInnerPlans(this, node.typeParameters)
      ..addInnerPlans(this, node.parameters)
      ..addInnerPlans(this, node.body);
  }

  EditPlan visitNode(AstNode node) {
    var plan = SimpleEditPlan.forNonExpression(node);
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        plan.addInnerPlans(this, entity);
      }
    }
    return plan;
  }

  EditPlan visitParenthesizedExpression(ParenthesizedExpression node) {
    return ProvisionalParenEditPlan(node, _exploratory2(node.expression));
  }

  EditPlan visitPostfixExpression(PostfixExpression node) {
    // TODO(paulberry): test
    return SimpleEditPlan.forExpression(node)
      ..addInnerPlans(this, node.operand, threshold: Precedence.postfix);
  }

  EditPlan visitPrefixExpression(PrefixExpression node) {
    // TODO(paulberry): test
    return SimpleEditPlan.forExpression(node)
      ..addInnerPlans(this, node.operand);
  }

  EditPlan visitSimpleIdentifier(Expression node) {
    return SimpleEditPlan.forExpression(node);
  }

  /// This version passes around a plan
  /// TODO(paulberry): rename
  EditPlan _exploratory2(AstNode node) {
    var change = _changes[node] ?? NoChange();
    return change.apply(node, this);
  }

  static Map<int, List<PreviewInfo>> run(
      CompilationUnit unit, Map<AstNode, Change> changes,
      {bool allowRedundantParens = true}) {
    var fixPlanner = FixPlanner._(changes, allowRedundantParens);
    var plan = fixPlanner._exploratory2(unit);
    return plan.getChanges(false);
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
    var innerChanges = innerPlan.getChanges(
        innerPlan.parensNeeded(Precedence.relational, false, false));
    return SimpleEditPlan.withPrecedence(node, Precedence.relational)
      ..addInnerChanges(innerChanges)
      ..addInnerChanges({
        node.end: [AddAs(type)]
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
    var innerChanges = innerPlan
        .getChanges(innerPlan.parensNeeded(Precedence.postfix, true, false));
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

class _MakeNullable extends _NestableChange {
  _MakeNullable(Change inner) : super(inner);

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

abstract class _NestableChange extends Change {
  final Change _inner;

  const _NestableChange(this._inner);
}

extension on SimpleEditPlan {
  /// TODO(paulberry): can we infer atEnd?
  void addInnerPlans(FixPlanner planner, AstNode node,
      {Precedence threshold = Precedence.none, bool associative = false}) {
    if (node == null) return;
    // TODO(paulberry): test adding of parens
    var innerPlan = planner._exploratory2(node);
    // TODO(paulberry): do the right thing for allowCascade
    bool allowCascade = false;
    bool parensNeeded =
        innerPlan.parensNeeded(threshold, associative, allowCascade);
    assert(_checkParenLogic(planner, innerPlan, parensNeeded));
    var innerChanges = innerPlan.getChanges(parensNeeded);
    addInnerChanges(innerChanges);
  }

  bool _checkParenLogic(
      FixPlanner planner, EditPlan innerPlan, bool parensNeeded) {
    if (innerPlan is SimpleEditPlan && innerPlan.isPassThrough) {
      // TODO(paulberry): carve out an exception for cascades, e.g. changing
      // `a..b = throw c` to `a..b = (throw c..d)`
      assert(
          !parensNeeded,
          "Code prior to fixes didn't need parens here, "
          "shouldn't need parens now.");
    }
    if (innerPlan is ProvisionalParenEditPlan) {
      var innerInnerPlan = innerPlan.innerPlan;
      if (innerInnerPlan is SimpleEditPlan &&
          innerInnerPlan.isPassThrough &&
          !planner.allowRedundantParens) {
        // TODO(paulberry): carve out an exception for cascades, e.g. changing
        // `a..b = (throw c)` to `a..b = (throw c..d)`
        assert(parensNeeded,
            "Code prior to fixes needed parens here, should need parens now.");
      }
    }
    return true;
  }
}
