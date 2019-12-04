// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:_fe_analyzer_shared/src/flow_analysis/flow_analysis.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Hooks used by resolution to communicate with the migration engine.
abstract class MigrationResolutionHooks {
  DartType getElementReturnType(FunctionTypedElement element);

  DartType getVariableType(VariableElement variable);

  DartType modifyExpressionType(Expression expression, DartType dartType);

  void setFlowAnalysis(
      FlowAnalysis<AstNode, Statement, Expression, PromotableElement, DartType>
          flowAnalysis);
}
