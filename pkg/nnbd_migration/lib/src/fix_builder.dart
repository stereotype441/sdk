// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/protocol_server.dart' hide Element;
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/handle.dart';
import 'package:analyzer/src/dart/element/inheritance_manager3.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type_algebra.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis_visitor.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:front_end/src/scanner/token.dart';
import 'package:meta/meta.dart';
import 'package:meta/meta.dart';
import 'package:nnbd_migration/instrumentation.dart';
import 'package:nnbd_migration/instrumentation.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:nnbd_migration/src/conditional_discard.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/decorated_type.dart';
import 'package:nnbd_migration/src/expression_checks.dart';
import 'package:nnbd_migration/src/nullability_migration_impl.dart';
import 'package:nnbd_migration/src/nullability_node.dart';
import 'package:nnbd_migration/src/potential_modification.dart';
import 'package:nnbd_migration/src/utilities/annotation_tracker.dart';
import 'package:nnbd_migration/src/utilities/permissive_mode.dart';
import 'package:nnbd_migration/src/variables.dart';

class FixBuilder extends GeneralizingAstVisitor<DartType> {
  final NullabilityMigrationListener _listener;

  final Source _source;

  final LineInfo _lineInfo;

  final Variables _variables;

  final TypeProvider _typeProvider;

  final TypeSystem _typeSystem;

  DartType _currentCascadeTargetType;

  final DecoratedClassHierarchy _decoratedClassHierarchy;

  FixBuilder(this._listener, this._source, this._lineInfo, this._variables,
      this._typeProvider, this._typeSystem, this._decoratedClassHierarchy);

  @override
  DartType visitAssignmentExpression(AssignmentExpression node) {
    if (node.operator.type != TokenType.EQ) {
      throw UnimplementedError('TODO(paulberry)');
    } else {
      // TODO(paulberry): make sure we reach setters when evaluating LHS.
      var lhsType = node.leftHandSide.accept(this);
      return _visitSubexpression(
          node.rightHandSide, _typeSystem.isNullable(lhsType));
    }
  }

  @override
  DartType visitBinaryExpression(BinaryExpression node) {
    var operatorType = node.operator.type;
    if (operatorType == TokenType.EQ || operatorType == TokenType.BANG_EQ) {
      _visitSubexpression(node.leftOperand, true);
      _visitSubexpression(node.rightOperand, true);
      return (_typeProvider.boolType as TypeImpl)
          .withNullability(NullabilitySuffix.none);
    }
    var element = node.staticElement;
    if (element == null) {
      throw UnimplementedError('TODO(paulberry)');
    }
    var methodType = _computeMigratedType(element) as FunctionType;
    var lhsType = _visitSubexpression(node.leftOperand, false);
    if (lhsType is InterfaceType && lhsType.typeArguments.isNotEmpty) {
      throw UnimplementedError('TODO(paulberry)');
    }
    _visitSubexpression(node.rightOperand,
        _typeSystem.isNullable(methodType.parameters[0].type));
    return methodType.returnType;
  }

  @override
  DartType visitCascadeExpression(CascadeExpression node) {
    var oldCascadeTargetType = _currentCascadeTargetType;
    try {
      _currentCascadeTargetType = _visitSubexpression(node.target, true);
      for (var cascadeSection in node.cascadeSections) {
        if (cascadeSection is AssignmentExpression) {
          // TODO(paulberry): make sure visitPropertyAccess handles the ".."
          // properly.
          _visitSubexpression(cascadeSection, true);
        } else {
          throw UnimplementedError('TODO(paulberry)');
        }
      }
    } finally {
      _currentCascadeTargetType = oldCascadeTargetType;
    }
  }

  @override
  DartType visitDefaultFormalParameter(DefaultFormalParameter node) {
    node.metadata.accept(this);
    node.parameter.accept(this);
    var element = node.declaredElement;
    var type = _computeMigratedType(element);
    var isNullable = _typeSystem.isNullable(type);
    if (node.defaultValue != null) {
      _visitSubexpression(node.defaultValue, isNullable);
      return null;
    } else if (node.declaredElement.hasRequired) {
      // TODO(paulberry): change `@required` to `required`.  See
      // https://github.com/dart-lang/sdk/issues/38462
      return null;
    } else if (!isNullable) {
      if (node.metadata.isNotEmpty) {
        throw new UnimplementedError(
            'TODO(paulberry): figure out where to add "required"');
      }
      var offset = node.offset;
      var method = element.enclosingElement;
      var fix = _SingleNullabilityFix(
          _source,
          _lineInfo,
          offset,
          0,
          NullabilityFixDescription.addRequired(
              method.enclosingElement.name, method.name, element.name));
      _listener.addFix(fix);
      _listener.addEdit(fix, SourceEdit(offset, 0, 'required '));
      return null;
    }
  }

  @override
  DartType visitExpression(Expression node) {
    // TODO(paulberry): when we no longer need the exception in visitExpression,
    // get rid of calls to visitNode.
    throw UnimplementedError('TODO(paulberry)');
  }

  @override
  DartType visitFunctionExpression(FunctionExpression node) {
    if (node.parent is FunctionDeclaration) return visitNode(node);
    return super.visitFunctionExpression(node);
  }

  @override
  DartType visitIndexExpression(IndexExpression node) {
    var parent = node.parent;
    if (parent is AssignmentExpression &&
        identical(node, parent.leftHandSide)) {
      throw UnimplementedError('TODO(paulberry)');
    }
    if (node.leftBracket.type != TokenType.OPEN_SQUARE_BRACKET) {
      throw UnimplementedError('TODO(paulberry)');
    }
    if (node.target == null) {
      throw UnimplementedError('TODO(paulberry)');
    }
    var targetType = _visitSubexpression(node.target, false);
    var element = node.staticElement;
    var operatorMethodType =
        _computeMigratedType(element, targetType: targetType) as FunctionType;
    var substitution =
        _visitInvocationArguments(operatorMethodType, [node.index], null);
    assert(substitution.isEmpty);
    return operatorMethodType.returnType;
  }

  @override
  DartType visitInstanceCreationExpression(InstanceCreationExpression node) {
    var constructor = node.staticElement;
    var class_ = constructor.enclosingElement;
    if (class_.typeParameters.isNotEmpty) {
      throw UnimplementedError('TODO(paulberry)');
    }
    node.constructorName.accept(this);
    var type = _computeMigratedType(constructor) as FunctionType;
    _visitInvocationArguments(type, node.argumentList.arguments, null);
    return InterfaceTypeImpl.explicit(class_, [],
        nullabilitySuffix: NullabilitySuffix.none);
  }

  DartType visitLiteral(Literal node) {
    if (node is StringLiteral) {
      // TODO(paulberry): need to visit interpolations
      throw UnimplementedError('TODO(paulberry)');
    }
    return (node.staticType as TypeImpl)
        .withNullability(NullabilitySuffix.none);
  }

  @override
  DartType visitMethodInvocation(MethodInvocation node) {
    bool isNullAware = node.operator != null &&
        node.operator.type == TokenType.QUESTION_PERIOD;
    DartType type;
    if (node.target != null) {
      var targetType = _visitSubexpression(node.target, isNullAware);
      type = _computeMigratedType(node.methodName.staticElement,
          targetType: targetType);
    } else if (node.realTarget != null) {
      // TODO(paulberry): in addition to getting the right target, we need to
      // figure out isNullAware correctly.
      throw UnimplementedError('TODO(paulberry)');
    } else {
      type = _computeMigratedType(node.methodName.staticElement);
    }
    if (type is FunctionType) {
      var substitution = _visitInvocationArguments(
          type, node.argumentList.arguments, node.typeArguments);
      return substitute(type.returnType, substitution);
    } else {
      throw UnimplementedError('TODO(paulberry)');
    }
  }

  @override
  DartType visitPrefixedIdentifier(PrefixedIdentifier node) {
    return _handlePropertyAccess(
        node.prefix, node.period.type, node.identifier);
  }

  @override
  DartType visitPropertyAccess(PropertyAccess node) {
    return _handlePropertyAccess(
        node.target, node.operator.type, node.propertyName);
  }

  @override
  DartType visitSimpleIdentifier(SimpleIdentifier node) {
    var element = node.staticElement;
    if (element == null) return _typeProvider.dynamicType;
    return _computeMigratedType(element);
  }

  @override
  DartType visitTypeAnnotation(TypeAnnotation node) {
    super.visitTypeAnnotation(node);
    var decoratedType = _variables.decoratedTypeAnnotation(_source, node);
    if (decoratedType != null && decoratedType.node.isNullable) {
      var type = decoratedType.type;
      if (type.isDynamic || type.isVoid) {
        // `void` and `dynamic` are always nullable so nothing needs to be
        // changed.
      } else {
        var offset = node.end;
        var fix = _SingleNullabilityFix(_source, _lineInfo, offset, 0,
            NullabilityFixDescription.makeTypeNullable(type.toString()));
        _listener.addFix(fix);
        _listener.addEdit(fix, SourceEdit(offset, 0, '?'));
      }
    }
    return null;
  }

  @override
  DartType visitTypeName(TypeName node) => visitTypeAnnotation(node);

  @override
  DartType visitVariableDeclaration(VariableDeclaration node) {
    node.metadata.accept(this);
    var element = node.declaredElement;
    var type = _computeMigratedType(element);
    if (node.initializer != null) {
      _visitSubexpression(node.initializer, _typeSystem.isNullable(type));
    }
    return null;
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
      return (_typeProvider.typeType as TypeImpl)
          .withNullability(NullabilitySuffix.none);
    } else if (baseElement is PropertyAccessorElement) {
      if (baseElement.isSynthetic) {
        type = _variables
            .decoratedElementType(baseElement.variable)
            .toFinalType(_typeProvider);
      } else {
        var functionType = _variables.decoratedElementType(baseElement);
        var decoratedType = baseElement.isGetter
            ? functionType.returnType
            : functionType.positionalParameters[0];
        type = decoratedType.toFinalType(_typeProvider);
      }
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

  DartType _handlePropertyAccess(
      Expression target, TokenType tokenType, SimpleIdentifier propertyName) {
    DartType targetType;
    if (tokenType == TokenType.PERIOD_PERIOD) {
      targetType = _currentCascadeTargetType;
      if (_typeSystem.isNullable(targetType)) {
        throw UnimplementedError('TODO(paulberry)');
      }
    } else if (tokenType == TokenType.PERIOD) {
      targetType = _visitSubexpression(target, false);
    } else {
      throw UnimplementedError('TODO(paulberry)');
    }
    if (targetType is InterfaceType && targetType.typeArguments.isNotEmpty) {
      throw UnimplementedError('TODO(paulberry): substitute');
    }
    var element = propertyName.staticElement;
    return _computeMigratedType(element);
  }

  Map<TypeParameterElement, DartType> _visitInvocationArguments(
      FunctionType type,
      List<Expression> arguments,
      TypeArgumentList typeArguments) {
    typeArguments?.accept(this);
    Map<TypeParameterElement, DartType> substitution;
    if (type.typeFormals.isNotEmpty) {
      if (typeArguments != null) {
        assert(type.typeFormals.length == typeArguments.arguments.length);
        substitution = {
          for (int i = 0; i < type.typeFormals.length; i++)
            type.typeFormals[i]: _variables
                .decoratedTypeAnnotation(_source, typeArguments.arguments[i])
                .toFinalType(_typeProvider)
        };
      } else {
        throw UnimplementedError('TODO(paulberry)');
      }
    } else {
      substitution = const {};
    }
    int i = 0;
    for (var argument in arguments) {
      Expression expression;
      DartType parameterType;
      if (argument is NamedExpression) {
        expression = argument.expression;
        parameterType = type.namedParameterTypes[argument.name.label.name];
      } else {
        expression = argument;
        parameterType = type.parameters[i++].type;
      }
      parameterType = substitute(parameterType, substitution);
      _visitSubexpression(expression, _typeSystem.isNullable(parameterType));
    }
    return substitution;
  }

  DartType _visitSubexpression(Expression subexpression, bool nullableContext) {
    var type = subexpression.accept(this);
    if (_typeSystem.isNullable(type) && !nullableContext) {
      // TODO(paulberry): add parens if necessary.
      // See https://github.com/dart-lang/sdk/issues/38469
      var offset = subexpression.end;
      var fix = _SingleNullabilityFix(_source, _lineInfo, offset, 0,
          NullabilityFixDescription.checkExpression);
      _listener.addFix(fix);
      _listener.addEdit(fix, SourceEdit(offset, 0, '!'));
      return _typeSystem.promoteToNonNull(type as TypeImpl);
    } else {
      return type;
    }
  }
}

/// Implementation of [SingleNullabilityFix] used internally by
/// [NullabilityMigration].
class _SingleNullabilityFix extends SingleNullabilityFix {
  @override
  final Source source;

  @override
  final NullabilityFixDescription description;

  Location _location;

  factory _SingleNullabilityFix(Source source, LineInfo lineInfo, int offset,
      int length, NullabilityFixDescription description) {
    Location location;

    final locationInfo = lineInfo.getLocation(offset);
    location = new Location(
      source.fullName,
      offset,
      length,
      locationInfo.lineNumber,
      locationInfo.columnNumber,
    );

    return _SingleNullabilityFix._(source, description, location: location);
  }

  _SingleNullabilityFix._(this.source, this.description, {Location location})
      : this._location = location;

  Location get location => _location;
}
