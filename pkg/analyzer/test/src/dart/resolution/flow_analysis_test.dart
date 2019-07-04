// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'flow_analysis_dsl.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NullableFlowTest);
    defineReflectiveTests(ReachableFlowTest);
    defineReflectiveTests(TypePromotionFlowTest);
  });
}

class FlowTestBase {
  FlowAnalysisResult flowResult;

  /// Resolve the given [code] and track nullability in the unit.
  void trackCode(Unit code) {
    flowResult = FlowAnalysisDriver.run(code);
  }
}

@reflectiveTest
class NullableFlowTest extends FlowTestBase {
  void assertNonNullable([
    Get search1,
    Get search2,
    Get search3,
    Get search4,
    Get search5,
  ]) {
    var expected = [search1, search2, search3, search4, search5]
        .where((i) => i != null)
        .toList();
    expect(flowResult.nonNullableNodes, unorderedEquals(expected));
  }

  void assertNullable([
    Get search1,
    Get search2,
    Get search3,
    Get search4,
    Get search5,
  ]) {
    var expected = [search1, search2, search3, search4, search5]
        .where((i) => i != null)
        .toList();
    expect(flowResult.nullableNodes, unorderedEquals(expected));
  }

  test_assign_toNonNull() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(NotEq(GetVariable(x), NullLiteral()), Return()),
          (x0 = GetVariable(x)),
          SetVariable(x, Int(0)),
          (x1 = GetVariable(x))
        ])
    ]));
    assertNullable(x0);
    assertNonNullable(x1);
  }

  test_assign_toNull() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(Eq(GetVariable(x), NullLiteral()), Return()),
          (x0 = GetVariable(x)),
          SetVariable(x, NullLiteral()),
          (x1 = GetVariable(x))
        ])
    ]));
    assertNullable(x1);
    assertNonNullable(x0);
  }

  test_assign_toUnknown_fromNotNull() async {
    GetVariable a0;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(Eq(GetVariable(a), NullLiteral()), Return()),
          (a0 = GetVariable(a)),
          SetVariable(a, GetVariable(b)),
          GetVariable(a)
        ])
    ]));
    assertNullable();
    assertNonNullable(a0);
  }

  test_assign_toUnknown_fromNull() async {
    GetVariable a0;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(NotEq(GetVariable(a), NullLiteral()), Return()),
          (a0 = GetVariable(a)),
          SetVariable(a, GetVariable(b)),
          GetVariable(a)
        ])
    ]));
    assertNullable(a0);
    assertNonNullable();
  }

  test_binaryExpression_logicalAnd() async {
    GetVariable x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          And(Eq(GetVariable(x), NullLiteral()),
              PropertyGet((x0 = GetVariable(x)), "isEven"))
        ])
    ]));
    assertNullable(x0);
    assertNonNullable();
  }

  test_binaryExpression_logicalOr() async {
    GetVariable x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Or(Eq(GetVariable(x), NullLiteral()),
              PropertyGet((x0 = GetVariable(x)), "isEven"))
        ])
    ]));
    assertNullable();
    assertNonNullable(x0);
  }

  test_constructor_if_then_else() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Class("C", [
        Constructor(
            null,
            [x],
            Block([
              If(
                  Eq(GetVariable(x), NullLiteral()),
                  Block([(x0 = GetVariable(x))]),
                  Block([(x1 = GetVariable(x))]))
            ]))
      ])
    ]));
    assertNullable(x0);
    assertNonNullable(x1);
  }

  test_if_joinThenElse_ifNull() async {
    GetVariable a0;
    GetVariable b0;
    GetVariable a1;
    GetVariable b1;
    GetVariable b2;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(
              Eq(GetVariable(a), NullLiteral()),
              Block([
                (a0 = GetVariable(a)),
                If(Eq(GetVariable(b), NullLiteral()), Return()),
                (b0 = GetVariable(b))
              ]),
              Block([
                (a1 = GetVariable(a)),
                If(Eq(GetVariable(b), NullLiteral()), Return()),
                (b1 = GetVariable(b))
              ])),
          GetVariable(a),
          (b2 = GetVariable(b))
        ])
    ]));
    assertNullable(a0);
    assertNonNullable(b0, a1, b1, b2);
  }

  test_if_notNull_thenExit_left() async {
    GetVariable x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(NotEq(NullLiteral(), GetVariable(x)), Return()),
          (x0 = GetVariable(x))
        ])
    ]));
    assertNullable(x0);
    assertNonNullable();
  }

  test_if_notNull_thenExit_right() async {
    GetVariable x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(NotEq(GetVariable(x), NullLiteral()), Return()),
          (x0 = GetVariable(x))
        ])
    ]));
    assertNullable(x0);
    assertNonNullable();
  }

  test_if_null_thenExit_left() async {
    GetVariable x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(Eq(NullLiteral(), GetVariable(x)), Return()),
          (x0 = GetVariable(x))
        ])
    ]));
    assertNullable();
    assertNonNullable(x0);
  }

  test_if_null_thenExit_right() async {
    GetVariable x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(Eq(GetVariable(x), NullLiteral()), Return()),
          (x0 = GetVariable(x))
        ])
    ]));
    assertNullable();
    assertNonNullable(x0);
  }

  test_if_then_else() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(Eq(GetVariable(x), NullLiteral()), Block([(x0 = GetVariable(x))]),
              Block([(x1 = GetVariable(x))]))
        ])
    ]));
    assertNullable(x0);
    assertNonNullable(x1);
  }

  test_method_if_then_else() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Class("C", [
        Method(
            InterfaceType("void"),
            "f",
            [x],
            Block([
              If(
                  Eq(GetVariable(x), NullLiteral()),
                  Block([(x0 = GetVariable(x))]),
                  Block([(x1 = GetVariable(x))]))
            ]))
      ])
    ]));
    assertNullable(x0);
    assertNonNullable(x1);
  }

  test_potentiallyMutatedInClosure() async {
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    var localFunction = Func(null, "localFunction", []);
    await trackCode(Unit([
      Func(null, "f", [a, b])
        ..body = Block([
          localFunction..body = Block([SetVariable(a, GetVariable(b))]),
          If(
              Eq(GetVariable(a), NullLiteral()),
              Block([
                GetVariable(a),
                StaticCall(localFunction, []),
                GetVariable(a)
              ]))
        ])
    ]));
    assertNullable();
    assertNonNullable();
  }

  test_tryFinally_eqNullExit_body() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(
              Block([
                If(Eq(GetVariable(x), NullLiteral()), Return()),
                (x0 = GetVariable(x))
              ]),
              [],
              Block([GetVariable(x)])),
          (x1 = GetVariable(x))
        ])
    ]));
    assertNullable();
    assertNonNullable(x0, x1);
  }

  test_tryFinally_eqNullExit_finally() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(
              Block([GetVariable(x)]),
              [],
              Block([
                If(Eq(GetVariable(x), NullLiteral()), Return()),
                (x0 = GetVariable(x))
              ])),
          (x1 = GetVariable(x))
        ])
    ]));
    assertNullable();
    assertNonNullable(x0, x1);
  }

  test_tryFinally_outerEqNotNullExit_assignUnknown_body() async {
    GetVariable a0;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(NotEq(GetVariable(a), NullLiteral()), Return()),
          Try(
              Block([
                (a0 = GetVariable(a)),
                SetVariable(a, GetVariable(b)),
                GetVariable(a)
              ]),
              [],
              Block([GetVariable(a)])),
          GetVariable(a)
        ])
    ]));
    assertNullable(a0);
    assertNonNullable();
  }

  test_tryFinally_outerEqNullExit_assignUnknown_body() async {
    GetVariable a0;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(Eq(GetVariable(a), NullLiteral()), Return()),
          Try(
              Block([
                (a0 = GetVariable(a)),
                SetVariable(a, GetVariable(b)),
                GetVariable(a)
              ]),
              [],
              Block([GetVariable(a)])),
          GetVariable(a)
        ])
    ]));
    assertNullable();
    assertNonNullable(a0);
  }

  test_tryFinally_outerEqNullExit_assignUnknown_finally() async {
    GetVariable a0;
    GetVariable a1;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(Eq(GetVariable(a), NullLiteral()), Return()),
          Try(
              Block([(a0 = GetVariable(a))]),
              [],
              Block([
                (a1 = GetVariable(a)),
                SetVariable(a, GetVariable(b)),
                GetVariable(a)
              ])),
          GetVariable(a)
        ])
    ]));
    assertNullable();
    assertNonNullable(a0, a1);
  }

  test_while_eqNull() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          While(Eq(GetVariable(x), NullLiteral()),
              Block([(x0 = GetVariable(x))])),
          (x1 = GetVariable(x))
        ])
    ]));
    assertNullable(x0);
    assertNonNullable(x1);
  }

  test_while_notEqNull() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          While(NotEq(GetVariable(x), NullLiteral()),
              Block([(x0 = GetVariable(x))])),
          (x1 = GetVariable(x))
        ])
    ]));
    assertNullable(x1);
    assertNonNullable(x0);
  }
}

@reflectiveTest
class ReachableFlowTest extends FlowTestBase {
  test_conditional_false() async {
    Int value_1;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([Conditional(Bool(false), (value_1 = Int(1)), Int(2))])
    ]));
    verify(unreachableExpressions: [value_1]);
  }

  test_conditional_true() async {
    Int value_2;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([Conditional(Bool(true), Int(1), (value_2 = Int(2)))])
    ]));
    verify(unreachableExpressions: [value_2]);
  }

  test_do_false() async {
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Do(Block([Int(1)]), Bool(false)),
          Int(2)
        ])
    ]));
    verify();
  }

  test_do_true() async {
    Expression statement;
    Statement statement0;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = (statement0 = Block([
          Do(Block([Int(1)]), Bool(true)),
          (statement = Int(2))
        ]))
    ]));
    verify(
      unreachableStatements: [statement],
      functionBodiesThatDontComplete: [statement0],
    );
  }

  test_exit_beforeSplitStatement() async {
    Locals statement;
    Do statement0;
    ForExpr statement1;
    ForEachIdentifier statement2;
    If statement3;
    Switch statement4;
    Try statement5;
    While statement6;
    Statement statement7;
    var b = Param(InterfaceType("bool"), "b");
    var i = Param(InterfaceType("int"), "i");
    var _ = Local("_");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, i])
        ..body = (statement7 = Block([
          Return(),
          (statement = Locals(InterfaceType("Object"), [_])),
          (statement0 = Do(Block([]), GetVariable(b))),
          (statement1 = ForExpr(null, null, [], Block([]))),
          (statement2 = ForEachIdentifier(_, ListLiteral(null, []), Block([]))),
          (statement3 = If(GetVariable(b), Block([]))),
          (statement4 = Switch(GetVariable(i), [])),
          (statement5 = Try(Block([]), [], Block([]))),
          (statement6 = While(GetVariable(b), Block([])))
        ]))
    ]));
    verify(
      unreachableStatements: [
        statement,
        statement0,
        statement1,
        statement2,
        statement3,
        statement5,
        statement4,
        statement6
      ],
      functionBodiesThatDontComplete: [statement7],
    );
  }

  test_for_condition_true() async {
    Expression statement;
    Statement statement0;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = (statement0 = Block([
          ForExpr(null, Bool(true), [], Block([Int(1)])),
          (statement = Int(2))
        ]))
    ]));
    verify(
      unreachableStatements: [statement],
      functionBodiesThatDontComplete: [statement0],
    );
  }

  test_for_condition_true_implicit() async {
    Expression statement;
    Statement statement0;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = (statement0 = Block([
          ForExpr(null, null, [], Block([Int(1)])),
          (statement = Int(2))
        ]))
    ]));
    verify(
      unreachableStatements: [statement],
      functionBodiesThatDontComplete: [statement0],
    );
  }

  test_forEach() async {
    var _ = Local("_");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Locals(InterfaceType("Object"), [_]),
          ForEachIdentifier(_, ListLiteral(null, [Int(0), Int(1), Int(2)]),
              Block([Int(1), Return()])),
          Int(2)
        ])
    ]));
    verify();
  }

  test_functionBody_hasReturn() async {
    Statement statement;
    await trackCode(Unit([
      Func(InterfaceType("int"), "f", [])
        ..body = (statement = Block([Return(Int(42))]))
    ]));
    verify(functionBodiesThatDontComplete: [statement]);
  }

  test_functionBody_noReturn() async {
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])..body = Block([Int(1)])
    ]));
    verify();
  }

  test_if_condition() async {
    var b = Param(InterfaceType("bool"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b])
        ..body = Block([
          If(GetVariable(b), Block([Int(1)]), Block([Int(2)])),
          Int(3)
        ])
    ]));
    verify();
  }

  test_if_false_then_else() async {
    Block statement;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          If(Bool(false), (statement = Block([Int(1)])), Block([])),
          Int(3)
        ])
    ]));
    verify(unreachableStatements: [statement]);
  }

  test_if_true_return() async {
    Expression statement;
    Statement statement0;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = (statement0 = Block([
          Int(1),
          If(Bool(true), Block([Return()])),
          (statement = Int(2))
        ]))
    ]));
    verify(
      unreachableStatements: [statement],
      functionBodiesThatDontComplete: [statement0],
    );
  }

  test_if_true_then_else() async {
    Block statement;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          If(Bool(true), Block([]), (statement = Block([Int(2)]))),
          Int(3)
        ])
    ]));
    verify(unreachableStatements: [statement]);
  }

  test_logicalAnd_leftFalse() async {
    Expression expression;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          And(Bool(false), (expression = Parens(Eq(GetVariable(x), Int(1)))))
        ])
    ]));
    verify(unreachableExpressions: [expression]);
  }

  test_logicalOr_leftTrue() async {
    Expression expression;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block(
            [Or(Bool(true), (expression = Parens(Eq(GetVariable(x), Int(1)))))])
    ]));
    verify(unreachableExpressions: [expression]);
  }

  test_switch_case_neverCompletes() async {
    Expression statement;
    var b = Param(InterfaceType("bool"), "b");
    var i = Param(InterfaceType("int"), "i");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, i])
        ..body = Block([
          Switch(GetVariable(i), [
            Case(
                [],
                Int(1),
                [
                  Int(1),
                  If(GetVariable(b), Block([Return()]), Block([Return()])),
                  (statement = Int(2))
                ])
          ]),
          Int(3)
        ])
    ]));
    verify(unreachableStatements: [statement]);
  }

  test_tryCatch() async {
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Try(Block([Int(1)]), [
            Catch(CatchVariable("_"), Block([Int(2)]))
          ]),
          Int(3)
        ])
    ]));
    verify();
  }

  test_tryCatch_return_body() async {
    Expression statement;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Try(Block([Int(1), Return(), (statement = Int(2))]), [
            Catch(CatchVariable("_"), Block([Int(3)]))
          ]),
          Int(4)
        ])
    ]));
    verify(unreachableStatements: [statement]);
  }

  test_tryCatch_return_catch() async {
    Expression statement;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Try(Block([Int(1)]), [
            Catch(CatchVariable("_"),
                Block([Int(2), Return(), (statement = Int(3))]))
          ]),
          Int(4)
        ])
    ]));
    verify(unreachableStatements: [statement]);
  }

  test_tryCatchFinally_return_body() async {
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Try(
              Block([Int(1), Return()]),
              [
                Catch(CatchVariable("_"), Block([Int(2)]))
              ],
              Block([Int(3)])),
          Int(4)
        ])
    ]));
    verify();
  }

  test_tryCatchFinally_return_bodyCatch() async {
    Expression statement;
    Statement statement0;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = (statement0 = Block([
          Try(
              Block([Int(1), Return()]),
              [
                Catch(CatchVariable("_"), Block([Int(2), Return()]))
              ],
              Block([Int(3)])),
          (statement = Int(4))
        ]))
    ]));
    verify(
      unreachableStatements: [statement],
      functionBodiesThatDontComplete: [statement0],
    );
  }

  test_tryCatchFinally_return_catch() async {
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Try(
              Block([Int(1)]),
              [
                Catch(CatchVariable("_"), Block([Int(2), Return()]))
              ],
              Block([Int(3)])),
          Int(4)
        ])
    ]));
    verify();
  }

  test_tryFinally_return_body() async {
    Expression statement;
    Statement statement0;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = (statement0 = Block([
          Try(Block([Int(1), Return()]), [], Block([Int(2)])),
          (statement = Int(3))
        ]))
    ]));
    verify(
      unreachableStatements: [statement],
      functionBodiesThatDontComplete: [statement0],
    );
  }

  test_while_false() async {
    Block statement;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          While(Bool(false), (statement = Block([Int(1)]))),
          Int(2)
        ])
    ]));
    verify(unreachableStatements: [statement]);
  }

  test_while_true() async {
    Expression statement;
    Expression statement0;
    Statement statement1;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = (statement1 = Block([
          While(Bool(true), Block([Int(1)])),
          (statement = Int(2)),
          (statement0 = Int(3))
        ]))
    ]));
    verify(
      unreachableStatements: [statement, statement0],
      functionBodiesThatDontComplete: [statement1],
    );
  }

  test_while_true_break() async {
    Expression statement;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          While(Bool(true), Block([Int(1), Break(), (statement = Int(2))])),
          Int(3)
        ])
    ]));
    verify(unreachableStatements: [statement]);
  }

  test_while_true_breakIf() async {
    var b = Param(InterfaceType("bool"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b])
        ..body = Block([
          While(
              Bool(true), Block([Int(1), If(GetVariable(b), Break()), Int(2)])),
          Int(3)
        ])
    ]));
    verify();
  }

  test_while_true_continue() async {
    Expression statement;
    Expression statement0;
    Statement statement1;
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = (statement1 = Block([
          While(Bool(true), Block([Int(1), Continue(), (statement = Int(2))])),
          (statement0 = Int(3))
        ]))
    ]));
    verify(
      unreachableStatements: [statement, statement0],
      functionBodiesThatDontComplete: [statement1],
    );
  }

  void verify({
    List<Expression> unreachableExpressions = const [],
    List<Statement> unreachableStatements = const [],
    List<Statement> functionBodiesThatDontComplete = const [],
  }) {
    var expectedUnreachableNodes = <Statement>[];
    expectedUnreachableNodes.addAll(unreachableStatements);
    expectedUnreachableNodes.addAll(unreachableExpressions);

    expect(
      flowResult.unreachableNodes,
      unorderedEquals(expectedUnreachableNodes),
    );
    expect(
      flowResult.functionBodiesThatDontComplete,
      unorderedEquals(functionBodiesThatDontComplete),
    );
  }
}

@reflectiveTest
class TypePromotionFlowTest extends FlowTestBase {
  void assertElementTypeString(DartType type, String expectedType) {
    expect(type.toString(), expectedType);
  }

  void assertNotPromoted(Get node) {
    var actualType = flowResult.promotedTypes[node];
    expect(actualType, isNull, reason: node.toString());
  }

  void assertPromoted(Get node, String expectedType) {
    var actualType = flowResult.promotedTypes[node];
    if (actualType == null) {
      fail('$expectedType expected, but actually not promoted\n$node');
    }
    assertElementTypeString(actualType, expectedType);
  }

  test_assignment() async {
    GetVariable x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(null, "f", [x])
        ..body = Block([
          If(Is(GetVariable(x), InterfaceType("String")),
              Block([SetVariable(x, Int(42)), (x0 = GetVariable(x))]))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_binaryExpression_ifNull() async {
    GetVariable x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          IfNull(
              Parens(Or(Parens(Is(GetVariable(x), InterfaceType("num"))),
                  Parens(Throw(Int(1))))),
              Parens(Or(Parens(Is(GetVariable(x), InterfaceType("int"))),
                  Parens(Throw(Int(2)))))),
          (x0 = GetVariable(x))
        ])
    ]));
    assertPromoted(x0, 'num');
  }

  test_binaryExpression_ifNull_rightUnPromote() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("Object"), "x");
    var y = Param(InterfaceType("Object"), "y");
    var z = Param(InterfaceType("Object"), "z");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x, y, z])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("int")),
              Block([
                (x0 = GetVariable(x)),
                IfNull(GetVariable(y), Parens(SetVariable(x, GetVariable(z)))),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'int');
    assertNotPromoted(x1);
  }

  test_conditional_both() async {
    GetVariable x0;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          Conditional(
              GetVariable(b),
              Parens(Or(Parens(Is(GetVariable(x), InterfaceType("num"))),
                  Parens(Throw(Int(1))))),
              Parens(Or(Parens(Is(GetVariable(x), InterfaceType("int"))),
                  Parens(Throw(Int(2)))))),
          (x0 = GetVariable(x))
        ])
    ]));
    assertPromoted(x0, 'num');
  }

  test_conditional_else() async {
    GetVariable x0;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          Conditional(
              GetVariable(b),
              Int(0),
              Parens(Or(Parens(Is(GetVariable(x), InterfaceType("int"))),
                  Parens(Throw(Int(2)))))),
          (x0 = GetVariable(x))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_conditional_then() async {
    GetVariable x0;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          Conditional(
              GetVariable(b),
              Parens(Or(Parens(Is(GetVariable(x), InterfaceType("num"))),
                  Parens(Throw(Int(1))))),
              Int(0)),
          (x0 = GetVariable(x))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_do_condition_isNotType() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Do(Block([(x0 = GetVariable(x)), SetVariable(x, StringLiteral(""))]),
              Is(GetVariable(x), InterfaceType("String"))),
          (x1 = GetVariable(x))
        ])
    ]));
    assertNotPromoted(x0);
    assertPromoted(x1, 'String');
  }

  test_do_condition_isType() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Do(Block([(x0 = GetVariable(x))]),
              Is(GetVariable(x), InterfaceType("String"))),
          (x1 = GetVariable(x))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_do_outerIsType() async {
    GetVariable x0;
    GetVariable x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                Do(Block([(x0 = GetVariable(x))]), GetVariable(b)),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
  }

  test_do_outerIsType_loopAssigned_body() async {
    GetVariable x0;
    GetVariable x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                Do(
                    Block([
                      (x0 = GetVariable(x)),
                      SetVariable(x, PropertyGet(GetVariable(x), "length"))
                    ]),
                    GetVariable(b)),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_do_outerIsType_loopAssigned_condition() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [Param(InterfaceType("bool"), "b"), x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                Do(
                    Block([
                      (x0 = GetVariable(x)),
                      SetVariable(x, PropertyGet(GetVariable(x), "length"))
                    ]),
                    NotEq((x1 = GetVariable(x)), Int(0))),
                (x2 = GetVariable(x))
              ]))
        ])
    ]));
    assertNotPromoted(x1);
    assertNotPromoted(x0);
    assertNotPromoted(x2);
  }

  test_do_outerIsType_loopAssigned_condition2() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [Param(InterfaceType("bool"), "b"), x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                Do(Block([(x0 = GetVariable(x))]),
                    NotEq(Parens(SetVariable(x, Int(1))), Int(0))),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_for_outerIsType() async {
    GetVariable x0;
    GetVariable x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                ForExpr(
                    null, GetVariable(b), [], Block([(x0 = GetVariable(x))])),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
  }

  test_for_outerIsType_loopAssigned_body() async {
    GetVariable x0;
    GetVariable x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                ForExpr(null, GetVariable(b), [],
                    Block([(x0 = GetVariable(x)), SetVariable(x, Int(42))])),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_for_outerIsType_loopAssigned_condition() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                ForExpr(null, Gt(Parens(SetVariable(x, Int(42))), Int(0)), [],
                    Block([(x0 = GetVariable(x))])),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_for_outerIsType_loopAssigned_updaters() async {
    GetVariable x0;
    GetVariable x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                ForExpr(null, GetVariable(b), [SetVariable(x, Int(42))],
                    Block([(x0 = GetVariable(x))])),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_forEach_outerIsType_loopAssigned() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("Object"), "x");
    var v1 = Local("v1");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Locals(InterfaceType("Object"), [v1]),
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                ForEachDeclared(
                    ForEachVariable(null, "_"),
                    Parens(SetVariable(
                        v1, ListLiteral(null, [Int(0), Int(1), Int(2)]))),
                    Block([(x0 = GetVariable(x)), SetVariable(x, Int(42))])),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_functionExpression_isType() async {
    GetVariable x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Func(InterfaceType("void"), "g", [x])
            ..body = Block([
              If(Is(GetVariable(x), InterfaceType("String")),
                  Block([(x0 = GetVariable(x))])),
              SetVariable(x, Int(42))
            ])
        ])
    ]));
    assertPromoted(x0, 'String');
  }

  test_functionExpression_isType_mutatedInClosure2() async {
    GetVariable x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Func(InterfaceType("void"), "g", [x])
            ..body = Block([
              If(Is(GetVariable(x), InterfaceType("String")),
                  Block([(x0 = GetVariable(x))])),
              Func(InterfaceType("void"), "h", [])
                ..body = Block([SetVariable(x, Int(42))])
            ])
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_functionExpression_outerIsType_assignedOutside() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    var x = Param(InterfaceType("Object"), "x");
    var g = Local("g");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Locals(FunctionType(InterfaceType("void"), []), [g]),
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                (x0 = GetVariable(x)),
                SetVariable(g, Closure([], Block([(x1 = GetVariable(x))])))
              ])),
          SetVariable(x, Int(42)),
          (x2 = GetVariable(x)),
          CallVariable(g, [])
        ])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
    assertNotPromoted(x2);
  }

  test_if_combine_empty() async {
    GetVariable v0;
    var b = Param(InterfaceType("bool"), "b");
    var v = Param(InterfaceType("Object"), "v");
    await trackCode(Unit([
      Func(null, "main", [b, v])
        ..body = Block([
          If(
              GetVariable(b),
              Block([
                Or(Is(GetVariable(v), InterfaceType("int")),
                    Parens(Throw(Int(1))))
              ]),
              Block([
                Or(Is(GetVariable(v), InterfaceType("String")),
                    Parens(Throw(Int(2))))
              ])),
          (v0 = GetVariable(v))
        ])
    ]));
    assertNotPromoted(v0);
  }

  test_if_conditional_isNotType() async {
    GetVariable v0;
    GetVariable v1;
    GetVariable v2;
    var b = Param(InterfaceType("bool"), "b");
    var v = Param(InterfaceType("Object"), "v");
    await trackCode(Unit([
      Func(null, "f", [b, v])
        ..body = Block([
          If(
              Conditional(
                  GetVariable(b),
                  Parens(Is(GetVariable(v), InterfaceType("int"))),
                  Parens(Is(GetVariable(v), InterfaceType("num")))),
              Block([(v0 = GetVariable(v))]),
              Block([(v1 = GetVariable(v))])),
          (v2 = GetVariable(v))
        ])
    ]));
    assertNotPromoted(v0);
    assertPromoted(v1, 'num');
    assertNotPromoted(v2);
  }

  test_if_conditional_isType() async {
    GetVariable v0;
    GetVariable v1;
    GetVariable v2;
    var b = Param(InterfaceType("bool"), "b");
    var v = Param(InterfaceType("Object"), "v");
    await trackCode(Unit([
      Func(null, "f", [b, v])
        ..body = Block([
          If(
              Conditional(
                  GetVariable(b),
                  Parens(Is(GetVariable(v), InterfaceType("int"))),
                  Parens(Is(GetVariable(v), InterfaceType("num")))),
              Block([(v0 = GetVariable(v))]),
              Block([(v1 = GetVariable(v))])),
          (v2 = GetVariable(v))
        ])
    ]));
    assertPromoted(v0, 'num');
    assertNotPromoted(v1);
    assertNotPromoted(v2);
  }

  test_if_isNotType() async {
    GetVariable v0;
    GetVariable v1;
    GetVariable v2;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          If(Is(GetVariable(v), InterfaceType("String")),
              Block([(v0 = GetVariable(v))]), Block([(v1 = GetVariable(v))])),
          (v2 = GetVariable(v))
        ])
    ]));
    assertNotPromoted(v0);
    assertPromoted(v1, 'String');
    assertNotPromoted(v2);
  }

  test_if_isNotType_return() async {
    GetVariable v0;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          If(Is(GetVariable(v), InterfaceType("String")), Return()),
          (v0 = GetVariable(v))
        ])
    ]));
    assertPromoted(v0, 'String');
  }

  test_if_isNotType_throw() async {
    GetVariable v0;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          If(Is(GetVariable(v), InterfaceType("String")), Throw(Int(42))),
          (v0 = GetVariable(v))
        ])
    ]));
    assertPromoted(v0, 'String');
  }

  test_if_isType() async {
    GetVariable v0;
    GetVariable v1;
    GetVariable v2;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          If(Is(GetVariable(v), InterfaceType("String")),
              Block([(v0 = GetVariable(v))]), Block([(v1 = GetVariable(v))])),
          (v2 = GetVariable(v))
        ])
    ]));
    assertPromoted(v0, 'String');
    assertNotPromoted(v1);
    assertNotPromoted(v2);
  }

  test_if_isType_thenNonBoolean() async {
    GetVariable x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(null, "f", [x])
        ..body = Block([
          If(NotEq(Parens(Is(GetVariable(x), InterfaceType("String"))), Int(3)),
              Block([(x0 = GetVariable(x))]))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_if_logicalNot_isType() async {
    GetVariable v0;
    GetVariable v1;
    GetVariable v2;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          If(Not(Parens(Is(GetVariable(v), InterfaceType("String")))),
              Block([(v0 = GetVariable(v))]), Block([(v1 = GetVariable(v))])),
          (v2 = GetVariable(v))
        ])
    ]));
    assertNotPromoted(v0);
    assertPromoted(v1, 'String');
    assertNotPromoted(v2);
  }

  test_if_then_isNotType_return() async {
    GetVariable x0;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              GetVariable(b),
              Block(
                  [If(Is(GetVariable(x), InterfaceType("String")), Return())])),
          (x0 = GetVariable(x))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_logicalOr_throw() async {
    GetVariable v0;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          Or(Is(GetVariable(v), InterfaceType("String")),
              Parens(Throw(Int(42)))),
          (v0 = GetVariable(v))
        ])
    ]));
    assertPromoted(v0, 'String');
  }

  test_potentiallyMutatedInClosure() async {
    GetVariable x0;
    var x = Param(InterfaceType("Object"), "x");
    var localFunction = Func(null, "localFunction", []);
    await trackCode(Unit([
      Func(null, "f", [x])
        ..body = Block([
          localFunction..body = Block([SetVariable(x, Int(42))]),
          If(Is(GetVariable(x), InterfaceType("String")),
              Block([StaticCall(localFunction, []), (x0 = GetVariable(x))]))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_potentiallyMutatedInScope() async {
    GetVariable x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(null, "f", [x])
        ..body = Block([
          If(Is(GetVariable(x), InterfaceType("String")),
              Block([(x0 = GetVariable(x))])),
          SetVariable(x, Int(42))
        ])
    ]));
    assertPromoted(x0, 'String');
  }

  test_switch_outerIsType_assignedInCase() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    var e = Param(InterfaceType("int"), "e");
    var x = Param(InterfaceType("Object"), "x");
    var L = Label("L");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [e, x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                Switch(GetVariable(e), [
                  Case([L], Int(1), [(x0 = GetVariable(x)), Break()]),
                  Case([], Int(2), [(x1 = GetVariable(x)), Break()]),
                  Case([], Int(3), [SetVariable(x, Int(42)), Continue(L)])
                ]),
                (x2 = GetVariable(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertPromoted(x1, 'String');
    assertNotPromoted(x2);
  }

  test_tryCatch_assigned_body() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    var x = Param(InterfaceType("Object"), "x");
    var g = Func(InterfaceType("void"), "g", []);
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(Is(GetVariable(x), InterfaceType("String")), Return()),
          (x0 = GetVariable(x)),
          Try(
              Block([
                SetVariable(x, Int(42)),
                StaticCall(g, []),
                If(Is(GetVariable(x), InterfaceType("String")), Return()),
                (x1 = GetVariable(x))
              ]),
              [Catch(CatchVariable("_"), Block([]))]),
          (x2 = GetVariable(x))
        ]),
      g..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
    assertNotPromoted(x2);
  }

  test_tryCatch_isNotType_exit_body() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(
              Block([
                If(Is(GetVariable(x), InterfaceType("String")), Return()),
                (x0 = GetVariable(x))
              ]),
              [Catch(CatchVariable("_"), Block([]))]),
          (x1 = GetVariable(x))
        ]),
      Func(InterfaceType("void"), "g", [])..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
  }

  test_tryCatch_isNotType_exit_body_catch() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(
              Block([
                If(Is(GetVariable(x), InterfaceType("String")), Return()),
                (x0 = GetVariable(x))
              ]),
              [
                Catch(
                    CatchVariable("_"),
                    Block([
                      If(Is(GetVariable(x), InterfaceType("String")), Return()),
                      (x1 = GetVariable(x))
                    ]))
              ]),
          (x2 = GetVariable(x))
        ]),
      Func(InterfaceType("void"), "g", [])..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
    assertPromoted(x2, 'String');
  }

  test_tryCatch_isNotType_exit_body_catchRethrow() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(
              Block([
                If(Is(GetVariable(x), InterfaceType("String")), Return()),
                (x0 = GetVariable(x))
              ]),
              [
                Catch(CatchVariable("_"),
                    Block([(x1 = GetVariable(x)), Rethrow()]))
              ]),
          (x2 = GetVariable(x))
        ]),
      Func(InterfaceType("void"), "g", [])..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
    assertPromoted(x2, 'String');
  }

  test_tryCatch_isNotType_exit_catch() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(Block([]), [
            Catch(
                CatchVariable("_"),
                Block([
                  If(Is(GetVariable(x), InterfaceType("String")), Return()),
                  (x0 = GetVariable(x))
                ]))
          ]),
          (x1 = GetVariable(x))
        ]),
      Func(InterfaceType("void"), "g", [])..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
  }

  test_tryCatchFinally_outerIsType() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    GetVariable x3;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                Try(
                    Block([(x0 = GetVariable(x))]),
                    [
                      Catch(CatchVariable("_"), Block([(x1 = GetVariable(x))]))
                    ],
                    Block([(x2 = GetVariable(x))])),
                (x3 = GetVariable(x))
              ]))
        ]),
      Func(InterfaceType("void"), "g", [])..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
    assertPromoted(x2, 'String');
    assertPromoted(x3, 'String');
  }

  test_tryCatchFinally_outerIsType_assigned_body() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    GetVariable x3;
    var x = Param(InterfaceType("Object"), "x");
    var g = Func(InterfaceType("void"), "g", []);
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                Try(
                    Block([
                      (x0 = GetVariable(x)),
                      SetVariable(x, Int(42)),
                      StaticCall(g, [])
                    ]),
                    [
                      Catch(CatchVariable("_"), Block([(x1 = GetVariable(x))]))
                    ],
                    Block([(x2 = GetVariable(x))])),
                (x3 = GetVariable(x))
              ]))
        ]),
      g..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
    assertNotPromoted(x2);
    assertNotPromoted(x3);
  }

  test_tryCatchFinally_outerIsType_assigned_catch() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    GetVariable x3;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                Try(
                    Block([(x0 = GetVariable(x))]),
                    [
                      Catch(
                          CatchVariable("_"),
                          Block(
                              [(x1 = GetVariable(x)), SetVariable(x, Int(42))]))
                    ],
                    Block([(x2 = GetVariable(x))])),
                (x3 = GetVariable(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
    assertNotPromoted(x2);
    assertNotPromoted(x3);
  }

  test_tryFinally_outerIsType_assigned_body() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                Try(Block([(x0 = GetVariable(x)), SetVariable(x, Int(42))]), [],
                    Block([(x1 = GetVariable(x))])),
                (x2 = GetVariable(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
    assertNotPromoted(x2);
  }

  test_tryFinally_outerIsType_assigned_finally() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                Try(Block([(x0 = GetVariable(x))]), [],
                    Block([(x1 = GetVariable(x)), SetVariable(x, Int(42))])),
                (x2 = GetVariable(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
    assertNotPromoted(x2);
  }

  test_while_condition_false() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          While(Is(GetVariable(x), InterfaceType("String")),
              Block([(x0 = GetVariable(x))])),
          (x1 = GetVariable(x))
        ])
    ]));
    assertNotPromoted(x0);
    assertPromoted(x1, 'String');
  }

  test_while_condition_true() async {
    GetVariable x0;
    GetVariable x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          While(Is(GetVariable(x), InterfaceType("String")),
              Block([(x0 = GetVariable(x))])),
          (x1 = GetVariable(x))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
  }

  test_while_outerIsType() async {
    GetVariable x0;
    GetVariable x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                While(GetVariable(b), Block([(x0 = GetVariable(x))])),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
  }

  test_while_outerIsType_loopAssigned_body() async {
    GetVariable x0;
    GetVariable x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                While(
                    GetVariable(b),
                    Block([
                      (x0 = GetVariable(x)),
                      SetVariable(x, PropertyGet(GetVariable(x), "length"))
                    ])),
                (x1 = GetVariable(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_while_outerIsType_loopAssigned_condition() async {
    GetVariable x0;
    GetVariable x1;
    GetVariable x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [Param(InterfaceType("bool"), "b"), x])
        ..body = Block([
          If(
              Is(GetVariable(x), InterfaceType("String")),
              Block([
                While(
                    NotEq((x0 = GetVariable(x)), Int(0)),
                    Block([
                      (x1 = GetVariable(x)),
                      SetVariable(x, PropertyGet(GetVariable(x), "length"))
                    ])),
                (x2 = GetVariable(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
    assertNotPromoted(x2);
  }
}
