// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class C<T extends num> {
  void promotes(T t) {
    if (t is int) {
      /*T & int*/ t;
    }
  }

  void doesNotPromote(T t) {
    if (t is String) {
      t;
    }
  }
}
