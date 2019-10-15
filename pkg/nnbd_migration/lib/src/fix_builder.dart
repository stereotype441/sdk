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
import 'package:analyzer/src/generated/source.dart';
import 'package:front_end/src/fasta/flow_analysis/flow_analysis.dart';
import 'package:meta/meta.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/utilities/resolution_utils.dart';
import 'package:nnbd_migration/src/variables.dart';

/// Information about the target of an assignment expression analyzed by
/// [FixBuilder].
class AssignmentTargetInfo {
  /// The type that the assignment target has when read.  This is only relevant
  /// for compound assignments (since they both read and write the assignment
  /// target)
  final DartType readType;

  /// The type that the assignment target has when written to.
  final DartType writeType;

  AssignmentTargetInfo(this.readType, this.writeType);
}

/// Problem reported by [FixBuilder] when encountering a compound assignment
/// for which the combination result is nullable.  This occurs if the compound
/// assignment resolves to a user-defined operator that returns a nullable type,
/// but the target of the assignment expects a non-nullable type.  We need to
/// add a null check but it's nontrivial to do so because we would have to
/// rewrite the assignment as an ordinary assignment (e.g. change `x += y` to
/// `x = (x + y)!`), but that might change semantics by causing subexpressions
/// of the target to be evaluated twice.
///
/// TODO(paulberry): consider alternatives.
/// See https://github.com/dart-lang/sdk/issues/38675.
class CompoundAssignmentCombinedNullable implements Problem {
  const CompoundAssignmentCombinedNullable();
}

/// Problem reported by [FixBuilder] when encountering a compound assignment
/// for which the value read from the target of the assignment has a nullable
/// type.  We need to add a null check but it's nontrivial to do so because we
/// would have to rewrite the assignment as an ordinary assignment (e.g. change
/// `x += y` to `x = x! + y`), but that might change semantics by causing
/// subexpressions of the target to be evaluated twice.
///
/// TODO(paulberry): consider alternatives.
/// See https://github.com/dart-lang/sdk/issues/38676.
class CompoundAssignmentReadNullable implements Problem {
  const CompoundAssignmentReadNullable();
}

/// This class visits the AST of code being migrated, after graph propagation,
/// to figure out what changes need to be made to the code.  It doesn't actually
/// make the changes; it simply reports what changes are necessary through
/// abstract methods.
abstract class FixBuilder extends GeneralizingAstVisitor<DartType>
    with ResolutionUtils {
  /// The decorated class hierarchy for this migration run.
  final DecoratedClassHierarchy _decoratedClassHierarchy;

  /// Type provider providing non-nullable types.
  final TypeProvider typeProvider;

  /// The type system.
  final TypeSystem _typeSystem;

  /// Variables for this migration run.
  final Variables _variables;

  /// If we are visiting a function body or initializer, instance of flow
  /// analysis.  Otherwise `null`.
  FlowAnalysis<Statement, Expression, PromotableElement, DartType>
      _flowAnalysis;

  /// If we are visiting a function body or initializer, assigned variable
  /// information  used in flow analysis.  Otherwise `null`.
  AssignedVariables<AstNode, PromotableElement> _assignedVariables;

  /// If we are visiting a subexpression, the context type used for type
  /// inference.  This is used to determine when `!` needs to be inserted.
  DartType _contextType;

  /// The file being analyzed.
  final Source source;

  FixBuilder(this.source, this._decoratedClassHierarchy,
      TypeProvider typeProvider, this._typeSystem, this._variables)
      : typeProvider = (typeProvider as TypeProviderImpl)
            .withNullability(NullabilitySuffix.none);

  /// Called whenever a type annotation is found for which a `?` needs to be
  /// inserted.
  void addNullable(TypeAnnotation node);

  /// Called whenever an expression is found for which a `!` needs to be
  /// inserted.
  void addNullCheck(Expression subexpression);

  /// Called whenever code is found that can't be automatically fixed.
  void addProblem(AstNode node, Problem problem);

  /// Initializes flow analysis for a function node.
  void createFlowAnalysis(Declaration node, FormalParameterList parameters) {
    assert(_flowAnalysis == null);
    assert(_assignedVariables == null);
    _assignedVariables =
        FlowAnalysisHelper.computeAssignedVariables(node, parameters);
    _flowAnalysis =
        FlowAnalysis<Statement, Expression, PromotableElement, DartType>(
            TypeSystemTypeOperations(_typeSystem),
            _assignedVariables.writtenAnywhere,
            _assignedVariables.capturedAnywhere);
  }

  @override
  DartType visitAssignmentExpression(AssignmentExpression node) {
    var operatorType = node.operator.type;
    var targetInfo =
        visitAssignmentTarget(node.leftHandSide, operatorType != TokenType.EQ);
    if (operatorType == TokenType.EQ) {
      return visitSubexpression(node.rightHandSide, targetInfo.writeType);
    } else if (operatorType == TokenType.QUESTION_QUESTION_EQ) {
      // TODO(paulberry): if targetInfo.readType is non-nullable, then the
      // assignment is dead code.
      // See https://github.com/dart-lang/sdk/issues/38678
      // TODO(paulberry): once flow analysis supports `??=`, integrate it here.
      // See https://github.com/dart-lang/sdk/issues/38680
      var rhsType =
          visitSubexpression(node.rightHandSide, targetInfo.writeType);
      return _typeSystem.leastUpperBound(
          _typeSystem.promoteToNonNull(targetInfo.readType as TypeImpl),
          rhsType);
    } else {
      var combiner = node.staticElement;
      DartType combinedType;
      if (combiner == null) {
        visitSubexpression(node.rightHandSide, typeProvider.dynamicType);
        combinedType = typeProvider.dynamicType;
      } else {
        if (_typeSystem.isNullable(targetInfo.readType)) {
          addProblem(node, const CompoundAssignmentReadNullable());
        }
        var combinerType = _computeMigratedType(combiner) as FunctionType;
        visitSubexpression(node.rightHandSide, combinerType.parameters[0].type);
        combinedType =
            _fixNumericTypes(combinerType.returnType, node.staticType);
      }
      if (_doesAssignmentNeedCheck(
          from: combinedType, to: targetInfo.writeType)) {
        addProblem(node, const CompoundAssignmentCombinedNullable());
        combinedType = _typeSystem.promoteToNonNull(combinedType as TypeImpl);
      }
      return combinedType;
    }
  }

  /// Recursively visits an assignment target, returning information about the
  /// target's read and write types.
  ///
  /// If [isCompound] is true, the target is being both read from and written
  /// to.  If it is false, then only the write type is needed.
  AssignmentTargetInfo visitAssignmentTarget(Expression node, bool isCompound) {
    if (node is SimpleIdentifier) {
      var writeType = _computeMigratedType(node.staticElement);
      var auxiliaryElements = node.auxiliaryElements;
      var readType = auxiliaryElements == null
          ? writeType
          : _computeMigratedType(auxiliaryElements.staticElement);
      return AssignmentTargetInfo(isCompound ? readType : null, writeType);
    } else if (node is IndexExpression) {
      var targetType = visitSubexpression(node.target, typeProvider.objectType);
      var writeElement = node.staticElement;
      DartType indexContext;
      DartType writeType;
      DartType readType;
      if (writeElement == null) {
        indexContext = UnknownInferredType.instance;
        writeType = typeProvider.dynamicType;
        readType = isCompound ? typeProvider.dynamicType : null;
      } else {
        var writerType =
            _computeMigratedType(writeElement, targetType: targetType)
                as FunctionType;
        writeType = writerType.parameters[1].type;
        if (isCompound) {
          var readerType = _computeMigratedType(
              node.auxiliaryElements.staticElement,
              targetType: targetType) as FunctionType;
          readType = readerType.returnType;
          indexContext = readerType.parameters[0].type;
        } else {
          indexContext = writerType.parameters[0].type;
        }
      }
      visitSubexpression(node.index, indexContext);
      return AssignmentTargetInfo(readType, writeType);
    } else if (node is PropertyAccess) {
      return _handleAssignmentTargetForPropertyAccess(node, node.target,
          node.propertyName, isNullAwareToken(node.operator.type), isCompound);
    } else if (node is PrefixedIdentifier) {
      if (node.prefix.staticElement is ImportElement) {
        // TODO(paulberry)
        throw UnimplementedError(
            'TODO(paulberry): PrefixedIdentifier with a prefix');
      } else {
        return _handleAssignmentTargetForPropertyAccess(
            node, node.prefix, node.identifier, false, isCompound);
      }
    } else {
      throw UnimplementedError('TODO(paulberry)');
    }
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
        visitSubexpression(leftOperand, typeProvider.dynamicType);
        _flowAnalysis.equalityOp_rightBegin(leftOperand);
        visitSubexpression(rightOperand, typeProvider.dynamicType);
        _flowAnalysis.equalityOp_end(node, rightOperand,
            notEqual: operatorType == TokenType.BANG_EQ);
        return typeProvider.boolType;
      case TokenType.AMPERSAND_AMPERSAND:
      case TokenType.BAR_BAR:
        var isAnd = operatorType == TokenType.AMPERSAND_AMPERSAND;
        visitSubexpression(leftOperand, typeProvider.boolType);
        _flowAnalysis.logicalBinaryOp_rightBegin(leftOperand, isAnd: isAnd);
        visitSubexpression(rightOperand, typeProvider.boolType);
        _flowAnalysis.logicalBinaryOp_end(node, rightOperand, isAnd: isAnd);
        return typeProvider.boolType;
      case TokenType.QUESTION_QUESTION:
        // If `a ?? b` is used in a non-nullable context, we don't want to
        // migrate it to `(a ?? b)!`.  We want to migrate it to `a ?? b!`.
        var leftType = visitSubexpression(node.leftOperand,
            _typeSystem.makeNullable(_contextType as TypeImpl));
        _flowAnalysis.ifNullExpression_rightBegin();
        var rightType = visitSubexpression(node.rightOperand, _contextType);
        _flowAnalysis.ifNullExpression_end();
        return _typeSystem.leastUpperBound(
            _typeSystem.promoteToNonNull(leftType as TypeImpl), rightType);
      default:
        var targetType =
            visitSubexpression(leftOperand, typeProvider.objectType);
        DartType contextType;
        DartType returnType;
        if (staticElement == null) {
          contextType = typeProvider.dynamicType;
          returnType = typeProvider.dynamicType;
        } else {
          var methodType =
              _computeMigratedType(staticElement, targetType: targetType)
                  as FunctionType;
          contextType = methodType.parameters[0].type;
          returnType = methodType.returnType;
        }
        visitSubexpression(rightOperand, contextType);
        return _fixNumericTypes(returnType, node.staticType);
    }
  }

  @override
  DartType visitBlock(Block node) {
    for (var statement in node.statements) {
      statement.accept(this);
    }
    return null;
  }

  @override
  DartType visitConditionalExpression(ConditionalExpression node) {
    visitSubexpression(node.condition, typeProvider.boolType);
    _flowAnalysis.conditional_thenBegin(node.condition);
    var thenType = visitSubexpression(node.thenExpression, _contextType);
    _flowAnalysis.conditional_elseBegin(node.thenExpression);
    var elseType = visitSubexpression(node.elseExpression, _contextType);
    _flowAnalysis.conditional_end(node, node.elseExpression);
    return _typeSystem.leastUpperBound(thenType, elseType);
  }

  @override
  DartType visitExpressionStatement(ExpressionStatement node) {
    visitSubexpression(node.expression, UnknownInferredType.instance);
    return null;
  }

  @override
  DartType visitIfStatement(IfStatement node) {
    visitSubexpression(node.condition, typeProvider.boolType);
    _flowAnalysis.ifStatement_thenBegin(node.condition);
    node.thenStatement.accept(this);
    bool hasElse = node.elseStatement != null;
    if (hasElse) {
      _flowAnalysis.ifStatement_elseBegin();
      node.elseStatement.accept(this);
    }
    _flowAnalysis.ifStatement_end(hasElse);
    return null;
  }

  @override
  DartType visitIndexExpression(IndexExpression node) {
    var target = node.target;
    var staticElement = node.staticElement;
    var index = node.index;
    var targetType = visitSubexpression(target, typeProvider.objectType);
    DartType contextType;
    DartType returnType;
    if (staticElement == null) {
      contextType = typeProvider.dynamicType;
      returnType = typeProvider.dynamicType;
    } else {
      var methodType =
          _computeMigratedType(staticElement, targetType: targetType)
              as FunctionType;
      contextType = methodType.parameters[0].type;
      returnType = methodType.returnType;
    }
    visitSubexpression(index, contextType);
    return returnType;
  }

  @override
  DartType visitListLiteral(ListLiteral node) {
    DartType contextType;
    var typeArguments = node.typeArguments;
    if (typeArguments != null) {
      var typeArgumentTypes = _visitTypeArgumentList(typeArguments);
      if (typeArgumentTypes.isNotEmpty) {
        contextType = typeArgumentTypes[0];
      } else {
        contextType = UnknownInferredType.instance;
      }
    } else {
      throw UnimplementedError(
          'TODO(paulberry): extract from surrounding context');
    }
    for (var listElement in node.elements) {
      if (listElement is Expression) {
        visitSubexpression(listElement, contextType);
      } else {
        throw UnimplementedError(
            'TODO(paulberry): handle spread and control flow');
      }
    }
    if (typeArguments != null) {
      return typeProvider.listType2(contextType);
    } else {
      throw UnimplementedError(
          'TODO(paulberry): infer list type based on contents');
    }
  }

  @override
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
  DartType visitNode(AstNode node) {
    // Every node type needs its own visit method.
    throw UnimplementedError('No visit method for ${node.runtimeType}');
  }

  @override
  DartType visitNullLiteral(NullLiteral node) {
    _flowAnalysis.nullLiteral(node);
    return typeProvider.nullType;
  }

  @override
  DartType visitParenthesizedExpression(ParenthesizedExpression node) {
    var result = node.expression.accept(this);
    _flowAnalysis.parenthesizedExpression(node, node.expression);
    return result;
  }

  @override
  DartType visitPostfixExpression(PostfixExpression node) {
    if (node.operator.type == TokenType.BANG) {
      throw UnimplementedError(
          'TODO(paulberry): re-migration of already migrated code not '
          'supported yet');
    } else {
      var targetInfo = visitAssignmentTarget(node.operand, true);
      _handleIncrementOrDecrement(node.staticElement, targetInfo, node);
      return targetInfo.readType;
    }
  }

  @override
  DartType visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.staticElement is ImportElement) {
      // TODO(paulberry)
      throw UnimplementedError(
          'TODO(paulberry): PrefixedIdentifier with a prefix');
    } else {
      return _handlePropertyAccess(node, node.prefix, node.identifier, false);
    }
  }

  @override
  DartType visitPrefixExpression(PrefixExpression node) {
    var operand = node.operand;
    switch (node.operator.type) {
      case TokenType.BANG:
        visitSubexpression(operand, typeProvider.boolType);
        _flowAnalysis.logicalNot_end(node, operand);
        return typeProvider.boolType;
      case TokenType.MINUS:
      case TokenType.TILDE:
        var targetType = visitSubexpression(operand, typeProvider.objectType);
        var staticElement = node.staticElement;
        if (staticElement == null) {
          return typeProvider.dynamicType;
        } else {
          var methodType =
              _computeMigratedType(staticElement, targetType: targetType)
                  as FunctionType;
          return methodType.returnType;
        }
        break;
      case TokenType.PLUS_PLUS:
      case TokenType.MINUS_MINUS:
        return _handleIncrementOrDecrement(
            node.staticElement, visitAssignmentTarget(operand, true), node);
      default:
        throw StateError('Unexpected prefix operator: ${node.operator}');
    }
  }

  @override
  DartType visitPropertyAccess(PropertyAccess node) {
    return _handlePropertyAccess(node, node.target, node.propertyName,
        isNullAwareToken(node.operator.type));
  }

  @override
  DartType visitSimpleIdentifier(SimpleIdentifier node) {
    assert(!node.inSetterContext(),
        'Should use visitAssignmentTarget in setter contexts');
    var element = node.staticElement;
    if (element == null) return typeProvider.dynamicType;
    if (element is PromotableElement) {
      var promotedType = _flowAnalysis.variableRead(node, element);
      if (promotedType != null) return promotedType;
    }
    return _computeMigratedType(element);
  }

  /// Recursively visits a subexpression, providing a context type.
  DartType visitSubexpression(Expression subexpression, DartType contextType) {
    var oldContextType = _contextType;
    try {
      _contextType = contextType;
      var type = subexpression.accept(this);
      if (_doesAssignmentNeedCheck(from: type, to: contextType)) {
        addNullCheck(subexpression);
        _flowAnalysis.nonNullAssert_end(subexpression);
        return _typeSystem.promoteToNonNull(type as TypeImpl);
      } else {
        return type;
      }
    } finally {
      _contextType = oldContextType;
    }
  }

  @override
  DartType visitThrowExpression(ThrowExpression node) {
    visitSubexpression(node.expression, typeProvider.objectType);
    _flowAnalysis.handleExit();
    return typeProvider.neverType;
  }

  @override
  DartType visitTypeName(TypeName node) {
    var decoratedType = _variables.decoratedTypeAnnotation(source, node);
    assert(decoratedType != null);
    List<DartType> arguments = [];
    if (node.typeArguments != null) {
      for (var argument in node.typeArguments.arguments) {
        arguments.add(argument.accept(this));
      }
    }
    if (decoratedType.type.isDynamic || decoratedType.type.isVoid) {
      // Already nullable.  Nothing to do.
      return decoratedType.type;
    } else {
      var element = decoratedType.type.element as ClassElement;
      bool isNullable = decoratedType.node.isNullable;
      if (isNullable) {
        addNullable(node);
      }
      return InterfaceTypeImpl.explicit(element, arguments,
          nullabilitySuffix:
              isNullable ? NullabilitySuffix.question : NullabilitySuffix.none);
    }
  }

  @override
  DartType visitVariableDeclarationList(VariableDeclarationList node) {
    node.metadata.accept(this);
    DartType contextType;
    var typeAnnotation = node.type;
    if (typeAnnotation != null) {
      contextType = typeAnnotation.accept(this);
      assert(contextType != null);
    } else {
      contextType = UnknownInferredType.instance;
    }
    for (var variable in node.variables) {
      if (variable.initializer != null) {
        visitSubexpression(variable.initializer, contextType);
      }
    }
    return null;
  }

  @override
  DartType visitVariableDeclarationStatement(
      VariableDeclarationStatement node) {
    node.variables.accept(this);
    return null;
  }

  /// Computes the type that [element] will have after migration.
  ///
  /// If [targetType] is present, and [element] is a class member, it is the
  /// type of the class within which [element] is being accessed; this is used
  /// to perform the correct substitutions.
  DartType _computeMigratedType(Element element, {DartType targetType}) {
    Element baseElement;
    if (element is Member) {
      baseElement = element.baseElement;
    } else {
      baseElement = element;
    }
    DartType type;
    if (baseElement is ClassElement || baseElement is TypeParameterElement) {
      return typeProvider.typeType;
    } else if (baseElement is PropertyAccessorElement) {
      if (baseElement.isSynthetic) {
        type = _variables
            .decoratedElementType(baseElement.variable)
            .toFinalType(typeProvider);
      } else {
        var functionType = _variables.decoratedElementType(baseElement);
        var decoratedType = baseElement.isGetter
            ? functionType.returnType
            : functionType.positionalParameters[0];
        type = decoratedType.toFinalType(typeProvider);
      }
    } else {
      type = _variables
          .decoratedElementType(baseElement)
          .toFinalType(typeProvider);
    }
    if (targetType is InterfaceType && targetType.typeArguments.isNotEmpty) {
      var superclass = baseElement.enclosingElement as ClassElement;
      var class_ = targetType.element;
      if (class_ != superclass) {
        var supertype = _decoratedClassHierarchy
            .getDecoratedSupertype(class_, superclass)
            .toFinalType(typeProvider) as InterfaceType;
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

  /// Determines whether a null check is needed when assigning a value of type
  /// [from] to a context of type [to].
  bool _doesAssignmentNeedCheck(
      {@required DartType from, @required DartType to}) {
    return !from.isDynamic &&
        _typeSystem.isNullable(from) &&
        !_typeSystem.isNullable(to);
  }

  /// Determines whether a `num` type originating from a call to a
  /// user-definable operator needs to be changed to `int`.  [type] is the type
  /// determined by naive operator lookup; [originalType] is the type that was
  /// determined by the analyzer's full resolution algorithm when analyzing the
  /// pre-migrated code.
  DartType _fixNumericTypes(DartType type, DartType originalType) {
    if (type.isDartCoreNum && originalType.isDartCoreInt) {
      return (originalType as TypeImpl)
          .withNullability((type as TypeImpl).nullabilitySuffix);
    } else {
      return type;
    }
  }

  AssignmentTargetInfo _handleAssignmentTargetForPropertyAccess(
      Expression node,
      Expression target,
      SimpleIdentifier propertyName,
      bool isNullAware,
      bool isCompound) {
    var targetType = visitSubexpression(target,
        isNullAware ? typeProvider.dynamicType : typeProvider.objectType);
    var writeElement = propertyName.staticElement;
    DartType writeType;
    DartType readType;
    if (writeElement == null) {
      writeType = typeProvider.dynamicType;
      readType = isCompound ? typeProvider.dynamicType : null;
    } else {
      writeType = _computeMigratedType(writeElement, targetType: targetType);
      if (isCompound) {
        readType = _computeMigratedType(
            propertyName.auxiliaryElements.staticElement,
            targetType: targetType);
      }
      return AssignmentTargetInfo(readType, writeType);
    }
    return AssignmentTargetInfo(readType, writeType);
  }

  DartType _handleIncrementOrDecrement(MethodElement combiner,
      AssignmentTargetInfo targetInfo, Expression node) {
    DartType combinedType;
    if (combiner == null) {
      combinedType = typeProvider.dynamicType;
    } else {
      if (_typeSystem.isNullable(targetInfo.readType)) {
        addProblem(node, const CompoundAssignmentReadNullable());
      }
      var combinerType = _computeMigratedType(combiner) as FunctionType;
      combinedType = _fixNumericTypes(combinerType.returnType, node.staticType);
    }
    if (_doesAssignmentNeedCheck(
        from: combinedType, to: targetInfo.writeType)) {
      addProblem(node, const CompoundAssignmentCombinedNullable());
      combinedType = _typeSystem.promoteToNonNull(combinedType as TypeImpl);
    }
    return combinedType;
  }

  DartType _handlePropertyAccess(Expression node, Expression target,
      SimpleIdentifier propertyName, bool isNullAware) {
    var staticElement = propertyName.staticElement;
    var isNullOk = isNullAware || isDeclaredOnObject(propertyName.name);
    var targetType = visitSubexpression(
        target, isNullOk ? typeProvider.dynamicType : typeProvider.objectType);
    if (staticElement == null) {
      return typeProvider.dynamicType;
    } else {
      var type = _computeMigratedType(staticElement, targetType: targetType);
      if (isNullAware) {
        return _typeSystem.makeNullable(type as TypeImpl);
      } else {
        return type;
      }
    }
  }

  /// Visits all the type arguments in a [TypeArgumentList] and returns the
  /// types they ger migrated to.
  List<DartType> _visitTypeArgumentList(TypeArgumentList arguments) =>
      [for (var argument in arguments.arguments) argument.accept(this)];
}

/// Common supertype for problems reported by [FixBuilder.addProblem].
abstract class Problem {}
