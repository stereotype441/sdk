class Get {}
class TypeAnnotation {
  final String class_;

  TypeAnnotation(this.class_);
}
class Param {
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
class Func extends Declaration {
  final TypeAnnotation returnType;
  final String name;
  final List<Param> parameters;
  Statement body;

  Func(this.returnType, this.name, this.parameters);
}
class Block extends Statement {
  final List<Statement> statements;

  Block(this.statements);
}
