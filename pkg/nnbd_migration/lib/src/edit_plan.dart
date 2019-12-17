// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';

class AddCloseParen extends PreviewInfo {
  const AddCloseParen();
}

class AddOpenParen extends PreviewInfo {
  const AddOpenParen();
}

abstract class EditPlan {
  final AstNode _sourceNode;

  EditPlan(this._sourceNode);

  factory EditPlan.extract(AstNode sourceNode, EditPlan innerPlan) {
    if (innerPlan is ProvisionalParenEditPlan) {
      return _ProvisionalParenExtractEditPlan(sourceNode, innerPlan);
    } else {
      return _ExtractEditPlan(sourceNode, innerPlan);
    }
  }

  // TODO(paulberry): make some of these parameters optional?
  Map<int, List<PreviewInfo>> getChanges(bool parens);

  bool parensNeeded(Precedence threshold, bool associative, bool allowCascade);

  Map<int, List<PreviewInfo>> _createAddParenChanges(
      Map<int, List<PreviewInfo>> changes) {
    changes ??= {};
    (changes[_sourceNode.offset] ??= []).insert(0, const AddOpenParen());
    (changes[_sourceNode.end] ??= []).add(const AddCloseParen());
    return changes;
  }

  static Map<int, List<PreviewInfo>> _createExtractChanges(EditPlan innerPlan,
      AstNode sourceNode, Map<int, List<PreviewInfo>> changes) {
    // TODO(paulberry): don't remove comments
    if (innerPlan._sourceNode.offset > sourceNode.offset) {
      ((changes ??= {})[sourceNode.offset] ??= []).insert(
          0, RemoveText(innerPlan._sourceNode.offset - sourceNode.offset));
    }
    if (innerPlan._sourceNode.end < sourceNode.end) {
      ((changes ??= {})[innerPlan._sourceNode.end] ??= [])
          .add(RemoveText(sourceNode.end - innerPlan._sourceNode.end));
    }
    return changes;
  }
}

abstract class PreviewInfo {
  const PreviewInfo();
}

class ProvisionalParenEditPlan extends EditPlan {
  final EditPlan _innerPlan;

  /// TODO(paulberry): if there are multiple levels of redundant parens, what
  /// should we do?
  ProvisionalParenEditPlan(ParenthesizedExpression node, this._innerPlan)
      : super(node);

  @override
  Map<int, List<PreviewInfo>> getChanges(bool parens) {
    var changes = _innerPlan.getChanges(false);
    if (!parens) {
      changes ??= {};
      // TODO(paulberry): preserve empty parens if no other significant changes
      (changes[_sourceNode.offset] ??= []).add(const RemoveText(1));
      (changes[_sourceNode.end - 1] ??= []).add(const RemoveText(1));
    }
    return changes;
  }

  @override
  bool parensNeeded(
          Precedence threshold, bool associative, bool allowCascade) =>
      _innerPlan.parensNeeded(threshold, associative, allowCascade);
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

  bool _endsInCascade = false;

  Map<int, List<PreviewInfo>> _innerChanges;

  SimpleEditPlan.forExpression(Expression node)
      : _precedence = node.precedence,
        super(node);

  SimpleEditPlan.forNonExpression(AstNode node)
      : _precedence = Precedence.primary,
        super(node);

  SimpleEditPlan.withPrecedence(AstNode node, this._precedence) : super(node);

  /// TODO(paulberry): document that this takes over ownership of newChanges.
  /// TODO(paulberry): need to document ownership semantics elsewhere too.
  void addInnerChanges(Map<int, List<PreviewInfo>> newChanges) {
    if (newChanges == null) return;
    if (_innerChanges == null) {
      _innerChanges = newChanges;
    } else {
      for (var entry in newChanges.entries) {
        var currentValue = _innerChanges[entry.key];
        if (currentValue == null) {
          _innerChanges[entry.key] = entry.value;
        } else {
          currentValue.addAll(entry.value);
        }
      }
    }
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
  bool parensNeeded(Precedence threshold, bool associative, bool allowCascade) {
    // TODO(paulberry): add logic for allowCascade.
    return _precedence < threshold ||
        (!associative && _precedence == threshold);
  }
}

class _ExtractEditPlan extends EditPlan {
  final EditPlan _innerPlan;

  final Map<int, List<PreviewInfo>> _innerChanges;

  _ExtractEditPlan(AstNode sourceNode, this._innerPlan)
      : _innerChanges = EditPlan._createExtractChanges(
            _innerPlan, sourceNode, _innerPlan.getChanges(false)),
        super(sourceNode);

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
          Precedence threshold, bool associative, bool allowCascade) =>
      _innerPlan.parensNeeded(threshold, associative, allowCascade);
}

class _ProvisionalParenExtractEditPlan extends EditPlan {
  final ProvisionalParenEditPlan _innerPlan;

  _ProvisionalParenExtractEditPlan(AstNode sourceNode, this._innerPlan)
      : super(sourceNode);

  @override
  Map<int, List<PreviewInfo>> getChanges(bool parens) {
    var innerPlan = _innerPlan;
    var sourceNode = _sourceNode;
    var changes = innerPlan.getChanges(parens);
    return EditPlan._createExtractChanges(innerPlan, sourceNode, changes);
  }

  @override
  bool parensNeeded(
          Precedence threshold, bool associative, bool allowCascade) =>
      _innerPlan.parensNeeded(threshold, associative, allowCascade);
}
