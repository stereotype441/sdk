// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/testing/test_type_provider.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:nnbd_migration/src/already_migrated_code_decorator.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/decorated_type.dart';
import 'package:nnbd_migration/src/edge_builder.dart';
import 'package:nnbd_migration/src/edge_origin.dart';
import 'package:nnbd_migration/src/expression_checks.dart';
import 'package:nnbd_migration/src/nullability_node.dart';
import 'package:test/test.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_context.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(_AlreadyMigratedCodeDecoratorTest);
  });
}

@reflectiveTest
class _AlreadyMigratedCodeDecoratorTest {
  final TypeProvider typeProvider;

  final AlreadyMigratedCodeDecorator decorator;

  final NullabilityGraphForTesting graph;

  factory _AlreadyMigratedCodeDecoratorTest() {
    return _AlreadyMigratedCodeDecoratorTest._(NullabilityGraphForTesting());
  }

  _AlreadyMigratedCodeDecoratorTest._(this.graph)
      : typeProvider = TestTypeProvider(),
        decorator = AlreadyMigratedCodeDecorator(graph);

  DecoratedType decorate(DartType type) {
    var decoratedType = decorator.decorate(type);
    expect(decoratedType.type, same(type));
    return decoratedType;
  }

  test_decorate_dynamic() {
    expect(decorate(typeProvider.dynamicType).node, same(graph.always));
  }

  test_decorate_functionType_star() {
    expect(
        decorate(FunctionTypeImpl.synthetic(typeProvider.voidType, [], []))
            .node,
        same(graph.never));
  }

  test_decorate_void() {
    expect(decorate(typeProvider.voidType).node, same(graph.always));
  }
}
