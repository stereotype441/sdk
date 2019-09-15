// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:nnbd_migration/nullability_state.dart';

/// Information about the set of nullability nodes decorating a type in the
/// program being migrated.
abstract class DecoratedTypeInfo {
  NullabilityNodeInfo get node;

  DecoratedTypeInfo get returnType;

  DartType get type;

  DecoratedTypeInfo namedParameter(String name);

  DecoratedTypeInfo positionalParameter(int i);

  DecoratedTypeInfo typeArgument(int i);
}

abstract class EdgeInfo {
  NullabilityNodeInfo get destinationNode;

  Iterable<NullabilityNodeInfo> get guards;

  bool get hard;

  bool get isSatisfied;

  bool get isUnion;

  NullabilityNodeInfo get primarySource;
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

abstract class EdgeOriginInfo {}

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
