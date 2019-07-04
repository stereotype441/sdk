List<List<Object>> testData = [
  [
    "void f(int x) {\n  if (x != null) return;\n  x; // 1\n  x = 0;\n  x; // 2\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(NotEq(GetVariable(x), NullLiteral()), Return()), (x0 = GetVariable(x)), SetVariable(x, Int(0)), (x1 = GetVariable(x))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(int x) {\n  if (x == null) return;\n  x; // 1\n  x = null;\n  x; // 2\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Eq(GetVariable(x), NullLiteral()), Return()), (x0 = GetVariable(x)), SetVariable(x, NullLiteral()), (x1 = GetVariable(x))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a == null) return;\n  a; // 1\n  a = b;\n  a; // 2\n}\n",
    "GetVariable a0;\nvar a = Param(InterfaceType(\"int\"), \"a\");\nvar b = Param(InterfaceType(\"int\"), \"b\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [a, b])..body = Block([If(Eq(GetVariable(a), NullLiteral()), Return()), (a0 = GetVariable(a)), SetVariable(a, GetVariable(b)), GetVariable(a)])]))",
    {
      "a; // 1": "a0"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a != null) return;\n  a; // 1\n  a = b;\n  a; // 2\n}\n",
    "GetVariable a0;\nvar a = Param(InterfaceType(\"int\"), \"a\");\nvar b = Param(InterfaceType(\"int\"), \"b\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [a, b])..body = Block([If(NotEq(GetVariable(a), NullLiteral()), Return()), (a0 = GetVariable(a)), SetVariable(a, GetVariable(b)), GetVariable(a)])]))",
    {
      "a; // 1": "a0"
    }
  ],
  [
    "void f(int x) {\n  x == null && x.isEven;\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([And(Eq(GetVariable(x), NullLiteral()), PropertyGet((x0 = GetVariable(x)), \"isEven\"))])]))",
    {
      "x.isEven": "x0"
    }
  ],
  [
    "void f(int x) {\n  x == null || x.isEven;\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Or(Eq(GetVariable(x), NullLiteral()), PropertyGet((x0 = GetVariable(x)), \"isEven\"))])]))",
    {
      "x.isEven": "x0"
    }
  ],
  [
    "class C {\n  C(int x) {\n    if (x == null) {\n      x; // 1\n    } else {\n      x; // 2\n    }\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Class(\"C\", [Constructor(null, [x], Block([If(Eq(GetVariable(x), NullLiteral()), Block([(x0 = GetVariable(x))]), Block([(x1 = GetVariable(x))]))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a == null) {\n    a; // 1\n    if (b == null) return;\n    b; // 2\n  } else {\n    a; // 3\n    if (b == null) return;\n    b; // 4\n  }\n  a; // 5\n  b; // 6\n}\n",
    "GetVariable a0;\nGetVariable b0;\nGetVariable a1;\nGetVariable b1;\nGetVariable b2;\nvar a = Param(InterfaceType(\"int\"), \"a\");\nvar b = Param(InterfaceType(\"int\"), \"b\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [a, b])..body = Block([If(Eq(GetVariable(a), NullLiteral()), Block([(a0 = GetVariable(a)), If(Eq(GetVariable(b), NullLiteral()), Return()), (b0 = GetVariable(b))]), Block([(a1 = GetVariable(a)), If(Eq(GetVariable(b), NullLiteral()), Return()), (b1 = GetVariable(b))])), GetVariable(a), (b2 = GetVariable(b))])]))",
    {
      "a; // 1": "a0",
      "b; // 2": "b0",
      "a; // 3": "a1",
      "b; // 4": "b1",
      "b; // 6": "b2"
    }
  ],
  [
    "void f(int x) {\n  if (null != x) return;\n  x; // 1\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(NotEq(NullLiteral(), GetVariable(x)), Return()), (x0 = GetVariable(x))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(int x) {\n  if (x != null) return;\n  x; // 1\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(NotEq(GetVariable(x), NullLiteral()), Return()), (x0 = GetVariable(x))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(int x) {\n  if (null == x) return;\n  x; // 1\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Eq(NullLiteral(), GetVariable(x)), Return()), (x0 = GetVariable(x))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(int x) {\n  if (x == null) return;\n  x; // 1\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Eq(GetVariable(x), NullLiteral()), Return()), (x0 = GetVariable(x))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(int x) {\n  if (x == null) {\n    x; // 1\n  } else {\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Eq(GetVariable(x), NullLiteral()), Block([(x0 = GetVariable(x))]), Block([(x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "class C {\n  void f(int x) {\n    if (x == null) {\n      x; // 1\n    } else {\n      x; // 2\n    }\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Class(\"C\", [Method(InterfaceType(\"void\"), \"f\", [x], Block([If(Eq(GetVariable(x), NullLiteral()), Block([(x0 = GetVariable(x))]), Block([(x1 = GetVariable(x))]))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "f(int a, int b) {\n  localFunction() {\n    a = b;\n  }\n\n  if (a == null) {\n    a; // 1\n    localFunction();\n    a; // 2\n  }\n}\n",
    "var a = Param(InterfaceType(\"int\"), \"a\");\nvar b = Param(InterfaceType(\"int\"), \"b\");\nvar localFunction = Func(null, \"localFunction\", []);\nawait trackCode(Unit([Func(null, \"f\", [a, b])..body = Block([localFunction..body = Block([SetVariable(a, GetVariable(b))]), If(Eq(GetVariable(a), NullLiteral()), Block([GetVariable(a), StaticCall(localFunction, []), GetVariable(a)]))])]))",
    {}
  ],
  [
    "void f(int x) {\n  try {\n    if (x == null) return;\n    x; // 1\n  } finally {\n    x; // 2\n  }\n  x; // 3\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Try(Block([If(Eq(GetVariable(x), NullLiteral()), Return()), (x0 = GetVariable(x))]), [], Block([GetVariable(x)])), (x1 = GetVariable(x))])]))",
    {
      "x; // 1": "x0",
      "x; // 3": "x1"
    }
  ],
  [
    "void f(int x) {\n  try {\n    x; // 1\n  } finally {\n    if (x == null) return;\n    x; // 2\n  }\n  x; // 3\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Try(Block([GetVariable(x)]), [], Block([If(Eq(GetVariable(x), NullLiteral()), Return()), (x0 = GetVariable(x))])), (x1 = GetVariable(x))])]))",
    {
      "x; // 2": "x0",
      "x; // 3": "x1"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a != null) return;\n  try {\n    a; // 1\n    a = b;\n    a; // 2\n  } finally {\n    a; // 3\n  }\n  a; // 4\n}\n",
    "GetVariable a0;\nvar a = Param(InterfaceType(\"int\"), \"a\");\nvar b = Param(InterfaceType(\"int\"), \"b\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [a, b])..body = Block([If(NotEq(GetVariable(a), NullLiteral()), Return()), Try(Block([(a0 = GetVariable(a)), SetVariable(a, GetVariable(b)), GetVariable(a)]), [], Block([GetVariable(a)])), GetVariable(a)])]))",
    {
      "a; // 1": "a0"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a == null) return;\n  try {\n    a; // 1\n    a = b;\n    a; // 2\n  } finally {\n    a; // 3\n  }\n  a; // 4\n}\n",
    "GetVariable a0;\nvar a = Param(InterfaceType(\"int\"), \"a\");\nvar b = Param(InterfaceType(\"int\"), \"b\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [a, b])..body = Block([If(Eq(GetVariable(a), NullLiteral()), Return()), Try(Block([(a0 = GetVariable(a)), SetVariable(a, GetVariable(b)), GetVariable(a)]), [], Block([GetVariable(a)])), GetVariable(a)])]))",
    {
      "a; // 1": "a0"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a == null) return;\n  try {\n    a; // 1\n  } finally {\n    a; // 2\n    a = b;\n    a; // 3\n  }\n  a; // 4\n}\n",
    "GetVariable a0;\nGetVariable a1;\nvar a = Param(InterfaceType(\"int\"), \"a\");\nvar b = Param(InterfaceType(\"int\"), \"b\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [a, b])..body = Block([If(Eq(GetVariable(a), NullLiteral()), Return()), Try(Block([(a0 = GetVariable(a))]), [], Block([(a1 = GetVariable(a)), SetVariable(a, GetVariable(b)), GetVariable(a)])), GetVariable(a)])]))",
    {
      "a; // 1": "a0",
      "a; // 2": "a1"
    }
  ],
  [
    "void f(int x) {\n  while (x == null) {\n    x; // 1\n  }\n  x; // 2\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([While(Eq(GetVariable(x), NullLiteral()), Block([(x0 = GetVariable(x))])), (x1 = GetVariable(x))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(int x) {\n  while (x != null) {\n    x; // 1\n  }\n  x; // 2\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([While(NotEq(GetVariable(x), NullLiteral()), Block([(x0 = GetVariable(x))])), (x1 = GetVariable(x))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f() {\n  false ? 1 : 2;\n}\n",
    "Int value_1;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Conditional(Bool(false), (value_1 = Int(1)), Int(2))])]))",
    {
      "1": "value_1"
    }
  ],
  [
    "void f() {\n  true ? 1 : 2;\n}\n",
    "Int value_2;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Conditional(Bool(true), Int(1), (value_2 = Int(2)))])]))",
    {
      "2": "value_2"
    }
  ],
  [
    "void f() {\n  do {\n    1;\n  } while (false);\n  2;\n}\n",
    "await trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Do(Block([Int(1)]), Bool(false)), Int(2)])]))",
    {}
  ],
  [
    "void f() { // f\n  do {\n    1;\n  } while (true);\n  2;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = (statement0 = Block([Do(Block([Int(1)]), Bool(true)), (statement = Int(2))]))]))",
    {
      "2;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f(bool b, int i) { // f\n  return;\n  Object _;\n  do {} while (b);\n  for (;;) {}\n  for (_ in []) {}\n  if (b) {}\n  switch (i) {}\n  try {} finally {}\n  while (b) {}\n}\n",
    "Locals statement;\nDo statement0;\nForExpr statement1;\nForEachIdentifier statement2;\nIf statement3;\nSwitch statement4;\nTry statement5;\nWhile statement6;\nStatement statement7;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar i = Param(InterfaceType(\"int\"), \"i\");\nvar _ = Local(\"_\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, i])..body = (statement7 = Block([Return(), (statement = Locals(InterfaceType(\"Object\"), [_])), (statement0 = Do(Block([]), GetVariable(b))), (statement1 = ForExpr(null, null, [], Block([]))), (statement2 = ForEachIdentifier(_, ListLiteral(null, []), Block([]))), (statement3 = If(GetVariable(b), Block([]))), (statement4 = Switch(GetVariable(i), [])), (statement5 = Try(Block([]), [], Block([]))), (statement6 = While(GetVariable(b), Block([])))]))]))",
    {
      "Object _": "statement",
      "do {}": "statement0",
      "for (;;": "statement1",
      "for (_": "statement2",
      "if (b)": "statement3",
      "switch (i)": "statement4",
      "try {": "statement5",
      "while (b) {}": "statement6",
      "{ // f": "statement7"
    }
  ],
  [
    "void f() { // f\n  for (; true;) {\n    1;\n  }\n  2;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = (statement0 = Block([ForExpr(null, Bool(true), [], Block([Int(1)])), (statement = Int(2))]))]))",
    {
      "2;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f() { // f\n  for (;;) {\n    1;\n  }\n  2;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = (statement0 = Block([ForExpr(null, null, [], Block([Int(1)])), (statement = Int(2))]))]))",
    {
      "2;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f() {\n  Object _;\n  for (_ in [0, 1, 2]) {\n    1;\n    return;\n  }\n  2;\n}\n",
    "var _ = Local(\"_\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Locals(InterfaceType(\"Object\"), [_]), ForEachIdentifier(_, ListLiteral(null, [Int(0), Int(1), Int(2)]), Block([Int(1), Return()])), Int(2)])]))",
    {}
  ],
  [
    "int f() { // f\n  return 42;\n}\n",
    "Statement statement;\nawait trackCode(Unit([Func(InterfaceType(\"int\"), \"f\", [])..body = (statement = Block([Return(Int(42))]))]))",
    {
      "{ // f": "statement"
    }
  ],
  [
    "void f() {\n  1;\n}\n",
    "await trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Int(1)])]))",
    {}
  ],
  [
    "void f(bool b) {\n  if (b) {\n    1;\n  } else {\n    2;\n  }\n  3;\n}\n",
    "var b = Param(InterfaceType(\"bool\"), \"b\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b])..body = Block([If(GetVariable(b), Block([Int(1)]), Block([Int(2)])), Int(3)])]))",
    {}
  ],
  [
    "void f() {\n  if (false) { // 1\n    1;\n  } else { // 2\n  }\n  3;\n}\n",
    "Block statement;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([If(Bool(false), (statement = Block([Int(1)])), Block([])), Int(3)])]))",
    {
      "{ // 1": "statement"
    }
  ],
  [
    "void f() { // f\n  1;\n  if (true) {\n    return;\n  }\n  2;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = (statement0 = Block([Int(1), If(Bool(true), Block([Return()])), (statement = Int(2))]))]))",
    {
      "2;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f() {\n  if (true) { // 1\n  } else { // 2\n    2;\n  }\n  3;\n}\n",
    "Block statement;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([If(Bool(true), Block([]), (statement = Block([Int(2)]))), Int(3)])]))",
    {
      "{ // 2": "statement"
    }
  ],
  [
    "void f(int x) {\n  false && (x == 1);\n}\n",
    "Expression expression;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([And(Bool(false), (expression = Parens(Eq(GetVariable(x), Int(1)))))])]))",
    {
      "(x == 1)": "expression"
    }
  ],
  [
    "void f(int x) {\n  true || (x == 1);\n}\n",
    "Expression expression;\nvar x = Param(InterfaceType(\"int\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Or(Bool(true), (expression = Parens(Eq(GetVariable(x), Int(1)))))])]))",
    {
      "(x == 1)": "expression"
    }
  ],
  [
    "void f(bool b, int i) {\n  switch (i) {\n    case 1:\n      1;\n      if (b) {\n        return;\n      } else {\n        return;\n      }\n      2;\n  }\n  3;\n}\n",
    "Expression statement;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar i = Param(InterfaceType(\"int\"), \"i\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, i])..body = Block([Switch(GetVariable(i), [Case([], Int(1), [Int(1), If(GetVariable(b), Block([Return()]), Block([Return()])), (statement = Int(2))])]), Int(3)])]))",
    {
      "2;": "statement"
    }
  ],
  [
    "void f() {\n  try {\n    1;\n  } catch (_) {\n    2;\n  }\n  3;\n}\n",
    "await trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Try(Block([Int(1)]), [Catch(CatchVariable(\"_\"), Block([Int(2)]))]), Int(3)])]))",
    {}
  ],
  [
    "void f() {\n  try {\n    1;\n    return;\n    2;\n  } catch (_) {\n    3;\n  }\n  4;\n}\n",
    "Expression statement;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Try(Block([Int(1), Return(), (statement = Int(2))]), [Catch(CatchVariable(\"_\"), Block([Int(3)]))]), Int(4)])]))",
    {
      "2;": "statement"
    }
  ],
  [
    "void f() {\n  try {\n    1;\n  } catch (_) {\n    2;\n    return;\n    3;\n  }\n  4;\n}\n",
    "Expression statement;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Try(Block([Int(1)]), [Catch(CatchVariable(\"_\"), Block([Int(2), Return(), (statement = Int(3))]))]), Int(4)])]))",
    {
      "3;": "statement"
    }
  ],
  [
    "void f() {\n  try {\n    1;\n    return;\n  } catch (_) {\n    2;\n  } finally {\n    3;\n  }\n  4;\n}\n",
    "await trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Try(Block([Int(1), Return()]), [Catch(CatchVariable(\"_\"), Block([Int(2)]))], Block([Int(3)])), Int(4)])]))",
    {}
  ],
  [
    "void f() { // f\n  try {\n    1;\n    return;\n  } catch (_) {\n    2;\n    return;\n  } finally {\n    3;\n  }\n  4;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = (statement0 = Block([Try(Block([Int(1), Return()]), [Catch(CatchVariable(\"_\"), Block([Int(2), Return()]))], Block([Int(3)])), (statement = Int(4))]))]))",
    {
      "4;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f() {\n  try {\n    1;\n  } catch (_) {\n    2;\n    return;\n  } finally {\n    3;\n  }\n  4;\n}\n",
    "await trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Try(Block([Int(1)]), [Catch(CatchVariable(\"_\"), Block([Int(2), Return()]))], Block([Int(3)])), Int(4)])]))",
    {}
  ],
  [
    "void f() { // f\n  try {\n    1;\n    return;\n  } finally {\n    2;\n  }\n  3;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = (statement0 = Block([Try(Block([Int(1), Return()]), [], Block([Int(2)])), (statement = Int(3))]))]))",
    {
      "3;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f() {\n  while (false) { // 1\n    1;\n  }\n  2;\n}\n",
    "Block statement;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([While(Bool(false), (statement = Block([Int(1)]))), Int(2)])]))",
    {
      "{ // 1": "statement"
    }
  ],
  [
    "void f() { // f\n  while (true) {\n    1;\n  }\n  2;\n  3;\n}\n",
    "Expression statement;\nExpression statement0;\nStatement statement1;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = (statement1 = Block([While(Bool(true), Block([Int(1)])), (statement = Int(2)), (statement0 = Int(3))]))]))",
    {
      "2;": "statement",
      "3;": "statement0",
      "{ // f": "statement1"
    }
  ],
  [
    "void f() {\n  while (true) {\n    1;\n    break;\n    2;\n  }\n  3;\n}\n",
    "Expression statement;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([While(Bool(true), Block([Int(1), Break(), (statement = Int(2))])), Int(3)])]))",
    {
      "2;": "statement"
    }
  ],
  [
    "void f(bool b) {\n  while (true) {\n    1;\n    if (b) break;\n    2;\n  }\n  3;\n}\n",
    "var b = Param(InterfaceType(\"bool\"), \"b\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b])..body = Block([While(Bool(true), Block([Int(1), If(GetVariable(b), Break()), Int(2)])), Int(3)])]))",
    {}
  ],
  [
    "void f() { // f\n  while (true) {\n    1;\n    continue;\n    2;\n  }\n  3;\n}\n",
    "Expression statement;\nExpression statement0;\nStatement statement1;\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = (statement1 = Block([While(Bool(true), Block([Int(1), Continue(), (statement = Int(2))])), (statement0 = Int(3))]))]))",
    {
      "2;": "statement",
      "3;": "statement0",
      "{ // f": "statement1"
    }
  ],
  [
    "f(Object x) {\n  if (x is String) {\n    x = 42;\n    x; // 1\n  }\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(null, \"f\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([SetVariable(x, Int(42)), (x0 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(Object x) {\n  ((x is num) || (throw 1)) ?? ((x is int) || (throw 2));\n  x; // 1\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([IfNull(Parens(Or(Parens(Is(GetVariable(x), InterfaceType(\"num\"))), Parens(Throw(Int(1))))), Parens(Or(Parens(Is(GetVariable(x), InterfaceType(\"int\"))), Parens(Throw(Int(2)))))), (x0 = GetVariable(x))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(Object x, Object y, Object z) {\n  if (x is int) {\n    x; // 1\n    y ?? (x = z);\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nvar y = Param(InterfaceType(\"Object\"), \"y\");\nvar z = Param(InterfaceType(\"Object\"), \"z\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x, y, z])..body = Block([If(Is(GetVariable(x), InterfaceType(\"int\")), Block([(x0 = GetVariable(x)), IfNull(GetVariable(y), Parens(SetVariable(x, GetVariable(z)))), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  b ? ((x is num) || (throw 1)) : ((x is int) || (throw 2));\n  x; // 1\n}\n",
    "GetVariable x0;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([Conditional(GetVariable(b), Parens(Or(Parens(Is(GetVariable(x), InterfaceType(\"num\"))), Parens(Throw(Int(1))))), Parens(Or(Parens(Is(GetVariable(x), InterfaceType(\"int\"))), Parens(Throw(Int(2)))))), (x0 = GetVariable(x))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(bool b, Object x) {\n  b ? 0 : ((x is int) || (throw 2));\n  x; // 1\n}\n",
    "GetVariable x0;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([Conditional(GetVariable(b), Int(0), Parens(Or(Parens(Is(GetVariable(x), InterfaceType(\"int\"))), Parens(Throw(Int(2)))))), (x0 = GetVariable(x))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(bool b, Object x) {\n  b ? ((x is num) || (throw 1)) : 0;\n  x; // 1\n}\n",
    "GetVariable x0;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([Conditional(GetVariable(b), Parens(Or(Parens(Is(GetVariable(x), InterfaceType(\"num\"))), Parens(Throw(Int(1))))), Int(0)), (x0 = GetVariable(x))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(Object x) {\n  do {\n    x; // 1\n    x = '';\n  } while (x is! String);\n  x; // 2\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Do(Block([(x0 = GetVariable(x)), SetVariable(x, StringLiteral(\"\"))]), Is(GetVariable(x), InterfaceType(\"String\"))), (x1 = GetVariable(x))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  do {\n    x; // 1\n  } while (x is String);\n  x; // 2\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Do(Block([(x0 = GetVariable(x))]), Is(GetVariable(x), InterfaceType(\"String\"))), (x1 = GetVariable(x))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    do {\n      x; // 1\n    } while (b);\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([Do(Block([(x0 = GetVariable(x))]), GetVariable(b)), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    do {\n      x; // 1\n      x = x.length;\n    } while (b);\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([Do(Block([(x0 = GetVariable(x)), SetVariable(x, PropertyGet(GetVariable(x), \"length\"))]), GetVariable(b)), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    do {\n      x; // 1\n      x = x.length;\n    } while (x != 0);\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [Param(InterfaceType(\"bool\"), \"b\"), x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([Do(Block([(x0 = GetVariable(x)), SetVariable(x, PropertyGet(GetVariable(x), \"length\"))]), NotEq((x1 = GetVariable(x)), Int(0))), (x2 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x != 0": "x1",
      "x; // 2": "x2"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    do {\n      x; // 1\n    } while ((x = 1) != 0);\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [Param(InterfaceType(\"bool\"), \"b\"), x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([Do(Block([(x0 = GetVariable(x))]), NotEq(Parens(SetVariable(x, Int(1))), Int(0))), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    for (; b;) {\n      x; // 1\n    }\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([ForExpr(null, GetVariable(b), [], Block([(x0 = GetVariable(x))])), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    for (; b;) {\n      x; // 1\n      x = 42;\n    }\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([ForExpr(null, GetVariable(b), [], Block([(x0 = GetVariable(x)), SetVariable(x, Int(42))])), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    for (; (x = 42) > 0;) {\n      x; // 1\n    }\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([ForExpr(null, Gt(Parens(SetVariable(x, Int(42))), Int(0)), [], Block([(x0 = GetVariable(x))])), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    for (; b; x = 42) {\n      x; // 1\n    }\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([ForExpr(null, GetVariable(b), [SetVariable(x, Int(42))], Block([(x0 = GetVariable(x))])), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  Object v1;\n  if (x is String) {\n    for (var _ in (v1 = [0, 1, 2])) {\n      x; // 1\n      x = 42;\n    }\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nvar v1 = Local(\"v1\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Locals(InterfaceType(\"Object\"), [v1]), If(Is(GetVariable(x), InterfaceType(\"String\")), Block([ForEachDeclared(ForEachVariable(null, \"_\"), Parens(SetVariable(v1, ListLiteral(null, [Int(0), Int(1), Int(2)]))), Block([(x0 = GetVariable(x)), SetVariable(x, Int(42))])), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f() {\n  void g(Object x) {\n    if (x is String) {\n      x; // 1\n    }\n    x = 42;\n  }\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Func(InterfaceType(\"void\"), \"g\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([(x0 = GetVariable(x))])), SetVariable(x, Int(42))])])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f() {\n  void g(Object x) {\n    if (x is String) {\n      x; // 1\n    }\n    \n    void h() {\n      x = 42;\n    }\n  }\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [])..body = Block([Func(InterfaceType(\"void\"), \"g\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([(x0 = GetVariable(x))])), Func(InterfaceType(\"void\"), \"h\", [])..body = Block([SetVariable(x, Int(42))])])])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(Object x) {\n  void Function() g;\n  \n  if (x is String) {\n    x; // 1\n\n    g = () {\n      x; // 2\n    };\n  }\n\n  x = 42;\n  x; // 3\n  g();\n}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nvar g = Local(\"g\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Locals(FunctionType(InterfaceType(\"void\"), []), [g]), If(Is(GetVariable(x), InterfaceType(\"String\")), Block([(x0 = GetVariable(x)), SetVariable(g, Closure([], Block([(x1 = GetVariable(x))])))])), SetVariable(x, Int(42)), (x2 = GetVariable(x)), CallVariable(g, [])])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "main(bool b, Object v) {\n  if (b) {\n    v is int || (throw 1);\n  } else {\n    v is String || (throw 2);\n  }\n  v; // 3\n}\n",
    "GetVariable v0;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar v = Param(InterfaceType(\"Object\"), \"v\");\nawait trackCode(Unit([Func(null, \"main\", [b, v])..body = Block([If(GetVariable(b), Block([Or(Is(GetVariable(v), InterfaceType(\"int\")), Parens(Throw(Int(1))))]), Block([Or(Is(GetVariable(v), InterfaceType(\"String\")), Parens(Throw(Int(2))))])), (v0 = GetVariable(v))])]))",
    {
      "v; // 3": "v0"
    }
  ],
  [
    "f(bool b, Object v) {\n  if (b ? (v is! int) : (v is! num)) {\n    v; // 1\n  } else {\n    v; // 2\n  }\n  v; // 3\n}\n",
    "GetVariable v0;\nGetVariable v1;\nGetVariable v2;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar v = Param(InterfaceType(\"Object\"), \"v\");\nawait trackCode(Unit([Func(null, \"f\", [b, v])..body = Block([If(Conditional(GetVariable(b), Parens(Is(GetVariable(v), InterfaceType(\"int\"))), Parens(Is(GetVariable(v), InterfaceType(\"num\")))), Block([(v0 = GetVariable(v))]), Block([(v1 = GetVariable(v))])), (v2 = GetVariable(v))])]))",
    {
      "v; // 1": "v0",
      "v; // 2": "v1",
      "v; // 3": "v2"
    }
  ],
  [
    "f(bool b, Object v) {\n  if (b ? (v is int) : (v is num)) {\n    v; // 1\n  } else {\n    v; // 2\n  }\n  v; // 3\n}\n",
    "GetVariable v0;\nGetVariable v1;\nGetVariable v2;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar v = Param(InterfaceType(\"Object\"), \"v\");\nawait trackCode(Unit([Func(null, \"f\", [b, v])..body = Block([If(Conditional(GetVariable(b), Parens(Is(GetVariable(v), InterfaceType(\"int\"))), Parens(Is(GetVariable(v), InterfaceType(\"num\")))), Block([(v0 = GetVariable(v))]), Block([(v1 = GetVariable(v))])), (v2 = GetVariable(v))])]))",
    {
      "v; // 1": "v0",
      "v; // 2": "v1",
      "v; // 3": "v2"
    }
  ],
  [
    "main(v) {\n  if (v is! String) {\n    v; // 1\n  } else {\n    v; // 2\n  }\n  v; // 3\n}\n",
    "GetVariable v0;\nGetVariable v1;\nGetVariable v2;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([If(Is(GetVariable(v), InterfaceType(\"String\")), Block([(v0 = GetVariable(v))]), Block([(v1 = GetVariable(v))])), (v2 = GetVariable(v))])]))",
    {
      "v; // 1": "v0",
      "v; // 2": "v1",
      "v; // 3": "v2"
    }
  ],
  [
    "main(v) {\n  if (v is! String) return;\n  v; // ref\n}\n",
    "GetVariable v0;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([If(Is(GetVariable(v), InterfaceType(\"String\")), Return()), (v0 = GetVariable(v))])]))",
    {
      "v; // ref": "v0"
    }
  ],
  [
    "main(v) {\n  if (v is! String) throw 42;\n  v; // ref\n}\n",
    "GetVariable v0;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([If(Is(GetVariable(v), InterfaceType(\"String\")), Throw(Int(42))), (v0 = GetVariable(v))])]))",
    {
      "v; // ref": "v0"
    }
  ],
  [
    "main(v) {\n  if (v is String) {\n    v; // 1\n  } else {\n    v; // 2\n  }\n  v; // 3\n}\n",
    "GetVariable v0;\nGetVariable v1;\nGetVariable v2;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([If(Is(GetVariable(v), InterfaceType(\"String\")), Block([(v0 = GetVariable(v))]), Block([(v1 = GetVariable(v))])), (v2 = GetVariable(v))])]))",
    {
      "v; // 1": "v0",
      "v; // 2": "v1",
      "v; // 3": "v2"
    }
  ],
  [
    "f(Object x) {\n  if ((x is String) != 3) {\n    x; // 1\n  }\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(null, \"f\", [x])..body = Block([If(NotEq(Parens(Is(GetVariable(x), InterfaceType(\"String\"))), Int(3)), Block([(x0 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "main(v) {\n  if (!(v is String)) {\n    v; // 1\n  } else {\n    v; // 2\n  }\n  v; // 3\n}\n",
    "GetVariable v0;\nGetVariable v1;\nGetVariable v2;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([If(Not(Parens(Is(GetVariable(v), InterfaceType(\"String\")))), Block([(v0 = GetVariable(v))]), Block([(v1 = GetVariable(v))])), (v2 = GetVariable(v))])]))",
    {
      "v; // 1": "v0",
      "v; // 2": "v1",
      "v; // 3": "v2"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (b) {\n    if (x is! String) return;\n  }\n  x; // 1\n}\n",
    "GetVariable x0;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([If(GetVariable(b), Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Return())])), (x0 = GetVariable(x))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "main(v) {\n  v is String || (throw 42);\n  v; // ref\n}\n",
    "GetVariable v0;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([Or(Is(GetVariable(v), InterfaceType(\"String\")), Parens(Throw(Int(42)))), (v0 = GetVariable(v))])]))",
    {
      "v; // ref": "v0"
    }
  ],
  [
    "f(Object x) {\n  localFunction() {\n    x = 42;\n  }\n\n  if (x is String) {\n    localFunction();\n    x; // 1\n  }\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nvar localFunction = Func(null, \"localFunction\", []);\nawait trackCode(Unit([Func(null, \"f\", [x])..body = Block([localFunction..body = Block([SetVariable(x, Int(42))]), If(Is(GetVariable(x), InterfaceType(\"String\")), Block([StaticCall(localFunction, []), (x0 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "f(Object x) {\n  if (x is String) {\n    x; // 1\n  }\n\n  x = 42;\n}\n",
    "GetVariable x0;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(null, \"f\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([(x0 = GetVariable(x))])), SetVariable(x, Int(42))])]))",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(int e, Object x) {\n  if (x is String) {\n    switch (e) {\n      L: case 1:\n        x; // 1\n        break;\n      case 2: // no label\n        x; // 2\n        break;\n      case 3:\n        x = 42;\n        continue L;\n    }\n    x; // 3\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nvar e = Param(InterfaceType(\"int\"), \"e\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nvar L = Label(\"L\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [e, x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([Switch(GetVariable(e), [Case([L], Int(1), [(x0 = GetVariable(x)), Break()]), Case([], Int(2), [(x1 = GetVariable(x)), Break()]), Case([], Int(3), [SetVariable(x, Int(42)), Continue(L)])]), (x2 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  if (x is! String) return;\n  x; // 1\n  try {\n    x = 42;\n    g(); // might throw\n    if (x is! String) return;\n    x; // 2\n  } catch (_) {}\n  x; // 3\n}\n\nvoid g() {}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nvar g = Func(InterfaceType(\"void\"), \"g\", []);\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Return()), (x0 = GetVariable(x)), Try(Block([SetVariable(x, Int(42)), StaticCall(g, []), If(Is(GetVariable(x), InterfaceType(\"String\")), Return()), (x1 = GetVariable(x))]), [Catch(CatchVariable(\"_\"), Block([]))]), (x2 = GetVariable(x))]), g..body = Block([])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  try {\n    if (x is! String) return;\n    x; // 1\n  } catch (_) {}\n  x; // 2\n}\n\nvoid g() {}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Try(Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Return()), (x0 = GetVariable(x))]), [Catch(CatchVariable(\"_\"), Block([]))]), (x1 = GetVariable(x))]), Func(InterfaceType(\"void\"), \"g\", [])..body = Block([])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  try {\n    if (x is! String) return;\n    x; // 1\n  } catch (_) {\n    if (x is! String) return;\n    x; // 2\n  }\n  x; // 3\n}\n\nvoid g() {}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Try(Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Return()), (x0 = GetVariable(x))]), [Catch(CatchVariable(\"_\"), Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Return()), (x1 = GetVariable(x))]))]), (x2 = GetVariable(x))]), Func(InterfaceType(\"void\"), \"g\", [])..body = Block([])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  try {\n    if (x is! String) return;\n    x; // 1\n  } catch (_) {\n    x; // 2\n    rethrow;\n  }\n  x; // 3\n}\n\nvoid g() {}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Try(Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Return()), (x0 = GetVariable(x))]), [Catch(CatchVariable(\"_\"), Block([(x1 = GetVariable(x)), Rethrow()]))]), (x2 = GetVariable(x))]), Func(InterfaceType(\"void\"), \"g\", [])..body = Block([])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  try {\n  } catch (_) {\n    if (x is! String) return;\n    x; // 1\n  }\n  x; // 2\n}\n\nvoid g() {}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([Try(Block([]), [Catch(CatchVariable(\"_\"), Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Return()), (x0 = GetVariable(x))]))]), (x1 = GetVariable(x))]), Func(InterfaceType(\"void\"), \"g\", [])..body = Block([])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    try {\n      x; // 1\n    } catch (_) {\n      x; // 2\n    } finally {\n      x; // 3\n    }\n    x; // 4\n  }\n}\n\nvoid g() {}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nGetVariable x3;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([Try(Block([(x0 = GetVariable(x))]), [Catch(CatchVariable(\"_\"), Block([(x1 = GetVariable(x))]))], Block([(x2 = GetVariable(x))])), (x3 = GetVariable(x))]))]), Func(InterfaceType(\"void\"), \"g\", [])..body = Block([])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2",
      "x; // 4": "x3"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    try {\n      x; // 1\n      x = 42;\n      g();\n    } catch (_) {\n      x; // 2\n    } finally {\n      x; // 3\n    }\n    x; // 4\n  }\n}\n\nvoid g() {}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nGetVariable x3;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nvar g = Func(InterfaceType(\"void\"), \"g\", []);\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([Try(Block([(x0 = GetVariable(x)), SetVariable(x, Int(42)), StaticCall(g, [])]), [Catch(CatchVariable(\"_\"), Block([(x1 = GetVariable(x))]))], Block([(x2 = GetVariable(x))])), (x3 = GetVariable(x))]))]), g..body = Block([])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2",
      "x; // 4": "x3"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    try {\n      x; // 1\n    } catch (_) {\n      x; // 2\n      x = 42;\n    } finally {\n      x; // 3\n    }\n    x; // 4\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nGetVariable x3;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([Try(Block([(x0 = GetVariable(x))]), [Catch(CatchVariable(\"_\"), Block([(x1 = GetVariable(x)), SetVariable(x, Int(42))]))], Block([(x2 = GetVariable(x))])), (x3 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2",
      "x; // 4": "x3"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    try {\n      x; // 1\n      x = 42;\n    } finally {\n      x; // 2\n    }\n    x; // 3\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([Try(Block([(x0 = GetVariable(x)), SetVariable(x, Int(42))]), [], Block([(x1 = GetVariable(x))])), (x2 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    try {\n      x; // 1\n    } finally {\n      x; // 2\n      x = 42;\n    }\n    x; // 3\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([Try(Block([(x0 = GetVariable(x))]), [], Block([(x1 = GetVariable(x)), SetVariable(x, Int(42))])), (x2 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  while (x is! String) {\n    x; // 1\n  }\n  x; // 2\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([While(Is(GetVariable(x), InterfaceType(\"String\")), Block([(x0 = GetVariable(x))])), (x1 = GetVariable(x))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  while (x is String) {\n    x; // 1\n  }\n  x; // 2\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [x])..body = Block([While(Is(GetVariable(x), InterfaceType(\"String\")), Block([(x0 = GetVariable(x))])), (x1 = GetVariable(x))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    while (b) {\n      x; // 1\n    }\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([While(GetVariable(b), Block([(x0 = GetVariable(x))])), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    while (b) {\n      x; // 1\n      x = x.length;\n    }\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nvar b = Param(InterfaceType(\"bool\"), \"b\");\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [b, x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([While(GetVariable(b), Block([(x0 = GetVariable(x)), SetVariable(x, PropertyGet(GetVariable(x), \"length\"))])), (x1 = GetVariable(x))]))])]))",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    while (x != 0) {\n      x; // 1\n      x = x.length;\n    }\n    x; // 2\n  }\n}\n",
    "GetVariable x0;\nGetVariable x1;\nGetVariable x2;\nvar x = Param(InterfaceType(\"Object\"), \"x\");\nawait trackCode(Unit([Func(InterfaceType(\"void\"), \"f\", [Param(InterfaceType(\"bool\"), \"b\"), x])..body = Block([If(Is(GetVariable(x), InterfaceType(\"String\")), Block([While(NotEq((x0 = GetVariable(x)), Int(0)), Block([(x1 = GetVariable(x)), SetVariable(x, PropertyGet(GetVariable(x), \"length\"))])), (x2 = GetVariable(x))]))])]))",
    {
      "x != 0": "x0",
      "x; // 1": "x1",
      "x; // 2": "x2"
    }
  ]
];
