// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:front_end/src/fasta/flow_analysis/flow_analysis.dart';
import 'package:test/test.dart';

main() {
  test('assignedInClosureAnywhere records assignments in closures', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    var v2 = _Variable('v2');
    var v3 = _Variable('v3');
    av.write(v1);
    av.beginClosure();
    av.write(v2);
    av.endClosure(_Node());
    av.write(v3);
    expect(av.assignedInClosureAnywhere, {v2});
  });

  test('assigned ignores assignments outside the node', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    var v2 = _Variable('v2');
    av.write(v1);
    av.beginStatementOrElement();
    var node = _Node();
    av.endStatementOrElement(node);
    av.write(v2);
    expect(av.assigned(node), isEmpty);
  });

  test('assigned records assignments inside the node', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    av.beginStatementOrElement();
    av.write(v1);
    var node = _Node();
    av.endStatementOrElement(node);
    expect(av.assigned(node), {v1});
  });

  test('assigned records assignments in a nested node', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    av.beginStatementOrElement();
    av.beginStatementOrElement();
    av.write(v1);
    av.endStatementOrElement(_Node());
    var node = _Node();
    av.endStatementOrElement(node);
    expect(av.assigned(node), {v1});
  });

  test('assigned records assignments in a closure', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    av.beginClosure();
    av.write(v1);
    var node = _Node();
    av.endClosure(node);
    expect(av.assigned(node), {v1});
  });

  test('assignedInClosure ignores assignments in non-nested closures', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    var v2 = _Variable('v2');
    av.beginClosure();
    av.write(v1);
    av.endClosure(_Node());
    av.beginStatementOrElement();
    var node = _Node();
    av.endStatementOrElement(node);
    av.beginClosure();
    av.write(v2);
    av.endClosure(_Node());
    expect(av.assignedInClosure(node), isEmpty);
  });

  test('assignedInClosure records assignments in nested closures', () {
    var av = AssignedVariables<_Node, _Variable>();
    var v1 = _Variable('v1');
    av.beginStatementOrElement();
    av.beginClosure();
    av.write(v1);
    av.endClosure(_Node());
    var node = _Node();
    av.endStatementOrElement(node);
    expect(av.assigned(node), {v1});
  });
}

class _Node {}

class _Variable {
  final String name;

  _Variable(this.name);

  @override
  String toString() => name;
}
