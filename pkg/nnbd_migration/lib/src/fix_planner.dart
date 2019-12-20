// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:nnbd_migration/src/edit_plan.dart';

class FixPlanner extends UnifyingAstVisitor<void> {
  final Map<AstNode, NodeChange> _changes;

  List<EditPlan> _plans = [];

  FixPlanner._(this._changes);

  EditPlan gather(AstNode node) {
    var previousPlans = _plans;
    try {
      _plans = [];
      node.visitChildren(this);
      return EditPlan.passThrough(node, innerPlans: _plans);
    } finally {
      _plans = previousPlans;
    }
  }

  void visitNode(AstNode node) {
    var change = _changes[node];
    if (change != null) {
      var innerPlan = change.apply(node, gather);
      if (innerPlan != null) {
        _plans.add(innerPlan);
      }
    } else {
      node.visitChildren(this);
    }
  }

  static Map<int, List<PreviewInfo>> run(
      CompilationUnit unit, Map<AstNode, NodeChange> changes) {
    var planner = FixPlanner._(changes);
    unit.accept(planner);
    if (planner._plans.isEmpty) return {};
    EditPlan plan;
    if (planner._plans.length == 1) {
      plan = planner._plans[0];
    } else {
      plan = EditPlan.passThrough(unit, innerPlans: planner._plans);
    }
    return plan.finalize();
  }
}

class IntroduceAs extends _NestableChange {
  /// TODO(paulberry): shouldn't be a String
  final String type;

  const IntroduceAs(this.type, [NodeChange inner = const NoChange()])
      : super(inner);

  @override
  bool operator ==(Object other) {
    return other is IntroduceAs &&
        other._inner == this._inner &&
        other.type == this.type;
  }

  @override
  EditPlan apply(AstNode node, EditPlan Function(AstNode) gather) {
    var innerPlan = _inner.apply(node, gather);
    return EditPlan.surround(innerPlan,
        suffix: [AddText(' as $type')],
        precedence: Precedence.relational,
        threshold: Precedence.relational);
  }
}

class MakeNullable extends _NestableChange {
  const MakeNullable([NodeChange inner = const NoChange()]) : super(inner);

  @override
  bool operator ==(Object other) {
    return other is MakeNullable && other._inner == this._inner;
  }

  @override
  EditPlan apply(AstNode node, EditPlan Function(AstNode) gather) {
    var innerPlan = _inner.apply(node, gather);
    return EditPlan.surround(innerPlan, suffix: [const AddText('?')]);
  }
}

class NoChange extends NodeChange {
  const NoChange();

  @override
  bool operator ==(Object other) {
    return other is NoChange;
  }

  @override
  EditPlan apply(AstNode node, EditPlan Function(AstNode) gather) {
    return gather(node);
  }
}

abstract class NodeChange {
  const NodeChange();

  EditPlan apply(AstNode node, EditPlan Function(AstNode) gather);
}

class NullCheck extends _NestableChange {
  const NullCheck([NodeChange inner = const NoChange()]) : super(inner);

  @override
  bool operator ==(Object other) {
    return other is NullCheck && other._inner == this._inner;
  }

  @override
  EditPlan apply(AstNode node, EditPlan Function(AstNode) gather) {
    var innerPlan = _inner.apply(node, gather);
    return EditPlan.surround(innerPlan,
        suffix: [const AddText('!')],
        precedence: Precedence.postfix,
        threshold: Precedence.postfix,
        associative: true);
  }
}

class RemoveAs extends _NestableChange {
  const RemoveAs([NodeChange inner = const NoChange()]) : super(inner);

  @override
  bool operator ==(Object other) {
    return other is RemoveAs && other._inner == this._inner;
  }

  @override
  EditPlan apply(AstNode node, EditPlan Function(AstNode) gather) {
    return EditPlan.extract(
        node, _inner.apply((node as AsExpression).expression, gather));
  }
}

abstract class _NestableChange extends NodeChange {
  final NodeChange _inner;

  const _NestableChange(this._inner);
}
