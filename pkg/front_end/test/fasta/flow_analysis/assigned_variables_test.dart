// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:front_end/src/fasta/flow_analysis/flow_analysis.dart';
import 'package:test/test.dart';

main() {
  test('capturedAnywhere records assignments in closures', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    var v2 = _Variable('v2');
    var v3 = _Variable('v3');
    av.write(v1);
    av.beginNode(isClosure: true);
    av.write(v2);
    av.endNode(_Node(), isClosure: true);
    av.write(v3);
    expect(av.capturedAnywhere, {v2});
  });

  test('writtenInNode ignores assignments outside the node', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    var v2 = _Variable('v2');
    av.write(v1);
    av.beginNode();
    var node = _Node();
    av.endNode(node);
    av.write(v2);
    expect(av.writtenInNode(node), isEmpty);
  });

  test('writtenInNode records assignments inside the node', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    av.beginNode();
    av.write(v1);
    var node = _Node();
    av.endNode(node);
    expect(av.writtenInNode(node), {v1});
  });

  test('writtenInNode records assignments in a nested node', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    av.beginNode();
    av.beginNode();
    av.write(v1);
    av.endNode(_Node());
    var node = _Node();
    av.endNode(node);
    expect(av.writtenInNode(node), {v1});
  });

  test('writtenInNode records assignments in a closure', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    av.beginNode(isClosure: true);
    av.write(v1);
    var node = _Node();
    av.endNode(node, isClosure: true);
    expect(av.writtenInNode(node), {v1});
  });

  test('capturedInNode ignores assignments in non-nested closures', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    var v2 = _Variable('v2');
    av.beginNode(isClosure: true);
    av.write(v1);
    av.endNode(_Node(), isClosure: true);
    av.beginNode();
    var node = _Node();
    av.endNode(node);
    av.beginNode(isClosure: true);
    av.write(v2);
    av.endNode(_Node(), isClosure: true);
    expect(av.capturedInNode(node), isEmpty);
  });

  test('capturedInNode records assignments in nested closures', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    av.beginNode();
    av.beginNode(isClosure: true);
    av.write(v1);
    av.endNode(_Node(), isClosure: true);
    var node = _Node();
    av.endNode(node);
    expect(av.capturedInNode(node), {v1});
  });
}

class _Node {}

class _Variable {
  final String name;

  _Variable(this.name);

  @override
  String toString() => name;
}
