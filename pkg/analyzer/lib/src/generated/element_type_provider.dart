// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

class ElementTypeProvider {
  const ElementTypeProvider();

  List<ParameterElement> getExecutableParameters(ExecutableElement element) =>
      element.parameters;

  DartType getExecutableReturnType(FunctionTypedElement element) =>
      element.returnType;

  FunctionType getExecutableType(FunctionTypedElement element) => element.type;

  DartType getVariableType(VariableElement variable) => variable.type;
}
