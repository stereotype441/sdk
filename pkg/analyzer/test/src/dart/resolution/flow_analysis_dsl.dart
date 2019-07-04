class Get implements Expression {
  final Variable variable;

  Get(this.variable);
}
class Variable {}
class TypeAnnotation {
  final String class_;

  TypeAnnotation(this.class_);
}
class Param implements Variable {
  final TypeAnnotation type;
  final String name;

  Param(this.type, this.name);
}
class Declaration {}
class Unit {
  final List<Declaration> declarations;

  Unit(this.declarations);
}
class Statement {}
class Constructor implements Declaration {
  final String name;
  final List<Param> parameters;
  Statement body;

  Constructor(this.name, this.parameters, [this.body]);
}
class Func implements Declaration, Statement {
  final TypeAnnotation returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Func(this.returnType, this.name, this.parameters, [this.body]);
}
class Method implements Declaration {
  final TypeAnnotation returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Method(this.returnType, this.name, this.parameters, [this.body]);
}
class StringLiteral implements Expression {
  final String value;

  StringLiteral(this.value);
}
class Block implements Statement {
  final List<Statement> statements;

  Block(this.statements);
}
class Expression implements Statement {}
class NullLiteral implements Expression {}
class Return implements Statement {
  final Expression value;

  Return([this.value]);
}
class Parens implements Expression {
  final Expression contents;

  Parens(this.contents);
}
class Throw implements Expression {
  final Expression exception;

  Throw(this.exception);
}
class IfNull implements Expression {
  final Expression left;
  final Expression right;

  IfNull(this.left, this.right);
}
class NotEq implements Expression {
  final Expression left;
  final Expression right;

  NotEq(this.left, this.right);
}
class Eq implements Expression {
  final Expression left;
  final Expression right;

  Eq(this.left, this.right);
}
class Class implements Declaration {
  final String name;
  final List<Declaration> members;

  Class(this.name, this.members);
}
class Or implements Expression {
  final Expression left;
  final Expression right;

  Or(this.left, this.right);
}
class PropertyGet implements Expression {
  final Expression target;
  final String propertyName;

  PropertyGet(this.target, this.propertyName);
}
class And implements Expression {
  final Expression left;
  final Expression right;

  And(this.left, this.right);
}
class Conditional implements Expression {
  final Expression condition;
  final Expression thenExpression;
  final Expression elseExpression;

  Conditional(this.condition, this.thenExpression, this.elseExpression);
}
class If implements Statement {
  final Expression condition;
  final Statement thenStatement;
  final Statement elseStatement;

  If(this.condition, this.thenStatement, [this.elseStatement]);
}
class Locals implements Statement {
  final List<Local> variables;

  Locals(this.variables);
}
class ForExpr implements Statement {
  final Expression initializer;
  final Expression condition;
  final List<Expression> updaters;
  final Statement body;

  ForExpr(this.initializer, this.condition, this.updaters, this.body);
}
class ForEachIdentifier implements Statement {
  final Variable variable;
  final Expression iterable;
  final Statement body;

  ForEachIdentifier(this.variable, this.iterable, this.body);
}
class Local implements Variable {
  final String name;

  Local(this.name);
}
class ListLiteral implements Expression {
  final TypeAnnotation type;
  final List<Expression> values;

  ListLiteral(this.type, this.values);
}
class CatchVariable {
  final String name;

  CatchVariable(this.name);
}
class Catch {
  final CatchVariable exception;
  final Statement body;

  Catch(this.exception, this.body);
}
class Case {
  final List<String> labels;
  final Expression value;
  final List<Statement> body;

  Case(this.labels, this.value, this.body);
}
class Switch implements Statement {
  final Expression value;
  final List<Case> cases;

  Switch(this.value, this.cases);
}
class Do implements Expression {
  final Statement body;
  final Expression condition;

  Do(this.body, this.condition);
}
class While implements Expression {
  final Expression condition;
  final Statement body;

  While(this.condition, this.body);
}
class Bool implements Expression {
  final bool value;

  Bool(this.value);
}
class Int implements Expression {
  final int value;

  Int(this.value);
}
class Break implements Statement {}
class Continue implements Statement {}
class Is implements Expression {
  final Expression expression;
  final TypeAnnotation type;

  Is(this.expression, this.type);
}
class Try implements Expression {
  final Statement body;
  final List<Catch> catches;
  final Statement finallyClause;

  Try(this.body, this.catches, [this.finallyClause]);
}
class StaticCall implements Expression {
  final Func target;
  final List<Expression> arguments;

  StaticCall(this.target, this.arguments);
}
class Set implements Expression {
  final Variable variable;
  final Expression value;

  Set(this.variable, this.value);
}