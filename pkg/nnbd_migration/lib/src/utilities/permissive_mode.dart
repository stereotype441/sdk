// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:nnbd_migration/nnbd_migration.dart';

mixin PermissiveModeVisitor<T> on GeneralizingAstVisitor<T> {
  NullabilityMigrationListener /*?*/ get listener;
  
  void reportExceptionsIfPermissive(void callback()) {
    if (listener != null) {
      try {
        return callback();
      } catch (exception, stackTrace) {
        _reportException(exception, stackTrace);
      }
    } else {
      callback();
    }
  }
  
  @override
  T visitNode(AstNode node) {
    if (listener != null) {
      try {
        return super.visitNode(node);
      } catch (exception, stackTrace) {
        _reportException(exception, stackTrace);
        return null;
      }
    } else {
      return super.visitNode(node);
    }
  }

  void _reportException(Object exception, StackTrace stackTrace) {
    listener.addDetail('''
$exception

$stackTrace''');
  }
}
