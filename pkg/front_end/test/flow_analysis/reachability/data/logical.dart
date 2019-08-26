// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

void logicalAnd_leftFalse(int x) {
  false && /*unreachable*/ (x == 1);
}

void logicalOr_leftTrue(int x) {
  true || /*unreachable*/ (x == 1);
}
