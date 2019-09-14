// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/test_utilities/find_node.dart';
import 'package:nnbd_migration/instrumentation.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:nnbd_migration/nullability_state.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_context.dart';
import 'api_test_base.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(_InstrumentationTest);
  });
}

class _InstrumentationClient implements NullabilityMigrationInstrumentation {
  final _InstrumentationTest test;

  _InstrumentationClient(this.test);

  @override
  void explicitTypeNullability(
      Source source, TypeAnnotation typeAnnotation, NullabilityNodeInfo node) {
    expect(source, test.source);
    expect(test.explicitTypeNullability, isNot(contains(typeAnnotation)));
    test.explicitTypeNullability[typeAnnotation] = node;
  }

  @override
  void externalDecoratedType(Element element, DecoratedTypeInfo decoratedType) {
    expect(test.externalDecoratedType, isNot(contains(element)));
    test.externalDecoratedType[element] = decoratedType;
  }

  @override
  void graphEdge(EdgeInfo edge) {
    test.edges.add(edge);
  }

  @override
  void implicitReturnType(
      Source source, AstNode node, DecoratedTypeInfo decoratedReturnType) {
    expect(source, test.source);
    expect(test.implicitReturnType, isNot(contains(node)));
    test.implicitReturnType[node] = decoratedReturnType;
  }

  @override
  void implicitType(
      Source source, AstNode node, DecoratedTypeInfo decoratedType) {
    expect(source, test.source);
    expect(test.implicitType, isNot(contains(node)));
    test.implicitType[node] = decoratedType;
  }

  @override
  void implicitTypeArguments(
      Source source, AstNode node, Iterable<DecoratedTypeInfo> types) {
    expect(source, test.source);
    expect(test.implicitTypeArguments, isNot(contains(node)));
    test.implicitTypeArguments[node] = types.toList();
  }

  @override
  void propagationInfo(NullabilityNodeInfo node, NullabilityState state,
      StateChangeReason reason,
      {EdgeInfo edge, SubstitutionNodeInfo substitutionNode}) {
    // TODO: implement propagationInfo
  }
}

@reflectiveTest
class _InstrumentationTest extends AbstractContextTest {
  final Map<TypeAnnotation, NullabilityNodeInfo> explicitTypeNullability = {};

  final Map<Element, DecoratedTypeInfo> externalDecoratedType = {};

  final List<EdgeInfo> edges = [];

  final Map<AstNode, DecoratedTypeInfo> implicitReturnType = {};

  final Map<AstNode, DecoratedTypeInfo> implicitType = {};

  final Map<AstNode, List<DecoratedTypeInfo>> implicitTypeArguments = {};

  FindNode findNode;

  Source source;

  Future<void> analyze(String content) async {
    var sourcePath = convertPath('/home/test/lib/test.dart');
    newFile(sourcePath, content: content);
    var listener = new TestMigrationListener();
    var migration = NullabilityMigration(listener,
        instrumentation: _InstrumentationClient(this));
    var result = await session.getResolvedUnit(sourcePath);
    source = result.unit.declaredElement.source;
    findNode = FindNode(content, result.unit);
    migration.prepareInput(result);
    migration.processInput(result);
    migration.finish();
  }

  test_explicitTypeNullability() async {
    var content = '''
int x = 1;
int y = null;
''';
    await analyze(content);
    expect(explicitTypeNullability[findNode.typeAnnotation('int x')].isNullable,
        false);
    expect(explicitTypeNullability[findNode.typeAnnotation('int y')].isNullable,
        true);
  }

  test_externalDecoratedType() async {
    await analyze('''
main() {
  print(1);
}
''');
    expect(
        externalDecoratedType[findNode.simple('print').staticElement]
            .type
            .toString(),
        'void Function(Object)');
  }

  test_graphEdge() async {
    await analyze('''
int f(int x) => x;
''');
    var xNode = explicitTypeNullability[findNode.typeAnnotation('int x')];
    var returnNode = explicitTypeNullability[findNode.typeAnnotation('int f')];
    expect(
        edges.where(
            (e) => e.primarySource == xNode && e.destinationNode == returnNode),
        hasLength(1));
  }

  test_implicitReturnType() async {
    await analyze('''
abstract class Base {
  int f();
}
abstract class Derived extends Base {
  f /*derived*/();
}
''');
    var baseReturnNode =
        explicitTypeNullability[findNode.typeAnnotation('int')];
    var derivedReturnNode =
        implicitReturnType[findNode.methodDeclaration('f /*derived*/')].node;
    expect(
        edges.where((e) =>
            e.primarySource == derivedReturnNode &&
            e.destinationNode == baseReturnNode),
        hasLength(1));
  }

  test_implicitType() async {
    await analyze('''
abstract class Base {
  void f(int i);
}
abstract class Derived extends Base {
  void f(i); /*derived*/
}
''');
    var baseParamNode =
        explicitTypeNullability[findNode.typeAnnotation('int i')];
    var derivedParamNode =
        implicitType[findNode.simpleParameter('i); /*derived*/')].node;
    expect(
        edges.where((e) =>
            e.primarySource == baseParamNode &&
            e.destinationNode == derivedParamNode),
        hasLength(1));
  }

  test_implicitTypeArguments() async {
    await analyze('''
List<int> f() => [null];
''');
    var implicitListLiteralElementNode =
        implicitTypeArguments[findNode.listLiteral('[null]')].single.node;
    var returnElementNode =
        explicitTypeNullability[findNode.typeAnnotation('int')];
    expect(
        edges.where((e) =>
            e.primarySource.isImmutable &&
            e.primarySource.isNullable &&
            e.destinationNode == implicitListLiteralElementNode),
        hasLength(1));
    expect(
        edges.where((e) =>
            e.primarySource == implicitListLiteralElementNode &&
            e.destinationNode == returnElementNode),
        hasLength(1));
  }
}
