class And implements Expression {
  final Expression left;
  final Expression right;

  And(this.left, this.right);
}

class Block implements Statement {
  final List<Statement> statements;

  Block(this.statements);
}

class Bool implements Expression {
  final bool value;

  Bool(this.value);
}

class Rethrow implements Statement {}

class Break implements Statement {
  final Label label;

  Break([this.label]);
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
  Statement body;

  Closure(this.parameters, [this.body]);
}

class Conditional implements Expression {
  final Expression condition;
  final Expression thenExpression;
  final Expression elseExpression;

  Conditional(this.condition, this.thenExpression, this.elseExpression);
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
}

class Declaration {}

class Do implements Expression {
  final Statement body;
  final Expression condition;

  Do(this.body, this.condition);
}

class Eq implements Expression {
  final Expression left;
  final Expression right;

  Eq(this.left, this.right);
}

class Expression implements Statement {}

class ForEachDeclared implements Statement {
  final ForEachVariable variable;
  final Expression iterable;
  final Statement body;

  ForEachDeclared(this.variable, this.iterable, this.body);
}

class ForEachIdentifier implements Statement {
  final Variable variable;
  final Expression iterable;
  final Statement body;

  ForEachIdentifier(this.variable, this.iterable, this.body);
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
}

class Func implements Declaration, Statement {
  final TypeAnnotation returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Func(this.returnType, this.name, this.parameters, [this.body]);
}

class Get implements Expression {
  final Variable variable;

  Get(this.variable);
}

class Gt implements Expression {
  final Expression left;
  final Expression right;

  Gt(this.left, this.right);
}

class If implements Statement {
  final Expression condition;
  final Statement thenStatement;
  final Statement elseStatement;

  If(this.condition, this.thenStatement, [this.elseStatement]);
}

class IfNull implements Expression {
  final Expression left;
  final Expression right;

  IfNull(this.left, this.right);
}

class Int implements Expression {
  final int value;

  Int(this.value);
}

class Is implements Expression {
  final Expression expression;
  final TypeAnnotation type;

  Is(this.expression, this.type);
}

class ListLiteral implements Expression {
  final TypeAnnotation type;
  final List<Expression> values;

  ListLiteral(this.type, this.values);
}

class Local implements Variable {
  final String name;

  Local(this.name);
}

class Locals implements Statement {
  final List<Local> variables;

  Locals(this.variables);
}

class Method implements Declaration {
  final TypeAnnotation returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Method(this.returnType, this.name, this.parameters, [this.body]);
}

class Label {
  final String name;

  Label(this.name);
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

class Return implements Statement {
  final Expression value;

  Return([this.value]);
}

class Set implements Expression {
  final Variable variable;
  final Expression value;

  Set(this.variable, this.value);
}

class Statement {}

class LocalCall implements Expression {
  final Variable variable;
  final List<Expression> arguments;

  LocalCall(this.variable, this.arguments);
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
}

class Unit {
  final List<Declaration> declarations;

  Unit(this.declarations);
}

class Variable {}

class While implements Expression {
  final Expression condition;
  final Statement body;

  While(this.condition, this.body);
}
