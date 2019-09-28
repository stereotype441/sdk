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
    var staticElement = node.staticElement;
    switch (operatorType) {
      case TokenType.BANG_EQ:
      case TokenType.EQ_EQ:
        visitSubexpression(leftOperand, _typeProvider.dynamicType,
            NullabilityContext.nullable);
        visitSubexpression(rightOperand, _typeProvider.dynamicType,
            NullabilityContext.nullable);
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
        visitSubexpression(leftOperand, _typeProvider.boolType,
            NullabilityContext.nonNullableUsage);
        _flowAnalysis.logicalBinaryOp_rightBegin(leftOperand, isAnd: isAnd);
        visitSubexpression(rightOperand, _typeProvider.boolType,
            NullabilityContext.nonNullableUsage);
        _flowAnalysis.logicalBinaryOp_end(node, rightOperand, isAnd: isAnd);
        return _typeProvider.boolType;
      case TokenType.QUESTION_QUESTION:
        throw StateError('Should be handled by visitSubexpression');
      default:
        var targetType = visitSubexpression(leftOperand,
            _typeProvider.objectType, NullabilityContext.nonNullableUsage);
        NullabilityContext context;
        DartType contextType;
        DartType returnType;
        if (staticElement == null) {
          context = NullabilityContext.nullable;
          contextType = _typeProvider.dynamicType;
          returnType = _typeProvider.dynamicType;
        } else {
          var methodType =
              _computeMigratedType(staticElement, targetType: targetType)
                  as FunctionType;
          contextType = methodType.parameters[0].type;
          context = _assignmentContext(contextType);
          returnType = methodType.returnType;
        }
        visitSubexpression(rightOperand, contextType, context);
        return returnType;
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

  DartType visitSubexpression(Expression subexpression, DartType contextType,
      NullabilityContext context) {
    if (subexpression is BinaryExpression &&
        subexpression.operator.type == TokenType.QUESTION_QUESTION) {
      // If `a ?? b` is used in a non-nullable context, we don't want to migrate
      // it to `(a ?? b)!`.  We want to migrate it to `a ?? b!`.
      var leftType = visitSubexpression(
          subexpression.leftOperand,
          _typeSystem.makeNullable(contextType as TypeImpl),
          NullabilityContext.nullable);
      var rightType =
          visitSubexpression(subexpression.rightOperand, contextType, context);
      // Since flow analysis doesn't support `??` yet, the best we can do is
      // take the LUB of the two types.  TODO(paulberry): improve this once flow
      // analysis supports `??`.
      return _typeSystem.leastUpperBound(leftType, rightType);
    }
    var type = subexpression.accept(this);
    bool needsNullCheck;
    switch (context) {
      case NullabilityContext.nullable:
        needsNullCheck = false;
        break;
      case NullabilityContext.nonNullableUsage:
        needsNullCheck = !type.isDynamic && _typeSystem.isNullable(type);
        break;
      case NullabilityContext.assignToNonNullable:
        needsNullCheck = _typeSystem.isNullable(type);
        break;
    }
    if (needsNullCheck) {
      addNullCheck(subexpression);
      return _typeSystem.promoteToNonNull(type as TypeImpl);
    } else {
      return type;
    }
  }

  NullabilityContext _assignmentContext(DartType type) =>
      _typeSystem.isNullable(type)
          ? NullabilityContext.nullable
          : NullabilityContext.assignToNonNullable;

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
        var supertype = _decoratedClassHierarchy
            .getDecoratedSupertype(class_, superclass)
            .toFinalType(_typeProvider) as InterfaceType;
        type = Substitution.fromInterfaceType(supertype).substituteType(type);
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

enum NullabilityContext { nullable, nonNullableUsage, assignToNonNullable }
