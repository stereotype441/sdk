// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

ifNull_left() {
  int v;
  (v = 0) ?? 0;
  v;
}

ifNull_right(int a) {
  int v;
  a ?? (v = 0);
  /*unassigned*/ v;
}

logicalAnd_left(bool c) {
  int v;
  ((v = 0) >= 0) && c;
  v;
}

logicalAnd_right(bool c) {
  int v;
  c && ((v = 0) >= 0);
  /*unassigned*/ v;
}

logicalOr_left(bool c) {
  int v;
  ((v = 0) >= 0) || c;
  v;
}

logicalOr_right(bool c) {
  int v;
  c || ((v = 0) >= 0);
  /*unassigned*/ v;
}

plus_left() {
  int v;
  (v = 0) + 1;
  v;
}

plus_right() {
  int v;
  1 + (v = 0);
  v;
}

