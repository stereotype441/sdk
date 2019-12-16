// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:nnbd_migration/src/fix_builder.dart';

/// TODO(paulberry): this seems like a horrible hack.
extension _CorrectedPrecedence on Expression {
  Precedence get correctedPrecedence {
    var node = this;
    if (node is ThrowExpression) {
      var subExpression = node.expression;
      if (subExpression is CascadeExpression) {
        return Precedence.cascade;
      }
    }
    return precedence;
  }
}

abstract class _Change {
  _Plan apply(AstNode node, _Plan recurse(AstNode node));
}

abstract class _NestableChange extends _Change {
  final _Change _inner;

  _NestableChange(this._inner);
}

class _NoChange extends _Change {
  @override
  _Plan apply(AstNode node, _Plan recurse(AstNode node)) {
    return recurse(node);
  }
}

class _NullCheck extends _NestableChange {
  _NullCheck(_Change inner) : super(inner);

  @override
  _Plan apply(AstNode node, _Plan recurse(AstNode node)) {
    return _Plan.suffix(_inner.apply(node, recurse).addParensIfLowerPrecedenceThan(Precedence.postfix), '!', Precedence.postfix, false);
  }
}

class _MakeNullable extends _NestableChange {
  _MakeNullable(_Change inner) : super(inner);

  @override
  _Plan apply(AstNode node, _Plan recurse(AstNode node)) {
    return _Plan.suffix(_inner.apply(node, recurse), '?', Precedence.primary, false);
  }
}

class _IntroduceAs extends _NestableChange {
  _IntroduceAs(_Change inner, this.type) : super(inner);

  final String type;

  @override
  _Plan apply(AstNode node, _Plan recurse(AstNode node)) {
    return _Plan.suffix(_inner.apply(node, recurse).addParensIfLowerPrecedenceThan(Precedence.bitwiseOr), ' as $type', Precedence.relational, false);
  }
}

class _ExtractSubexpression extends _Change {
  AstNode _inner;

  _ExtractSubexpression(this._inner);

  @override
  _Plan apply(AstNode node, _Plan recurse(AstNode node)) {
    return recurse(_inner);
  }
}

class _Plan {
  factory _Plan.suffix(_Plan innerPlan, String affix, Precedence precedence, bool endsInCascade) {
    throw UnimplementedError('TODO(paulberry)');
  }

  bool get endsInCascade => throw UnimplementedError('TODO(paulberry)');

  _Plan addParensIfLowerPrecedenceThan(Precedence p) {
    throw UnimplementedError('TODO(paulberry)');
  }

  factory _Plan.empty(AstNode node, bool endsInCascade) {
    throw UnimplementedError('TODO(paulberry)');
  }

  _Plan addParensIfEndsInCascade() {
    throw UnimplementedError('TODO(paulberry)');
  }

  void execute() {
    throw UnimplementedError('TODO(paulberry)');
  }
}

class FixApplier extends GeneralizingAstVisitor<void> {
  final Map<AstNode, _Change> _changes;

  /// This version passes around a plan
  _Plan _exploratory2(AstNode node) {
    var change = _changes[node] ?? _NoChange();
    return change.apply(node, _exploratory2b);
  }

  Precedence _getContextPrecedence(AstNode node){
    throw UnimplementedError('TODO(paulberry)');
  }

  bool _getContextDisallowsCascade(AstNode node) {
    throw UnimplementedError('TODO(paulberry)');
  }

  bool _getContextIsAtEnd(AstNode node) {
    throw UnimplementedError('TODO(paulberry)');
  }

  _Plan _exploratory2b(AstNode node) {
    bool endsInCascade = false;
    for (var entity in node.childEntities) {
      if (entity is AstNode) {
        var subPlan = _exploratory2(entity).addParensIfLowerPrecedenceThan(_getContextPrecedence(entity));
        if (_getContextDisallowsCascade(entity)) {
          subPlan = subPlan.addParensIfEndsInCascade();
        }
        if (_getContextIsAtEnd(entity) && subPlan.endsInCascade) {
          endsInCascade = true;
        }
      }
    }
    var plan = _Plan.empty(node, endsInCascade);
    return plan;
  }

  FixApplier(this._changes);

  Precedence _contextPrecedence;

  void dispatchSubexpression(Expression subexpression, Precedence precedence) {
    // TODO(paulberry): I don't like that it's easy to forget to call
    // dispatchSubexpression and just visit normally.
    _contextPrecedence = precedence;
    var change = _changes[subexpression];
    if (change == null) {
      subexpression.accept(this);
    } else if (change is NullCheck) {

    } else {
    }
    _contextPrecedence = null;
  }

  void visitExpression(Expression node) {
    
  }
}