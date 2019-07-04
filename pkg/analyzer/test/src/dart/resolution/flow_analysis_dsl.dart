class And implements Expression {
  final Expression left;
  final Expression right;

  And(this.left, this.right);

  DartType visit() {
    left.visit();
    right.visit();
    return DartType('bool');
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
    return DartType('bool');
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
}

class Catch {
  final CatchVariable exception;
  final Statement body;

  Catch(this.exception, this.body);
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
  Expression body;

  Closure(this.parameters, [this.body]);

  DartType visit() {
    var paramNames = parameters.map((p) => p.name).join(', ');
    var bodyType = body.visit();
    return DartType('$bodyType Function($paramNames)');
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

class DartType {
  final String name;

  DartType(this.name);

  factory DartType.LUB(DartType a, DartType b) {
    throw new UnimplementedError('TODO(paulberry)');
  }
}

class Declaration {}

class Do implements Statement {
  final Statement body;
  final Expression condition;

  Do(this.body, this.condition);

  DartType visit() {
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
    return DartType('bool');
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
  final TypeAnnotation type;
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
  final TypeAnnotation returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Func(this.returnType, this.name, this.parameters, [this.body]);

  void visit() {
    body.visit();
  }
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
    return DartType('bool');
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
    return DartType('int');
  }
}

class Is implements Expression {
  final Expression expression;
  final TypeAnnotation type;

  Is(this.expression, this.type);

  DartType visit() {
    return DartType('bool');
  }
}

class Label {
  final String name;

  Label(this.name);
}

class ListLiteral implements Expression {
  final TypeAnnotation type;
  final List<Expression> values;

  ListLiteral(this.type, this.values);

  DartType visit() {
    for (var value in values) {
      value.visit();
    }
    return DartType('List<$type>');
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
}

class Locals implements Statement {
  final List<Local> variables;

  Locals(this.variables) {
    for (var variable in variables) {
      variable.declaredType = type;
    }
  }
}

class Method implements Declaration {
  final TypeAnnotation returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Method(this.returnType, this.name, this.parameters, [this.body]);
}

class Not implements Expression {
  final Expression operand;

  Not(this.operand);
}

class NotEq implements Expression {
  final Expression left;
  final Expression right;

  NotEq(this.left, this.right);
}

class NullLiteral implements Expression {}

class Or implements Expression {
  final Expression left;
  final Expression right;

  Or(this.left, this.right);
}

class Param implements Variable {
  final TypeAnnotation type;
  final String name;

  Param(this.type, this.name);
}

class Parens implements Expression {
  final Expression contents;

  Parens(this.contents);
}

class PropertyGet implements Expression {
  final Expression target;
  final String propertyName;

  PropertyGet(this.target, this.propertyName);
}

class Rethrow implements Statement {
  void visit() {}
}

class Return implements Statement {
  final Expression value;

  Return([this.value]);
}

class Set implements Expression {
  final Variable variable;
  final Expression value;

  Set(this.variable, this.value);
}

abstract class Statement {
  void visit();
}

class StaticCall implements Expression {
  final Func target;
  final List<Expression> arguments;

  StaticCall(this.target, this.arguments);
}

class StringLiteral implements Expression {
  final String value;

  StringLiteral(this.value);
}

class Switch implements Statement {
  final Expression value;
  final List<Case> cases;

  Switch(this.value, this.cases);
}

class Throw implements Expression {
  final Expression exception;

  Throw(this.exception);
}

class Try implements Expression {
  final Statement body;
  final List<Catch> catches;
  final Statement finallyClause;

  Try(this.body, this.catches, [this.finallyClause]);
}

class TypeAnnotation {
  final String class_;

  TypeAnnotation(this.class_);

  String toString() => class_;
}

class Unit {
  final List<Declaration> declarations;

  Unit(this.declarations);
}

abstract class Variable {
  DartType get declaredType;
}

class While implements Expression {
  final Expression condition;
  final Statement body;

  While(this.condition, this.body);
}
