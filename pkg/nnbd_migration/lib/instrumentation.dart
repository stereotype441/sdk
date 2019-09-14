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
  DartType get type;

  NullabilityNodeInfo get node;
}

abstract class EdgeInfo {
  NullabilityNodeInfo get primarySource;

  NullabilityNodeInfo get destinationNode;
}

abstract class NullabilityMigrationInstrumentation {
  void explicitTypeNullability(
      Source source, TypeAnnotation typeAnnotation, NullabilityNodeInfo node);

  void externalDecoratedType(Element element, DecoratedTypeInfo decoratedType);

  void graphEdge(EdgeInfo edge);

  void implicitReturnType(
      Source source, AstNode node, DecoratedTypeInfo decoratedReturnType);

  void implicitType(
      Source source, AstNode node, DecoratedTypeInfo decoratedType);

  void implicitTypeArguments(
      Source source, AstNode node, Iterable<DecoratedTypeInfo> types);

  void propagationStep(PropagationInfo info);
}

abstract class PropagationInfo {
  NullabilityNodeInfo get node;

  NullabilityState get newState;

  StateChangeReason get reason;

  EdgeInfo get edge;

  SubstitutionNodeInfo get substitutionNode;
}

/// Information about a single node in the nullability inference graph.
abstract class NullabilityNodeInfo {
  /// After migration is complete, this getter can be used to query whether
  /// the type associated with this node was determined to be nullable.
  bool get isNullable;

  bool get isImmutable;
}

enum StateChangeReason {
  union,
  upstream,
  downstream,
  exactUpstream,
  substituteInner,
  substituteOuter,
}

abstract class SubstitutionNodeInfo extends NullabilityNodeInfo {}
