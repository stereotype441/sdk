// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;

main() {
  var inputPath = path.join(Directory.current.path, 'test', 'src', 'dart',
      'resolution', 'flow_analysis_test.dart');
  var input = File(inputPath).readAsStringSync();
  var parsed = parseString(content: input);
  parsed.unit.accept(TestTransformer());
}

class TestTransformer extends GeneralizingAstVisitor<void> {
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) {
      var name = node.methodName.name;
      if (name == 'assertNullable' ||
          name == 'assertNonNullable' ||
          name == 'assertNotPromoted' ||
          name == 'assertPromoted' ||
          name == 'verify') {
        return;
      }
    }
    return super.visitMethodInvocation(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    print(node.name.name);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    var s = node.stringValue;
    try {
      var parsed = parseString(content: s);
      print(parsed.unit);
    } catch (e) {
      print('Error parsing $s');
      rethrow;
    }
  }

  @override
  void visitUriBasedDirective(UriBasedDirective node) {}
}
