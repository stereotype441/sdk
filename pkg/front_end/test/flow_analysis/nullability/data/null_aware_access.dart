// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class C {
  void set setter(value) {}
  C operator[](index) => this;
  void operator[]=(index, value) {}
  C get getterReturningC => this;
  C? get getterReturningNullableC => this;
}

class D {
  void set setter(value) {}
  D? operator[](index) => this;
  void operator[]=(index, value) {}
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

void setterCall_nullShorting(C? c, D? d) {
  c?.getterReturningC.setter = /*nonNullable*/ c;
  c?.getterReturningNullableC?.setter = /*nonNullable*/ c;
  c?.[0].setter = /*nonNullable*/ c;
  d?.[0]?.setter = /*nonNullable*/ d;
}

void indexGetterCall_nullShorting(C? c, D? d) {
  c?.getterReturningC[/*nonNullable*/ c];
  c?.getterReturningNullableC?.[/*nonNullable*/ c];
  c?.[0][/*nonNullable*/ c];
  d?.[0]?.[/*nonNullable*/ d];
}

void indexSetterCall_nullShorting(C? c, D? d) {
  c?.getterReturningC[/*nonNullable*/ c] = /*nonNullable*/ c;
  c?.getterReturningNullableC?.[/*nonNullable*/ c] = /*nonNullable*/ c;
  c?.[0][/*nonNullable*/ c] = /*nonNullable*/ c;
  d?.[0]?.[/*nonNullable*/ d] = /*nonNullable*/ d;
}

void cascaded(C? c) {
  // Cascaded invocations act on an invisible temporary variable that
  // holds the result of evaluating the cascade target.  So
  // effectively, no promotion happens (because there is no way to
  // observe a change to the type of that variable).
  c?..setter = c;
  c?..[c];
  c?..[c] = c;
}
