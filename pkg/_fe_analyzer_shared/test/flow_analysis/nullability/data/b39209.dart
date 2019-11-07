propertyAccess(int? x) {
  x?..isEven..isEven;
}

methodCall(C? c) {
  c?..f(/*notNull*/ c)..f(/*notNull*/ c);
}

abstract class C {
  void f(argument);
}
