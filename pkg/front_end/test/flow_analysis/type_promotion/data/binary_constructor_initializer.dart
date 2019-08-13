// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class C {
  dynamic x;
  C(dynamic value);
  C.inRedirect(num n) : this(n is! int || /*int*/ n.isEven);
  C.inAssert(num n) : assert(n is! int || /*int*/ n.isEven);
  C.inInitializer(num n) : x = n is! int || /*int*/ n.isEven;
}
