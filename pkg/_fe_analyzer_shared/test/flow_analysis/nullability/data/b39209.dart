propertyGet(C? c) {
  c?..property.f(/*nonNullable*/ c)..method(/*nonNullable*/ c);
}

propertySet(C? c) {
  c?..property = /*nonNullable*/ c..method(/*nonNullable*/ c);
}

methodCall(C? c) {
  c?..method(/*nonNullable*/ c)..method(/*nonNullable*/ c);
}

indexGet(C? c) {
  c?..[/*nonNullable*/ c].f(/*nonNullable*/ c)..method(/*nonNullable*/ c);
}

indexSet(C? c) {
  c?..[/*nonNullable*/ c] = /*nonNullable*/ c..method(/*nonNullable*/ c);
}

abstract class C {
  dynamic get property;
  void set property(dynamic value);
  void method(dynamic argument);
  dynamic operator[](dynamic index);
  void operator[]=(dynamic index, dynamic value);
}
