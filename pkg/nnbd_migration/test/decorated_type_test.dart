// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/testing/test_type_provider.dart';
import 'package:nnbd_migration/src/decorated_type.dart';
import 'package:nnbd_migration/src/nullability_node.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'migration_visitor_test_base.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DecoratedTypeTest);
  });
}

@reflectiveTest
class DecoratedTypeTest extends Object
    with DecoratedTypeTester
    implements DecoratedTypeTesterBase {
  final graph = NullabilityGraph();

  final TypeProvider typeProvider;

  factory DecoratedTypeTest() {
    var typeProvider = TestTypeProvider();
    return DecoratedTypeTest._(typeProvider);
  }

  DecoratedTypeTest._(this.typeProvider);

  NullabilityNode get always => graph.always;

  ClassElement get listElement => typeProvider.listType.element;

  void setUp() {
    NullabilityNode.clearDebugNames();
  }

  test_equal_interfaceType_different_args() {
    var node = newNode();
    expect(list(int_(), node: node) == list(int_(), node: node), isFalse);
  }

  test_equal_interfaceType_different_classes() {
    var node = newNode();
    expect(int_(node: node) == object(node: node), isFalse);
  }

  test_equal_interfaceType_different_nodes() {
    expect(int_() == int_(), isFalse);
  }

  test_equal_interfaceType_same() {
    var node = newNode();
    expect(int_(node: node) == int_(node: node), isTrue);
  }

  test_equal_interfaceType_same_generic() {
    var argType = int_();
    var node = newNode();
    expect(list(argType, node: node) == list(argType, node: node), isTrue);
  }

  test_toString_bottom() {
    var node = newNode();
    var decoratedType = DecoratedType(BottomTypeImpl.instance, node);
    expect(decoratedType.toString(), 'Never?($node)');
  }

  test_toString_interface_type_argument() {
    var argType = int_();
    var decoratedType = list(argType, node: always);
    expect(decoratedType.toString(), 'List<$argType>?');
  }

  test_toString_named_parameter() {
    var xType = int_();
    var decoratedType = function(dynamic_, named: {'x': xType}, node: always);
    expect(decoratedType.toString(), 'dynamic Function({x: $xType})?');
  }

  test_toString_normal_and_named_parameter() {
    var xType = int_();
    var yType = int_();
    var decoratedType = function(dynamic_,
        required: [xType], named: {'y': yType}, node: always);
    expect(decoratedType.toString(), 'dynamic Function($xType, {y: $yType})?');
  }

  test_toString_normal_and_optional_parameter() {
    var xType = int_();
    var yType = int_();
    var decoratedType = function(dynamic_,
        required: [xType], positional: [yType], node: always);
    expect(decoratedType.toString(), 'dynamic Function($xType, [$yType])?');
  }

  test_toString_normal_parameter() {
    var xType = int_();
    var decoratedType = function(dynamic_, required: [xType], node: always);
    expect(decoratedType.toString(), 'dynamic Function($xType)?');
  }

  test_toString_optional_parameter() {
    var xType = int_();
    var decoratedType = function(dynamic_, positional: [xType], node: always);
    expect(decoratedType.toString(), 'dynamic Function([$xType])?');
  }
}
