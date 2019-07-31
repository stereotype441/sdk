// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:_rti' as rti;
import "package:expect/expect.dart";

void checkRtiIdentical(Object rti1, Object rti2) {
  var format = rti.testingRtiToString;
  Expect.isTrue(
      identical(rti1, rti2), 'identical(${format(rti1)}, ${format(rti2)}');
}

test1() {
  var universe = rti.testingCreateUniverse();

  // Extend environment in one step
  var env1a = rti.testingUniverseEval(universe, 'Foo');
  var args1 = rti.testingUniverseEval(universe, '@<aa,bb>');
  var env1b = rti.testingEnvironmentBind(universe, env1a, args1);

  var rti1 = rti.testingEnvironmentEval(universe, env1b, 'A<0,1,2>');
  Expect.equals('A<Foo, aa, bb>', rti.testingRtiToString(rti1));

  Expect.equals('binding(interface("Foo"), [interface("aa"), interface("bb")])',
      rti.testingRtiToDebugString(env1b));

  // Extend environment in two steps
  var env2a = rti.testingUniverseEval(universe, 'Foo');
  var args2a = rti.testingUniverseEval(universe, 'aa');
  var env2b = rti.testingEnvironmentBind(universe, env2a, args2a);
  var args2b = rti.testingUniverseEval(universe, 'bb');
  var env2c = rti.testingEnvironmentBind(universe, env2b, args2b);

  var rti2 = rti.testingEnvironmentEval(universe, env2c, 'A<0,1,2>');
  Expect.equals('A<Foo, aa, bb>', rti.testingRtiToString(rti2));

  Expect.equals('binding(interface("Foo"), [interface("aa")])',
      rti.testingRtiToDebugString(env2b));
  Expect.equals('binding(interface("Foo"), [interface("aa"), interface("bb")])',
      rti.testingRtiToDebugString(env2c));

  checkRtiIdentical(env1b, env2c);
}

main() {
  test1();
}
