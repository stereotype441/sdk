// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

void if_condition(bool b) {
  if (b) {
    1;
  } else {
    2;
  }
  3;
}

void if_false_then_else() {
  if (false) /*stmt: unreachable*/ {
    1;
  } else {
  }
  3;
}

/*member: if_true_return:doesNotComplete*/
void if_true_return() {
  1;
  if (true) {
    return;
  }
  /*stmt: unreachable*/ 2;
}

void if_true_then_else() {
  if (true) {
  } else /*stmt: unreachable*/ {
    2;
  }
  3;
}

