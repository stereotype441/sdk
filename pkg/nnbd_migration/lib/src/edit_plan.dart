// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
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

class ProvisionalParenEditPlan extends EditPlan {
  final EditPlan innerPlan;

  /// Creates a new edit plan that consists of executing [innerPlan], and then
  /// possibly removing surrounding parentheses from the source code.
  ///
  /// Caller should not re-use [innerPlan] after this call--it (and the data
  /// structures it points to) may be incorporated into this edit plan and later
  /// modified.
  ProvisionalParenEditPlan(ParenthesizedExpression node, this.innerPlan)
      : super(node);

  bool get endsInCascade => innerPlan.endsInCascade;

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

  SimpleEditPlan.forExpression(Expression node)
      : _precedence = node.precedence,
        isPassThrough = true,
        super(node);

  SimpleEditPlan.forNonExpression(AstNode node)
      : _precedence = Precedence.primary,
        isPassThrough = true,
        super(node);

  SimpleEditPlan.withPrecedence(AstNode node, this._precedence)
      : isPassThrough = false,
        super(node);

  bool get isEmpty => _innerChanges == null;

  /// Adds the set of changes in [newChanges] to this edit plan.
  ///
  /// Caller should not re-use [newChanges] after this call--it (and the data
  /// structures it points to) may be incorporated into this edit plan and later
  /// modified.
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
  bool parensNeeded(
      {@required Precedence threshold,
      bool associative = false,
      bool allowCascade = false}) {
    if (endsInCascade && !allowCascade) return true;
    if (_precedence < threshold) return true;
    if (_precedence == threshold && !associative) return true;
    return false;
  }
}

class _ExtractEditPlan extends EditPlan {
  final EditPlan _innerPlan;

  final Map<int, List<PreviewInfo>> _innerChanges;

  _ExtractEditPlan(AstNode sourceNode, this._innerPlan)
      : _innerChanges = EditPlan._createExtractChanges(
            _innerPlan, sourceNode, _innerPlan.getChanges(false)),
        super(sourceNode);

  bool get endsInCascade => _innerPlan.endsInCascade;

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
          bool allowCascade = false}) =>
      _innerPlan.parensNeeded(
          threshold: threshold,
          associative: associative,
          allowCascade: allowCascade);
}

class _ProvisionalParenExtractEditPlan extends EditPlan {
  final ProvisionalParenEditPlan _innerPlan;

  _ProvisionalParenExtractEditPlan(AstNode sourceNode, this._innerPlan)
      : super(sourceNode);

  bool get endsInCascade => _innerPlan.endsInCascade;

  @override
  Map<int, List<PreviewInfo>> getChanges(bool parens) {
    var changes = _innerPlan.getChanges(parens);
    return EditPlan._createExtractChanges(_innerPlan, sourceNode, changes);
  }

  @override
  bool parensNeeded(
          {@required Precedence threshold,
          bool associative = false,
          bool allowCascade = false}) =>
      _innerPlan.parensNeeded(
          threshold: threshold,
          associative: associative,
          allowCascade: allowCascade);
}
