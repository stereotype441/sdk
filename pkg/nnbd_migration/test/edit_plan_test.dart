// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:nnbd_migration/src/edit_plan.dart';
import 'package:nnbd_migration/src/fix_planner.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_single_unit.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SimpleEditPlanTest);
  });
}

class EditPlanTestBase extends AbstractSingleUnitTest {}

@reflectiveTest
class SimpleEditPlanTest extends EditPlanTestBase {
  test_parensNeeded_forExpression() async {
    await resolveTestUnit('''
void f(a, b) => a + b;
''');
    var editPlan = SimpleEditPlan.forExpression(findNode.binary('a + b'));
    expect(
        editPlan.parensNeeded(
            threshold: Precedence.additive,
            associative: true,
            allowCascade: true),
        false);
  }
}
