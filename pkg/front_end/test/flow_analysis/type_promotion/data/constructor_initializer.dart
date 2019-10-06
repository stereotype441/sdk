// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class C {
  int y;
  C.normalInitializer(Object x)
  : y = x is int ? /*int*/x : throw 'foo' {
    /*int*/x;
  }
  C.assertInitializer(Object x)
  : y = 0,
  assert((x is int ? /*int*/x : throw 'foo') == 0) {
    // Note: not promoted because the assertion doesn't execute in release mode.
    /*int*/x;
  }
}
