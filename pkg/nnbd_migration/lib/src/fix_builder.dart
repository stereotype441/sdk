// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type_provider.dart';
import 'package:analyzer/src/generated/resolver.dart';

abstract class FixBuilder extends GeneralizingAstVisitor<DartType> {
  final TypeProvider _typeProvider;

  final TypeSystem _typeSystem;

  FixBuilder(TypeProvider typeProvider, this._typeSystem)
      : _typeProvider = (typeProvider as TypeProviderImpl)
            .withNullability(NullabilitySuffix.none);

  void addNullCheck(Expression subexpression);

  @override
  DartType visitBinaryExpression(BinaryExpression node) {
    var operatorType = node.operator.type;
    if (operatorType == TokenType.EQ || operatorType == TokenType.BANG_EQ) {
      throw UnimplementedError('TODO(paulberry): test');
      _visitSubexpression(node.leftOperand, true);
      _visitSubexpression(node.rightOperand, true);
      return _typeProvider.boolType;
    } else {
      throw UnimplementedError('TODO(paulberry)');
    }
  }

  @override
  DartType visitExpression(Expression node) {
    // Every expression type needs its own visit method.
    throw UnimplementedError('No visit method for ${node.runtimeType}');
  }

  DartType visitLiteral(Literal node) {
    if (node is AdjacentStrings) {
      // TODO(paulberry): need to visit interpolations
      throw UnimplementedError('TODO(paulberry)');
    }
    if (node is TypedLiteral) {
      throw UnimplementedError('TODO(paulberry)');
    }
    return (node.staticType as TypeImpl)
        .withNullability(NullabilitySuffix.none);
  }

  @override
  DartType visitSimpleIdentifier(SimpleIdentifier node) {
    // TODO(paulberry): add an assertion message pointing to how setter context
    // should be handled.
    assert(!node.inSetterContext());
    var element = node.staticElement;
    if (element == null) return _typeProvider.dynamicType;
    return _computeMigratedType(element);
  }

  DartType _visitSubexpression(Expression subexpression, bool nullableContext) {
    var type = subexpression.accept(this);
    if (_typeSystem.isNullable(type) && !nullableContext) {
      addNullCheck(subexpression);
      return _typeSystem.promoteToNonNull(type as TypeImpl);
    } else {
      return type;
    }
  }
}
