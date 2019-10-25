// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/*member: tryOn:assigned={x, y}*/
tryOn(int x, int y) {
  try /*stmt: assigned={x}*/ {
    x = 0;
  } on String {
    y = 0;
  }
}

/*member: tryCatch:assigned={x, y}*/
tryCatch(int x, int y) {
  try /*stmt: assigned={x}*/ {
    x = 0;
  } catch (e) {
    y = 0;
  }
}

/*member: tryOnCatch:assigned={x, y}*/
tryOnCatch(int x, int y) {
  try /*stmt: assigned={x}*/ {
    x = 0;
  } on String catch (e) {
    y = 0;
  }
}

/*member: tryCatchStackTrace:assigned={x, y}*/
tryCatchStackTrace(int x, int y) {
  try /*stmt: assigned={x}*/ {
    x = 0;
  } catch (e, st) {
    y = 0;
  }
}

/*member: tryOnCatchStackTrace:assigned={x, y}*/
tryOnCatchStackTrace(int x, int y) {
  try /*stmt: assigned={x}*/ {
    x = 0;
  } on String catch (e, st) {
    y = 0;
  }
}
