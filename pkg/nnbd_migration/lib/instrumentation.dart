// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source.dart';

abstract class NullabilityMigrationInstrumentation {
  void explicitTypeNullability(Source source, TypeAnnotation typeAnnotation, NullabilityNodeInfo node);

  void implicitTypeArguments(Source source, AstNode node, Iterable<DecoratedTypeInfo> type);

  void implicitDeclarationReturnType(Source source, AstNode node, DecoratedTypeInfo decoratedReturnType);

  void implicitDeclarationType(Source source, AstNode node, DecoratedTypeInfo decoratedType);

  void externalDecoratedType(Element element, DecoratedTypeInfo decoratedType);

  void graphEdge(EdgeInfo edge) {}
}

/// Information about a single node in the nullability inference graph.
abstract class NullabilityNodeInfo {}

/// Information about the set of nullability nodes decorating a type in the
/// program being migrated.
abstract class DecoratedTypeInfo {}

abstract class EdgeInfo {}