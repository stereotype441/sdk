// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:front_end/src/fasta/flow_analysis/flow_analysis.dart';
import 'package:test/test.dart';

class _Node {}

class _Variable {
  final String name;

  _Variable(this.name);
}

class _Harness {
  final av = AssignedVariables<_Node, _Variable>();
}

main() {
  test('assignedInClosureAnywhere records assignments in closures', () {
    var h = _Harness();
    var v1 = _Variable('v1');
    var v2 = _Variable('v2');
    var v3 = _Variable('v3');
    h.av.write(v1);
    h.av.beginClosure();
    h.av.write(v2);
    h.av.endClosure(_Node());
    h.av.write(v3);
    expect(h.av.assignedInClosureAnywhere, {v2});
  });

  test('assignedInClosure')
}