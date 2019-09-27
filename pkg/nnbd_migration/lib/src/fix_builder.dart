// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';

class FixBuilder extends GeneralizingAstVisitor<DartType> {
  @override
  DartType visitBinaryExpression(BinaryExpression node) {
    var operatorType = node.operator.type;
    if (operatorType == TokenType.EQ || operatorType == TokenType.BANG_EQ) {
      _visitSubexpression(node.leftOperand, true);
      _visitSubexpression(node.rightOperand, true);
      return (_typeProvider.boolType as TypeImpl)
          .withNullability(NullabilitySuffix.none);
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
}
