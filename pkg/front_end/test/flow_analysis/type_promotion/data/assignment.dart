// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

assignmentDepromotes(Object x) {
  if (x is String) {
    x = 42;
    x;
  }
}

assignmentDepromotes_partial(Object x) {
  if (x is num) {
    if (/*num*/x is int) {
      x = 42.0;
      /*num*/x;
    }
  }
}

assignmentPreservesPromotion(Object x) {
  if (x is num) {
    x = 42;
    /*num*/ x;
  }
}

compoundAssignmentDepromotes(Object x) {
  if (x is int) {
    /*int*/ x += 0.5;
    x;
  }
}

compoundAssignmentDepromotes_partial(Object x) {
  if (x is num) {
    if (/*num*/x is int) {
      /*int*/ x += 0.5;
      /*num*/ x;
    }
  }
}

compoundAssignmentPreservesPromotion(Object x) {
  if (x is num) {
    /*num*/ x += 0.5;
    /*num*/ x;
  }
}
