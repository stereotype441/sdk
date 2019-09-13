// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/generated/source.dart';

abstract class NullabilityMigrationInstrumentation {
  void explicitTypeNullability(Source source, TypeAnnotation node, NullabilityNode node);

  void implicitTypeNullability()
}