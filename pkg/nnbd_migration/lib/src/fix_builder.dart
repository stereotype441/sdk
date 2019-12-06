// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:_fe_analyzer_shared/src/flow_analysis/flow_analysis.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/element/inheritance_manager3.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type_algebra.dart';
import 'package:analyzer/src/dart/element/type_provider.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis_visitor.dart';
import 'package:analyzer/src/generated/migration.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'package:meta/meta.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/utilities/resolution_utils.dart';
import 'package:nnbd_migration/src/variables.dart';

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

/// TODO(paulberry): document
abstract class FixBuilder {
  /// The decorated class hierarchy for this migration run.
  final DecoratedClassHierarchy _decoratedClassHierarchy;

  /// The type provider providing non-nullable types.
  final TypeProvider typeProvider;

  /// The NNBD type system.
  final TypeSystemImpl _typeSystem;

  /// Variables for this migration run.
  final Variables _variables;

  /// The file being analyzed.
  final Source source;

  ResolverVisitor _resolver;

  FixBuilder(
      Source source,
      DecoratedClassHierarchy decoratedClassHierarchy,
      TypeProvider typeProvider,
      Dart2TypeSystem typeSystem,
      Variables variables,
      LibraryElement definingLibrary)
      : this._(
            decoratedClassHierarchy,
            _makeNnbdTypeSystem(
                (typeProvider as TypeProviderImpl).asNonNullableByDefault,
                typeSystem),
            variables,
            source,
            definingLibrary);

  FixBuilder._(this._decoratedClassHierarchy, this._typeSystem, this._variables,
      this.source, LibraryElement definingLibrary)
      : typeProvider = _typeSystem.typeProvider {
    assert(_typeSystem.isNonNullableByDefault);
    assert((typeProvider as TypeProviderImpl).isNonNullableByDefault);
    var inheritanceManager = InheritanceManager3();
    // TODO(paulberry): is it a bad idea to throw away errors?
    var errorListener = AnalysisErrorListener.NULL_LISTENER;
    // TODO(paulberry): once the feature is no longer experimental, change the
    // way we enable it in the resolver.
    var featureSet = FeatureSet.forTesting(
        sdkVersion: '2.6.0', additionalFeatures: [Feature.non_nullable]);
    _resolver = ResolverVisitorForMigration(
        inheritanceManager,
        definingLibrary,
        source,
        typeProvider,
        errorListener,
        _typeSystem,
        featureSet,
        MigrationResolutionHooksImpl(this));
  }

  /// Called whenever an AST node is found that needs to be changed.
  void addChange(AstNode node, NodeChange change);

  /// Called whenever code is found that can't be automatically fixed.
  void addProblem(AstNode node, Problem problem);

  void visitAll(CompilationUnit unit) {
    unit.accept(_resolver);
  }

  /// Computes the type that [element] will have after migration.
  ///
  /// If [targetType] is present, and [element] is a class member, it is the
  /// type of the class within which [element] is being accessed; this is used
  /// to perform the correct substitutions.
  DartType _computeMigratedType(Element element) {
    element = element.declaration;
    if (element is ClassElement || element is TypeParameterElement) {
      return typeProvider.typeType;
    } else if (element is PropertyAccessorElement && element.isSynthetic) {
      var variableType = _variables
          .decoratedElementType(element.variable)
          .toFinalType(typeProvider);
      if (element.isSetter) {
        return FunctionTypeImpl(
            returnType: typeProvider.voidType,
            typeFormals: [],
            parameters: [
              ParameterElementImpl.synthetic(
                  'value', variableType, ParameterKind.REQUIRED)
            ],
            nullabilitySuffix: NullabilitySuffix.none);
      } else {
        return FunctionTypeImpl(
            returnType: variableType,
            typeFormals: [],
            parameters: [],
            nullabilitySuffix: NullabilitySuffix.none);
      }
    } else {
      return _variables.decoratedElementType(element).toFinalType(typeProvider);
    }
  }

  static TypeSystemImpl _makeNnbdTypeSystem(
      TypeProvider nnbdTypeProvider, Dart2TypeSystem typeSystem) {
    // TODO(paulberry): do we need to test both possible values of
    // strictInference?
    return TypeSystemImpl(
        implicitCasts: typeSystem.implicitCasts,
        isNonNullableByDefault: true,
        strictInference: typeSystem.strictInference,
        typeProvider: nnbdTypeProvider);
  }
}

/// [NodeChange] reprensenting a type annotation that needs to have a question
/// mark added to it, to make it nullable.
class MakeNullable implements NodeChange {
  factory MakeNullable() => const MakeNullable._();

  const MakeNullable._();
}

class MigrationResolutionHooksImpl implements MigrationResolutionHooks {
  final FixBuilder _fixBuilder;

  FlowAnalysis<AstNode, Statement, Expression, PromotableElement, DartType>
      _flowAnalysis;

  MigrationResolutionHooksImpl(this._fixBuilder);

  @override
  List<ParameterElement> getExecutableParameters(ExecutableElement element) =>
      getExecutableType(element).parameters;

  @override
  DartType getExecutableReturnType(FunctionTypedElement element) =>
      getExecutableType(element).returnType;

  @override
  FunctionType getExecutableType(FunctionTypedElement element) {
    var type = _fixBuilder._computeMigratedType(element);
    Element baseElement = element;
    if (baseElement is Member) {
      type = baseElement.substitution.substituteType(type);
    }
    return type as FunctionType;
  }

  @override
  DartType getVariableType(VariableElement variable) =>
      _fixBuilder._computeMigratedType(variable);

  @override
  DartType modifyExpressionType(Expression node, DartType type) {
    if (type.isDynamic) return type;
    if (!_fixBuilder._typeSystem.isNullable(type)) return type;
    if (_needsNullCheckDueToStructure(node)) {
      return _addNullCheck(node, type);
    }
    var context = InferenceContext.getContext(node) ?? DynamicTypeImpl.instance;
    if (!_fixBuilder._typeSystem.isNullable(context)) {
      return _addNullCheck(node, type);
    }
    return type;
  }

  @override
  void setFlowAnalysis(
      FlowAnalysis<AstNode, Statement, Expression, PromotableElement, DartType>
          flowAnalysis) {
    _flowAnalysis = flowAnalysis;
  }

  DartType _addNullCheck(Expression node, DartType type) {
    _fixBuilder.addChange(node, NullCheck());
    _flowAnalysis.nonNullAssert_end(node);
    return _fixBuilder._typeSystem.promoteToNonNull(type as TypeImpl);
  }

  bool _needsNullCheckDueToStructure(Expression node) {
    var parent = node.parent;
    if (parent is BinaryExpression) {
      if (identical(node, parent.leftOperand)) {
        var operatorType = parent.operator.type;
        if (operatorType == TokenType.QUESTION_QUESTION ||
            operatorType == TokenType.EQ_EQ ||
            operatorType == TokenType.BANG_EQ) {
          return false;
        } else {
          return true;
        }
      }
    } else if (parent is PrefixedIdentifier) {
      if (identical(node, parent.prefix)) {
        // TODO(paulberry): ok for toString etc. if the shape is correct
        return true;
      }
    } else if (parent is PropertyAccess) {
      // TODO(paulberry): what about cascaded?
      if (parent.operator.type == TokenType.PERIOD &&
          identical(node, parent.target)) {
        // TODO(paulberry): ok for toString etc. if the shape is correct
        return true;
      }
    } else if (parent is IndexExpression) {
      if (identical(node, parent.target)) {
        // TODO(paulberry): what about cascaded?
        return true;
      }
    }
    return false;
  }
}

/// Base class representing a change the FixBuilder wishes to make to an AST
/// node.
abstract class NodeChange {}

/// [NodeChange] representing an expression that needs to have a null check
/// added to it.
class NullCheck implements NodeChange {
  factory NullCheck() => const NullCheck._();

  const NullCheck._();
}

/// Common supertype for problems reported by [FixBuilder.addProblem].
abstract class Problem {}
