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
import 'package:analyzer/src/dart/element/type_algebra.dart';
import 'package:analyzer/src/dart/element/type_provider.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis_visitor.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:front_end/src/fasta/flow_analysis/flow_analysis.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/variables.dart';

abstract class FixBuilder extends GeneralizingAstVisitor<DartType> {
  final DecoratedClassHierarchy _decoratedClassHierarchy;

  final TypeProvider _typeProvider;

  final TypeSystem _typeSystem;

  final Variables _variables;

  /// If we are visiting a function body or initializer, instance of flow
  /// analysis.  Otherwise `null`.
  FlowAnalysis<Statement, Expression, PromotableElement, DartType>
      _flowAnalysis;

  /// If we are visiting a function body or initializer, assigned variable
  /// information  used in flow analysis.  Otherwise `null`.
  AssignedVariables<AstNode, VariableElement> _assignedVariables;

  FixBuilder(this._decoratedClassHierarchy, TypeProvider typeProvider,
      this._typeSystem, this._variables)
      : _typeProvider = (typeProvider as TypeProviderImpl)
            .withNullability(NullabilitySuffix.none);

  void addNullCheck(Expression subexpression);

  void createFlowAnalysis(AstNode node) {
    assert(_flowAnalysis == null);
    assert(_assignedVariables == null);
    _flowAnalysis =
        FlowAnalysis<Statement, Expression, PromotableElement, DartType>(
            const AnalyzerNodeOperations(),
            TypeSystemTypeOperations(_typeSystem),
            AnalyzerFunctionBodyAccess(node is FunctionBody ? node : null));
    _assignedVariables = FlowAnalysisHelper.computeAssignedVariables(node);
  }

  @override
  DartType visitBinaryExpression(BinaryExpression node) {
    var leftOperand = node.leftOperand;
    var rightOperand = node.rightOperand;
    var operatorType = node.operator.type;
    switch (operatorType) {
      case TokenType.BANG_EQ:
      case TokenType.EQ_EQ:
        visitSubexpression(leftOperand, true);
        visitSubexpression(rightOperand, true);
        if (leftOperand is SimpleIdentifier && rightOperand is NullLiteral) {
          var leftElement = leftOperand.staticElement;
          if (leftElement is PromotableElement) {
            _flowAnalysis.conditionEqNull(node, leftElement,
                notEqual: operatorType == TokenType.BANG_EQ);
          }
        }
        return _typeProvider.boolType;
      case TokenType.AMPERSAND_AMPERSAND:
      case TokenType.BAR_BAR:
        var isAnd = operatorType == TokenType.AMPERSAND_AMPERSAND;
        visitSubexpression(leftOperand, false);
        _flowAnalysis.logicalBinaryOp_rightBegin(leftOperand, isAnd: isAnd);
        visitSubexpression(rightOperand, false);
        _flowAnalysis.logicalBinaryOp_end(node, rightOperand, isAnd: isAnd);
        return _typeProvider.boolType;
      case TokenType.QUESTION_QUESTION:
        throw StateError('Should be handled by visitSubexpression');
      default:
        var targetType = visitSubexpression(leftOperand, false);
        var methodType =
            _computeMigratedType(node.staticElement, targetType: targetType)
                as FunctionType;
        visitSubexpression(rightOperand,
            _typeSystem.isNullable(methodType.parameters[0].type));
        return methodType.returnType;
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
    if (element is PromotableElement) {
      var promotedType = _flowAnalysis.promotedType(element);
      if (promotedType != null) return promotedType;
    }
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
      var superclass = baseElement.enclosingElement as ClassElement;
      var class_ = targetType.element;
      if (class_ != superclass) {
        type = substitute(
            type,
            _decoratedClassHierarchy
                .getDecoratedSupertype(class_, superclass)
                .asFinalSubstitution(_typeProvider));
      }
      return substitute(type, {
        for (int i = 0; i < targetType.typeArguments.length; i++)
          class_.typeParameters[i]: targetType.typeArguments[i]
      });
    } else {
      return type;
    }
  }
}
