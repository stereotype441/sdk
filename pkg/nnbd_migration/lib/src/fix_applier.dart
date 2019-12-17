// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:nnbd_migration/src/fix_builder.dart';

class AddAs extends PreviewInfo {
  final String type;

  const AddAs(this.type);

  @override
  bool operator ==(Object other) => other is AddAs && type == other.type;
}

class AddBang extends PreviewInfo {
  const AddBang();
}

class AddCloseParen extends PreviewInfo {
  const AddCloseParen();
}

class AddOpenParen extends PreviewInfo {
  const AddOpenParen();
}

abstract class Change {
  const Change();

  _Plan apply(AstNode node, FixPlanner planner);
}

/// TODO(paulberry): rename file to fix_planner.dart?
class FixPlanner extends GeneralizingAstVisitor<_Plan> {
  final Map<AstNode, Change> _changes;

  FixPlanner._(this._changes);

  _Plan visitAssignmentExpression(AssignmentExpression node) {
    // TODO(paulberry): test
    // TODO(paulberry): RHS context
    // TODO(paulberry): ensure that cascades are properly handled
    return _Plan.empty(node)
      ..subsume(this, node.leftHandSide)
      ..subsume(this, node.rightHandSide, atEnd: true);
  }

  _Plan visitBinaryExpression(BinaryExpression node) {
    // TODO(paulberry): test
    // TODO(paulberry): fix context
    return _Plan.empty(node)
      ..subsume(this, node.leftOperand, context: node.precedence)
      ..subsume(this, node.rightOperand, context: node.precedence, atEnd: true);
  }

  _Plan visitExpression(Expression node) {
    throw UnimplementedError('TODO(paulberry): ${node.runtimeType}');
  }

  _Plan visitFunctionExpression(FunctionExpression node) {
    return _Plan.empty(node)
      ..subsume(this, node.typeParameters)
      ..subsume(this, node.parameters)
      ..subsume(this, node.body);
  }

  _Plan visitNode(AstNode node) {
    var plan = _Plan.empty(node);
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        plan.subsume(this, entity);
      }
    }
    return plan;
  }

  _Plan visitParenthesizedExpression(ParenthesizedExpression node) {
    // TODO(paulberry): I think we need to do something smarter than pass atEnd
    // as true.  It will be wrong if there are doubly nested parens.
    return _Plan.empty(node)..subsume(this, node.expression, atEnd: true);
  }

  _Plan visitPostfixExpression(PostfixExpression node) {
    // TODO(paulberry): test
    return _Plan.empty(node)
      ..subsume(this, node.operand, context: Precedence.postfix, atEnd: true);
  }

  _Plan visitPrefixExpression(PrefixExpression node) {
    // TODO(paulberry): test
    return _Plan.empty(node)..subsume(this, node.operand);
  }

  _Plan visitSimpleIdentifier(Expression node) {
    return _Plan.empty(node);
  }

  /// This version passes around a plan
  /// TODO(paulberry): rename
  _Plan _exploratory2(AstNode node) {
    var change = _changes[node] ?? NoChange();
    return change.apply(node, this);
  }

  static Map<int, List<PreviewInfo>> run(
      CompilationUnit unit, Map<AstNode, Change> changes) {
    var fixPlanner = FixPlanner._(changes);
    var plan = fixPlanner._exploratory2(unit);
    return plan._previewInfo;
  }
}

class IntroduceAs extends _NestableChange {
  /// TODO(paulberry): shouldn't be a String
  final String type;

  const IntroduceAs(this.type, [Change inner = const NoChange()])
      : super(inner);

  @override
  _Plan apply(AstNode node, FixPlanner planner) {
    return _Plan.suffix(
        _inner
            .apply(node, planner)
            .addParensIfLowerPrecedenceThan(Precedence.bitwiseOr),
        AddAs(type),
        Precedence.relational,
        false);
  }
}

class NoChange extends Change {
  const NoChange();

  @override
  _Plan apply(AstNode node, FixPlanner planner) {
    return node.accept(planner);
  }
}

class NullCheck extends _NestableChange {
  const NullCheck([Change inner = const NoChange()]) : super(inner);

  @override
  _Plan apply(AstNode node, FixPlanner planner) {
    return _Plan.suffix(
        _inner
            .apply(node, planner)
            .addParensIfLowerPrecedenceThan(Precedence.postfix),
        const AddBang(),
        Precedence.postfix,
        false);
  }
}

abstract class PreviewInfo {
  const PreviewInfo();
}

class RemoveAs extends _NestableChange {
  const RemoveAs([Change inner = const NoChange()]) : super(inner);

  @override
  _Plan apply(AstNode node, FixPlanner planner) {
    return _Plan.extract(
        node, _inner.apply((node as AsExpression).expression, planner));
  }
}

class RemoveText extends PreviewInfo {
  final int length;

  const RemoveText(this.length);

  @override
  bool operator ==(Object other) =>
      other is RemoveText && length == other.length;

  @override
  String toString() => 'RemoveText($length)';
}

class _MakeNullable extends _NestableChange {
  _MakeNullable(Change inner) : super(inner);

  @override
  _Plan apply(AstNode node, FixPlanner planner) {
    return _Plan.suffix(_inner.apply(node, planner), throw 'TODO(paulberry): ?',
        Precedence.primary, false);
  }
}

abstract class _NestableChange extends Change {
  final Change _inner;

  const _NestableChange(this._inner);
}

class _Plan {
  bool endsInCascade = false;

  Map<int, List<PreviewInfo>> _previewInfo;

  final Precedence _precedence;

  /// TODO(paulberry): should I replace offset and end with a node?
  final AstNode _node;

  _Plan.empty(AstNode node)
      : _precedence = _computePrecedenceFor(node),
        _node = node;

  _Plan.extract(AstNode node, _Plan innerPlan)
      : _previewInfo = innerPlan._previewInfo,
        _precedence = _computePrecedenceFor(node),
        endsInCascade = innerPlan.endsInCascade,
        _node = node {
    // TODO(paulberry): don't remove comments
    if (innerPlan._node.offset > _node.offset) {
      ((_previewInfo ??= {})[_node.offset] ??= [])
          .insert(0, RemoveText(innerPlan._node.offset - _node.offset));
    }
    if (innerPlan._node.end < _node.end) {
      ((_previewInfo ??= {})[innerPlan._node.end] ??= [])
          .add(RemoveText(_node.end - innerPlan._node.end));
    }
  }

  _Plan.suffix(
      _Plan innerPlan, PreviewInfo affix, this._precedence, this.endsInCascade)
      : _previewInfo = innerPlan._previewInfo,
        _node = innerPlan._node {
    ((_previewInfo ??= {})[innerPlan._node.end] ??= []).add(affix);
  }

  _Plan addParensIfEndsInCascade() {
    // TODO(paulberry): I think I have to combine with
    // addParensIfLowerPrecedenceThan so that I can compute the necessity for
    // parens once.
    throw UnimplementedError('TODO(paulberry)');
  }

  _Plan addParensIfLowerPrecedenceThan(Precedence other) {
    bool parensNeeded = _precedence < other;
    if (parensNeeded && _node is! ParenthesizedExpression) {
      ((_previewInfo ??= {})[_node.offset] ??= [])
          .insert(0, const AddOpenParen());
      ((_previewInfo ??= {})[_node.end] ??= []).add(const AddCloseParen());
    } else if (!parensNeeded && _node is ParenthesizedExpression) {
      // TODO(paulberry): preserve empty parens if no other significant changes
      ((_previewInfo ??= {})[_node.offset] ??= []).add(const RemoveText(1));
      ((_previewInfo ??= {})[_node.end - 1] ??= []).add(const RemoveText(1));
    }
    return this;
  }

  void execute() {
    throw UnimplementedError('TODO(paulberry)');
  }

  /// TODO(paulberry): subsume is no longer a good name.
  void subsume(FixPlanner planner, AstNode node,
      {Precedence context = Precedence.none, bool atEnd: false}) {
    if (node == null) return;
    // TODO(paulberry): test adding of parens
    var subPlan =
        planner._exploratory2(node).addParensIfLowerPrecedenceThan(context);
    // TODO(paulberry): test adding of parens for cascade reasons
    if (atEnd && subPlan.endsInCascade) {
      endsInCascade = true;
    }
    if (_previewInfo == null) {
      _previewInfo = subPlan._previewInfo;
    } else {
      _previewInfo.addAll(subPlan._previewInfo);
    }
  }

  static Precedence _computePrecedenceFor(AstNode node) {
    if (node is ParenthesizedExpression) {
      return node.expression.precedence;
    } else if (node is Expression) {
      return node.precedence;
    } else {
      // For non-expressions we can just use Precedence.primary since no adding
      // of parens is necessary.
      return Precedence.primary;
    }
  }
}
