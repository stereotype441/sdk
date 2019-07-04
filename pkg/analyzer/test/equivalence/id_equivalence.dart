// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'helpers.dart';
import 'source_span.dart';

/// Id for a code point or element with type inference information.
abstract class Id {
  IdKind get kind;
  bool get isGlobal;

  /// Display name for this id.
  String get descriptor;
}

enum IdKind {
  node,
  invoke,
  update,
  iterator,
  current,
  moveNext,
}

/// Id for a code point with testing information.
class NodeId implements Id {
  final int value;
  @override
  final IdKind kind;

  const NodeId(this.value, this.kind);

  @override
  bool get isGlobal => false;

  @override
  int get hashCode => value.hashCode * 13 + kind.hashCode * 17;

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is! NodeId) return false;
    return value == other.value && kind == other.kind;
  }

  @override
  String get descriptor => 'offset $value ($kind)';

  @override
  String toString() => '$kind:$value';
}

class ActualData<T> {
  final Id id;
  final T value;
  final SourceSpan sourceSpan;
  final Object object;

  ActualData(this.id, this.value, this.sourceSpan, this.object);

  int get offset {
    if (id is NodeId) {
      NodeId nodeId = id;
      return nodeId.value;
    } else {
      return sourceSpan.begin;
    }
  }

  String get objectText {
    return 'object `${'$object'.replaceAll('\n', '')}` (${object.runtimeType})';
  }

  @override
  String toString() =>
      'ActualData(id=$id,value=$value,sourceSpan=$sourceSpan,object=$objectText)';
}

abstract class DataRegistry<T> {
  Map<Id, ActualData<T>> get actualMap;

  void registerValue(SourceSpan sourceSpan, Id id, T value, Object object) {
    if (actualMap.containsKey(id)) {
      ActualData<T> existingData = actualMap[id];
      reportHere(sourceSpan,
          "Duplicate id ${id}, value=$value, object=$object");
      reportHere(
          sourceSpan,
          "Duplicate id ${id}, value=${existingData.value}, "
              "object=${existingData.object}");
      throw StateError("Duplicate id $id.");
    }
    if (value != null) {
      actualMap[id] = new ActualData<T>(id, value, sourceSpan, object);
    }
  }
}

class IdValue {
  final Id id;
  final String value;

  const IdValue(this.id, this.value);

  @override
  int get hashCode => id.hashCode * 13 + value.hashCode * 17;

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is! IdValue) return false;
    return id == other.id && value == other.value;
  }

  @override
  String toString() => idToString(id, value);

  static String idToString(Id id, String value) {
    switch (id.kind) {
      case IdKind.node:
        return value;
      case IdKind.invoke:
        return '$invokePrefix$value';
      case IdKind.update:
        return '$updatePrefix$value';
      case IdKind.iterator:
        return '$iteratorPrefix$value';
      case IdKind.current:
        return '$currentPrefix$value';
      case IdKind.moveNext:
        return '$moveNextPrefix$value';
    }
    throw new UnsupportedError("Unexpected id kind: ${id.kind}");
  }

  static const String globalPrefix = "global#";
  static const String invokePrefix = "invoke: ";
  static const String updatePrefix = "update: ";
  static const String iteratorPrefix = "iterator: ";
  static const String currentPrefix = "current: ";
  static const String moveNextPrefix = "moveNext: ";

  static IdValue decode(int offset, String text) {
    Id id;
    String expected;
    if (text.startsWith(invokePrefix)) {
      id = new NodeId(offset, IdKind.invoke);
      expected = text.substring(invokePrefix.length);
    } else if (text.startsWith(updatePrefix)) {
      id = new NodeId(offset, IdKind.update);
      expected = text.substring(updatePrefix.length);
    } else if (text.startsWith(iteratorPrefix)) {
      id = new NodeId(offset, IdKind.iterator);
      expected = text.substring(iteratorPrefix.length);
    } else if (text.startsWith(currentPrefix)) {
      id = new NodeId(offset, IdKind.current);
      expected = text.substring(currentPrefix.length);
    } else if (text.startsWith(moveNextPrefix)) {
      id = new NodeId(offset, IdKind.moveNext);
      expected = text.substring(moveNextPrefix.length);
    } else {
      id = new NodeId(offset, IdKind.node);
      expected = text;
    }
    // Remove newlines.
    expected = expected.replaceAll(new RegExp(r'\s*(\n\s*)+\s*'), '');
    return new IdValue(id, expected);
  }
}

/// Abstract IR visitor for computing data corresponding to a node or element,
/// and record it with a generic [Id]
/// TODO(paulberry): if I try to extend GeneralizingAstVisitor<void>, the VM
/// crashes.
abstract class AstDataExtractor<T> extends GeneralizingAstVisitor<dynamic> with DataRegistry<T> {
  final Uri uri;

  @override
  final Map<Id, ActualData<T>> actualMap;

  /// Implement this to compute the data corresponding to [node].
  ///
  /// If `null` is returned, [node] has no associated data.
  T computeNodeValue(Id id, AstNode node);

  AstDataExtractor(this.uri, this.actualMap);

  void computeForNode(AstNode node, NodeId id) {
    if (id == null) return;
    T value = computeNodeValue(id, node);
    registerValue(computeSourceSpan(node), id, value, node);
  }

  SourceSpan computeSourceSpan(AstNode node) {
    return SourceSpan(this.uri, node.offset, node.end);
  }

  int _nodeOffset(AstNode node) {
    var offset = node.offset;
    assert(offset != null && offset >= 0,
    "No fileOffset on $node (${node.runtimeType})");
    return offset;
  }

  NodeId computeDefaultNodeId(AstNode node) => NodeId(_nodeOffset(node), IdKind.node);

  NodeId _createInvokeId(AstNode node) => NodeId(_nodeOffset(node), IdKind.invoke);

  NodeId _createUpdateId(AstNode node) => NodeId(_nodeOffset(node), IdKind.update);

  NodeId _createIteratorId(ForEachParts node) => NodeId(_nodeOffset(node), IdKind.iterator);

  NodeId _createCurrentId(ForEachParts node) => NodeId(_nodeOffset(node), IdKind.current);

  NodeId _createMoveNextId(ForEachParts node) => NodeId(_nodeOffset(node), IdKind.moveNext);

  NodeId _createLabeledStatementId(LabeledStatement node) =>
      computeDefaultNodeId(node.statement);
  NodeId _createLoopId(AstNode node) => computeDefaultNodeId(node);
  NodeId _createGotoId(AstNode node) => computeDefaultNodeId(node);
  NodeId _createSwitchId(SwitchStatement node) => computeDefaultNodeId(node);
  NodeId _createSwitchCaseId(SwitchCase node) =>
      computeDefaultNodeId(node);
  
  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    computeForNode(node, computeDefaultNodeId(node));
    super.visitSimpleIdentifier(node);
  }

  void run(CompilationUnit unit) {
    unit.accept(this);
  }
}
