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
import 'package:test_reflective_loader/test_reflective_loader.dart';

main() {
  var inputPath = path.join(Directory.current.path, 'test', 'src', 'dart',
      'resolution', 'flow_analysis_test.dart');
  var input = File(inputPath).readAsStringSync();
  var parsed = parseString(content: input);
  parsed.unit.accept(TestTransformer());
}

List<List<Object>> _accumulatedTestData = [];

String _currentCode;

Map<AstNode, List<String>> _currentSearches;

CompilationUnit _currentUnit;

void recordRework(String code, CompilationUnit unit) {
  _currentCode = code;
  _currentUnit = unit;
  _currentSearches = {};
}

void recordSearch(String search, AstNode found) {
  (_currentSearches[found] ??= []).add(search);
}

void recordTestDone() {
  var testTransformer = DslTransformer(_currentSearches);
  var transformedCode = _currentUnit.accept(testTransformer).join('');
  _accumulatedTestData
      .add([_currentCode, transformedCode, testTransformer.searchVars]);
}

class DslNode {}

class DslTransformer extends ThrowingAstVisitor<List<Object>> {
  final Map<AstNode, List<String>> searches;

  final Map<String, String> searchVars = {};

  final Map<Element, String> _refNames = {};

  final Set<String> _usedNames = {};

  final List<ExtractableSubexpression> _extractableSubexpressions = [];

  final List<String> searchTargetDeclarations = [];

  DslTransformer(this.searches);

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

  ExtractedSubexpression ref(Element e) {
    return ExtractedSubexpression(_refNames[e] ??= _uniqueRefName(e.name));
  }

  List<Object> searchable(
      String type, AstNode node, String prefix, List<Object> value) {
    var searchTerms = this.searches[node];
    if (searchTerms != null) {
      var name = _uniqueRefName(prefix);
      searchTargetDeclarations.add('$type $name;');
      for (var searchTerm in searchTerms) {
        searchVars[searchTerm] = name;
      }
      return ['(', name, ' = ', ...value, ')'];
    } else {
      return value;
    }
  }

  List<Object> visit(Object node) {
    if (node is AstNode) {
      return node.accept(this);
    } else if (node is Iterable) {
      return ['[', ...commaSeparated(node), ']'];
    } else if (node is String) {
      return [json.encode(node)];
    } else if (node is ExtractedSubexpression) {
      return [node.toString()];
    } else if (node is ExtractableSubexpression) {
      return [node];
    } else if (node == null) {
      return ['null'];
    } else {
      throw 'TODO: ${node.runtimeType}';
    }
  }

  List<Object> visitAssignmentExpression(AssignmentExpression node) {
    assert(node.operator.lexeme == '=');
    var lhs = node.leftHandSide;
    if (lhs is SimpleIdentifier) {
      var lhsElement = lhs.staticElement;
      if (lhsElement is ParameterElement ||
          lhsElement is LocalVariableElement) {
        return call('Set', [ref(lhsElement), node.rightHandSide]);
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
      case '??':
        return call('IfNull', [node.leftOperand, node.rightOperand]);
      case '>':
        return call('Gt', [node.leftOperand, node.rightOperand]);
      default:
        throw node.operator.lexeme;
    }
  }

  List<Object> visitBlock(Block node) =>
      searchable('Block', node, 'statement', call('Block', [node.statements]));

  List<Object> visitBlockFunctionBody(BlockFunctionBody node) =>
      searchable('Statement', node, 'statement', visit(node.block));

  List<Object> visitBooleanLiteral(BooleanLiteral node) =>
      ['Bool(${node.value})'];

  List<Object> visitBreakStatement(BreakStatement node) =>
      call('Break', [if (node.label != null) ref(node.label.staticElement)]);

  List<Object> visitCatchClause(CatchClause node) {
    _unused(node.exceptionType);
    _unused(node.stackTraceParameter);
    return call('Catch',
        [..._declared('CatchVariable', node.exceptionParameter), node.body]);
  }

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
    var unsatisfiedReferences = _refNames.keys.toSet();
    for (var searchTargetDeclaration in searchTargetDeclarations) {
      result.add('$searchTargetDeclaration\n');
    }
    for (var extractableSubexpression in _extractableSubexpressions) {
      if (_refNames.containsKey(extractableSubexpression._element)) {
        result.addAll([
          'var ',
          _refNames[extractableSubexpression._element],
          ' = ',
          ...extractableSubexpression._value,
          ';\n'
        ]);
        unsatisfiedReferences.remove(extractableSubexpression._element);
      }
    }
    if (unsatisfiedReferences.isNotEmpty) {
      throw 'Unsatisfied references: $unsatisfiedReferences';
    }
    result.addAll(['await trackCode(', ...exprResult, ');']);
    for (var entry in this.searches.entries) {
      for (var searchTerm in entry.value) {
        if (!searchVars.containsKey(searchTerm)) {
          throw 'Unsearchable node: ${entry.key.runtimeType} ${entry.key} '
              '(search terms: ${entry.value})';
        }
      }
    }
    return result;
  }

  List<Object> visitConditionalExpression(ConditionalExpression node) => call(
      'Conditional',
      [node.condition, node.thenExpression, node.elseExpression]);

  List<Object> visitConstructorDeclaration(ConstructorDeclaration node) {
    _unusedList(node.metadata);
    _unusedList(node.initializers);
    _unused(node.redirectedConstructor);
    return call('Constructor',
        [node.name?.name, node.parameters.parameters, node.body]);
  }

  List<Object> visitContinueStatement(ContinueStatement node) =>
      call('Continue', [if (node.label != null) ref(node.label.staticElement)]);

  List<Object> visitDoStatement(DoStatement node) => searchable(
      'Do', node, 'statement', call('Do', [node.body, node.condition]));

  List<Object> visitExpressionStatement(ExpressionStatement node) =>
      searchable('Expression', node, 'statement', visit(node.expression));

  List<Object> visitForStatement(ForStatement node) {
    var parts = node.forLoopParts;
    if (parts is ForPartsWithExpression) {
      return searchable(
          'ForExpr',
          node,
          'statement',
          call('ForExpr', [
            parts.initialization,
            parts.condition,
            parts.updaters,
            node.body
          ]));
    } else if (parts is ForEachPartsWithIdentifier) {
      var element = parts.identifier.staticElement;
      if (element is LocalVariableElement) {
        return searchable(
            'ForEachIdentifier',
            node,
            'statement',
            call('ForEachIdentifier',
                [ref(element), parts.iterable, node.body]));
      }
      throw '${element.runtimeType}';
    } else if (parts is ForEachPartsWithDeclaration) {
      return call('ForEachDeclared', [
        _declared('ForEachVariable', parts.loopVariable.identifier),
        parts.iterable,
        node.body
      ]);
    }
    throw '${parts.runtimeType}';
  }

  List<Object> visitFunctionDeclaration(FunctionDeclaration node) {
    _unusedList(node.metadata);
    _unused(node.functionExpression.typeParameters);
    return [
      ...extractable(
          node.declaredElement,
          call('Func', [
            node.returnType,
            node.name.name,
            node.functionExpression.parameters.parameters
          ])),
      '..body = ',
      ...visit(node.functionExpression.body)
    ];
  }

  List<Object> visitFunctionDeclarationStatement(
          FunctionDeclarationStatement node) =>
      visit(node.functionDeclaration);

  List<Object> visitFunctionExpression(FunctionExpression node) {
    _unused(node.typeParameters);
    return call('Closure', [node.parameters.parameters, node.body]);
  }

  List<Object> visitIfStatement(IfStatement node) => searchable(
      'If',
      node,
      'statement',
      call('If', [
        node.condition,
        node.thenStatement,
        if (node.elseStatement != null) node.elseStatement
      ]));

  List<Object> visitIntegerLiteral(IntegerLiteral node) =>
      searchable('Int', node, 'value_${node.value}', ['Int(${node.value})']);

  List<Object> visitIsExpression(IsExpression node) =>
      call('Is', [node.expression, node.type]);

  List<Object> visitLabel(Label node) {
    return extractable(
        node.label.staticElement, call('Label', [node.label.name]));
  }

  List<Object> visitListLiteral(ListLiteral node) => call('ListLiteral', [
        node.typeArguments == null ? null : node.typeArguments.arguments[0],
        node.elements
      ]);

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

  List<Object> visitMethodInvocation(MethodInvocation node) {
    _unused(node.target);
    _unused(node.typeArguments);
    var staticElement = node.methodName.staticElement;
    if (staticElement is FunctionElement) {
      return call(
          'StaticCall', [ref(staticElement), node.argumentList.arguments]);
    } else if (staticElement is LocalVariableElement) {
      return call(
          'LocalCall', [ref(staticElement), node.argumentList.arguments]);
    }
    throw 'TODO';
  }

  List<Object> visitNullLiteral(NullLiteral node) => call('Null', []);

  List<Object> visitParenthesizedExpression(ParenthesizedExpression node) =>
      searchable(
          'Expression', node, 'expression', call('Parens', [node.expression]));

  List<Object> visitPrefixedIdentifier(PrefixedIdentifier node) {
    var identifier = node.identifier;
    if (identifier.inDeclarationContext()) {
      throw 'TODO';
    } else if (identifier.inGetterContext()) {
      return call('PropertyGet', [node.prefix, node.identifier.name]);
    } else if (identifier.inSetterContext()) {
      throw 'TODO';
    } else {
      throw 'TODO';
    }
  }

  List<Object> visitPrefixExpression(PrefixExpression node) {
    switch (node.operator.lexeme) {
      case '!':
        return call('Not', [node.operand]);
      default:
        throw node.operator.lexeme;
    }
  }

  List<Object> visitRethrowExpression(RethrowExpression node) =>
      call('Rethrow', []);

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
        return searchable(
            'Get', node, node.name, call('Get', [ref(staticElement)]));
      }
      throw '${staticElement.runtimeType}';
    } else if (node.inSetterContext()) {
      throw 'TODO';
    } else {
      throw 'TODO';
    }
  }

  List<Object> visitSimpleStringLiteral(SimpleStringLiteral node) =>
      ['String(', node.value, ')'];

  List<Object> visitSwitchCase(SwitchCase node) {
    return call('Case', [node.labels, node.expression, node.statements]);
  }

  List<Object> visitSwitchStatement(SwitchStatement node) => searchable(
      'Switch',
      node,
      'statement',
      call('Switch', [node.expression, node.members]));

  List<Object> visitThrowExpression(ThrowExpression node) =>
      call('Throw', [node.expression]);

  List<Object> visitTryStatement(TryStatement node) => searchable(
      'Try',
      node,
      'statement',
      call('Try', [
        node.body,
        node.catchClauses,
        if (node.finallyBlock != null) node.finallyBlock
      ]));

  List<Object> visitTypeName(TypeName node) {
    _unused(node.typeArguments);
    return call('Type', [(node.name as SimpleIdentifier).name]);
  }

  List<Object> visitVariableDeclaration(VariableDeclaration node) {
    _unusedList(node.metadata);
    return [
      ...extractable(node.declaredElement, call('Local', [node.name.name])),
      if (node.initializer != null) ...[
        '..initializer = ',
        ...visit(node.initializer)
      ]
    ];
  }

  List<Object> visitVariableDeclarationStatement(
          VariableDeclarationStatement node) =>
      searchable('Locals', node, 'statement',
          call('Locals', [node.variables.variables]));

  List<Object> visitWhileStatement(WhileStatement node) => searchable(
      'While', node, 'statement', call('While', [node.condition, node.body]));

  List<Object> _declared(String method, SimpleIdentifier name) {
    return extractable(name.staticElement, call(method, [name.name]));
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

class ExtractedSubexpression {
  final String _name;

  ExtractedSubexpression(this._name);

  String toString() => _name;
}

@reflectiveTest
class RecordAllDone {
  test_all_done() {
    var encodedData =
        JsonEncoder.withIndent('  ').convert(_accumulatedTestData);
    print('List<List<Object>> testData = $encodedData;');
  }
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
      print(parsed.unit.accept(DslTransformer({})));
    } catch (e) {
      print('Error in $s: $e');
      rethrow;
    }
  }

  @override
  void visitUriBasedDirective(UriBasedDirective node) {}
}
