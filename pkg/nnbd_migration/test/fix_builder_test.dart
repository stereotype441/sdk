// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/testing/test_type_provider.dart';
import 'package:analyzer/src/test_utilities/find_node.dart';
import 'package:analyzer/src/test_utilities/resource_provider_mixin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:nnbd_migration/instrumentation.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:nnbd_migration/nullability_state.dart';
import 'package:nnbd_migration/src/decorated_class_hierarchy.dart';
import 'package:nnbd_migration/src/decorated_type.dart';
import 'package:nnbd_migration/src/edge_builder.dart';
import 'package:nnbd_migration/src/edge_origin.dart';
import 'package:nnbd_migration/src/expression_checks.dart';
import 'package:nnbd_migration/src/fix_builder.dart';
import 'package:nnbd_migration/src/nullability_node.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test/test.dart';
import 'package:test/test.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FixBuilderTest);
  });
}

@reflectiveTest
class FixBuilderTest {
  String content;

  FindNode findNode;

  final fixBuilder = _FixBuilder();

  CompilationUnit unit;

  void checkResult(String expected) {
    var edits = fixBuilder.run(unit);
    expect(SourceEdit.applySequence(content, edits.reversed), expected);
  }

  void nullCheck(Expression expression) {
    fixBuilder._nullCheck.add(expression);
  }

  void parse(String content) {
    this.content = content;
    var parseResult = parseString(content: content);
    expect(parseResult.errors, isEmpty);
    findNode = FindNode(content, parseResult.unit);
    unit = parseResult.unit;
  }

  test_null_check_postfix() {
    parse('''
var x = y++;
''');
    nullCheck(findNode.simple('y').parent as Expression);
    checkResult('''
var x = y++!;
''');
  }

  test_null_check_simple() {
    parse('''
var x = y;
''');
    nullCheck(findNode.simple('y'));
    checkResult('''
var x = y!;
''');
  }
}

class _FixBuilder extends FixBuilder {
  final Map<IfStatement, IfBehavior> _ifBehavior = {};

  final Set<Expression> _nullCheck = {};

  @override
  IfBehavior getIfBehavior(IfStatement node) =>
      _ifBehavior[node] ?? IfBehavior.keepAll;

  @override
  bool needsNullCheck(Expression node) => _nullCheck.contains(node);
}
