// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' show SourceEdit;
import 'package:nnbd_migration/src/nullability_node.dart';
import 'package:nnbd_migration/src/potential_modification.dart';

import 'decorated_type.dart';

class AlreadyMigratedCodeDecorator {
  final NullabilityGraph graph;

  AlreadyMigratedCodeDecorator(this.graph);

  DecoratedType decorate(DartType type) {
    if (type.isVoid || type.isDynamic) {
      return DecoratedType(type, graph.always);
    }
    assert((type as TypeImpl).nullabilitySuffix ==
        NullabilitySuffix.star); // TODO(paulberry)
    if (type is FunctionType) {
      var positionalParameters = <DecoratedType>[];
      var namedParameters = <String, DecoratedType>{};
      for (var parameter in type.parameters) {
        if (parameter.isPositional) {
          positionalParameters.add(decorate(parameter.type));
        } else {
          namedParameters[parameter.name] = decorate(parameter.type);
        }
      }
      return DecoratedType(type, graph.never,
          returnType: decorate(type.returnType),
          namedParameters: namedParameters,
          positionalParameters: positionalParameters);
    } else if (type is InterfaceType) {
      if (type.typeParameters.isNotEmpty) {
        // TODO(paulberry)
        throw UnimplementedError('Decorating ${type.displayName}');
      }
      return DecoratedType(type, graph.never);
    } else if (type is TypeParameterType) {
      return DecoratedType(type, graph.never);
    } else {
      throw type.runtimeType; // TODO(paulberry)
    }
  }

  /// Creates a [DecoratedType] corresponding to the given [element], which is
  /// presumed to have come from code that is already migrated.
  DecoratedType decorateElement(Element element) {
    // TODO(paulberry): consider merging with caller

    // Sanity check:
    // Ensure the element is not from a library that is being migrated.
    // If this assertion fires, it probably means that the NodeBuilder failed to
    // generate the appropriate decorated type for the element when it was
    // visiting the source file.
    if (graph.isBeingMigrated(element.source)) {
      throw 'Internal Error: DecorateType.forElement should not be called'
          ' for elements being migrated: ${element.runtimeType} :: $element';
    }

    DecoratedType decoratedType;
    if (element is ExecutableElement) {
      decoratedType = decorate(element.type);
    } else if (element is TopLevelVariableElement) {
      decoratedType = decorate(element.type);
    } else if (element is TypeParameterElement) {
      // By convention, type parameter elements are decorated with the type of
      // their bounds.
      decoratedType = decorate(element.bound ?? DynamicTypeImpl.instance);
    } else {
      // TODO(paulberry)
      throw UnimplementedError('Decorating ${element.runtimeType}');
    }
    return decoratedType;
  }
}