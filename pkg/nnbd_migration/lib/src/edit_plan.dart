// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:meta/meta.dart';

class AddCloseParen extends PreviewInfo {
  const AddCloseParen();
}

class AddOpenParen extends PreviewInfo {
  const AddOpenParen();
}

abstract class EditPlan {
  final AstNode sourceNode;

  EditPlan(this.sourceNode);

  /// Creates a new edit plan that consists of executing [innerPlan], and then
  /// removing from the source code any code that is in [sourceNode] but not in
  /// [innerPlan.sourceNode].  This is intended to be used to drop unnecessary
  /// syntax (for example, to drop an unnecessary cast).
  ///
  /// Caller should not re-use [innerPlan] after this call--it (and the data
  /// structures it points to) may be incorporated into this edit plan and later
  /// modified.
  factory EditPlan.extract(AstNode sourceNode, EditPlan innerPlan) {
    if (innerPlan is ProvisionalParenEditPlan) {
      return _ProvisionalParenExtractEditPlan(sourceNode, innerPlan);
    } else {
      return _ExtractEditPlan(sourceNode, innerPlan);
    }
  }

  bool get endsInCascade;

  Map<int, List<PreviewInfo>> getChanges(bool parens);

  bool parensNeeded(
      {@required Precedence threshold,
      bool associative = false,
      bool allowCascade = false});

  bool parensNeededFromContext() {
    // TODO(paulberry): would it be more general to have a getChangesForContext?
    // That way I could customize provisional behavior to preserve inner parens
    // in `throw (a..b)` when it's placed in a context that doesn't allow
    // cascades.
    return sourceNode.parent.accept(_ParensNeededFromContextVisitor(this));
  }

  Map<int, List<PreviewInfo>> _createAddParenChanges(
      Map<int, List<PreviewInfo>> changes) {
    changes ??= {};
    (changes[sourceNode.offset] ??= []).insert(0, const AddOpenParen());
    (changes[sourceNode.end] ??= []).add(const AddCloseParen());
    return changes;
  }

  static Map<int, List<PreviewInfo>> _createExtractChanges(EditPlan innerPlan,
      AstNode sourceNode, Map<int, List<PreviewInfo>> changes) {
    // TODO(paulberry): don't remove comments
    if (innerPlan.sourceNode.offset > sourceNode.offset) {
      ((changes ??= {})[sourceNode.offset] ??= []).insert(
          0, RemoveText(innerPlan.sourceNode.offset - sourceNode.offset));
    }
    if (innerPlan.sourceNode.end < sourceNode.end) {
      ((changes ??= {})[innerPlan.sourceNode.end] ??= [])
          .add(RemoveText(sourceNode.end - innerPlan.sourceNode.end));
    }
    return changes;
  }
}

abstract class PreviewInfo {
  const PreviewInfo();
}

class ProvisionalParenEditPlan extends _NestedEditPlan {
  /// Creates a new edit plan that consists of executing [innerPlan], and then
  /// possibly removing surrounding parentheses from the source code.
  ///
  /// Caller should not re-use [innerPlan] after this call--it (and the data
  /// structures it points to) may be incorporated into this edit plan and later
  /// modified.
  ProvisionalParenEditPlan(ParenthesizedExpression node, EditPlan innerPlan)
      : super(node, innerPlan);

  @override
  Map<int, List<PreviewInfo>> getChanges(bool parens) {
    var changes = innerPlan.getChanges(false);
    if (!parens) {
      changes ??= {};
      (changes[sourceNode.offset] ??= []).add(const RemoveText(1));
      (changes[sourceNode.end - 1] ??= []).add(const RemoveText(1));
    }
    return changes;
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

class SimpleEditPlan extends EditPlan {
  Precedence _precedence;

  @override
  bool endsInCascade = false;

  Map<int, List<PreviewInfo>> _innerChanges;

  final bool isPassThrough;

  SimpleEditPlan.forNonExpression(AstNode node)
      : assert(node is! Expression),
        _precedence = Precedence.primary,
        isPassThrough = true,
        super(node);

  factory SimpleEditPlan.passThrough(AstNode node,
      {Iterable<EditPlan> innerPlans = const [],
      bool allowRedundantParens = true}) {
    bool /*?*/ endsInCascade = node is CascadeExpression ? true : null;
    Map<int, List<PreviewInfo>> changes;
    for (var innerPlan in innerPlans) {
      var parensNeeded = innerPlan.parensNeededFromContext();
      assert(_checkParenLogic(innerPlan, parensNeeded, allowRedundantParens));
      if (!parensNeeded && innerPlan is ProvisionalParenEditPlan) {
        var innerInnerPlan = innerPlan.innerPlan;
        if (innerInnerPlan is SimpleEditPlan && innerInnerPlan.isPassThrough) {
          // Input source code had redundant parens, so keep them.
          parensNeeded = true;
        }
      }
      changes += innerPlan.getChanges(parensNeeded);
      if (endsInCascade == null && innerPlan.sourceNode.end == node.end) {
        endsInCascade = !parensNeeded && innerPlan.endsInCascade;
      }
    }
    return SimpleEditPlan._(
        node,
        node is Expression ? node.precedence : Precedence.primary,
        endsInCascade ?? _EndsInCascadeVisitor.run(node),
        changes);
  }

  SimpleEditPlan.withPrecedence(AstNode node, this._precedence)
      : isPassThrough = false,
        super(node);

  SimpleEditPlan._(
      AstNode node, this._precedence, this.endsInCascade, this._innerChanges)
      : isPassThrough = true,
        super(node);

  bool get isEmpty => _innerChanges == null;

  /// Adds the set of changes in [newChanges] to this edit plan.
  ///
  /// Caller should not re-use [newChanges] after this call--it (and the data
  /// structures it points to) may be incorporated into this edit plan and later
  /// modified.
  void addInnerChanges(Map<int, List<PreviewInfo>> newChanges) {
    _innerChanges += newChanges;
  }

  @override
  Map<int, List<PreviewInfo>> getChanges(bool parens) {
    if (parens) {
      return _createAddParenChanges(_innerChanges);
    } else {
      return _innerChanges;
    }
  }

  @override
  bool parensNeeded(
      {@required Precedence threshold,
      bool associative = false,
      bool allowCascade = false}) {
    if (endsInCascade && !allowCascade) return true;
    if (_precedence < threshold) return true;
    if (_precedence == threshold && !associative) return true;
    return false;
  }

  static bool _checkParenLogic(
      EditPlan innerPlan, bool parensNeeded, bool allowRedundantParens) {
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
          !allowRedundantParens) {
        assert(
            parensNeeded,
            "Code prior to fixes had parens here, but we think they aren't "
            "needed now.");
      }
    }
    return true;
  }
}

/// TODO(paulberry): unit test
class _EndsInCascadeVisitor extends UnifyingAstVisitor<void> {
  bool endsInCascade = false;

  final int end;

  _EndsInCascadeVisitor(this.end);

  @override
  void visitCascadeExpression(CascadeExpression node) {
    endsInCascade = true;
  }

  @override
  void visitNode(AstNode node) {
    if (node.end != end) return;
    node.visitChildren(this);
  }

  static bool run(AstNode node) {
    var visitor = _EndsInCascadeVisitor(node.end);
    node.accept(visitor);
    return visitor.endsInCascade;
  }
}

class _ExtractEditPlan extends _NestedEditPlan {
  final Map<int, List<PreviewInfo>> _innerChanges;

  _ExtractEditPlan(AstNode sourceNode, EditPlan innerPlan)
      : _innerChanges = EditPlan._createExtractChanges(
            innerPlan, sourceNode, innerPlan.getChanges(false)),
        super(sourceNode, innerPlan);

  @override
  Map<int, List<PreviewInfo>> getChanges(bool parens) {
    if (parens) {
      return _createAddParenChanges(_innerChanges);
    } else {
      return _innerChanges;
    }
  }
}

abstract class _NestedEditPlan extends EditPlan {
  final EditPlan innerPlan;

  _NestedEditPlan(AstNode sourceNode, this.innerPlan) : super(sourceNode);

  @override
  bool get endsInCascade => innerPlan.endsInCascade;

  @override
  bool parensNeeded(
          {@required Precedence threshold,
          bool associative = false,
          bool allowCascade = false}) =>
      innerPlan.parensNeeded(
          threshold: threshold,
          associative: associative,
          allowCascade: allowCascade);
}

class _ParensNeededFromContextVisitor extends GeneralizingAstVisitor<bool> {
  final EditPlan editPlan;

  _ParensNeededFromContextVisitor(this.editPlan);

  AstNode get target => editPlan.sourceNode;

  @override
  bool visitAsExpression(AsExpression node) {
    if (identical(target, node.expression)) {
      return editPlan.parensNeeded(threshold: Precedence.relational);
    } else {
      return false;
    }
  }

  @override
  bool visitAssignmentExpression(AssignmentExpression node) {
    if (identical(target, node.rightHandSide)) {
      return editPlan.parensNeeded(
          threshold: Precedence.none,
          allowCascade: node.parent is! CascadeExpression);
    } else {
      return false;
    }
  }

  @override
  bool visitAwaitExpression(AwaitExpression node) {
    assert(identical(target, node.expression));
    return editPlan.parensNeeded(
        threshold: Precedence.prefix, associative: true);
  }

  @override
  bool visitBinaryExpression(BinaryExpression node) {
    var precedence = node.precedence;
    return editPlan.parensNeeded(
        threshold: precedence,
        associative: identical(target, node.leftOperand) &&
            precedence != Precedence.relational &&
            precedence != Precedence.equality);
  }

  @override
  bool visitCascadeExpression(CascadeExpression node) {
    if (identical(target, node.target)) {
      return editPlan.parensNeeded(
          threshold: Precedence.cascade, associative: true, allowCascade: true);
    } else {
      return false;
    }
  }

  @override
  bool visitConditionalExpression(ConditionalExpression node) {
    if (identical(target, node.condition)) {
      return editPlan.parensNeeded(threshold: Precedence.conditional);
    } else {
      return editPlan.parensNeeded(threshold: Precedence.none);
    }
  }

  @override
  bool visitExtensionOverride(ExtensionOverride node) {
    assert(identical(target, node.extensionName));
    return editPlan.parensNeeded(
        threshold: Precedence.postfix, associative: true);
  }

  @override
  bool visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    assert(identical(target, node.function));
    return editPlan.parensNeeded(
        threshold: Precedence.postfix, associative: true);
  }

  @override
  bool visitIndexExpression(IndexExpression node) {
    if (identical(target, node.target)) {
      return editPlan.parensNeeded(
          threshold: Precedence.postfix, associative: true);
    } else {
      return false;
    }
  }

  @override
  bool visitInstanceCreationExpression(InstanceCreationExpression node) {
    assert(identical(target, node.constructorName));
    return editPlan.parensNeeded(
        threshold: Precedence.postfix, associative: true);
  }

  @override
  bool visitIsExpression(IsExpression node) {
    if (identical(target, node.expression)) {
      return editPlan.parensNeeded(threshold: Precedence.relational);
    } else {
      return false;
    }
  }

  @override
  bool visitMethodInvocation(MethodInvocation node) {
    assert(identical(target, node.methodName));
    return editPlan.parensNeeded(
        threshold: Precedence.postfix, associative: true);
  }

  @override
  bool visitNode(AstNode node) {
    return false;
  }

  @override
  bool visitParenthesizedExpression(ParenthesizedExpression node) {
    assert(identical(target, node.expression));
    return false;
  }

  @override
  bool visitPostfixExpression(PostfixExpression node) {
    assert(identical(target, node.operand));
    return editPlan.parensNeeded(
        threshold: Precedence.postfix, associative: true);
  }

  @override
  bool visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (identical(target, node.prefix)) {
      return editPlan.parensNeeded(
          threshold: Precedence.postfix, associative: true);
    } else {
      assert(identical(target, node.identifier));
      return editPlan.parensNeeded(
          threshold: Precedence.primary, associative: true);
    }
  }

  @override
  bool visitPrefixExpression(PrefixExpression node) {
    assert(identical(target, node.operand));
    return editPlan.parensNeeded(
        threshold: Precedence.prefix, associative: true);
  }

  @override
  bool visitPropertyAccess(PropertyAccess node) {
    if (identical(target, node.target)) {
      return editPlan.parensNeeded(
          threshold: Precedence.postfix, associative: true);
    } else {
      assert(identical(target, node.propertyName));
      return editPlan.parensNeeded(
          threshold: Precedence.primary, associative: true);
    }
  }

  @override
  bool visitThrowExpression(ThrowExpression node) {
    assert(identical(target, node.expression));
    return false;
  }
}

class _ProvisionalParenExtractEditPlan extends _NestedEditPlan {
  _ProvisionalParenExtractEditPlan(AstNode sourceNode, EditPlan innerPlan)
      : super(sourceNode, innerPlan);

  @override
  Map<int, List<PreviewInfo>> getChanges(bool parens) {
    var changes = innerPlan.getChanges(parens);
    return EditPlan._createExtractChanges(innerPlan, sourceNode, changes);
  }
}

extension on Map<int, List<PreviewInfo>> {
  Map<int, List<PreviewInfo>> operator +(
      Map<int, List<PreviewInfo>> newChanges) {
    if (newChanges == null) return this;
    if (this == null) {
      return newChanges;
    } else {
      for (var entry in newChanges.entries) {
        var currentValue = this[entry.key];
        if (currentValue == null) {
          this[entry.key] = entry.value;
        } else {
          currentValue.addAll(entry.value);
        }
      }
      return this;
    }
  }
}
