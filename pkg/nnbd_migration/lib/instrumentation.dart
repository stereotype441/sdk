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

  DartType get type;

  DecoratedTypeInfo get returnType;

  DecoratedTypeInfo positionalParameter(int i);
}

abstract class EdgeInfo {
  NullabilityNodeInfo get destinationNode;

  NullabilityNodeInfo get primarySource;
}

abstract class NullabilityMigrationInstrumentation {
  void explicitTypeNullability(
      Source source, TypeAnnotation typeAnnotation, NullabilityNodeInfo node);

  void externalDecoratedType(Element element, DecoratedTypeInfo decoratedType);

  void graphEdge(EdgeInfo edge);

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

abstract class SubstitutionNodeInfo extends NullabilityNodeInfo {}
