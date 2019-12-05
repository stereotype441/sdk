// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

class ElementTypeProvider {
  const ElementTypeProvider();

  DartType getElementReturnType(FunctionTypedElement element) =>
      element.returnType;
}
