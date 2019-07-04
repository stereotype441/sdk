import 'package:analyzer/src/dart/resolver/flow_analysis.dart';

class And implements Expression {
  final Expression left;
  final Expression right;

  And(this.left, this.right);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitAnd(this);
}

class Block implements Statement {
  final List<Statement> statements;

  Block(this.statements);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitBlock(this);
}

class Bool implements Expression {
  final bool value;

  Bool(this.value);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitBool(this);
}

class Break implements Statement {
  final Label label;

  Break([this.label]);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitBreak(this);
}

class Case {
  final List<Label> labels;
  final Expression value;
  final List<Statement> body;

  Case(this.labels, this.value, this.body);

  R accept<R>(Visitor<R> visitor) => visitor.visitCase(this);
}

class Catch {
  final CatchVariable exception;
  final Statement body;

  Catch(this.exception, this.body);

  R accept<R>(Visitor<R> visitor) => visitor.visitCatch(this);
}

class CatchVariable {
  final String name;

  CatchVariable(this.name);
}

class Class implements Declaration {
  final String name;
  final List<Declaration> members;

  Class(this.name, this.members);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitClass(this);
}

class Closure implements Expression {
  final List<Param> parameters;
  Statement body;

  Closure(this.parameters, [this.body]);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitClosure(this);
}

class Conditional implements Expression {
  final Expression condition;
  final Expression thenExpression;
  final Expression elseExpression;

  Conditional(this.condition, this.thenExpression, this.elseExpression);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitConditional(this);
}

class Constructor implements Declaration {
  final String name;
  final List<Param> parameters;
  Statement body;

  Constructor(this.name, this.parameters, [this.body]);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitConstructor(this);
}

class Continue implements Statement {
  final Label label;

  Continue([this.label]);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitContinue();
}

abstract class DartType {
  factory DartType.LUB(DartType a, DartType b) {
    throw new UnimplementedError('TODO(paulberry)');
  }

  DartType._();

  static bool isSubtypeOf(DartType a, DartType b) {
    throw new UnimplementedError('TODO(paulberry)');
  }
}

abstract class Declaration {
  R accept<R>(Visitor<R> visitor);
}

class Do implements Statement {
  final Statement body;
  final Expression condition;

  Do(this.body, this.condition);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitDo(this);
}

abstract class Element {
  DartType get declaredType;

  bool get isPotentiallyMutatedInClosure;

  bool get isPotentiallyMutatedInScope;
}

class Eq implements Expression {
  final Expression left;
  final Expression right;

  Eq(this.left, this.right);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitEq(this);
}

abstract class Expression implements Statement {}

class FlowAnalysisDriver extends Visitor<DartType>
    implements
        FunctionBodyAccess<Element>,
        TypeOperations<Element, DartType>,
        NodeOperations<Expression> {
  FlowAnalysis<Statement, Expression, Element, DartType> _flowAnalysis;

  final _result = FlowAnalysisResult();

  FlowAnalysisDriver() {
    _flowAnalysis = FlowAnalysis<Statement, Expression, Element, DartType>(
        this, this, this);
  }

  @override
  defaultExpression() => throw UnimplementedError('Should be overridden');

  @override
  defaultNode() => null;

  @override
  defaultStatement() => null;

  @override
  DartType elementType(Element element) => element.declaredType;

  @override
  bool isLocalVariable(Element element) => element is Local;

  @override
  bool isPotentiallyMutatedInClosure(Element variable) =>
      variable.isPotentiallyMutatedInClosure;

  @override
  bool isPotentiallyMutatedInScope(Element variable) =>
      variable.isPotentiallyMutatedInScope;

  @override
  bool isSubtypeOf(DartType leftType, DartType rightType) =>
      DartType.isSubtypeOf(leftType, rightType);

  @override
  Expression unwrapParenthesized(Expression node) {
    while (node is Parens) {
      node = (node as Parens).contents;
    }
    return node;
  }

  DartType visitBool(Bool bool_) {
    _flowAnalysis.booleanLiteral(bool_, bool_.value);
    return InterfaceType('bool');
  }

  @override
  visitClosure(Closure closure) {
    for (var parameter in closure.parameters) {
      parameter.accept(this);
    }
    DartType bodyReturnType;
    var body = closure.body;
    if (body is Expression) {
      bodyReturnType = body.accept(this);
    } else {
      body.accept(this);
      bodyReturnType = VoidType();
    }
    return FunctionType(
        bodyReturnType, closure.parameters.map((p) => p.declaredType).toList());
  }

  DartType visitConditional(Conditional conditional) {
    conditional.condition.accept(this);
    _flowAnalysis.conditional_thenBegin(conditional, conditional.condition);
    var thenType = conditional.thenExpression.accept(this);
    bool isBool = thenType is InterfaceType && thenType.class_ == 'bool';
    _flowAnalysis.conditional_elseBegin(
        conditional, conditional.thenExpression, isBool);
    var elseType = conditional.elseExpression.accept(this);
    _flowAnalysis.conditional_end(
        conditional, conditional.elseExpression, isBool);
    return DartType.LUB(thenType, elseType);
  }

  DartType visitDo(Do do_) {
    _flowAnalysis.doStatement_bodyBegin(do_, _findAssignments(do_.body));
    do_.body.accept(this);
    _flowAnalysis.doStatement_conditionBegin();
    do_.condition.accept(this);
    _flowAnalysis.doStatement_end(do_, do_.condition);
    return null;
  }

  DartType visitGet(Get get) {
    return get.variable.declaredType;
  }

  DartType visitGt(Gt gt) {
    gt.left.accept(this);
    gt.right.accept(this);
    return InterfaceType('bool');
  }

  DartType visitIfNull(IfNull ifNull) {
    var leftType = ifNull.left.accept(this);
    var rightType = ifNull.right.accept(this);
    return DartType.LUB(leftType, rightType);
  }

  DartType visitInt(Int int) {
    return InterfaceType('int');
  }

  DartType visitIs(Is is_) {
    return InterfaceType('bool');
  }

  DartType visitListLiteral(ListLiteral listLiteral) {
    for (var value in listLiteral.values) {
      value.accept(this);
    }
    return InterfaceType('List', [listLiteral.type]);
  }

  DartType visitLocal(Local local) {
    // TODO(paulberry): test some examples of variables with initializers
    _flowAnalysis.add(local, assigned: false);
    return null;
  }

  DartType visitLocalCall(LocalCall localCall) {
    for (var argument in localCall.arguments) {
      argument.accept(this);
    }
    return (localCall.variable.declaredType as FunctionType).returnType;
  }

  DartType visitNot(Not not) {
    not.operand.accept(this);
    return InterfaceType('bool');
  }

  DartType visitNotEq(NotEq notEq) {
    notEq.left.accept(this);
    notEq.right.accept(this);
    return InterfaceType('bool');
  }

  DartType visitNullLiteral(NullLiteral nullLiteral) => NullType();

  DartType visitOr(Or or) {
    or.left.accept(this);
    or.right.accept(this);
    return InterfaceType('bool');
  }

  DartType visitParam(Param param) {
    _flowAnalysis.add(param);
    return null;
  }

  DartType visitPropertyGet(PropertyGet propertyGet) =>
      (propertyGet.target.accept(this) as InterfaceType)
          .getPropertyType(propertyGet.propertyName);

  DartType visitSet(Set set) {
    set.value.accept(this);
    return set.variable.declaredType;
  }

  DartType visitStaticCall(StaticCall staticCall) {
    for (var argument in staticCall.arguments) {
      argument.accept(this);
    }
    return staticCall.target.returnType;
  }

  DartType visitStringLiteral(StringLiteral stringLiteral) =>
      InterfaceType('String');

  DartType visitThrow(Throw throw_) {
    throw_.exception.accept(this);
    return InterfaceType('Never');
  }

  static FlowAnalysisResult run(Unit code) {
    var flowAnalyzer = FlowAnalysisDriver();
    code.accept(flowAnalyzer);
    return flowAnalyzer._result;
  }
}

class FlowAnalysisResult {
  final List<Get> nullableNodes = [];
  final List<Get> nonNullableNodes = [];
  final List<Statement> unreachableNodes = [];
  final List<Statement> functionBodiesThatDontComplete = [];
  final Map<Get, DartType> promotedTypes = {};
}

class ForEachDeclared implements Statement {
  final ForEachVariable variable;
  final Expression iterable;
  final Statement body;

  ForEachDeclared(this.variable, this.iterable, this.body);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitForEachDeclared(this);
}

class ForEachIdentifier implements Statement {
  final Variable variable;
  final Expression iterable;
  final Statement body;

  ForEachIdentifier(this.variable, this.iterable, this.body);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitForEachIdentifier(this);
}

class ForEachVariable {
  final DartType type;
  final String name;

  ForEachVariable(this.type, this.name);
}

class ForExpr implements Statement {
  final Expression initializer;
  final Expression condition;
  final List<Expression> updaters;
  final Statement body;

  ForExpr(this.initializer, this.condition, this.updaters, this.body);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitForExpr(this);
}

class Func implements Declaration, Statement {
  final DartType returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Func(this.returnType, this.name, this.parameters, [this.body]);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitFunc(this);
}

class FunctionType extends DartType {
  final DartType returnType;
  final List<DartType> paramTypes;

  FunctionType(this.returnType, this.paramTypes) : super._();

  String toString() => '$returnType Function(${paramTypes.join(', ')})';
}

class Get implements Expression {
  final Variable variable;

  Get(this.variable);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitGet(this);
}

class Gt implements Expression {
  final Expression left;
  final Expression right;

  Gt(this.left, this.right);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitGt(this);
}

class If implements Statement {
  final Expression condition;
  final Statement thenStatement;
  final Statement elseStatement;

  If(this.condition, this.thenStatement, [this.elseStatement]);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitIf(this);
}

class IfNull implements Expression {
  final Expression left;
  final Expression right;

  IfNull(this.left, this.right);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitIfNull(this);
}

class Int implements Expression {
  final int value;

  Int(this.value);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitInt(this);
}

class InterfaceType extends DartType {
  final String class_;

  final List<DartType> typeArguments;

  InterfaceType(this.class_, [this.typeArguments = const []]) : super._();

  DartType getPropertyType(String propertyName) {
    switch (propertyName) {
      case 'isEven':
        return InterfaceType('bool');
      default:
        throw StateError('Unexpected property get: $propertyName');
    }
  }

  String toString() {
    if (typeArguments.isEmpty) {
      return class_;
    } else {
      return '$class_<${typeArguments.join(', ')}>';
    }
  }
}

class Is implements Expression {
  final Expression expression;
  final DartType type;

  Is(this.expression, this.type);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitIs(this);
}

class Label {
  final String name;

  Label(this.name);
}

class ListLiteral implements Expression {
  final DartType type;
  final List<Expression> values;

  ListLiteral(this.type, this.values);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitListLiteral(this);
}

class Local extends Variable {
  final String name;

  @override
  DartType declaredType;

  Local(this.name, {bool isPotentiallyMutatedInClosure = false})
      : super(isPotentiallyMutatedInClosure: isPotentiallyMutatedInClosure);

  R accept<R>(Visitor<R> visitor) => visitor.visitLocal(this);
}

class LocalCall implements Expression {
  final Variable variable;
  final List<Expression> arguments;

  LocalCall(this.variable, this.arguments);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitLocalCall(this);
}

class Locals implements Statement {
  final DartType type;

  final List<Local> variables;

  Locals(this.type, this.variables) {
    for (var variable in variables) {
      variable.declaredType = type;
    }
  }

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitlocals(this);
}

class Method implements Declaration {
  final DartType returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Method(this.returnType, this.name, this.parameters, [this.body]);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitMethod(this);
}

class NeverType extends DartType {
  NeverType() : super._();

  String toString() => 'Never';
}

class Not implements Expression {
  final Expression operand;

  Not(this.operand);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitNot(this);
}

class NotEq implements Expression {
  final Expression left;
  final Expression right;

  NotEq(this.left, this.right);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitNotEq(this);
}

class NullLiteral implements Expression {
  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitNullLiteral(this);
}

class NullType extends DartType {
  NullType() : super._();

  String toString() => 'Null';
}

class Or implements Expression {
  final Expression left;
  final Expression right;

  Or(this.left, this.right);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitOr(this);
}

class Param extends Variable {
  @override
  final DartType declaredType;
  final String name;

  Param(this.declaredType, this.name,
      {bool isPotentiallyMutatedInClosure = false})
      : super(isPotentiallyMutatedInClosure: isPotentiallyMutatedInClosure);

  void accept<R>(Visitor<R> visitor) => visitor.visitParam(this);
}

class Parens implements Expression {
  final Expression contents;

  Parens(this.contents);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitParens(this);
}

class PropertyGet implements Expression {
  final Expression target;
  final String propertyName;

  PropertyGet(this.target, this.propertyName);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitPropertyGet(this);
}

class Rethrow implements Statement {
  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitRethrow(this);
}

class Return implements Statement {
  final Expression value;

  Return([this.value]);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitReturn(this);
}

class Set implements Expression {
  final Variable variable;
  final Expression value;

  Set(this.variable, this.value) {
    variable.isPotentiallyMutatedInScope = true;
  }

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitSet(this);
}

abstract class Statement {
  R accept<R>(Visitor<R> visitor);
}

class StaticCall implements Expression {
  final Func target;
  final List<Expression> arguments;

  StaticCall(this.target, this.arguments);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitStaticCall(this);
}

class StringLiteral implements Expression {
  final String value;

  StringLiteral(this.value);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitStringLiteral(this);
}

class Switch implements Statement {
  final Expression value;
  final List<Case> cases;

  Switch(this.value, this.cases);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitSwitch(this);
}

class Throw implements Expression {
  final Expression exception;

  Throw(this.exception);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitThrow(this);
}

class Try implements Statement {
  final Statement body;
  final List<Catch> catches;
  final Statement finally_;

  Try(this.body, this.catches, [this.finally_]);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitTry(this);
}

class Unit {
  final List<Declaration> declarations;

  Unit(this.declarations);

  R accept<R>(Visitor<R> visitor) => visitor.visitUnit(this);
}

abstract class Variable implements Element {
  bool isPotentiallyMutatedInScope = false;

  @override
  final bool isPotentiallyMutatedInClosure;

  Variable({this.isPotentiallyMutatedInClosure = false});

  DartType get declaredType;
}

abstract class Visitor<R> {
  R defaultExpression();

  R defaultNode();

  R defaultStatement();

  R visitAnd(And and) {
    and.left.accept(this);
    and.right.accept(this);
    return defaultExpression();
  }

  R visitBlock(Block block) {
    for (var statement in block.statements) {
      statement.accept(this);
    }
    return defaultStatement();
  }

  R visitBool(Bool bool_) => defaultExpression();

  R visitBreak(Break break_) => defaultStatement();

  visitCase(Case case_) {
    case_.value.accept(this);
    for (var statement in case_.body) {
      statement.accept(this);
    }
  }

  R visitCatch(Catch catch_) {
    catch_.body.accept(this);
    return defaultNode();
  }

  R visitClass(Class class_) {
    for (var member in class_.members) {
      member.accept(this);
    }
    return defaultNode();
  }

  visitClosure(Closure closure) {
    for (var parameter in closure.parameters) {
      parameter.accept<R>(this);
    }
    closure.body.accept(this);
  }

  R visitConditional(Conditional conditional) {
    conditional.condition.accept(this);
    conditional.thenExpression.accept(this);
    conditional.elseExpression.accept(this);
    return defaultExpression();
  }

  R visitConstructor(Constructor constructor) {
    for (var parameter in constructor.parameters) {
      parameter.accept(this);
    }
    constructor.body.accept(this);
    return defaultNode();
  }

  R visitContinue() => defaultStatement();

  R visitDo(Do do_) {
    do_.body.accept(this);
    do_.condition.accept(this);
    return defaultStatement();
  }

  R visitEq(Eq eq) {
    eq.left.accept(this);
    eq.right.accept(this);
    return defaultExpression();
  }

  R visitForEachDeclared(ForEachDeclared forEachDeclared) {
    forEachDeclared.iterable.accept(this);
    forEachDeclared.body.accept(this);
    return defaultStatement();
  }

  R visitForEachIdentifier(ForEachIdentifier forEachIdentifier) {
    forEachIdentifier.iterable.accept(this);
    forEachIdentifier.body.accept(this);
    return defaultStatement();
  }

  R visitForExpr(ForExpr forExpr) {
    forExpr.initializer.accept(this);
    forExpr.condition.accept(this);
    forExpr.body.accept(this);
    for (var updater in forExpr.updaters) {
      updater.accept(this);
    }
    return defaultStatement();
  }

  R visitFunc(Func func) {
    for (var parameter in func.parameters) {
      parameter.accept(this);
    }
    func.body.accept(this);
    return defaultStatement();
  }

  R visitGet(Get get) => defaultExpression();

  R visitGt(Gt gt) {
    gt.left.accept(this);
    gt.right.accept(this);
    return defaultExpression();
  }

  R visitIf(If if_) {
    if_.condition.accept(this);
    if_.thenStatement.accept(this);
    if_.elseStatement.accept(this);
    return defaultStatement();
  }

  R visitIfNull(IfNull ifNull) {
    ifNull.left.accept(this);
    ifNull.right.accept(this);
    return defaultExpression();
  }

  R visitInt(Int int) => defaultExpression();

  R visitIs(Is is_) {
    return defaultExpression();
  }

  R visitListLiteral(ListLiteral listLiteral) {
    for (var value in listLiteral.values) {
      value.accept(this);
    }
    return defaultExpression();
  }

  R visitLocal(Local local) => defaultNode();

  R visitLocalCall(LocalCall localCall) {
    for (var argument in localCall.arguments) {
      argument.accept(this);
    }
    return defaultExpression();
  }

  R visitlocals(Locals locals) {
    for (var variable in locals.variables) {
      variable.accept(this);
    }
    return defaultStatement();
  }

  R visitMethod(Method method) {
    for (var parameter in method.parameters) {
      parameter.accept(this);
    }
    method.body.accept(this);
    return defaultNode();
  }

  R visitNot(Not not) {
    not.operand.accept(this);
    return defaultExpression();
  }

  R visitNotEq(NotEq notEq) {
    notEq.left.accept(this);
    notEq.right.accept(this);
    return defaultExpression();
  }

  R visitNullLiteral(NullLiteral nullLiteral) => defaultExpression();

  R visitOr(Or or) {
    or.left.accept(this);
    or.right.accept(this);
    return defaultExpression();
  }

  R visitParam(Param param) => defaultNode();

  R visitParens(Parens parens) => parens.contents.accept(this);

  R visitPropertyGet(PropertyGet propertyGet) => defaultExpression();

  R visitRethrow(Rethrow rethrow_) => defaultStatement();

  R visitReturn(Return return_) {
    return_.value?.accept(this);
    return defaultStatement();
  }

  R visitSet(Set set) {
    set.value.accept(this);
    return defaultStatement();
  }

  R visitStaticCall(StaticCall staticCall) {
    for (var argument in staticCall.arguments) {
      argument.accept(this);
    }
    return defaultExpression();
  }

  R visitStringLiteral(StringLiteral stringLiteral) => defaultExpression();

  R visitSwitch(Switch switch_) {
    switch_.value.accept(this);
    for (var case_ in switch_.cases) {
      case_.accept(this);
    }
    return defaultStatement();
  }

  R visitThrow(Throw throw_) {
    throw_.exception.accept(this);
    return defaultExpression();
  }

  R visitTry(Try try_) {
    try_.body.accept(this);
    for (var catch_ in try_.catches) {
      catch_.accept(this);
    }
    try_.finally_.accept(this);
    return defaultStatement();
  }

  R visitUnit(Unit unit) {
    for (var declaration in unit.declarations) {
      declaration.accept(this);
    }
    return defaultNode();
  }

  R visitWhile(While while_) {
    while_.condition.accept(this);
    while_.body.accept(this);
    return defaultStatement();
  }
}

class VoidType extends DartType {
  VoidType() : super._();

  String toString() => 'void';
}

class While implements Statement {
  final Expression condition;
  final Statement body;

  While(this.condition, this.body);

  @override
  R accept<R>(Visitor<R> visitor) => visitor.visitWhile(this);
}
