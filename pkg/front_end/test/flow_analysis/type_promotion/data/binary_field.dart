// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class C {
  static bool x1 = y is! int || /*int*/ y.isEven;
  bool x2 = y is! int || /*int*/ y.isEven;
}
num y = 1.0;
