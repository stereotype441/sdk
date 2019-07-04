class And implements Expression {
  final Expression left;
  final Expression right;

  And(this.left, this.right);

  DartType visit() {
    left.visit();
    right.visit();
    return InterfaceType('bool');
  }
}

class Block implements Statement {
  final List<Statement> statements;

  Block(this.statements);

  void visit() {
    for (var statement in statements) {
      statement.visit();
    }
  }
}

class Bool implements Expression {
  final bool value;

  Bool(this.value);

  DartType visit() {
    return InterfaceType('bool');
  }
}

class Break implements Statement {
  final Label label;

  Break([this.label]);

  void visit() {}
}

class Case {
  final List<Label> labels;
  final Expression value;
  final List<Statement> body;

  Case(this.labels, this.value, this.body);

  void visit() {
    value.visit();
    for (var statement in body) {
      statement.visit();
    }
  }
}

class Catch {
  final CatchVariable exception;
  final Statement body;

  Catch(this.exception, this.body);

  void visit() {
    body.visit();
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
}

class Closure implements Expression {
  final List<Param> parameters;
  Statement body;

  Closure(this.parameters, [this.body]);

  DartType visit() {
    DartType bodyReturnType;
    var body = this.body;
    if (body is Expression) {
      bodyReturnType = body.visit();
    } else {
      body.visit();
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

  DartType visit() {
    condition.visit();
    var thenType = thenExpression.visit();
    var elseType = elseExpression.visit();
    return DartType.LUB(thenType, elseType);
  }
}

class Constructor implements Declaration {
  final String name;
  final List<Param> parameters;
  Statement body;

  Constructor(this.name, this.parameters, [this.body]);
}

class Continue implements Statement {
  final Label label;

  Continue([this.label]);

  void visit() {}
}

abstract class DartType {
  factory DartType.LUB(DartType a, DartType b) {
    throw new UnimplementedError('TODO(paulberry)');
  }

  DartType._();
}

class Declaration {}

class Do implements Statement {
  final Statement body;
  final Expression condition;

  Do(this.body, this.condition);

  void visit() {
    body.visit();
    condition.visit();
  }
}

class Eq implements Expression {
  final Expression left;
  final Expression right;

  Eq(this.left, this.right);

  DartType visit() {
    left.visit();
    right.visit();
    return InterfaceType('bool');
  }
}

abstract class Expression implements Statement {
  DartType visit();
}

class ForEachDeclared implements Statement {
  final ForEachVariable variable;
  final Expression iterable;
  final Statement body;

  ForEachDeclared(this.variable, this.iterable, this.body);

  void visit() {
    iterable.visit();
    body.visit();
  }
}

class ForEachIdentifier implements Statement {
  final Variable variable;
  final Expression iterable;
  final Statement body;

  ForEachIdentifier(this.variable, this.iterable, this.body);

  void visit() {
    iterable.visit();
    body.visit();
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

  void visit() {
    initializer.visit();
    condition.visit();
    body.visit();
    for (var updater in updaters) {
      updater.visit();
    }
  }
}

class Func implements Declaration, Statement {
  final DartType returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Func(this.returnType, this.name, this.parameters, [this.body]);

  void visit() {
    body.visit();
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

  DartType visit() {
    return variable.declaredType;
  }
}

class Gt implements Expression {
  final Expression left;
  final Expression right;

  Gt(this.left, this.right);

  DartType visit() {
    left.visit();
    right.visit();
    return InterfaceType('bool');
  }
}

class If implements Statement {
  final Expression condition;
  final Statement thenStatement;
  final Statement elseStatement;

  If(this.condition, this.thenStatement, [this.elseStatement]);

  void visit() {
    condition.visit();
    thenStatement.visit();
    elseStatement.visit();
  }
}

class IfNull implements Expression {
  final Expression left;
  final Expression right;

  IfNull(this.left, this.right);

  DartType visit() {
    var leftType = left.visit();
    var rightType = right.visit();
    return DartType.LUB(leftType, rightType);
  }
}

class Int implements Expression {
  final int value;

  Int(this.value);

  DartType visit() {
    return InterfaceType('int');
  }
}

class InterfaceType extends DartType {
  final String class_;

  final List<DartType> typeArguments;

  InterfaceType(this.class_, [this.typeArguments = const []]) : super._();

  DartType getPropertyType(String propertyName) {
    throw UnimplementedError('TODO(paulberry)');
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

  DartType visit() {
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

  DartType visit() {
    for (var value in values) {
      value.visit();
    }
    return InterfaceType('List', [type]);
  }
}

class Local implements Variable {
  final String name;

  @override
  DartType declaredType;

  Local(this.name);
}

class LocalCall implements Expression {
  final Variable variable;
  final List<Expression> arguments;

  LocalCall(this.variable, this.arguments);

  DartType visit() {
    for (var argument in arguments) {
      argument.visit();
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
  void visit() {}
}

class Method implements Declaration {
  final DartType returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Method(this.returnType, this.name, this.parameters, [this.body]);
}

class NeverType extends DartType {
  NeverType() : super._();

  String toString() => 'Never';
}

class Not implements Expression {
  final Expression operand;

  Not(this.operand);

  DartType visit() {
    operand.visit();
    return InterfaceType('bool');
  }
}

class NotEq implements Expression {
  final Expression left;
  final Expression right;

  NotEq(this.left, this.right);

  DartType visit() {
    left.visit();
    right.visit();
    return InterfaceType('bool');
  }
}

class NullLiteral implements Expression {
  DartType visit() => NullType();
}

class NullType extends DartType {
  NullType() : super._();

  String toString() => 'Null';
}

class Or implements Expression {
  final Expression left;
  final Expression right;

  Or(this.left, this.right);

  DartType visit() {
    left.visit();
    right.visit();
    return InterfaceType('bool');
  }
}

class Param implements Variable {
  @override
  final DartType declaredType;
  final String name;

  Param(this.declaredType, this.name);
}

class Parens implements Expression {
  final Expression contents;

  Parens(this.contents);

  DartType visit() => contents.visit();
}

class PropertyGet implements Expression {
  final Expression target;
  final String propertyName;

  PropertyGet(this.target, this.propertyName);

  DartType visit() =>
      (target.visit() as InterfaceType).getPropertyType(propertyName);
}

class Rethrow implements Statement {
  void visit() {}
}

class Return implements Statement {
  final Expression value;

  Return([this.value]);

  @override
  void visit() {
    value.visit();
  }
}

class Set implements Expression {
  final Variable variable;
  final Expression value;

  Set(this.variable, this.value);

  @override
  DartType visit() {
    value.visit();
    return variable.declaredType;
  }
}

abstract class Statement {
  void visit();
}

class StaticCall implements Expression {
  final Func target;
  final List<Expression> arguments;

  StaticCall(this.target, this.arguments);

  @override
  DartType visit() {
    for (var argument in arguments) {
      argument.visit();
    }
    return target.returnType;
  }
}

class StringLiteral implements Expression {
  final String value;

  StringLiteral(this.value);

  DartType visit() => InterfaceType('String');
}

class Switch implements Statement {
  final Expression value;
  final List<Case> cases;

  Switch(this.value, this.cases);

  void visit() {
    value.visit();
    for (var case_ in cases) {
      case_.visit();
    }
  }
}

class Throw implements Expression {
  final Expression exception;

  Throw(this.exception);

  @override
  DartType visit() {
    return InterfaceType('Never');
  }
}

class Try implements Statement {
  final Statement body;
  final List<Catch> catches;
  final Statement finally_;

  Try(this.body, this.catches, [this.finally_]);

  @override
  void visit() {
    body.visit();
    for (var catch_ in catches) {
      catch_.visit();
    }
    finally_.visit();
  }
}

class Unit {
  final List<Declaration> declarations;

  Unit(this.declarations);
}

abstract class Variable {
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
  void visit() {
    condition.visit();
    body.visit();
  }
}
