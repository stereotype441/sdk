propertyAccess(int? x) {
  x?..isEven..isEven;
}

methodCall(C? c) {
  c?..f(/*nonNullable*/ c)..f(/*nonNullable*/ c);
}

abstract class C {
  void f(argument);
}
