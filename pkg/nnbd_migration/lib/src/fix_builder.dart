// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:_fe_analyzer_shared/src/flow_analysis/flow_analysis.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type_algebra.dart';
import 'package:analyzer/src/dart/element/type_provider.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis_visitor.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
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

/// TODO(paulberry): document
class FixBuilder {
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

  factory FixBuilder(
      Source source,
      DecoratedClassHierarchy decoratedClassHierarchy,
      TypeProvider typeProvider,
      Dart2TypeSystem typeSystem,
      Variables variables) {
    var nnbdTypeProvider =
        (typeProvider as TypeProviderImpl).asNonNullableByDefault;
    // TODO(paulberry): do we need to test both possible values of
    // strictInference?
    var nnbdTypeSystem = TypeSystemImpl(
        implicitCasts: typeSystem.implicitCasts,
        isNonNullableByDefault: true,
        strictInference: typeSystem.strictInference,
        typeProvider: nnbdTypeProvider);
    return FixBuilder._(decoratedClassHierarchy, nnbdTypeProvider,
        nnbdTypeSystem, variables, source);
  }

  FixBuilder._(this._decoratedClassHierarchy, this.typeProvider,
      this._typeSystem, this._variables, this.source);
}

/// [NodeChange] reprensenting a type annotation that needs to have a question
/// mark added to it, to make it nullable.
class MakeNullable implements NodeChange {
  factory MakeNullable() => const MakeNullable._();

  const MakeNullable._();
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
