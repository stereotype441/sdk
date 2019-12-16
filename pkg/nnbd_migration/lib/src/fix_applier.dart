// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:nnbd_migration/src/fix_builder.dart';

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

class _ExtractSubexpression extends Change {
  AstNode _inner;

  _ExtractSubexpression(this._inner);

  @override
  _Plan apply(AstNode node, FixPlanner planner) {
    return _inner.accept(planner);
  }
}

class _IntroduceAs extends _NestableChange {
  final String type;

  _IntroduceAs(Change inner, this.type) : super(inner);

  @override
  _Plan apply(AstNode node, FixPlanner planner) {
    return _Plan.suffix(
        _inner
            .apply(node, planner)
            .addParensIfLowerPrecedenceThan(Precedence.bitwiseOr),
        throw 'TODO(paulberry): as $type',
        Precedence.relational,
        false);
  }
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
  final int _offset;

  final int _end;

  _Plan.empty(AstNode node)
      : _precedence = _computePrecedenceFor(node),
        _offset = node.offset,
        _end = node.end;

  _Plan.suffix(
      _Plan innerPlan, PreviewInfo affix, this._precedence, this.endsInCascade)
      : _previewInfo = innerPlan._previewInfo,
        _offset = innerPlan._offset,
        _end = innerPlan._end {
    ((_previewInfo ??= {})[innerPlan._end] ??= []).add(affix);
  }

  _Plan addParensIfEndsInCascade() {
    throw UnimplementedError('TODO(paulberry)');
  }

  _Plan addParensIfLowerPrecedenceThan(Precedence other) {
    if (_precedence < other) {
      ((_previewInfo ??= {})[_offset] ??= []).insert(0, const AddOpenParen());
      ((_previewInfo ??= {})[_end] ??= []).add(const AddCloseParen());
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
    // TODO(paulberry): special handling of cascades
    if (node is Expression) return node.precedence;
    // For non-expressions we can just use Precedence.primary since no adding of
    // parens is necessary.
    return Precedence.primary;
  }
}
