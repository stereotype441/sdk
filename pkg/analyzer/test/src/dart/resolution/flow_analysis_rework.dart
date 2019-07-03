// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as path;

main() {
  var inputPath = path.join(Directory.current.path, 'test', 'src', 'dart',
      'resolution', 'flow_analysis_test.dart');
  var input = File(inputPath).readAsStringSync();
  var parsed = parseString(content: input);
  parsed.unit.accept(TestTransformer());
}

class DslNode {}

class DslTransformer extends ThrowingAstVisitor<List<Object>> {
  Map<Element, String> _refNames = {};

  final Set<String> _usedNames = {};

  final List<ExtractableSubexpression> _extractableSubexpressions = [];

  List<Object> call(String name, Iterable<Object> args) =>
      ['$name(', ...commaSeparated(args), ')'];

  List<Object> commaSeparated(Iterable<Object> nodes) {
    List<Object> result = [];
    bool first = true;
    for (var node in nodes) {
      if (!first) {
        result.add(', ');
      }
      first = false;
      result.addAll(visit(node));
    }
    return result;
  }

  List<Object> extractable(Element e, List<Object> value) {
    var extractableSubexpression =
        ExtractableSubexpression(_refNames, e, value);
    _extractableSubexpressions.add(extractableSubexpression);
    return [extractableSubexpression];
  }

  String ref(Element e) {
    return _refNames[e] ??= _uniqueRefName(e.name);
  }

  List<Object> visit(Object node) {
    if (node is AstNode) {
      return node.accept(this);
    } else if (node is Iterable) {
      return ['[', ...commaSeparated(node), ']'];
    } else if (node is String) {
      return [json.encode(node)];
    } else if (node == null) {
      return ['null'];
    } else {
      throw 'TODO';
    }
  }

  List<Object> visitAssignmentExpression(AssignmentExpression node) {
    assert(node.operator.lexeme == '=');
    var lhs = node.leftHandSide;
    if (lhs is SimpleIdentifier) {
      var lhsElement = lhs.staticElement;
      if (lhsElement is ParameterElement) {
        return ['Set(', ref(lhsElement), ', ', visit(node.rightHandSide), ')'];
      }
    }
    throw 'TODO';
  }

  List<Object> visitBinaryExpression(BinaryExpression node) {
    switch (node.operator.lexeme) {
      case '!=':
        return call('NotEq', [node.leftOperand, node.rightOperand]);
      case '==':
        return call('Eq', [node.leftOperand, node.rightOperand]);
      case '&&':
        return call('And', [node.leftOperand, node.rightOperand]);
      case '||':
        return call('Or', [node.leftOperand, node.rightOperand]);
      default:
        throw node.operator.lexeme;
    }
  }

  List<Object> visitBlock(Block node) => call('Block', [node.statements]);

  List<Object> visitBlockFunctionBody(BlockFunctionBody node) =>
      visit(node.block);

  List<Object> visitClassDeclaration(ClassDeclaration node) {
    _unusedList(node.metadata);
    _unused(node.typeParameters);
    _unused(node.extendsClause);
    _unused(node.withClause);
    _unused(node.implementsClause);
    _unused(node.nativeClause);
    return call('Class', [node.name.name, node.members]);
  }

  List<Object> visitCompilationUnit(CompilationUnit node) {
    _unused(node.scriptTag);
    _unusedList(node.directives);
    List<Object> result = [];
    var exprResult = call('Unit', [node.declarations]);
    for (var extractableSubexpression in _extractableSubexpressions) {
      if (_refNames.containsKey(extractableSubexpression._element)) {
        result.addAll([
          'var ',
          _refNames[extractableSubexpression._element],
          ' = ',
          ...extractableSubexpression._value,
          ';\n'
        ]);
      }
    }
    result.addAll(['await trackCode(', ...exprResult, ');']);
    return result;
  }

  List<Object> visitConstructorDeclaration(ConstructorDeclaration node) {
    _unusedList(node.metadata);
    _unusedList(node.initializers);
    _unused(node.redirectedConstructor);
    return call('Constructor',
        [node.name?.name, node.parameters.parameters, node.body]);
  }

  List<Object> visitExpressionStatement(ExpressionStatement node) =>
      visit(node.expression);

  List<Object> visitFunctionDeclaration(FunctionDeclaration node) {
    _unusedList(node.metadata);
    _unused(node.functionExpression.typeParameters);
    return call('Func', [
      node.returnType,
      node.name.name,
      node.functionExpression.parameters.parameters,
      node.functionExpression.body
    ]);
  }

  List<Object> visitIfStatement(IfStatement node) => call('If', [
        node.condition,
        node.thenStatement,
        if (node.elseStatement != null) node.elseStatement
      ]);

  List<Object> visitIntegerLiteral(IntegerLiteral node) =>
      ['Int(${node.value})'];

  List<Object> visitMethodDeclaration(MethodDeclaration node) {
    _unusedList(node.metadata);
    _unused(node.typeParameters);
    return call('Method', [
      node.returnType,
      node.name.name,
      node.parameters.parameters,
      node.body
    ]);
  }

  List<Object> visitNullLiteral(NullLiteral node) => ['Null()'];

  List<Object> visitPrefixedIdentifier(PrefixedIdentifier node) {
    var identifier = node.identifier;
    if (identifier.inDeclarationContext()) {
      throw 'TODO';
    } else if (identifier.inGetterContext()) {
      var staticElement = node.staticElement;
      if (staticElement is PropertyAccessorElement && !staticElement.isStatic) {
        return call('PropertyGet', [node.prefix, node.identifier.name]);
      }
      throw '${staticElement.runtimeType}';
    } else if (identifier.inSetterContext()) {
      throw 'TODO';
    } else {
      throw 'TODO';
    }
  }

  List<Object> visitReturnStatement(ReturnStatement node) =>
      call('Return', [if (node.expression != null) node.expression]);

  List<Object> visitSimpleFormalParameter(SimpleFormalParameter node) {
    return extractable(
        node.declaredElement, call('Param', [node.type, node.identifier.name]));
  }

  List<Object> visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.inDeclarationContext()) {
      throw 'TODO';
    } else if (node.inGetterContext()) {
      var staticElement = node.staticElement;
      if (staticElement is ParameterElement) {
        return ['Get(', ref(staticElement), ')'];
      }
      throw '${staticElement.runtimeType}';
    } else if (node.inSetterContext()) {
      throw 'TODO';
    } else {
      throw 'TODO';
    }
  }

  List<Object> visitTypeName(TypeName node) {
    _unused(node.typeArguments);
    return call('Type', [(node.name as SimpleIdentifier).name]);
  }

  String _uniqueRefName(String prefix) {
    if (prefix == null || prefix.isEmpty) prefix = '_';
    if (_usedNames.add(prefix)) return prefix;
    for (int i = 0;; i++) {
      var candidateName = '$prefix$i';
      if (_usedNames.add(candidateName)) return candidateName;
    }
  }

  void _unused(Object node) {
    if (node != null) throw 'Unexpected: $node';
  }

  void _unusedList(List<Object> nodes) {
    if (nodes.isNotEmpty) throw 'Unexpected: $nodes';
  }
}

class ExtractableSubexpression {
  final Map<Element, String> _refNames;
  final Element _element;
  final List<Object> _value;

  ExtractableSubexpression(this._refNames, this._element, this._value);

  String toString() => _refNames[_element] ?? _value.join('');
}

class TestTransformer extends GeneralizingAstVisitor<void> {
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) {
      var name = node.methodName.name;
      if (name == 'assertNullable' ||
          name == 'assertNonNullable' ||
          name == 'assertNotPromoted' ||
          name == 'assertPromoted' ||
          name == 'verify') {
        return;
      }
    }
    return super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    var s = node.stringValue;
    try {
      var parsed = parseString(content: s);
      print(parsed.unit.accept(DslTransformer()));
    } catch (e) {
      print('Error in $s: $e');
      rethrow;
    }
  }

  @override
  void visitUriBasedDirective(UriBasedDirective node) {}
}
