// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

localFunction_write() {
  late int v;

  void f() {
    v = 0;
  }

  /*unassigned*/ v;
}
