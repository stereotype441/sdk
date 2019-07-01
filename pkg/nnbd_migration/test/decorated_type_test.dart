// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/decorated_type.dart';
import 'package:nnbd_migration/src/nullability_node.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_single_unit.dart';
import 'migration_visitor_test_base.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DecoratedTypeTest);
  });
}

@reflectiveTest
class DecoratedTypeTest extends AbstractSingleUnitTest {
  final _graph = NullabilityGraph();

  NullabilityNode get always => _graph.always;

  @override
  void setUp() {
    NullabilityNode.clearDebugNames();
    super.setUp();
  }

  test_toString_named_parameter() async {
    await resolveTestUnit('''dynamic f({int x}) {}''');
    var type = findElement.function('f').type;
    var decoratedType = DecoratedType(type, always,
        namedParameters: {
          'x': DecoratedType(type.namedParameterTypes['x'], _node(1))
        },
        returnType: DecoratedType(type.returnType, always));
    expect(decoratedType.toString(), 'dynamic Function({x: int?(type(1))})?');
  }

  test_toString_normal_parameter() async {
    await resolveTestUnit('''dynamic f(int x) {}''');
    var type = findElement.function('f').type;
    var decoratedType = DecoratedType(type, always,
        positionalParameters: [
          DecoratedType(type.normalParameterTypes[0], _node(1))
        ],
        returnType: DecoratedType(type.returnType, always));
    expect(decoratedType.toString(), 'dynamic Function(int?(type(1)))?');
  }

  NullabilityNode _node(int offset) =>
      NullabilityNode.forTypeAnnotation(offset);
}
