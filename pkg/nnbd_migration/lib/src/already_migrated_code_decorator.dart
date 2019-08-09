// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:nnbd_migration/src/decorated_type.dart';
import 'package:nnbd_migration/src/nullability_node.dart';

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
}
