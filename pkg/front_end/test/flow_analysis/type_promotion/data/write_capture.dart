// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

T f<T>(T x, void callback()) {
  callback();
  return x;
}

forElement(Object a, Object b, Object c, Object d, Object e, bool cond) {
  [
    for (var x = f(0, () {
      a = '';
    });
        cond;
        cond)
      [
        a is int ? a : null,
      ]
  ];
}

