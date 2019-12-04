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
import 'package:analyzer/src/dart/element/inheritance_manager3.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type_algebra.dart';
import 'package:analyzer/src/dart/element/type_provider.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis_visitor.dart';
import 'package:analyzer/src/generated/migration.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
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
  DartType _computeMigratedType(Element element, {DartType targetType}) {
    element = element.declaration;
    DartType type;
    if (element is ClassElement || element is TypeParameterElement) {
      return typeProvider.typeType;
    } else if (element is PropertyAccessorElement) {
      if (element.isSynthetic) {
        type = _variables
            .decoratedElementType(element.variable)
            .toFinalType(typeProvider);
      } else {
        var functionType = _variables.decoratedElementType(element);
        var decoratedType = element.isGetter
            ? functionType.returnType
            : functionType.positionalParameters[0];
        type = decoratedType.toFinalType(typeProvider);
      }
    } else {
      type = _variables.decoratedElementType(element).toFinalType(typeProvider);
    }
    if (targetType is InterfaceType && targetType.typeArguments.isNotEmpty) {
      var superclass = element.enclosingElement as ClassElement;
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

  MigrationResolutionHooksImpl(this._fixBuilder);

  @override
  DartType getElementReturnType(FunctionTypedElement element) =>
      (_fixBuilder._computeMigratedType(element) as FunctionType).returnType;

  @override
  DartType getVariableType(VariableElement variable) =>
      _fixBuilder._computeMigratedType(variable);

  @override
  DartType modifyExpressionType(Expression node, DartType type) {
    if (type.isDynamic) return type;
    if (!_fixBuilder._typeSystem.isNullable(type)) return type;
    if (_needsNullCheckDueToStructure(node)) {
      _fixBuilder.addChange(node, NullCheck());
      return _fixBuilder._typeSystem.promoteToNonNull(type as TypeImpl);
    }
    var context = InferenceContext.getContext(node) ?? DynamicTypeImpl.instance;
    if (!_fixBuilder._typeSystem.isNullable(context)) {
      _fixBuilder.addChange(node, NullCheck());
      return _fixBuilder._typeSystem.promoteToNonNull(type as TypeImpl);
    }
    return type;
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
