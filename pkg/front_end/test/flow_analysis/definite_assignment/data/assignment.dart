// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

leftExpression() {
  List<int> v;
  /*unassigned*/ v[0] = (v = [1, 2])[1];
  v;
}

leftLocal_compound() {
  int v;
  /*unassigned*/ v += 1;
}

leftLocal_compound_assignInRight() {
  int v;
  /*unassigned*/ v += (v = /*unassigned*/ v);
}

leftLocal_pure_eq() {
  int v;
  v = 0;
}

leftLocal_pure_eq_self() {
  int v;
  v = /*unassigned*/ v;
}

leftLocal_pure_questionEq() {
  int v;
  /*unassigned*/ v ??= 0;
}

leftLocal_pure_questionEq_self() {
  int v;
  /*unassigned*/ v ??= v;
}
