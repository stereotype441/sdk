List<List<Object>> testData = [
  [
    "void f(int x) {\n  if (x != null) return;\n  x; // 1\n  x = 0;\n  x; // 2\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(NotEq(Get(x), Null()), Return()), (x0 = Get(x)), Set(x, Int(0)), (x1 = Get(x))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(int x) {\n  if (x == null) return;\n  x; // 1\n  x = null;\n  x; // 2\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Eq(Get(x), Null()), Return()), (x0 = Get(x)), Set(x, Null()), (x1 = Get(x))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a == null) return;\n  a; // 1\n  a = b;\n  a; // 2\n}\n",
    "Get a0;\nvar a = Param(Type(\"int\"), \"a\");\nvar b = Param(Type(\"int\"), \"b\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [a, b])..body = Block([If(Eq(Get(a), Null()), Return()), (a0 = Get(a)), Set(a, Get(b)), Get(a)])]));",
    {
      "a; // 1": "a0"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a != null) return;\n  a; // 1\n  a = b;\n  a; // 2\n}\n",
    "Get a0;\nvar a = Param(Type(\"int\"), \"a\");\nvar b = Param(Type(\"int\"), \"b\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [a, b])..body = Block([If(NotEq(Get(a), Null()), Return()), (a0 = Get(a)), Set(a, Get(b)), Get(a)])]));",
    {
      "a; // 1": "a0"
    }
  ],
  [
    "void f(int x) {\n  x == null && x.isEven;\n}\n",
    "Get x0;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([And(Eq(Get(x), Null()), PropertyGet((x0 = Get(x)), \"isEven\"))])]));",
    {
      "x.isEven": "x0"
    }
  ],
  [
    "void f(int x) {\n  x == null || x.isEven;\n}\n",
    "Get x0;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Or(Eq(Get(x), Null()), PropertyGet((x0 = Get(x)), \"isEven\"))])]));",
    {
      "x.isEven": "x0"
    }
  ],
  [
    "class C {\n  C(int x) {\n    if (x == null) {\n      x; // 1\n    } else {\n      x; // 2\n    }\n  }\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Class(\"C\", [Constructor(null, [x], Block([If(Eq(Get(x), Null()), Block([(x0 = Get(x))]), Block([(x1 = Get(x))]))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a == null) {\n    a; // 1\n    if (b == null) return;\n    b; // 2\n  } else {\n    a; // 3\n    if (b == null) return;\n    b; // 4\n  }\n  a; // 5\n  b; // 6\n}\n",
    "Get a0;\nGet b0;\nGet a1;\nGet b1;\nGet b2;\nvar a = Param(Type(\"int\"), \"a\");\nvar b = Param(Type(\"int\"), \"b\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [a, b])..body = Block([If(Eq(Get(a), Null()), Block([(a0 = Get(a)), If(Eq(Get(b), Null()), Return()), (b0 = Get(b))]), Block([(a1 = Get(a)), If(Eq(Get(b), Null()), Return()), (b1 = Get(b))])), Get(a), (b2 = Get(b))])]));",
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
    "Get x0;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(NotEq(Null(), Get(x)), Return()), (x0 = Get(x))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(int x) {\n  if (x != null) return;\n  x; // 1\n}\n",
    "Get x0;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(NotEq(Get(x), Null()), Return()), (x0 = Get(x))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(int x) {\n  if (null == x) return;\n  x; // 1\n}\n",
    "Get x0;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Eq(Null(), Get(x)), Return()), (x0 = Get(x))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(int x) {\n  if (x == null) return;\n  x; // 1\n}\n",
    "Get x0;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Eq(Get(x), Null()), Return()), (x0 = Get(x))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(int x) {\n  if (x == null) {\n    x; // 1\n  } else {\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Eq(Get(x), Null()), Block([(x0 = Get(x))]), Block([(x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "class C {\n  void f(int x) {\n    if (x == null) {\n      x; // 1\n    } else {\n      x; // 2\n    }\n  }\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Class(\"C\", [Method(Type(\"void\"), \"f\", [x], Block([If(Eq(Get(x), Null()), Block([(x0 = Get(x))]), Block([(x1 = Get(x))]))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "f(int a, int b) {\n  localFunction() {\n    a = b;\n  }\n\n  if (a == null) {\n    a; // 1\n    localFunction();\n    a; // 2\n  }\n}\n",
    "var a = Param(Type(\"int\"), \"a\");\nvar b = Param(Type(\"int\"), \"b\");\nvar localFunction = Func(null, \"localFunction\", []);\nawait trackCode(Unit([Func(null, \"f\", [a, b])..body = Block([localFunction..body = Block([Set(a, Get(b))]), If(Eq(Get(a), Null()), Block([Get(a), StaticCall(localFunction, []), Get(a)]))])]));",
    {}
  ],
  [
    "void f(int x) {\n  try {\n    if (x == null) return;\n    x; // 1\n  } finally {\n    x; // 2\n  }\n  x; // 3\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Try(Block([If(Eq(Get(x), Null()), Return()), (x0 = Get(x))]), [], Block([Get(x)])), (x1 = Get(x))])]));",
    {
      "x; // 1": "x0",
      "x; // 3": "x1"
    }
  ],
  [
    "void f(int x) {\n  try {\n    x; // 1\n  } finally {\n    if (x == null) return;\n    x; // 2\n  }\n  x; // 3\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Try(Block([Get(x)]), [], Block([If(Eq(Get(x), Null()), Return()), (x0 = Get(x))])), (x1 = Get(x))])]));",
    {
      "x; // 2": "x0",
      "x; // 3": "x1"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a != null) return;\n  try {\n    a; // 1\n    a = b;\n    a; // 2\n  } finally {\n    a; // 3\n  }\n  a; // 4\n}\n",
    "Get a0;\nvar a = Param(Type(\"int\"), \"a\");\nvar b = Param(Type(\"int\"), \"b\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [a, b])..body = Block([If(NotEq(Get(a), Null()), Return()), Try(Block([(a0 = Get(a)), Set(a, Get(b)), Get(a)]), [], Block([Get(a)])), Get(a)])]));",
    {
      "a; // 1": "a0"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a == null) return;\n  try {\n    a; // 1\n    a = b;\n    a; // 2\n  } finally {\n    a; // 3\n  }\n  a; // 4\n}\n",
    "Get a0;\nvar a = Param(Type(\"int\"), \"a\");\nvar b = Param(Type(\"int\"), \"b\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [a, b])..body = Block([If(Eq(Get(a), Null()), Return()), Try(Block([(a0 = Get(a)), Set(a, Get(b)), Get(a)]), [], Block([Get(a)])), Get(a)])]));",
    {
      "a; // 1": "a0"
    }
  ],
  [
    "void f(int a, int b) {\n  if (a == null) return;\n  try {\n    a; // 1\n  } finally {\n    a; // 2\n    a = b;\n    a; // 3\n  }\n  a; // 4\n}\n",
    "Get a0;\nGet a1;\nvar a = Param(Type(\"int\"), \"a\");\nvar b = Param(Type(\"int\"), \"b\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [a, b])..body = Block([If(Eq(Get(a), Null()), Return()), Try(Block([(a0 = Get(a))]), [], Block([(a1 = Get(a)), Set(a, Get(b)), Get(a)])), Get(a)])]));",
    {
      "a; // 1": "a0",
      "a; // 2": "a1"
    }
  ],
  [
    "void f(int x) {\n  while (x == null) {\n    x; // 1\n  }\n  x; // 2\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([While(Eq(Get(x), Null()), Block([(x0 = Get(x))])), (x1 = Get(x))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(int x) {\n  while (x != null) {\n    x; // 1\n  }\n  x; // 2\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([While(NotEq(Get(x), Null()), Block([(x0 = Get(x))])), (x1 = Get(x))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f() {\n  false ? 1 : 2;\n}\n",
    "Int value_1;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Conditional(Bool(false), (value_1 = Int(1)), Int(2))])]));",
    {
      "1": "value_1"
    }
  ],
  [
    "void f() {\n  true ? 1 : 2;\n}\n",
    "Int value_2;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Conditional(Bool(true), Int(1), (value_2 = Int(2)))])]));",
    {
      "2": "value_2"
    }
  ],
  [
    "void f() {\n  do {\n    1;\n  } while (false);\n  2;\n}\n",
    "await trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Do(Block([Int(1)]), Bool(false)), Int(2)])]));",
    {}
  ],
  [
    "void f() { // f\n  do {\n    1;\n  } while (true);\n  2;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = (statement0 = Block([Do(Block([Int(1)]), Bool(true)), (statement = Int(2))]))]));",
    {
      "2;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f(bool b, int i) { // f\n  return;\n  Object _;\n  do {} while (b);\n  for (;;) {}\n  for (_ in []) {}\n  if (b) {}\n  switch (i) {}\n  try {} finally {}\n  while (b) {}\n}\n",
    "Locals statement;\nDo statement0;\nForExpr statement1;\nForEachIdentifier statement2;\nIf statement3;\nSwitch statement4;\nTry statement5;\nWhile statement6;\nStatement statement7;\nvar b = Param(Type(\"bool\"), \"b\");\nvar i = Param(Type(\"int\"), \"i\");\nvar _ = Local(\"_\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, i])..body = (statement7 = Block([Return(), (statement = Locals([_])), (statement0 = Do(Block([]), Get(b))), (statement1 = ForExpr(null, null, [], Block([]))), (statement2 = ForEachIdentifier(_, ListLiteral(null, []), Block([]))), (statement3 = If(Get(b), Block([]))), (statement4 = Switch(Get(i), [])), (statement5 = Try(Block([]), [], Block([]))), (statement6 = While(Get(b), Block([])))]))]));",
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
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = (statement0 = Block([ForExpr(null, Bool(true), [], Block([Int(1)])), (statement = Int(2))]))]));",
    {
      "2;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f() { // f\n  for (;;) {\n    1;\n  }\n  2;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = (statement0 = Block([ForExpr(null, null, [], Block([Int(1)])), (statement = Int(2))]))]));",
    {
      "2;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f() {\n  Object _;\n  for (_ in [0, 1, 2]) {\n    1;\n    return;\n  }\n  2;\n}\n",
    "var _ = Local(\"_\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Locals([_]), ForEachIdentifier(_, ListLiteral(null, [Int(0), Int(1), Int(2)]), Block([Int(1), Return()])), Int(2)])]));",
    {}
  ],
  [
    "int f() { // f\n  return 42;\n}\n",
    "Statement statement;\nawait trackCode(Unit([Func(Type(\"int\"), \"f\", [])..body = (statement = Block([Return(Int(42))]))]));",
    {
      "{ // f": "statement"
    }
  ],
  [
    "void f() {\n  1;\n}\n",
    "await trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Int(1)])]));",
    {}
  ],
  [
    "void f(bool b) {\n  if (b) {\n    1;\n  } else {\n    2;\n  }\n  3;\n}\n",
    "var b = Param(Type(\"bool\"), \"b\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b])..body = Block([If(Get(b), Block([Int(1)]), Block([Int(2)])), Int(3)])]));",
    {}
  ],
  [
    "void f() {\n  if (false) { // 1\n    1;\n  } else { // 2\n  }\n  3;\n}\n",
    "Block statement;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([If(Bool(false), (statement = Block([Int(1)])), Block([])), Int(3)])]));",
    {
      "{ // 1": "statement"
    }
  ],
  [
    "void f() { // f\n  1;\n  if (true) {\n    return;\n  }\n  2;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = (statement0 = Block([Int(1), If(Bool(true), Block([Return()])), (statement = Int(2))]))]));",
    {
      "2;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f() {\n  if (true) { // 1\n  } else { // 2\n    2;\n  }\n  3;\n}\n",
    "Block statement;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([If(Bool(true), Block([]), (statement = Block([Int(2)]))), Int(3)])]));",
    {
      "{ // 2": "statement"
    }
  ],
  [
    "void f(int x) {\n  false && (x == 1);\n}\n",
    "Expression expression;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([And(Bool(false), (expression = Parens(Eq(Get(x), Int(1)))))])]));",
    {
      "(x == 1)": "expression"
    }
  ],
  [
    "void f(int x) {\n  true || (x == 1);\n}\n",
    "Expression expression;\nvar x = Param(Type(\"int\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Or(Bool(true), (expression = Parens(Eq(Get(x), Int(1)))))])]));",
    {
      "(x == 1)": "expression"
    }
  ],
  [
    "void f(bool b, int i) {\n  switch (i) {\n    case 1:\n      1;\n      if (b) {\n        return;\n      } else {\n        return;\n      }\n      2;\n  }\n  3;\n}\n",
    "Expression statement;\nvar b = Param(Type(\"bool\"), \"b\");\nvar i = Param(Type(\"int\"), \"i\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, i])..body = Block([Switch(Get(i), [Case([], Int(1), [Int(1), If(Get(b), Block([Return()]), Block([Return()])), (statement = Int(2))])]), Int(3)])]));",
    {
      "2;": "statement"
    }
  ],
  [
    "void f() {\n  try {\n    1;\n  } catch (_) {\n    2;\n  }\n  3;\n}\n",
    "await trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Try(Block([Int(1)]), [Catch(CatchVariable(\"_\"), Block([Int(2)]))]), Int(3)])]));",
    {}
  ],
  [
    "void f() {\n  try {\n    1;\n    return;\n    2;\n  } catch (_) {\n    3;\n  }\n  4;\n}\n",
    "Expression statement;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Try(Block([Int(1), Return(), (statement = Int(2))]), [Catch(CatchVariable(\"_\"), Block([Int(3)]))]), Int(4)])]));",
    {
      "2;": "statement"
    }
  ],
  [
    "void f() {\n  try {\n    1;\n  } catch (_) {\n    2;\n    return;\n    3;\n  }\n  4;\n}\n",
    "Expression statement;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Try(Block([Int(1)]), [Catch(CatchVariable(\"_\"), Block([Int(2), Return(), (statement = Int(3))]))]), Int(4)])]));",
    {
      "3;": "statement"
    }
  ],
  [
    "void f() {\n  try {\n    1;\n    return;\n  } catch (_) {\n    2;\n  } finally {\n    3;\n  }\n  4;\n}\n",
    "await trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Try(Block([Int(1), Return()]), [Catch(CatchVariable(\"_\"), Block([Int(2)]))], Block([Int(3)])), Int(4)])]));",
    {}
  ],
  [
    "void f() { // f\n  try {\n    1;\n    return;\n  } catch (_) {\n    2;\n    return;\n  } finally {\n    3;\n  }\n  4;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = (statement0 = Block([Try(Block([Int(1), Return()]), [Catch(CatchVariable(\"_\"), Block([Int(2), Return()]))], Block([Int(3)])), (statement = Int(4))]))]));",
    {
      "4;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f() {\n  try {\n    1;\n  } catch (_) {\n    2;\n    return;\n  } finally {\n    3;\n  }\n  4;\n}\n",
    "await trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Try(Block([Int(1)]), [Catch(CatchVariable(\"_\"), Block([Int(2), Return()]))], Block([Int(3)])), Int(4)])]));",
    {}
  ],
  [
    "void f() { // f\n  try {\n    1;\n    return;\n  } finally {\n    2;\n  }\n  3;\n}\n",
    "Expression statement;\nStatement statement0;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = (statement0 = Block([Try(Block([Int(1), Return()]), [], Block([Int(2)])), (statement = Int(3))]))]));",
    {
      "3;": "statement",
      "{ // f": "statement0"
    }
  ],
  [
    "void f() {\n  while (false) { // 1\n    1;\n  }\n  2;\n}\n",
    "Block statement;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([While(Bool(false), (statement = Block([Int(1)]))), Int(2)])]));",
    {
      "{ // 1": "statement"
    }
  ],
  [
    "void f() { // f\n  while (true) {\n    1;\n  }\n  2;\n  3;\n}\n",
    "Expression statement;\nExpression statement0;\nStatement statement1;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = (statement1 = Block([While(Bool(true), Block([Int(1)])), (statement = Int(2)), (statement0 = Int(3))]))]));",
    {
      "2;": "statement",
      "3;": "statement0",
      "{ // f": "statement1"
    }
  ],
  [
    "void f() {\n  while (true) {\n    1;\n    break;\n    2;\n  }\n  3;\n}\n",
    "Expression statement;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([While(Bool(true), Block([Int(1), Break(), (statement = Int(2))])), Int(3)])]));",
    {
      "2;": "statement"
    }
  ],
  [
    "void f(bool b) {\n  while (true) {\n    1;\n    if (b) break;\n    2;\n  }\n  3;\n}\n",
    "var b = Param(Type(\"bool\"), \"b\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b])..body = Block([While(Bool(true), Block([Int(1), If(Get(b), Break()), Int(2)])), Int(3)])]));",
    {}
  ],
  [
    "void f() { // f\n  while (true) {\n    1;\n    continue;\n    2;\n  }\n  3;\n}\n",
    "Expression statement;\nExpression statement0;\nStatement statement1;\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = (statement1 = Block([While(Bool(true), Block([Int(1), Continue(), (statement = Int(2))])), (statement0 = Int(3))]))]));",
    {
      "2;": "statement",
      "3;": "statement0",
      "{ // f": "statement1"
    }
  ],
  [
    "f(Object x) {\n  if (x is String) {\n    x = 42;\n    x; // 1\n  }\n}\n",
    "Get x0;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(null, \"f\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Set(x, Int(42)), (x0 = Get(x))]))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(Object x) {\n  ((x is num) || (throw 1)) ?? ((x is int) || (throw 2));\n  x; // 1\n}\n",
    "Get x0;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([IfNull(Parens(Or(Parens(Is(Get(x), Type(\"num\"))), Parens(Throw(Int(1))))), Parens(Or(Parens(Is(Get(x), Type(\"int\"))), Parens(Throw(Int(2)))))), (x0 = Get(x))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(Object x, Object y, Object z) {\n  if (x is int) {\n    x; // 1\n    y ?? (x = z);\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"Object\"), \"x\");\nvar y = Param(Type(\"Object\"), \"y\");\nvar z = Param(Type(\"Object\"), \"z\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x, y, z])..body = Block([If(Is(Get(x), Type(\"int\")), Block([(x0 = Get(x)), IfNull(Get(y), Parens(Set(x, Get(z)))), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  b ? ((x is num) || (throw 1)) : ((x is int) || (throw 2));\n  x; // 1\n}\n",
    "Get x0;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([Conditional(Get(b), Parens(Or(Parens(Is(Get(x), Type(\"num\"))), Parens(Throw(Int(1))))), Parens(Or(Parens(Is(Get(x), Type(\"int\"))), Parens(Throw(Int(2)))))), (x0 = Get(x))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(bool b, Object x) {\n  b ? 0 : ((x is int) || (throw 2));\n  x; // 1\n}\n",
    "Get x0;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([Conditional(Get(b), Int(0), Parens(Or(Parens(Is(Get(x), Type(\"int\"))), Parens(Throw(Int(2)))))), (x0 = Get(x))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(bool b, Object x) {\n  b ? ((x is num) || (throw 1)) : 0;\n  x; // 1\n}\n",
    "Get x0;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([Conditional(Get(b), Parens(Or(Parens(Is(Get(x), Type(\"num\"))), Parens(Throw(Int(1))))), Int(0)), (x0 = Get(x))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(Object x) {\n  do {\n    x; // 1\n    x = '';\n  } while (x is! String);\n  x; // 2\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Do(Block([(x0 = Get(x)), Set(x, String())]), Is(Get(x), Type(\"String\"))), (x1 = Get(x))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  do {\n    x; // 1\n  } while (x is String);\n  x; // 2\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Do(Block([(x0 = Get(x))]), Is(Get(x), Type(\"String\"))), (x1 = Get(x))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    do {\n      x; // 1\n    } while (b);\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Do(Block([(x0 = Get(x))]), Get(b)), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    do {\n      x; // 1\n      x = x.length;\n    } while (b);\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Do(Block([(x0 = Get(x)), Set(x, PropertyGet(Get(x), \"length\"))]), Get(b)), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    do {\n      x; // 1\n      x = x.length;\n    } while (x != 0);\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nGet x2;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [Param(Type(\"bool\"), \"b\"), x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Do(Block([(x0 = Get(x)), Set(x, PropertyGet(Get(x), \"length\"))]), NotEq((x1 = Get(x)), Int(0))), (x2 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x != 0": "x1",
      "x; // 2": "x2"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    do {\n      x; // 1\n    } while ((x = 1) != 0);\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [Param(Type(\"bool\"), \"b\"), x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Do(Block([(x0 = Get(x))]), NotEq(Parens(Set(x, Int(1))), Int(0))), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    for (; b;) {\n      x; // 1\n    }\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([ForExpr(null, Get(b), [], Block([(x0 = Get(x))])), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    for (; b;) {\n      x; // 1\n      x = 42;\n    }\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([ForExpr(null, Get(b), [], Block([(x0 = Get(x)), Set(x, Int(42))])), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    for (; (x = 42) > 0;) {\n      x; // 1\n    }\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([ForExpr(null, Gt(Parens(Set(x, Int(42))), Int(0)), [], Block([(x0 = Get(x))])), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    for (; b; x = 42) {\n      x; // 1\n    }\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([ForExpr(null, Get(b), [Set(x, Int(42))], Block([(x0 = Get(x))])), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  Object v1;\n  if (x is String) {\n    for (var _ in (v1 = [0, 1, 2])) {\n      x; // 1\n      x = 42;\n    }\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"Object\"), \"x\");\nvar v1 = Local(\"v1\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Locals([v1]), If(Is(Get(x), Type(\"String\")), Block([ForEachDeclared([ForEachVariable(\"_\")], Parens(Set(v1, ListLiteral(null, [Int(0), Int(1), Int(2)]))), Block([(x0 = Get(x)), Set(x, Int(42))])), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f() {\n  void g(Object x) {\n    if (x is String) {\n      x; // 1\n    }\n    x = 42;\n  }\n}\n",
    "Get x0;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Func(Type(\"void\"), \"g\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([(x0 = Get(x))])), Set(x, Int(42))])])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f() {\n  void g(Object x) {\n    if (x is String) {\n      x; // 1\n    }\n    \n    void h() {\n      x = 42;\n    }\n  }\n}\n",
    "Get x0;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [])..body = Block([Func(Type(\"void\"), \"g\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([(x0 = Get(x))])), Func(Type(\"void\"), \"h\", [])..body = Block([Set(x, Int(42))])])])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(Object x) {\n  void Function() g;\n  \n  if (x is String) {\n    x; // 1\n\n    g = () {\n      x; // 2\n    };\n  }\n\n  x = 42;\n  x; // 3\n  g();\n}\n",
    "Get x0;\nGet x1;\nGet x2;\nvar x = Param(Type(\"Object\"), \"x\");\nvar g = Local(\"g\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Locals([g]), If(Is(Get(x), Type(\"String\")), Block([(x0 = Get(x)), Set(g, Closure([], Block([(x1 = Get(x))])))])), Set(x, Int(42)), (x2 = Get(x)), LocalCall(g, [])])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "main(bool b, Object v) {\n  if (b) {\n    v is int || (throw 1);\n  } else {\n    v is String || (throw 2);\n  }\n  v; // 3\n}\n",
    "Get v0;\nvar b = Param(Type(\"bool\"), \"b\");\nvar v = Param(Type(\"Object\"), \"v\");\nawait trackCode(Unit([Func(null, \"main\", [b, v])..body = Block([If(Get(b), Block([Or(Is(Get(v), Type(\"int\")), Parens(Throw(Int(1))))]), Block([Or(Is(Get(v), Type(\"String\")), Parens(Throw(Int(2))))])), (v0 = Get(v))])]));",
    {
      "v; // 3": "v0"
    }
  ],
  [
    "f(bool b, Object v) {\n  if (b ? (v is! int) : (v is! num)) {\n    v; // 1\n  } else {\n    v; // 2\n  }\n  v; // 3\n}\n",
    "Get v0;\nGet v1;\nGet v2;\nvar b = Param(Type(\"bool\"), \"b\");\nvar v = Param(Type(\"Object\"), \"v\");\nawait trackCode(Unit([Func(null, \"f\", [b, v])..body = Block([If(Conditional(Get(b), Parens(Is(Get(v), Type(\"int\"))), Parens(Is(Get(v), Type(\"num\")))), Block([(v0 = Get(v))]), Block([(v1 = Get(v))])), (v2 = Get(v))])]));",
    {
      "v; // 1": "v0",
      "v; // 2": "v1",
      "v; // 3": "v2"
    }
  ],
  [
    "f(bool b, Object v) {\n  if (b ? (v is int) : (v is num)) {\n    v; // 1\n  } else {\n    v; // 2\n  }\n  v; // 3\n}\n",
    "Get v0;\nGet v1;\nGet v2;\nvar b = Param(Type(\"bool\"), \"b\");\nvar v = Param(Type(\"Object\"), \"v\");\nawait trackCode(Unit([Func(null, \"f\", [b, v])..body = Block([If(Conditional(Get(b), Parens(Is(Get(v), Type(\"int\"))), Parens(Is(Get(v), Type(\"num\")))), Block([(v0 = Get(v))]), Block([(v1 = Get(v))])), (v2 = Get(v))])]));",
    {
      "v; // 1": "v0",
      "v; // 2": "v1",
      "v; // 3": "v2"
    }
  ],
  [
    "main(v) {\n  if (v is! String) {\n    v; // 1\n  } else {\n    v; // 2\n  }\n  v; // 3\n}\n",
    "Get v0;\nGet v1;\nGet v2;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([If(Is(Get(v), Type(\"String\")), Block([(v0 = Get(v))]), Block([(v1 = Get(v))])), (v2 = Get(v))])]));",
    {
      "v; // 1": "v0",
      "v; // 2": "v1",
      "v; // 3": "v2"
    }
  ],
  [
    "main(v) {\n  if (v is! String) return;\n  v; // ref\n}\n",
    "Get v0;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([If(Is(Get(v), Type(\"String\")), Return()), (v0 = Get(v))])]));",
    {
      "v; // ref": "v0"
    }
  ],
  [
    "main(v) {\n  if (v is! String) throw 42;\n  v; // ref\n}\n",
    "Get v0;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([If(Is(Get(v), Type(\"String\")), Throw(Int(42))), (v0 = Get(v))])]));",
    {
      "v; // ref": "v0"
    }
  ],
  [
    "main(v) {\n  if (v is String) {\n    v; // 1\n  } else {\n    v; // 2\n  }\n  v; // 3\n}\n",
    "Get v0;\nGet v1;\nGet v2;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([If(Is(Get(v), Type(\"String\")), Block([(v0 = Get(v))]), Block([(v1 = Get(v))])), (v2 = Get(v))])]));",
    {
      "v; // 1": "v0",
      "v; // 2": "v1",
      "v; // 3": "v2"
    }
  ],
  [
    "f(Object x) {\n  if ((x is String) != 3) {\n    x; // 1\n  }\n}\n",
    "Get x0;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(null, \"f\", [x])..body = Block([If(NotEq(Parens(Is(Get(x), Type(\"String\"))), Int(3)), Block([(x0 = Get(x))]))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "main(v) {\n  if (!(v is String)) {\n    v; // 1\n  } else {\n    v; // 2\n  }\n  v; // 3\n}\n",
    "Get v0;\nGet v1;\nGet v2;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([If(Not(Parens(Is(Get(v), Type(\"String\")))), Block([(v0 = Get(v))]), Block([(v1 = Get(v))])), (v2 = Get(v))])]));",
    {
      "v; // 1": "v0",
      "v; // 2": "v1",
      "v; // 3": "v2"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (b) {\n    if (x is! String) return;\n  }\n  x; // 1\n}\n",
    "Get x0;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([If(Get(b), Block([If(Is(Get(x), Type(\"String\")), Return())])), (x0 = Get(x))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "main(v) {\n  v is String || (throw 42);\n  v; // ref\n}\n",
    "Get v0;\nvar v = Param(null, \"v\");\nawait trackCode(Unit([Func(null, \"main\", [v])..body = Block([Or(Is(Get(v), Type(\"String\")), Parens(Throw(Int(42)))), (v0 = Get(v))])]));",
    {
      "v; // ref": "v0"
    }
  ],
  [
    "f(Object x) {\n  localFunction() {\n    x = 42;\n  }\n\n  if (x is String) {\n    localFunction();\n    x; // 1\n  }\n}\n",
    "Get x0;\nvar x = Param(Type(\"Object\"), \"x\");\nvar localFunction = Func(null, \"localFunction\", []);\nawait trackCode(Unit([Func(null, \"f\", [x])..body = Block([localFunction..body = Block([Set(x, Int(42))]), If(Is(Get(x), Type(\"String\")), Block([StaticCall(localFunction, []), (x0 = Get(x))]))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "f(Object x) {\n  if (x is String) {\n    x; // 1\n  }\n\n  x = 42;\n}\n",
    "Get x0;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(null, \"f\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([(x0 = Get(x))])), Set(x, Int(42))])]));",
    {
      "x; // 1": "x0"
    }
  ],
  [
    "void f(int e, Object x) {\n  if (x is String) {\n    switch (e) {\n      L: case 1:\n        x; // 1\n        break;\n      case 2: // no label\n        x; // 2\n        break;\n      case 3:\n        x = 42;\n        continue L;\n    }\n    x; // 3\n  }\n}\n",
    "Get x0;\nGet x1;\nGet x2;\nvar e = Param(Type(\"int\"), \"e\");\nvar x = Param(Type(\"Object\"), \"x\");\nvar L = Label(\"L\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [e, x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Switch(Get(e), [Case([L], Int(1), [(x0 = Get(x)), Break()]), Case([], Int(2), [(x1 = Get(x)), Break()]), Case([], Int(3), [Set(x, Int(42)), Continue(L)])]), (x2 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  if (x is! String) return;\n  x; // 1\n  try {\n    x = 42;\n    g(); // might throw\n    if (x is! String) return;\n    x; // 2\n  } catch (_) {}\n  x; // 3\n}\n\nvoid g() {}\n",
    "Get x0;\nGet x1;\nGet x2;\nvar x = Param(Type(\"Object\"), \"x\");\nvar g = Func(Type(\"void\"), \"g\", []);\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Return()), (x0 = Get(x)), Try(Block([Set(x, Int(42)), StaticCall(g, []), If(Is(Get(x), Type(\"String\")), Return()), (x1 = Get(x))]), [Catch(CatchVariable(\"_\"), Block([]))]), (x2 = Get(x))]), g..body = Block([])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  try {\n    if (x is! String) return;\n    x; // 1\n  } catch (_) {}\n  x; // 2\n}\n\nvoid g() {}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Try(Block([If(Is(Get(x), Type(\"String\")), Return()), (x0 = Get(x))]), [Catch(CatchVariable(\"_\"), Block([]))]), (x1 = Get(x))]), Func(Type(\"void\"), \"g\", [])..body = Block([])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  try {\n    if (x is! String) return;\n    x; // 1\n  } catch (_) {\n    if (x is! String) return;\n    x; // 2\n  }\n  x; // 3\n}\n\nvoid g() {}\n",
    "Get x0;\nGet x1;\nGet x2;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Try(Block([If(Is(Get(x), Type(\"String\")), Return()), (x0 = Get(x))]), [Catch(CatchVariable(\"_\"), Block([If(Is(Get(x), Type(\"String\")), Return()), (x1 = Get(x))]))]), (x2 = Get(x))]), Func(Type(\"void\"), \"g\", [])..body = Block([])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  try {\n    if (x is! String) return;\n    x; // 1\n  } catch (_) {\n    x; // 2\n    rethrow;\n  }\n  x; // 3\n}\n\nvoid g() {}\n",
    "Get x0;\nGet x1;\nGet x2;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Try(Block([If(Is(Get(x), Type(\"String\")), Return()), (x0 = Get(x))]), [Catch(CatchVariable(\"_\"), Block([(x1 = Get(x)), Rethrow()]))]), (x2 = Get(x))]), Func(Type(\"void\"), \"g\", [])..body = Block([])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  try {\n  } catch (_) {\n    if (x is! String) return;\n    x; // 1\n  }\n  x; // 2\n}\n\nvoid g() {}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([Try(Block([]), [Catch(CatchVariable(\"_\"), Block([If(Is(Get(x), Type(\"String\")), Return()), (x0 = Get(x))]))]), (x1 = Get(x))]), Func(Type(\"void\"), \"g\", [])..body = Block([])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    try {\n      x; // 1\n    } catch (_) {\n      x; // 2\n    } finally {\n      x; // 3\n    }\n    x; // 4\n  }\n}\n\nvoid g() {}\n",
    "Get x0;\nGet x1;\nGet x2;\nGet x3;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Try(Block([(x0 = Get(x))]), [Catch(CatchVariable(\"_\"), Block([(x1 = Get(x))]))], Block([(x2 = Get(x))])), (x3 = Get(x))]))]), Func(Type(\"void\"), \"g\", [])..body = Block([])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2",
      "x; // 4": "x3"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    try {\n      x; // 1\n      x = 42;\n      g();\n    } catch (_) {\n      x; // 2\n    } finally {\n      x; // 3\n    }\n    x; // 4\n  }\n}\n\nvoid g() {}\n",
    "Get x0;\nGet x1;\nGet x2;\nGet x3;\nvar x = Param(Type(\"Object\"), \"x\");\nvar g = Func(Type(\"void\"), \"g\", []);\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Try(Block([(x0 = Get(x)), Set(x, Int(42)), StaticCall(g, [])]), [Catch(CatchVariable(\"_\"), Block([(x1 = Get(x))]))], Block([(x2 = Get(x))])), (x3 = Get(x))]))]), g..body = Block([])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2",
      "x; // 4": "x3"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    try {\n      x; // 1\n    } catch (_) {\n      x; // 2\n      x = 42;\n    } finally {\n      x; // 3\n    }\n    x; // 4\n  }\n}\n",
    "Get x0;\nGet x1;\nGet x2;\nGet x3;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Try(Block([(x0 = Get(x))]), [Catch(CatchVariable(\"_\"), Block([(x1 = Get(x)), Set(x, Int(42))]))], Block([(x2 = Get(x))])), (x3 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2",
      "x; // 4": "x3"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    try {\n      x; // 1\n      x = 42;\n    } finally {\n      x; // 2\n    }\n    x; // 3\n  }\n}\n",
    "Get x0;\nGet x1;\nGet x2;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Try(Block([(x0 = Get(x)), Set(x, Int(42))]), [], Block([(x1 = Get(x))])), (x2 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  if (x is String) {\n    try {\n      x; // 1\n    } finally {\n      x; // 2\n      x = 42;\n    }\n    x; // 3\n  }\n}\n",
    "Get x0;\nGet x1;\nGet x2;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([Try(Block([(x0 = Get(x))]), [], Block([(x1 = Get(x)), Set(x, Int(42))])), (x2 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1",
      "x; // 3": "x2"
    }
  ],
  [
    "void f(Object x) {\n  while (x is! String) {\n    x; // 1\n  }\n  x; // 2\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([While(Is(Get(x), Type(\"String\")), Block([(x0 = Get(x))])), (x1 = Get(x))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(Object x) {\n  while (x is String) {\n    x; // 1\n  }\n  x; // 2\n}\n",
    "Get x0;\nGet x1;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [x])..body = Block([While(Is(Get(x), Type(\"String\")), Block([(x0 = Get(x))])), (x1 = Get(x))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    while (b) {\n      x; // 1\n    }\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([While(Get(b), Block([(x0 = Get(x))])), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    while (b) {\n      x; // 1\n      x = x.length;\n    }\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nvar b = Param(Type(\"bool\"), \"b\");\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [b, x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([While(Get(b), Block([(x0 = Get(x)), Set(x, PropertyGet(Get(x), \"length\"))])), (x1 = Get(x))]))])]));",
    {
      "x; // 1": "x0",
      "x; // 2": "x1"
    }
  ],
  [
    "void f(bool b, Object x) {\n  if (x is String) {\n    while (x != 0) {\n      x; // 1\n      x = x.length;\n    }\n    x; // 2\n  }\n}\n",
    "Get x0;\nGet x1;\nGet x2;\nvar x = Param(Type(\"Object\"), \"x\");\nawait trackCode(Unit([Func(Type(\"void\"), \"f\", [Param(Type(\"bool\"), \"b\"), x])..body = Block([If(Is(Get(x), Type(\"String\")), Block([While(NotEq((x0 = Get(x)), Int(0)), Block([(x1 = Get(x)), Set(x, PropertyGet(Get(x), \"length\"))])), (x2 = Get(x))]))])]));",
    {
      "x != 0": "x0",
      "x; // 1": "x1",
      "x; // 2": "x2"
    }
  ]
];