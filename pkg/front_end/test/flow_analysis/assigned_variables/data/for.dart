// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/*member: cStyleWithDeclaration:declared={a, b, c, d, e}, assigned={a, b, c, d}*/
cStyleWithDeclaration(int a, int b, int c, int d) {
  /*assigned={b, c, d}*/ for (int e = (a = 0); (b = 0) != 0; c = 0) {
    d = 0;
  }
}
