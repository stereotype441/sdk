// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type_provider.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/type_system.dart';
import 'package:analyzer/src/task/strong/checker.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/fix_applier.dart';
import 'package:nnbd_migration/src/variables.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_single_unit.dart';
import 'migration_visitor_test_base.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FixPlannerTest);
  });
}

@reflectiveTest
class FixPlannerTest extends AbstractSingleUnitTest {
  void test_adjacentFixes() async {
    await resolveTestUnit('''
f(a, b) => a + b;
''');
    var aRef = findNode.simple('a +');
    var bRef = findNode.simple('b;');
    var previewInfo = FixPlanner.run(testUnit, {
      aRef: const NullCheck(),
      bRef: const NullCheck(),
      findNode.binary('a + b'): const NullCheck()
    });
    expect(previewInfo, {
      aRef.offset: [const AddOpenParen()],
      aRef.end: [const AddBang()],
      bRef.end: [const AddBang(), const AddCloseParen(), const AddBang()]
    });
  }

  void test_nullCheck_no_parens() async {
    await resolveTestUnit('''
f(a) => a++;
''');
    var postfix = findNode.postfix('a++');
    var previewInfo = FixPlanner.run(testUnit, {postfix: const NullCheck()});
    expect(previewInfo, {
      postfix.end: [const AddBang()]
    });
  }

  void test_nullCheck_parens() async {
    await resolveTestUnit('''
f(a) => -a;
''');
    var prefix = findNode.prefix('-a');
    var previewInfo = FixPlanner.run(testUnit, {prefix: const NullCheck()});
    expect(previewInfo, {
      prefix.offset: [const AddOpenParen()],
      prefix.end: [const AddCloseParen(), const AddBang()]
    });
  }
}
