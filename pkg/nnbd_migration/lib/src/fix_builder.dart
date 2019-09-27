// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type_provider.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:front_end/src/fasta/flow_analysis/flow_analysis.dart';
import 'package:nnbd_migration/src/variables.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis_visitor.dart';

abstract class FixBuilder extends GeneralizingAstVisitor<DartType> {
  final TypeProvider _typeProvider;

  final TypeSystem _typeSystem;

  final Variables _variables;

  /// If we are visiting a function body or initializer, instance of flow
  /// analysis.  Otherwise `null`.
  FlowAnalysis<Statement, Expression, VariableElement, DartType> _flowAnalysis;

  FixBuilder(TypeProvider typeProvider, this._typeSystem, this._variables)
      : _typeProvider = (typeProvider as TypeProviderImpl)
            .withNullability(NullabilitySuffix.none);

  void addNullCheck(Expression subexpression);

  @override
  DartType visitBinaryExpression(BinaryExpression node) {
    switch (node.operator.type) {
      case TokenType.BANG_EQ:
      case TokenType.EQ_EQ:
        visitSubexpression(node.leftOperand, true);
        visitSubexpression(node.rightOperand, true);
        return _typeProvider.boolType;
      case TokenType.AMPERSAND_AMPERSAND:
      case TokenType.BAR_BAR:
        visitSubexpression(node.leftOperand, false);
        visitSubexpression(node.rightOperand, false);
        return _typeProvider.boolType;
      case TokenType.QUESTION_QUESTION:
        throw StateError('Should be handled by visitSubexpression');
      default:
        throw UnimplementedError('TODO(paulberry)');
    }
  }

  /// If we are visiting a function body or initializer, assigned variable
  /// information  used in flow analysis.  Otherwise `null`.
  AssignedVariables<AstNode, VariableElement> _assignedVariables;

  void createFlowAnalysis() {
    assert(_flowAnalysis == null);
    assert(_assignedVariables == null);
    _flowAnalysis =
        FlowAnalysis<Statement, Expression, VariableElement, DartType>(
            const AnalyzerNodeOperations(),
            DecoratedTypeOperations(_typeSystem, _variables, _graph),
            AnalyzerFunctionBodyAccess(node is FunctionBody ? node : null));
    _assignedVariables = FlowAnalysisHelper.computeAssignedVariables(node);
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

  DartType visitSubexpression(Expression subexpression, bool nullableContext) {
    if (subexpression is BinaryExpression &&
        subexpression.operator.type == TokenType.QUESTION_QUESTION) {
      // If `a ?? b` is used in a non-nullable context, we don't want to migrate
      // it to `(a ?? b)!`.  We want to migrate it to `a ?? b!`.
      var leftType = visitSubexpression(subexpression.leftOperand, true);
      var rightType =
          visitSubexpression(subexpression.rightOperand, nullableContext);
      // Since flow analysis doesn't support `??` yet, the best we can do is
      // take the LUB of the two types.  TODO(paulberry): improve this once flow
      // analysis supports `??`.
      return _typeSystem.leastUpperBound(leftType, rightType);
    }
    var type = subexpression.accept(this);
    if (_typeSystem.isNullable(type) && !nullableContext) {
      addNullCheck(subexpression);
      return _typeSystem.promoteToNonNull(type as TypeImpl);
    } else {
      return type;
    }
  }

  DartType _computeMigratedType(Element element, {DartType targetType}) {
    Element baseElement;
    if (element is Member) {
      assert(targetType != null);
      baseElement = element.baseElement;
    } else {
      baseElement = element;
    }
    DartType type;
    if (baseElement is ClassElement || baseElement is TypeParameterElement) {
      throw UnimplementedError('TODO(paulberry)');
//      return (_typeProvider.typeType as TypeImpl)
//          .withNullability(NullabilitySuffix.none);
    } else if (baseElement is PropertyAccessorElement) {
      throw UnimplementedError('TODO(paulberry)');
//      if (baseElement.isSynthetic) {
//        type = _variables
//            .decoratedElementType(baseElement.variable)
//            .toFinalType(_typeProvider);
//      } else {
//        var functionType = _variables.decoratedElementType(baseElement);
//        var decoratedType = baseElement.isGetter
//            ? functionType.returnType
//            : functionType.positionalParameters[0];
//        type = decoratedType.toFinalType(_typeProvider);
//      }
    } else {
      type = _variables
          .decoratedElementType(baseElement)
          .toFinalType(_typeProvider);
    }
    if (targetType is InterfaceType && targetType.typeArguments.isNotEmpty) {
      throw UnimplementedError('TODO(paulberry)');
//      var superclass = baseElement.enclosingElement as ClassElement;
//      var class_ = targetType.element;
//      if (class_ != superclass) {
//        type = substitute(
//            type,
//            _decoratedClassHierarchy
//                .getDecoratedSupertype(class_, superclass)
//                .asFinalSubstitution(_typeProvider));
//      }
//      return substitute(type, {
//      for (int i = 0; i < targetType.typeArguments.length; i++)
//      class_.typeParameters[i]: targetType.typeArguments[i]
//      });
    } else {
      return type;
    }
  }
}
