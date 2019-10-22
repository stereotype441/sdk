// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class C {
  int methodReturningInt([value]) => 0;
  void set setter(value) {}
  C operator[](index) => this;
  void operator[]=(index, value) {}
  C methodReturningC() => this;
  C? methodReturningNullableC() => this;
  C get getterReturningC => this;
  C? get getterReturningNullableC => this;
}

class D {
  void set setter(value) {}
  D? operator[](index) => this;
  void operator[]=(index, value) {}
  int methodReturningInt([value]) => 0;
}

void methodCall(C? c) {
  c?.methodReturningInt(/*nonNullable*/ c);
}

void setterCall(C? c) {
  c?.setter = /*nonNullable*/ c;
}

void indexGetterCall(C? c) {
  c?.[/*nonNullable*/ c];
}

void indexSetterCall(C? c) {
  c?.[/*nonNullable*/ c] = /*nonNullable*/ c;
}

void methodCall_nullShorting(C? c, D? d) {
  c?.methodReturningC().methodReturningInt(/*nonNullable*/ c);
  c?.methodReturningNullableC()?.methodReturningInt(/*nonNullable*/ c);
  c?.getterReturningC.methodReturningInt(/*nonNullable*/ c);
  c?.getterReturningNullableC?.methodReturningInt(/*nonNullable*/ c);
  c?.[0].methodReturningInt(/*nonNullable*/ c);
  d?.[0]?.methodReturningInt(/*nonNullable*/ d);
}

void setterCall_nullShorting(C? c, D? d) {
  c?.methodReturningC().setter = /*nonNullable*/ c;
  c?.methodReturningNullableC()?.setter = /*nonNullable*/ c;
  c?.getterReturningC.setter = /*nonNullable*/ c;
  c?.getterReturningNullableC?.setter = /*nonNullable*/ c;
  c?.[0].setter = /*nonNullable*/ c;
  d?.[0]?.setter = /*nonNullable*/ d;
}

void indexGetterCall_nullShorting(C? c, D? d) {
  c?.methodReturningC()[/*nonNullable*/ c];
  c?.methodReturningNullableC()?.[/*nonNullable*/ c];
  c?.getterReturningC[/*nonNullable*/ c];
  c?.getterReturningNullableC?.[/*nonNullable*/ c];
  c?.[0][/*nonNullable*/ c];
  d?.[0]?.[/*nonNullable*/ d];
}

void indexSetterCall_nullShorting(C? c, D? d) {
  c?.methodReturningC()[/*nonNullable*/ c] = /*nonNullable*/ c;
  c?.methodReturningNullableC()?.[/*nonNullable*/ c] = /*nonNullable*/ c;
  c?.getterReturningC[/*nonNullable*/ c] = /*nonNullable*/ c;
  c?.getterReturningNullableC?.[/*nonNullable*/ c] = /*nonNullable*/ c;
  c?.[0][/*nonNullable*/ c] = /*nonNullable*/ c;
  d?.[0]?.[/*nonNullable*/ d] = /*nonNullable*/ d;
}
