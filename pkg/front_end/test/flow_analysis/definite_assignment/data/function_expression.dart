// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

closure_read() {
  int v1, v2;
  
  v1 = 0;
  
  [0, 1, 2].forEach((t) {
    v1;
    /*unassigned*/ v2;
  });
}

closure_write() {
  int v;
  
  [0, 1, 2].forEach((t) {
    v = t;
  });

  /*unassigned*/ v;
}

localFunction_local() {
  int v;

  v = 0;

  void f() {
    int v; // 1
    /*unassigned*/ v;
  }
}

localFunction_local2() {
  int v1;

  v1 = 0;

  void f() {
    int v2, v3;
    v2 = 0;
    v1;
    v2;
    /*unassigned*/ v3;
  }
}

localFunction_read() {
  int v1, v2, v3;

  v1 = 0;

  void f() {
    v1;
    /*unassigned*/ v2;
  }

  v2 = 0;
}

localFunction_write() {
  int v;

  void f() {
    v = 0;
  }

  /*unassigned*/ v;
}
