// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class Class {}

main() {
  var o;
  // ignore: unused_local_variable
  /*as: Class*/ for (Class c
      in /*dynamic*/ o?. /*as: Iterable<dynamic>*/ /*dynamic*/ iterable) {}
}
