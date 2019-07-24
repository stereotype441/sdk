// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

void f() {}

tryCatch_all() {
  int v;
  try {
    f();
    v = 0;
  } catch (_) {
    v = 0;
  }
  v;
}

tryCatch_catch() {
  int v;
  try {
    // not assigned
  } catch (_) {
    v = 0;
  }
  /*unassigned*/ v;
}

tryCatch_try() {
  int v;
  try {
    v = 0;
  } catch (_) {
    // not assigned
  }
  /*unassigned*/ v;
}

tryCatchFinally_catch() {
  int v;
  try {
    // not assigned
  } catch (_) {
    v = 0;
  } finally {
    // not assigned
  }
  /*unassigned*/ v;
}

tryCatchFinally_finally() {
  int v;
  try {
    // not assigned
  } catch (_) {
    // not assigned
  } finally {
    v = 0;
  }
  v;
}

tryCatchFinally_try() {
  int v;
  try {
    v = 0;
  } catch (_) {
    // not assigned
  } finally {
    // not assigned
  }
  /*unassigned*/ v;
}

tryFinally_finally() {
  int v;
  try {
    // not assigned
  } finally {
    v = 0;
  }
  v;
}

tryFinally_try() {
  int v;
  try {
    v = 0;
  } finally {
    // not assigned
  }
  v;
}
