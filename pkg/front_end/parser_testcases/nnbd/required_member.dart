main() {
  dynamic foo = new X();
  var bar = foo.required;
  required();
  bar();
  new X().required();
  new Y().required;
}

required() {
  print("hello");
}

class X {
  required() {
    print("hello");
  }
}

class Y {
  int required = 42;
}
