// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:front_end/src/testing/id.dart'
    show ActualData, Id, IdKind, NodeId;

import 'helpers.dart';

/// Abstract IR visitor for computing data corresponding to a node or element,
/// and record it with a generic [Id]
/// TODO(paulberry): if I try to extend GeneralizingAstVisitor<void>, the VM
/// crashes.
abstract class AstDataExtractor<T> extends GeneralizingAstVisitor<dynamic>
    with DataRegistry<T> {
  final Uri uri;

  @override
  final Map<Id, ActualData<T>> actualMap;

  AstDataExtractor(this.uri, this.actualMap);

  NodeId computeDefaultNodeId(AstNode node) =>
      NodeId(_nodeOffset(node), IdKind.node);

  void computeForExpression(Expression node, NodeId id) {
    if (id == null) return;
    T value = computeNodeValue(id, node);
    registerValue(uri, node.offset, id, value, node);
  }

  void computeForFunctionBody(FunctionBody node, NodeId id) {
    if (id == null) return;
    T value = computeNodeValue(id, node);
    registerValue(uri, node.offset, id, value, node);
  }

  void computeForStatement(Statement node, NodeId id) {
    if (id == null) return;
    T value = computeNodeValue(id, node);
    registerValue(uri, node.offset, id, value, node);
  }

  /// Implement this to compute the data corresponding to [node].
  ///
  /// If `null` is returned, [node] has no associated data.
  T computeNodeValue(Id id, AstNode node);

  NodeId createFunctionBodyId(FunctionBody node) =>
      NodeId(_nodeOffset(node), IdKind.functionBody);

  NodeId createStatementId(Statement node) =>
      NodeId(_nodeOffset(node), IdKind.statement);

  void run(CompilationUnit unit) {
    unit.accept(this);
  }

  @override
  visitExpression(Expression node) {
    computeForExpression(node, computeDefaultNodeId(node));
    super.visitExpression(node);
  }

  @override
  visitFunctionBody(FunctionBody node) {
    computeForFunctionBody(node, createFunctionBodyId(node));
    super.visitFunctionBody(node);
  }

  @override
  visitStatement(Statement node) {
    computeForStatement(node, createStatementId(node));
    super.visitStatement(node);
  }

  int _nodeOffset(AstNode node) {
    var offset = node.offset;
    assert(offset != null && offset >= 0,
        "No fileOffset on $node (${node.runtimeType})");
    return offset;
  }
}

abstract class DataRegistry<T> {
  Map<Id, ActualData<T>> get actualMap;

  void registerValue(Uri uri, int offset, Id id, T value, Object object) {
    if (actualMap.containsKey(id)) {
      ActualData<T> existingData = actualMap[id];
      reportHere(offset, "Duplicate id $id, value=$value, object=$object");
      reportHere(
          offset,
          "Duplicate id $id, value=${existingData.value}, "
          "object=${existingData.object}");
      throw StateError("Duplicate id $id.");
    }
    if (value != null) {
      actualMap[id] = new ActualData<T>(id, value, uri, offset, object);
    }
  }
}
