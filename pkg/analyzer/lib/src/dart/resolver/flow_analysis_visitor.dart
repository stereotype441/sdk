// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/variable_type_provider.dart';
import 'package:front_end/src/fasta/flow_analysis/flow_analysis.dart';

/// The helper for performing flow analysis during resolution.
///
/// It contains related precomputed data, result, and non-trivial pieces of
/// code that are independent from visiting AST during resolution, so can
/// be extracted.
class FlowAnalysisHelper {
  /// The reused instance for creating new [FlowAnalysis] instances.
  final TypeSystemTypeOperations _typeOperations;

  /// Precomputed sets of potentially assigned variables.
  AssignedVariables<AstNode, PromotableElement> assignedVariables;

  /// The result for post-resolution stages of analysis.
  final FlowAnalysisResult result;

  /// The current flow, when resolving a function body, or `null` otherwise.
  FlowAnalysis<Statement, Expression, PromotableElement, DartType> flow;

  factory FlowAnalysisHelper(TypeSystem typeSystem, bool retainDataForTesting) {
    return FlowAnalysisHelper._(TypeSystemTypeOperations(typeSystem),
        retainDataForTesting ? FlowAnalysisResult() : null);
  }

  FlowAnalysisHelper._(this._typeOperations, this.result);

  LocalVariableTypeProvider get localVariableTypeProvider {
    return _LocalVariableTypeProvider(this);
  }

  VariableElement assignmentExpression(AssignmentExpression node) {
    if (flow == null) return null;

    var left = node.leftHandSide;

    if (left is SimpleIdentifier) {
      var element = left.staticElement;
      if (element is VariableElement) {
        return element;
      }
    }

    return null;
  }

  void assignmentExpression_afterRight(
      VariableElement localElement, Expression right) {
    if (localElement == null) return;

    flow.write(localElement);
  }

  void breakStatement(BreakStatement node) {
    var target = getLabelTarget(node, node.label?.staticElement);
    flow.handleBreak(target);
  }

  /// Mark the [node] as unreachable if it is not covered by another node that
  /// is already known to be unreachable.
  void checkUnreachableNode(AstNode node) {
    if (flow == null) return;
    if (flow.isReachable) return;

    if (result != null) {
      // Ignore the [node] if it is fully covered by the last unreachable.
      if (result.unreachableNodes.isNotEmpty) {
        var last = result.unreachableNodes.last;
        if (node.offset >= last.offset && node.end <= last.end) return;
      }

      result.unreachableNodes.add(node);
    }
  }

  void continueStatement(ContinueStatement node) {
    var target = getLabelTarget(node, node.label?.staticElement);
    flow.handleContinue(target);
  }

  void executableDeclaration_enter(
      Declaration node, FormalParameterList parameters, bool isClosure) {
    if (parameters != null) {
      for (var parameter in parameters.parameters) {
        flow.initialize(parameter.declaredElement);
      }
    }

    if (isClosure) {
      flow.functionExpression_begin(assignedVariables.writtenInNode(node));
    }
  }

  void executableDeclaration_exit(FunctionBody body, bool isClosure) {
    if (isClosure) {
      flow.functionExpression_end();
    }
    if (!flow.isReachable) {
      result?.functionBodiesThatDontComplete?.add(body);
    }
  }

  void for_bodyBegin(AstNode node, Expression condition) {
    flow.for_bodyBegin(node is Statement ? node : null, condition);
  }

  void for_conditionBegin(AstNode node, Expression condition) {
    flow.for_conditionBegin(assignedVariables.writtenInNode(node),
        assignedVariables.capturedInNode(node));
  }

  void isExpression(IsExpression node) {
    if (flow == null) return;

    var expression = node.expression;
    var typeAnnotation = node.type;

    flow.isExpression_end(
      node,
      expression,
      node.notOperator != null,
      typeAnnotation.type,
    );
  }

  bool isPotentiallyNonNullableLocalReadBeforeWrite(SimpleIdentifier node) {
    if (flow == null) return false;

    if (node.inDeclarationContext()) return false;
    if (!node.inGetterContext()) return false;

    var element = node.staticElement;
    if (element is LocalVariableElement) {
      var typeSystem = _typeOperations.typeSystem;
      if (typeSystem.isPotentiallyNonNullable(element.type)) {
        var isUnassigned = !flow.isAssigned(element);
        if (isUnassigned) {
          result?.unassignedNodes?.add(node);
        }
        // Note: in principle we could make this slightly more performant by
        // checking element.isLate earlier, but we would lose the ability to
        // test the flow analysis mechanism using late variables.  And it seems
        // unlikely that the `late` modifier will be used often enough for it to
        // make a significant difference.
        if (element.isLate) return false;
        return isUnassigned;
      }
    }

    return false;
  }

  void topLevelDeclaration_enter(
      Declaration node, FormalParameterList parameters, FunctionBody body) {
    assert(node != null);
    assert(flow == null);
    assignedVariables = computeAssignedVariables(node, parameters);
    flow = FlowAnalysis<Statement, Expression, PromotableElement, DartType>(
        _typeOperations,
        assignedVariables.writtenAnywhere,
        assignedVariables.capturedAnywhere);
  }

  void topLevelDeclaration_exit() {
    // Set this.flow to null before doing any clean-up so that if an exception
    // is raised, the state is already updated correctly, and we don't have
    // cascading failures.
    var flow = this.flow;
    this.flow = null;
    assignedVariables = null;

    flow.finish();
  }

  void variableDeclarationList(VariableDeclarationList node) {
    if (flow != null) {
      var variables = node.variables;
      for (var i = 0; i < variables.length; ++i) {
        var variable = variables[i];
        if (variable.initializer != null) {
          flow.initialize(variable.declaredElement);
        }
      }
    }
  }

  /// Computes the [AssignedVariables] map for the given [node].
  static AssignedVariables<AstNode, PromotableElement> computeAssignedVariables(
      Declaration node, FormalParameterList parameters) {
    var assignedVariables = AssignedVariables<AstNode, PromotableElement>();
    var assignedVariablesVisitor = _AssignedVariablesVisitor(assignedVariables);
    assignedVariablesVisitor._declareParameters(parameters);
    node.visitChildren(assignedVariablesVisitor);
    assignedVariables.finish();
    return assignedVariables;
  }

  /// Return the target of the `break` or `continue` statement with the
  /// [element] label. The [element] might be `null` (when the statement does
  /// not specify a label), so the default enclosing target is returned.
  static Statement getLabelTarget(AstNode node, LabelElement element) {
    for (; node != null; node = node.parent) {
      if (node is DoStatement ||
          node is ForStatement ||
          node is SwitchStatement ||
          node is WhileStatement) {
        if (element == null) {
          return node;
        }
        var parent = node.parent;
        if (parent is LabeledStatement) {
          for (var nodeLabel in parent.labels) {
            if (identical(nodeLabel.label.staticElement, element)) {
              return node;
            }
          }
        }
      }
      if (element != null && node is SwitchStatement) {
        for (var member in node.members) {
          for (var nodeLabel in member.labels) {
            if (identical(nodeLabel.label.staticElement, element)) {
              return node;
            }
          }
        }
      }
    }
    return null;
  }
}

/// The result of performing flow analysis on a unit.
class FlowAnalysisResult {
  /// The list of nodes, [Expression]s or [Statement]s, that cannot be reached,
  /// for example because a previous statement always exits.
  final List<AstNode> unreachableNodes = [];

  /// The list of [FunctionBody]s that don't complete, for example because
  /// there is a `return` statement at the end of the function body block.
  final List<FunctionBody> functionBodiesThatDontComplete = [];

  /// The list of [Expression]s representing variable accesses that occur before
  /// the corresponding variable has been definitely assigned.
  final List<AstNode> unassignedNodes = [];
}

class TypeSystemTypeOperations
    implements TypeOperations<PromotableElement, DartType> {
  final TypeSystem typeSystem;

  TypeSystemTypeOperations(this.typeSystem);

  @override
  bool isSameType(covariant TypeImpl type1, covariant TypeImpl type2) {
    return type1 == type2;
  }

  @override
  bool isSubtypeOf(DartType leftType, DartType rightType) {
    return typeSystem.isSubtypeOf(leftType, rightType);
  }

  @override
  DartType promoteToNonNull(DartType type) {
    return typeSystem.promoteToNonNull(type);
  }

  @override
  DartType variableType(PromotableElement variable) {
    return variable.type;
  }
}

/// The visitor that gathers local variables that are potentially assigned
/// in corresponding statements, such as loops, `switch` and `try`.
class _AssignedVariablesVisitor extends RecursiveAstVisitor<void> {
  final AssignedVariables assignedVariables;

  _AssignedVariablesVisitor(this.assignedVariables);

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    var left = node.leftHandSide;

    super.visitAssignmentExpression(node);

    if (left is SimpleIdentifier) {
      var element = left.staticElement;
      if (element is VariableElement) {
        assignedVariables.write(element);
      }
    }
  }

  @override
  void visitCatchClause(CatchClause node) {
    for (var identifier in [
      node.exceptionParameter,
      node.stackTraceParameter
    ]) {
      if (identifier != null) {
        assignedVariables
            .declare(identifier.staticElement as PromotableElement);
      }
    }
    super.visitCatchClause(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    throw StateError('Should not visit top level declarations');
  }

  @override
  void visitDoStatement(DoStatement node) {
    assignedVariables.beginNode();
    super.visitDoStatement(node);
    assignedVariables.endNode(node);
  }

  @override
  void visitForElement(ForElement node) {
    _handleFor(node, node.forLoopParts, node.body);
  }

  @override
  void visitForStatement(ForStatement node) {
    _handleFor(node, node.forLoopParts, node.body);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit) {
      throw StateError('Should not visit top level declarations');
    }
    assignedVariables.beginNode();
    _declareParameters(node.functionExpression.parameters);
    // Note: we bypass this.visitFunctionExpression so that the function
    // expression isn't mistaken for a closure.
    super.visitFunctionExpression(node.functionExpression);
    assignedVariables.endNode(node, isClosure: true);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    assignedVariables.beginNode();
    _declareParameters(node.parameters);
    super.visitFunctionExpression(node);
    assignedVariables.endNode(node, isClosure: true);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    throw StateError('Should not visit top level declarations');
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    var expression = node.expression;
    var members = node.members;

    expression.accept(this);

    assignedVariables.beginNode();
    members.accept(this);
    assignedVariables.endNode(node);
  }

  @override
  void visitTryStatement(TryStatement node) {
    assignedVariables.beginNode();
    node.body.accept(this);
    assignedVariables.endNode(node.body);

    node.catchClauses.accept(this);

    var finallyBlock = node.finallyBlock;
    if (finallyBlock != null) {
      assignedVariables.beginNode();
      finallyBlock.accept(this);
      assignedVariables.endNode(finallyBlock);
    }
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    var grandParent = node.parent.parent;
    if (grandParent is TopLevelVariableDeclaration ||
        grandParent is FieldDeclaration) {
      throw StateError('Should not visit top level declarations');
    }
    assignedVariables.declare(node.declaredElement);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    assignedVariables.beginNode();
    super.visitWhileStatement(node);
    assignedVariables.endNode(node);
  }

  void _declareParameters(FormalParameterList parameters) {
    if (parameters == null) return;
    for (var parameter in parameters.parameters) {
      assignedVariables.declare(parameter.declaredElement);
    }
  }

  void _handleFor(AstNode node, ForLoopParts forLoopParts, AstNode body) {
    if (forLoopParts is ForParts) {
      if (forLoopParts is ForPartsWithExpression) {
        forLoopParts.initialization?.accept(this);
      } else if (forLoopParts is ForPartsWithDeclarations) {
        forLoopParts.variables?.accept(this);
      } else {
        throw new StateError('Unrecognized for loop parts');
      }

      assignedVariables.beginNode();
      forLoopParts.condition?.accept(this);
      body.accept(this);
      forLoopParts.updaters?.accept(this);
      assignedVariables.endNode(node);
    } else if (forLoopParts is ForEachParts) {
      var iterable = forLoopParts.iterable;

      iterable.accept(this);

      assignedVariables.beginNode();
      if (forLoopParts is ForEachPartsWithIdentifier) {
        var element = forLoopParts.identifier.staticElement;
        if (element is VariableElement) {
          assignedVariables.write(element);
        }
      } else if (forLoopParts is ForEachPartsWithDeclaration) {
        var variable = forLoopParts.loopVariable.declaredElement;
        assignedVariables.declare(variable);
        assignedVariables.write(variable);
      } else {
        throw new StateError('Unrecognized for loop parts');
      }
      body.accept(this);
      assignedVariables.endNode(node);
    } else {
      throw new StateError('Unrecognized for loop parts');
    }
  }
}

/// The flow analysis based implementation of [LocalVariableTypeProvider].
class _LocalVariableTypeProvider implements LocalVariableTypeProvider {
  final FlowAnalysisHelper _manager;

  _LocalVariableTypeProvider(this._manager);

  @override
  DartType getType(SimpleIdentifier node) {
    var variable = node.staticElement as VariableElement;
    if (variable is PromotableElement) {
      var promotedType = _manager.flow?.variableRead(node, variable);
      if (promotedType != null) return promotedType;
    }
    return variable.type;
  }
}
