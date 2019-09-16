// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:nnbd_migration/nullability_state.dart';

/// Information exposed to the migration client about the set of nullability
/// nodes decorating a type in the program being migrated.
abstract class DecoratedTypeInfo {
  /// Information about the graph node associated with the decision of whether
  /// or not to make this type into a nullable type.
  NullabilityNodeInfo get node;

  /// If [type] is a function type, information about the set of nullability
  /// nodes decorating the type's return type.
  DecoratedTypeInfo get returnType;

  /// The original (pre-migration) type that is being migrated.
  DartType get type;

  /// If [type] is a function type, looks up information about the set of
  /// nullability nodes decorating one of the type's named parameter types.
  DecoratedTypeInfo namedParameter(String name);

  /// If [type] is a function type, looks up information about the set of
  /// nullability nodes decorating one of the type's positional parameter types.
  /// (This could be an optional or a required positional parameter).
  DecoratedTypeInfo positionalParameter(int i);

  /// If [type] is an interface type, looks up information about the set of
  /// nullability nodes decorating one of the type's type arguments.
  DecoratedTypeInfo typeArgument(int i);
}

/// Information exposed to the migration client about an edge in the nullability
/// graph.
///
/// A graph edge represents a dependency relationship between two types being
/// migrated, suggesting that if one type (the source) is made nullable, it may
/// be desirable to make the other type (the destination) nullable as well.
abstract class EdgeInfo {
  /// Information about the graph node that this edge "points to".
  NullabilityNodeInfo get destinationNode;

  /// The set of "guard nodes" for this edge.  Guard nodes are graph nodes whose
  /// nullability determines whether it is important to satisfy a graph edge.
  /// If at least one of an edge's guards is non-nullable, then it is not
  /// important to satisfy the graph edge.  (Typically this is because the code
  /// that led to the graph edge being created is only reachable if the guards
  /// are all nullable).
  Iterable<NullabilityNodeInfo> get guards;

  /// A boolean indicating whether the graph edge is a "hard" edge.  Hard edges
  /// are associated with unconditional control flow, and thus allow information
  /// about non-nullability to be propagated "upstream" through the nullability
  /// graph.
  bool get hard;

  /// A boolean indicating whether the graph edge is "satisfied".  At its heart,
  /// the nullability propagation algorithm is an effort to satisfy graph edges
  /// in a way that corresponds to the user's intent.  A graph edge is
  /// considered satisfied if any of the following is true:
  /// - Its [primarySource] is non-nullable.
  /// - One of its [guards] is non-nullable.
  /// - Its [destinationNode] is nullable.
  bool get isSatisfied;

  /// A boolean indicating whether the graph edge is a "union" edge.  Union
  /// edges are edges for which the nullability propagation algorithm tries to
  /// ensure that both the [primarySource] and the [destinationNode] have the
  /// same nullability.  Typically these are associated with situations where
  /// Dart language semantics require two types to be the same type (e.g. a type
  /// formal bound on a generic function type in a base class, and the
  /// corresponding type formal bound on a generic function type in an
  /// overriding class).
  ///
  /// Union edges are always [hard].
  bool get isUnion;

  /// Information about the graph node that this edge "points away from".
  NullabilityNodeInfo get primarySource;
}

abstract class EdgeOriginInfo {
  AstNode get node;

  Source get source;
}

abstract class NullabilityMigrationInstrumentation {
  void explicitTypeNullability(
      Source source, TypeAnnotation typeAnnotation, NullabilityNodeInfo node);

  void externalDecoratedType(Element element, DecoratedTypeInfo decoratedType);

  void graphEdge(EdgeInfo edge, EdgeOriginInfo originInfo);

  void immutableNode(NullabilityNodeInfo node);

  void implicitReturnType(
      Source source, AstNode node, DecoratedTypeInfo decoratedReturnType);

  void implicitType(
      Source source, AstNode node, DecoratedTypeInfo decoratedType);

  void implicitTypeArguments(
      Source source, AstNode node, Iterable<DecoratedTypeInfo> types);

  void propagationStep(PropagationInfo info);
}

/// Information about a single node in the nullability inference graph.
abstract class NullabilityNodeInfo {
  bool get isImmutable;

  /// After migration is complete, this getter can be used to query whether
  /// the type associated with this node was determined to be nullable.
  bool get isNullable;
}

abstract class PropagationInfo {
  EdgeInfo get edge;

  NullabilityState get newState;

  NullabilityNodeInfo get node;

  StateChangeReason get reason;

  SubstitutionNodeInfo get substitutionNode;
}

enum StateChangeReason {
  union,
  upstream,
  downstream,
  exactUpstream,
  substituteInner,
  substituteOuter,
}

abstract class SubstitutionNodeInfo extends NullabilityNodeInfo {
  /// Nullability node representing the inner type of the substitution.
  ///
  /// For example, if this NullabilityNode arose from substituting `int*` for
  /// `T` in the type `T*`, [innerNode] is the nullability corresponding to the
  /// `*` in `int*`.
  NullabilityNodeInfo get innerNode;

  /// Nullability node representing the outer type of the substitution.
  ///
  /// For example, if this NullabilityNode arose from substituting `int*` for
  /// `T` in the type `T*`, [innerNode] is the nullability corresponding to the
  /// `*` in `T*`.
  NullabilityNodeInfo get outerNode;
}
