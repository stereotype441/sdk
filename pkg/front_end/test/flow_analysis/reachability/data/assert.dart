// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

assertFalse() {
  // Code following assert(false) is still reachable because
  // assertions are only checked in debug mode.
  assert(false);
  0;
}

assertThrow() {
  // Code following assert(throw ...) is still reachable because
  // assertions are only checked in debug mode.
  assert(throw 'foo');
  0;
}

assertThrowInString(bool b) {
  // Code following assert(..., throw ...) is still reachable because
  // assertions are only checked in debug mode.
  assert(b, throw 'foo');
  0;
}
