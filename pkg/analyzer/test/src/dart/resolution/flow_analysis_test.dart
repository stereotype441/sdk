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
    Get x0;
    Get x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(NotEq(Get(x), NullLiteral()), Return()),
          (x0 = Get(x)),
          Set(x, Int(0)),
          (x1 = Get(x))
        ])
    ]));
    assertNullable(x0);
    assertNonNullable(x1);
  }

  test_assign_toNull() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(Eq(Get(x), NullLiteral()), Return()),
          (x0 = Get(x)),
          Set(x, NullLiteral()),
          (x1 = Get(x))
        ])
    ]));
    assertNullable(x1);
    assertNonNullable(x0);
  }

  test_assign_toUnknown_fromNotNull() async {
    Get a0;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(Eq(Get(a), NullLiteral()), Return()),
          (a0 = Get(a)),
          Set(a, Get(b)),
          Get(a)
        ])
    ]));
    assertNullable();
    assertNonNullable(a0);
  }

  test_assign_toUnknown_fromNull() async {
    Get a0;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(NotEq(Get(a), NullLiteral()), Return()),
          (a0 = Get(a)),
          Set(a, Get(b)),
          Get(a)
        ])
    ]));
    assertNullable(a0);
    assertNonNullable();
  }

  test_binaryExpression_logicalAnd() async {
    Get x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          And(Eq(Get(x), NullLiteral()), PropertyGet((x0 = Get(x)), "isEven"))
        ])
    ]));
    assertNullable(x0);
    assertNonNullable();
  }

  test_binaryExpression_logicalOr() async {
    Get x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Or(Eq(Get(x), NullLiteral()), PropertyGet((x0 = Get(x)), "isEven"))
        ])
    ]));
    assertNullable();
    assertNonNullable(x0);
  }

  test_constructor_if_then_else() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Class("C", [
        Constructor(
            null,
            [x],
            Block([
              If(Eq(Get(x), NullLiteral()), Block([(x0 = Get(x))]),
                  Block([(x1 = Get(x))]))
            ]))
      ])
    ]));
    assertNullable(x0);
    assertNonNullable(x1);
  }

  test_if_joinThenElse_ifNull() async {
    Get a0;
    Get b0;
    Get a1;
    Get b1;
    Get b2;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(
              Eq(Get(a), NullLiteral()),
              Block([
                (a0 = Get(a)),
                If(Eq(Get(b), NullLiteral()), Return()),
                (b0 = Get(b))
              ]),
              Block([
                (a1 = Get(a)),
                If(Eq(Get(b), NullLiteral()), Return()),
                (b1 = Get(b))
              ])),
          Get(a),
          (b2 = Get(b))
        ])
    ]));
    assertNullable(a0);
    assertNonNullable(b0, a1, b1, b2);
  }

  test_if_notNull_thenExit_left() async {
    Get x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body =
            Block([If(NotEq(NullLiteral(), Get(x)), Return()), (x0 = Get(x))])
    ]));
    assertNullable(x0);
    assertNonNullable();
  }

  test_if_notNull_thenExit_right() async {
    Get x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body =
            Block([If(NotEq(Get(x), NullLiteral()), Return()), (x0 = Get(x))])
    ]));
    assertNullable(x0);
    assertNonNullable();
  }

  test_if_null_thenExit_left() async {
    Get x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([If(Eq(NullLiteral(), Get(x)), Return()), (x0 = Get(x))])
    ]));
    assertNullable();
    assertNonNullable(x0);
  }

  test_if_null_thenExit_right() async {
    Get x0;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([If(Eq(Get(x), NullLiteral()), Return()), (x0 = Get(x))])
    ]));
    assertNullable();
    assertNonNullable(x0);
  }

  test_if_then_else() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(Eq(Get(x), NullLiteral()), Block([(x0 = Get(x))]),
              Block([(x1 = Get(x))]))
        ])
    ]));
    assertNullable(x0);
    assertNonNullable(x1);
  }

  test_method_if_then_else() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Class("C", [
        Method(
            InterfaceType("void"),
            "f",
            [x],
            Block([
              If(Eq(Get(x), NullLiteral()), Block([(x0 = Get(x))]),
                  Block([(x1 = Get(x))]))
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
          localFunction..body = Block([Set(a, Get(b))]),
          If(Eq(Get(a), NullLiteral()),
              Block([Get(a), StaticCall(localFunction, []), Get(a)]))
        ])
    ]));
    assertNullable();
    assertNonNullable();
  }

  test_tryFinally_eqNullExit_body() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(Block([If(Eq(Get(x), NullLiteral()), Return()), (x0 = Get(x))]),
              [], Block([Get(x)])),
          (x1 = Get(x))
        ])
    ]));
    assertNullable();
    assertNonNullable(x0, x1);
  }

  test_tryFinally_eqNullExit_finally() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(Block([Get(x)]), [],
              Block([If(Eq(Get(x), NullLiteral()), Return()), (x0 = Get(x))])),
          (x1 = Get(x))
        ])
    ]));
    assertNullable();
    assertNonNullable(x0, x1);
  }

  test_tryFinally_outerEqNotNullExit_assignUnknown_body() async {
    Get a0;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(NotEq(Get(a), NullLiteral()), Return()),
          Try(Block([(a0 = Get(a)), Set(a, Get(b)), Get(a)]), [],
              Block([Get(a)])),
          Get(a)
        ])
    ]));
    assertNullable(a0);
    assertNonNullable();
  }

  test_tryFinally_outerEqNullExit_assignUnknown_body() async {
    Get a0;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(Eq(Get(a), NullLiteral()), Return()),
          Try(Block([(a0 = Get(a)), Set(a, Get(b)), Get(a)]), [],
              Block([Get(a)])),
          Get(a)
        ])
    ]));
    assertNullable();
    assertNonNullable(a0);
  }

  test_tryFinally_outerEqNullExit_assignUnknown_finally() async {
    Get a0;
    Get a1;
    var a = Param(InterfaceType("int"), "a");
    var b = Param(InterfaceType("int"), "b");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [a, b])
        ..body = Block([
          If(Eq(Get(a), NullLiteral()), Return()),
          Try(Block([(a0 = Get(a))]), [],
              Block([(a1 = Get(a)), Set(a, Get(b)), Get(a)])),
          Get(a)
        ])
    ]));
    assertNullable();
    assertNonNullable(a0, a1);
  }

  test_while_eqNull() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          While(Eq(Get(x), NullLiteral()), Block([(x0 = Get(x))])),
          (x1 = Get(x))
        ])
    ]));
    assertNullable(x0);
    assertNonNullable(x1);
  }

  test_while_notEqNull() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          While(NotEq(Get(x), NullLiteral()), Block([(x0 = Get(x))])),
          (x1 = Get(x))
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
          (statement0 = Do(Block([]), Get(b))),
          (statement1 = ForExpr(null, null, [], Block([]))),
          (statement2 = ForEachIdentifier(_, ListLiteral(null, []), Block([]))),
          (statement3 = If(Get(b), Block([]))),
          (statement4 = Switch(Get(i), [])),
          (statement5 = Try(Block([]), [], Block([]))),
          (statement6 = While(Get(b), Block([])))
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
          If(Get(b), Block([Int(1)]), Block([Int(2)])),
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
        ..body =
            Block([And(Bool(false), (expression = Parens(Eq(Get(x), Int(1)))))])
    ]));
    verify(unreachableExpressions: [expression]);
  }

  test_logicalOr_leftTrue() async {
    Expression expression;
    var x = Param(InterfaceType("int"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body =
            Block([Or(Bool(true), (expression = Parens(Eq(Get(x), Int(1)))))])
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
          Switch(Get(i), [
            Case(
                [],
                Int(1),
                [
                  Int(1),
                  If(Get(b), Block([Return()]), Block([Return()])),
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
          While(Bool(true), Block([Int(1), If(Get(b), Break()), Int(2)])),
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
    Get x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(null, "f", [x])
        ..body = Block([
          If(Is(Get(x), InterfaceType("String")),
              Block([Set(x, Int(42)), (x0 = Get(x))]))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_binaryExpression_ifNull() async {
    Get x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          IfNull(
              Parens(Or(Parens(Is(Get(x), InterfaceType("num"))),
                  Parens(Throw(Int(1))))),
              Parens(Or(Parens(Is(Get(x), InterfaceType("int"))),
                  Parens(Throw(Int(2)))))),
          (x0 = Get(x))
        ])
    ]));
    assertPromoted(x0, 'num');
  }

  test_binaryExpression_ifNull_rightUnPromote() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("Object"), "x");
    var y = Param(InterfaceType("Object"), "y");
    var z = Param(InterfaceType("Object"), "z");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x, y, z])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("int")),
              Block([
                (x0 = Get(x)),
                IfNull(Get(y), Parens(Set(x, Get(z)))),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'int');
    assertNotPromoted(x1);
  }

  test_conditional_both() async {
    Get x0;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          Conditional(
              Get(b),
              Parens(Or(Parens(Is(Get(x), InterfaceType("num"))),
                  Parens(Throw(Int(1))))),
              Parens(Or(Parens(Is(Get(x), InterfaceType("int"))),
                  Parens(Throw(Int(2)))))),
          (x0 = Get(x))
        ])
    ]));
    assertPromoted(x0, 'num');
  }

  test_conditional_else() async {
    Get x0;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          Conditional(
              Get(b),
              Int(0),
              Parens(Or(Parens(Is(Get(x), InterfaceType("int"))),
                  Parens(Throw(Int(2)))))),
          (x0 = Get(x))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_conditional_then() async {
    Get x0;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          Conditional(
              Get(b),
              Parens(Or(Parens(Is(Get(x), InterfaceType("num"))),
                  Parens(Throw(Int(1))))),
              Int(0)),
          (x0 = Get(x))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_do_condition_isNotType() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Do(Block([(x0 = Get(x)), Set(x, StringLiteral(""))]),
              Is(Get(x), InterfaceType("String"))),
          (x1 = Get(x))
        ])
    ]));
    assertNotPromoted(x0);
    assertPromoted(x1, 'String');
  }

  test_do_condition_isType() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Do(Block([(x0 = Get(x))]), Is(Get(x), InterfaceType("String"))),
          (x1 = Get(x))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_do_outerIsType() async {
    Get x0;
    Get x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                Do(Block([(x0 = Get(x))]), Get(b)),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
  }

  test_do_outerIsType_loopAssigned_body() async {
    Get x0;
    Get x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                Do(
                    Block(
                        [(x0 = Get(x)), Set(x, PropertyGet(Get(x), "length"))]),
                    Get(b)),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_do_outerIsType_loopAssigned_condition() async {
    Get x0;
    Get x1;
    Get x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [Param(InterfaceType("bool"), "b"), x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                Do(
                    Block(
                        [(x0 = Get(x)), Set(x, PropertyGet(Get(x), "length"))]),
                    NotEq((x1 = Get(x)), Int(0))),
                (x2 = Get(x))
              ]))
        ])
    ]));
    assertNotPromoted(x1);
    assertNotPromoted(x0);
    assertNotPromoted(x2);
  }

  test_do_outerIsType_loopAssigned_condition2() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [Param(InterfaceType("bool"), "b"), x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                Do(Block([(x0 = Get(x))]),
                    NotEq(Parens(Set(x, Int(1))), Int(0))),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_for_outerIsType() async {
    Get x0;
    Get x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                ForExpr(null, Get(b), [], Block([(x0 = Get(x))])),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
  }

  test_for_outerIsType_loopAssigned_body() async {
    Get x0;
    Get x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                ForExpr(
                    null, Get(b), [], Block([(x0 = Get(x)), Set(x, Int(42))])),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_for_outerIsType_loopAssigned_condition() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                ForExpr(null, Gt(Parens(Set(x, Int(42))), Int(0)), [],
                    Block([(x0 = Get(x))])),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_for_outerIsType_loopAssigned_updaters() async {
    Get x0;
    Get x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                ForExpr(
                    null, Get(b), [Set(x, Int(42))], Block([(x0 = Get(x))])),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_forEach_outerIsType_loopAssigned() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("Object"), "x");
    var v1 = Local("v1");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Locals(InterfaceType("Object"), [v1]),
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                ForEachDeclared(
                    ForEachVariable(null, "_"),
                    Parens(
                        Set(v1, ListLiteral(null, [Int(0), Int(1), Int(2)]))),
                    Block([(x0 = Get(x)), Set(x, Int(42))])),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_functionExpression_isType() async {
    Get x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Func(InterfaceType("void"), "g", [x])
            ..body = Block([
              If(Is(Get(x), InterfaceType("String")), Block([(x0 = Get(x))])),
              Set(x, Int(42))
            ])
        ])
    ]));
    assertPromoted(x0, 'String');
  }

  test_functionExpression_isType_mutatedInClosure2() async {
    Get x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [])
        ..body = Block([
          Func(InterfaceType("void"), "g", [x])
            ..body = Block([
              If(Is(Get(x), InterfaceType("String")), Block([(x0 = Get(x))])),
              Func(InterfaceType("void"), "h", [])
                ..body = Block([Set(x, Int(42))])
            ])
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_functionExpression_outerIsType_assignedOutside() async {
    Get x0;
    Get x1;
    Get x2;
    var x = Param(InterfaceType("Object"), "x");
    var g = Local("g");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Locals(FunctionType(InterfaceType("void"), []), [g]),
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                (x0 = Get(x)),
                Set(g, Closure([], Block([(x1 = Get(x))])))
              ])),
          Set(x, Int(42)),
          (x2 = Get(x)),
          LocalCall(g, [])
        ])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
    assertNotPromoted(x2);
  }

  test_if_combine_empty() async {
    Get v0;
    var b = Param(InterfaceType("bool"), "b");
    var v = Param(InterfaceType("Object"), "v");
    await trackCode(Unit([
      Func(null, "main", [b, v])
        ..body = Block([
          If(
              Get(b),
              Block([
                Or(Is(Get(v), InterfaceType("int")), Parens(Throw(Int(1))))
              ]),
              Block([
                Or(Is(Get(v), InterfaceType("String")), Parens(Throw(Int(2))))
              ])),
          (v0 = Get(v))
        ])
    ]));
    assertNotPromoted(v0);
  }

  test_if_conditional_isNotType() async {
    Get v0;
    Get v1;
    Get v2;
    var b = Param(InterfaceType("bool"), "b");
    var v = Param(InterfaceType("Object"), "v");
    await trackCode(Unit([
      Func(null, "f", [b, v])
        ..body = Block([
          If(
              Conditional(Get(b), Parens(Is(Get(v), InterfaceType("int"))),
                  Parens(Is(Get(v), InterfaceType("num")))),
              Block([(v0 = Get(v))]),
              Block([(v1 = Get(v))])),
          (v2 = Get(v))
        ])
    ]));
    assertNotPromoted(v0);
    assertPromoted(v1, 'num');
    assertNotPromoted(v2);
  }

  test_if_conditional_isType() async {
    Get v0;
    Get v1;
    Get v2;
    var b = Param(InterfaceType("bool"), "b");
    var v = Param(InterfaceType("Object"), "v");
    await trackCode(Unit([
      Func(null, "f", [b, v])
        ..body = Block([
          If(
              Conditional(Get(b), Parens(Is(Get(v), InterfaceType("int"))),
                  Parens(Is(Get(v), InterfaceType("num")))),
              Block([(v0 = Get(v))]),
              Block([(v1 = Get(v))])),
          (v2 = Get(v))
        ])
    ]));
    assertPromoted(v0, 'num');
    assertNotPromoted(v1);
    assertNotPromoted(v2);
  }

  test_if_isNotType() async {
    Get v0;
    Get v1;
    Get v2;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          If(Is(Get(v), InterfaceType("String")), Block([(v0 = Get(v))]),
              Block([(v1 = Get(v))])),
          (v2 = Get(v))
        ])
    ]));
    assertNotPromoted(v0);
    assertPromoted(v1, 'String');
    assertNotPromoted(v2);
  }

  test_if_isNotType_return() async {
    Get v0;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block(
            [If(Is(Get(v), InterfaceType("String")), Return()), (v0 = Get(v))])
    ]));
    assertPromoted(v0, 'String');
  }

  test_if_isNotType_throw() async {
    Get v0;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          If(Is(Get(v), InterfaceType("String")), Throw(Int(42))),
          (v0 = Get(v))
        ])
    ]));
    assertPromoted(v0, 'String');
  }

  test_if_isType() async {
    Get v0;
    Get v1;
    Get v2;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          If(Is(Get(v), InterfaceType("String")), Block([(v0 = Get(v))]),
              Block([(v1 = Get(v))])),
          (v2 = Get(v))
        ])
    ]));
    assertPromoted(v0, 'String');
    assertNotPromoted(v1);
    assertNotPromoted(v2);
  }

  test_if_isType_thenNonBoolean() async {
    Get x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(null, "f", [x])
        ..body = Block([
          If(NotEq(Parens(Is(Get(x), InterfaceType("String"))), Int(3)),
              Block([(x0 = Get(x))]))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_if_logicalNot_isType() async {
    Get v0;
    Get v1;
    Get v2;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          If(Not(Parens(Is(Get(v), InterfaceType("String")))),
              Block([(v0 = Get(v))]), Block([(v1 = Get(v))])),
          (v2 = Get(v))
        ])
    ]));
    assertNotPromoted(v0);
    assertPromoted(v1, 'String');
    assertNotPromoted(v2);
  }

  test_if_then_isNotType_return() async {
    Get x0;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(Get(b),
              Block([If(Is(Get(x), InterfaceType("String")), Return())])),
          (x0 = Get(x))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_logicalOr_throw() async {
    Get v0;
    var v = Param(null, "v");
    await trackCode(Unit([
      Func(null, "main", [v])
        ..body = Block([
          Or(Is(Get(v), InterfaceType("String")), Parens(Throw(Int(42)))),
          (v0 = Get(v))
        ])
    ]));
    assertPromoted(v0, 'String');
  }

  test_potentiallyMutatedInClosure() async {
    Get x0;
    var x = Param(InterfaceType("Object"), "x");
    var localFunction = Func(null, "localFunction", []);
    await trackCode(Unit([
      Func(null, "f", [x])
        ..body = Block([
          localFunction..body = Block([Set(x, Int(42))]),
          If(Is(Get(x), InterfaceType("String")),
              Block([StaticCall(localFunction, []), (x0 = Get(x))]))
        ])
    ]));
    assertNotPromoted(x0);
  }

  test_potentiallyMutatedInScope() async {
    Get x0;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(null, "f", [x])
        ..body = Block([
          If(Is(Get(x), InterfaceType("String")), Block([(x0 = Get(x))])),
          Set(x, Int(42))
        ])
    ]));
    assertPromoted(x0, 'String');
  }

  test_switch_outerIsType_assignedInCase() async {
    Get x0;
    Get x1;
    Get x2;
    var e = Param(InterfaceType("int"), "e");
    var x = Param(InterfaceType("Object"), "x");
    var L = Label("L");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [e, x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                Switch(Get(e), [
                  Case([L], Int(1), [(x0 = Get(x)), Break()]),
                  Case([], Int(2), [(x1 = Get(x)), Break()]),
                  Case([], Int(3), [Set(x, Int(42)), Continue(L)])
                ]),
                (x2 = Get(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertPromoted(x1, 'String');
    assertNotPromoted(x2);
  }

  test_tryCatch_assigned_body() async {
    Get x0;
    Get x1;
    Get x2;
    var x = Param(InterfaceType("Object"), "x");
    var g = Func(InterfaceType("void"), "g", []);
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(Is(Get(x), InterfaceType("String")), Return()),
          (x0 = Get(x)),
          Try(
              Block([
                Set(x, Int(42)),
                StaticCall(g, []),
                If(Is(Get(x), InterfaceType("String")), Return()),
                (x1 = Get(x))
              ]),
              [Catch(CatchVariable("_"), Block([]))]),
          (x2 = Get(x))
        ]),
      g..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
    assertNotPromoted(x2);
  }

  test_tryCatch_isNotType_exit_body() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(
              Block([
                If(Is(Get(x), InterfaceType("String")), Return()),
                (x0 = Get(x))
              ]),
              [Catch(CatchVariable("_"), Block([]))]),
          (x1 = Get(x))
        ]),
      Func(InterfaceType("void"), "g", [])..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
  }

  test_tryCatch_isNotType_exit_body_catch() async {
    Get x0;
    Get x1;
    Get x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(
              Block([
                If(Is(Get(x), InterfaceType("String")), Return()),
                (x0 = Get(x))
              ]),
              [
                Catch(
                    CatchVariable("_"),
                    Block([
                      If(Is(Get(x), InterfaceType("String")), Return()),
                      (x1 = Get(x))
                    ]))
              ]),
          (x2 = Get(x))
        ]),
      Func(InterfaceType("void"), "g", [])..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
    assertPromoted(x2, 'String');
  }

  test_tryCatch_isNotType_exit_body_catchRethrow() async {
    Get x0;
    Get x1;
    Get x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(
              Block([
                If(Is(Get(x), InterfaceType("String")), Return()),
                (x0 = Get(x))
              ]),
              [
                Catch(CatchVariable("_"), Block([(x1 = Get(x)), Rethrow()]))
              ]),
          (x2 = Get(x))
        ]),
      Func(InterfaceType("void"), "g", [])..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
    assertPromoted(x2, 'String');
  }

  test_tryCatch_isNotType_exit_catch() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          Try(Block([]), [
            Catch(
                CatchVariable("_"),
                Block([
                  If(Is(Get(x), InterfaceType("String")), Return()),
                  (x0 = Get(x))
                ]))
          ]),
          (x1 = Get(x))
        ]),
      Func(InterfaceType("void"), "g", [])..body = Block([])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
  }

  test_tryCatchFinally_outerIsType() async {
    Get x0;
    Get x1;
    Get x2;
    Get x3;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                Try(
                    Block([(x0 = Get(x))]),
                    [
                      Catch(CatchVariable("_"), Block([(x1 = Get(x))]))
                    ],
                    Block([(x2 = Get(x))])),
                (x3 = Get(x))
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
    Get x0;
    Get x1;
    Get x2;
    Get x3;
    var x = Param(InterfaceType("Object"), "x");
    var g = Func(InterfaceType("void"), "g", []);
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                Try(
                    Block([(x0 = Get(x)), Set(x, Int(42)), StaticCall(g, [])]),
                    [
                      Catch(CatchVariable("_"), Block([(x1 = Get(x))]))
                    ],
                    Block([(x2 = Get(x))])),
                (x3 = Get(x))
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
    Get x0;
    Get x1;
    Get x2;
    Get x3;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                Try(
                    Block([(x0 = Get(x))]),
                    [
                      Catch(CatchVariable("_"),
                          Block([(x1 = Get(x)), Set(x, Int(42))]))
                    ],
                    Block([(x2 = Get(x))])),
                (x3 = Get(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
    assertNotPromoted(x2);
    assertNotPromoted(x3);
  }

  test_tryFinally_outerIsType_assigned_body() async {
    Get x0;
    Get x1;
    Get x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                Try(Block([(x0 = Get(x)), Set(x, Int(42))]), [],
                    Block([(x1 = Get(x))])),
                (x2 = Get(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
    assertNotPromoted(x2);
  }

  test_tryFinally_outerIsType_assigned_finally() async {
    Get x0;
    Get x1;
    Get x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                Try(Block([(x0 = Get(x))]), [],
                    Block([(x1 = Get(x)), Set(x, Int(42))])),
                (x2 = Get(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
    assertNotPromoted(x2);
  }

  test_while_condition_false() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          While(Is(Get(x), InterfaceType("String")), Block([(x0 = Get(x))])),
          (x1 = Get(x))
        ])
    ]));
    assertNotPromoted(x0);
    assertPromoted(x1, 'String');
  }

  test_while_condition_true() async {
    Get x0;
    Get x1;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [x])
        ..body = Block([
          While(Is(Get(x), InterfaceType("String")), Block([(x0 = Get(x))])),
          (x1 = Get(x))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertNotPromoted(x1);
  }

  test_while_outerIsType() async {
    Get x0;
    Get x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                While(Get(b), Block([(x0 = Get(x))])),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertPromoted(x0, 'String');
    assertPromoted(x1, 'String');
  }

  test_while_outerIsType_loopAssigned_body() async {
    Get x0;
    Get x1;
    var b = Param(InterfaceType("bool"), "b");
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [b, x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                While(
                    Get(b),
                    Block([
                      (x0 = Get(x)),
                      Set(x, PropertyGet(Get(x), "length"))
                    ])),
                (x1 = Get(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
  }

  test_while_outerIsType_loopAssigned_condition() async {
    Get x0;
    Get x1;
    Get x2;
    var x = Param(InterfaceType("Object"), "x");
    await trackCode(Unit([
      Func(InterfaceType("void"), "f", [Param(InterfaceType("bool"), "b"), x])
        ..body = Block([
          If(
              Is(Get(x), InterfaceType("String")),
              Block([
                While(
                    NotEq((x0 = Get(x)), Int(0)),
                    Block([
                      (x1 = Get(x)),
                      Set(x, PropertyGet(Get(x), "length"))
                    ])),
                (x2 = Get(x))
              ]))
        ])
    ]));
    assertNotPromoted(x0);
    assertNotPromoted(x1);
    assertNotPromoted(x2);
  }
}
