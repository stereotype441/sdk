import 'package:analyzer/src/dart/resolver/flow_analysis.dart';

class And implements Expression {
  final Expression left;
  final Expression right;

  And(this.left, this.right);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    left.run(flowAnalyzer);
    right.run(flowAnalyzer);
    return InterfaceType('bool');
  }
}

class Block implements Statement {
  final List<Statement> statements;

  Block(this.statements);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    for (var statement in statements) {
      statement.run(flowAnalyzer);
    }
  }
}

class Bool implements Expression {
  final bool value;

  Bool(this.value);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    return InterfaceType('bool');
  }
}

class Break implements Statement {
  final Label label;

  Break([this.label]);

  @override
  void run(FlowAnalyzer flowAnalyzer) {}
}

class Case {
  final List<Label> labels;
  final Expression value;
  final List<Statement> body;

  Case(this.labels, this.value, this.body);

  void run(FlowAnalyzer flowAnalyzer) {
    value.run(flowAnalyzer);
    for (var statement in body) {
      statement.run(flowAnalyzer);
    }
  }
}

class Catch {
  final CatchVariable exception;
  final Statement body;

  Catch(this.exception, this.body);

  void run(FlowAnalyzer flowAnalyzer) {
    body.run(flowAnalyzer);
  }
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
  void run(FlowAnalyzer flowAnalyzer) {
    for (var member in members) {
      member.run(flowAnalyzer);
    }
  }
}

class Closure implements Expression {
  final List<Param> parameters;
  Statement body;

  Closure(this.parameters, [this.body]);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    DartType bodyReturnType;
    var body = this.body;
    if (body is Expression) {
      bodyReturnType = body.run(flowAnalyzer);
    } else {
      body.run(flowAnalyzer);
      bodyReturnType = VoidType();
    }
    return FunctionType(
        bodyReturnType, parameters.map((p) => p.declaredType).toList());
  }
}

class Conditional implements Expression {
  final Expression condition;
  final Expression thenExpression;
  final Expression elseExpression;

  Conditional(this.condition, this.thenExpression, this.elseExpression);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    condition.run(flowAnalyzer);
    var thenType = thenExpression.run(flowAnalyzer);
    var elseType = elseExpression.run(flowAnalyzer);
    return DartType.LUB(thenType, elseType);
  }
}

class Constructor implements Declaration {
  final String name;
  final List<Param> parameters;
  Statement body;

  Constructor(this.name, this.parameters, [this.body]);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    body.run(flowAnalyzer);
  }
}

class Continue implements Statement {
  final Label label;

  Continue([this.label]);

  @override
  void run(FlowAnalyzer flowAnalyzer) {}
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
  void run(FlowAnalyzer flowAnalyzer);
}

class Do implements Statement {
  final Statement body;
  final Expression condition;

  Do(this.body, this.condition);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    body.run(flowAnalyzer);
    condition.run(flowAnalyzer);
  }
}

abstract class Element {
  DartType get declaredType;

  bool get isLocalVariable;

  bool get isPotentiallyMutatedInClosure;

  bool get isPotentiallyMutatedInScope;
}

class Eq implements Expression {
  final Expression left;
  final Expression right;

  Eq(this.left, this.right);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    left.run(flowAnalyzer);
    right.run(flowAnalyzer);
    return InterfaceType('bool');
  }
}

abstract class Expression implements Statement {
  @override
  DartType run(FlowAnalyzer flowAnalyzer);
}

class FlowAnalysisResult {
  final List<Get> nullableNodes = [];
  final List<Get> nonNullableNodes = [];
  final List<Statement> unreachableNodes = [];
  final List<Statement> functionBodiesThatDontComplete = [];
  final Map<Get, DartType> promotedTypes = {};
}

class FlowAnalyzer
    implements
        FunctionBodyAccess<Element>,
        TypeOperations<Element, DartType>,
        NodeOperations<Expression> {
  FlowAnalysis<Statement, Expression, Element, DartType> _flowAnalysis;

  final _result = FlowAnalysisResult();

  FlowAnalyzer() {
    _flowAnalysis = FlowAnalysis<Statement, Expression, Element, DartType>(
        this, this, this);
  }

  @override
  DartType elementType(Element element) => element.declaredType;

  @override
  bool isLocalVariable(Element element) => element.isLocalVariable;

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

  static FlowAnalysisResult run(Unit code) {
    var flowAnalyzer = FlowAnalyzer();
    code.run(flowAnalyzer);
    return flowAnalyzer._result;
  }
}

class ForEachDeclared implements Statement {
  final ForEachVariable variable;
  final Expression iterable;
  final Statement body;

  ForEachDeclared(this.variable, this.iterable, this.body);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    iterable.run(flowAnalyzer);
    body.run(flowAnalyzer);
  }
}

class ForEachIdentifier implements Statement {
  final Variable variable;
  final Expression iterable;
  final Statement body;

  ForEachIdentifier(this.variable, this.iterable, this.body);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    iterable.run(flowAnalyzer);
    body.run(flowAnalyzer);
  }
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
  void run(FlowAnalyzer flowAnalyzer) {
    initializer.run(flowAnalyzer);
    condition.run(flowAnalyzer);
    body.run(flowAnalyzer);
    for (var updater in updaters) {
      updater.run(flowAnalyzer);
    }
  }
}

class Func implements Declaration, Statement {
  final DartType returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Func(this.returnType, this.name, this.parameters, [this.body]);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    body.run(flowAnalyzer);
  }
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
  DartType run(FlowAnalyzer flowAnalyzer) {
    return variable.declaredType;
  }
}

class Gt implements Expression {
  final Expression left;
  final Expression right;

  Gt(this.left, this.right);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    left.run(flowAnalyzer);
    right.run(flowAnalyzer);
    return InterfaceType('bool');
  }
}

class If implements Statement {
  final Expression condition;
  final Statement thenStatement;
  final Statement elseStatement;

  If(this.condition, this.thenStatement, [this.elseStatement]);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    condition.run(flowAnalyzer);
    thenStatement.run(flowAnalyzer);
    elseStatement.run(flowAnalyzer);
  }
}

class IfNull implements Expression {
  final Expression left;
  final Expression right;

  IfNull(this.left, this.right);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    var leftType = left.run(flowAnalyzer);
    var rightType = right.run(flowAnalyzer);
    return DartType.LUB(leftType, rightType);
  }
}

class Int implements Expression {
  final int value;

  Int(this.value);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    return InterfaceType('int');
  }
}

class InterfaceType extends DartType {
  final String class_;

  final List<DartType> typeArguments;

  InterfaceType(this.class_, [this.typeArguments = const []]) : super._();

  DartType getPropertyType(String propertyName) {
    switch (propertyName) {
      case 'isEven': return InterfaceType('bool');
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
  DartType run(FlowAnalyzer flowAnalyzer) {
    return InterfaceType('bool');
  }
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
  DartType run(FlowAnalyzer flowAnalyzer) {
    for (var value in values) {
      value.run(flowAnalyzer);
    }
    return InterfaceType('List', [type]);
  }
}

class Local extends Variable implements Element {
  final String name;

  @override
  DartType declaredType;

  @override
  final bool isPotentiallyMutatedInClosure;

  Local(this.name, {this.isPotentiallyMutatedInClosure = false});

  @override
  bool get isLocalVariable => true;
}

class LocalCall implements Expression {
  final Variable variable;
  final List<Expression> arguments;

  LocalCall(this.variable, this.arguments);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    for (var argument in arguments) {
      argument.run(flowAnalyzer);
    }
    return (variable.declaredType as FunctionType).returnType;
  }
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
  void run(FlowAnalyzer flowAnalyzer) {
    for (var variable in variables) {
      // TODO(paulberry): test some examples of variables with initializers
      flowAnalyzer._flowAnalysis.add(variable, assigned: false);
    }
  }
}

class Method implements Declaration {
  final DartType returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Method(this.returnType, this.name, this.parameters, [this.body]);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    body.run(flowAnalyzer);
  }
}

class NeverType extends DartType {
  NeverType() : super._();

  String toString() => 'Never';
}

class Not implements Expression {
  final Expression operand;

  Not(this.operand);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    operand.run(flowAnalyzer);
    return InterfaceType('bool');
  }
}

class NotEq implements Expression {
  final Expression left;
  final Expression right;

  NotEq(this.left, this.right);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    left.run(flowAnalyzer);
    right.run(flowAnalyzer);
    return InterfaceType('bool');
  }
}

class NullLiteral implements Expression {
  @override
  DartType run(FlowAnalyzer flowAnalyzer) => NullType();
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
  DartType run(FlowAnalyzer flowAnalyzer) {
    left.run(flowAnalyzer);
    right.run(flowAnalyzer);
    return InterfaceType('bool');
  }
}

class Param extends Variable {
  @override
  final DartType declaredType;
  final String name;

  Param(this.declaredType, this.name);
}

class Parens implements Expression {
  final Expression contents;

  Parens(this.contents);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) => contents.run(flowAnalyzer);
}

class PropertyGet implements Expression {
  final Expression target;
  final String propertyName;

  PropertyGet(this.target, this.propertyName);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) =>
      (target.run(flowAnalyzer) as InterfaceType).getPropertyType(propertyName);
}

class Rethrow implements Statement {
  @override
  void run(FlowAnalyzer flowAnalyzer) {}
}

class Return implements Statement {
  final Expression value;

  Return([this.value]);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    value?.run(flowAnalyzer);
  }
}

class Set implements Expression {
  final Variable variable;
  final Expression value;

  Set(this.variable, this.value) {
    variable.isPotentiallyMutatedInScope = true;
  }

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    value.run(flowAnalyzer);
    return variable.declaredType;
  }
}

abstract class Statement {
  void run(FlowAnalyzer flowAnalyzer);
}

class StaticCall implements Expression {
  final Func target;
  final List<Expression> arguments;

  StaticCall(this.target, this.arguments);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    for (var argument in arguments) {
      argument.run(flowAnalyzer);
    }
    return target.returnType;
  }
}

class StringLiteral implements Expression {
  final String value;

  StringLiteral(this.value);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) => InterfaceType('String');
}

class Switch implements Statement {
  final Expression value;
  final List<Case> cases;

  Switch(this.value, this.cases);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    value.run(flowAnalyzer);
    for (var case_ in cases) {
      case_.run(flowAnalyzer);
    }
  }
}

class Throw implements Expression {
  final Expression exception;

  Throw(this.exception);

  @override
  DartType run(FlowAnalyzer flowAnalyzer) {
    return InterfaceType('Never');
  }
}

class Try implements Statement {
  final Statement body;
  final List<Catch> catches;
  final Statement finally_;

  Try(this.body, this.catches, [this.finally_]);

  @override
  void run(FlowAnalyzer flowAnalyzer) {
    body.run(flowAnalyzer);
    for (var catch_ in catches) {
      catch_.run(flowAnalyzer);
    }
    finally_.run(flowAnalyzer);
  }
}

class Unit {
  final List<Declaration> declarations;

  Unit(this.declarations);

  void run(FlowAnalyzer flowAnalyzer) {
    for (var declaration in declarations) {
      declaration.run(flowAnalyzer);
    }
  }
}

abstract class Variable {
  bool isPotentiallyMutatedInScope = false;

  DartType get declaredType;
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
  void run(FlowAnalyzer flowAnalyzer) {
    condition.run(flowAnalyzer);
    body.run(flowAnalyzer);
  }
}
