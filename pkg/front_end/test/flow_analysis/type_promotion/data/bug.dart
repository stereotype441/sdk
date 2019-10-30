// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

f(Object x, bool b) {
  if (x is num) {
    if (x is int) {
      try {
        throw 'foo';
      } catch (e) {
        x = 1.5;
        if (b) throw 'baz';
        x = 0;
      } finally {
        x.isEven;
      }
    }
  }
}
