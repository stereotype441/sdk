// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/analysis/testing_data.dart';
import 'package:analyzer/src/dart/resolver/flow_analysis_visitor.dart';
import 'package:analyzer/src/util/ast_data_extractor.dart';
import 'package:front_end/src/fasta/flow_analysis/flow_analysis.dart';
import 'package:front_end/src/testing/id.dart' show ActualData, Id;
import 'package:front_end/src/testing/id_testing.dart';

import '../util/id_testing_helper.dart';

main(List<String> args) async {
  Directory dataDir = new Directory.fromUri(Platform.script.resolve(
      '../../../front_end/test/flow_analysis/assigned_variables/data'));
  await runTests(dataDir,
      args: args,
      supportedMarkers: sharedMarkers,
      createUriForFileName: createUriForFileName,
      onFailure: onFailure,
      runTest: runTestFor(
          const _AssignedVariablesDataComputer(), [analyzerNnbdConfig]));
}

class _AssignedVariablesDataComputer extends DataComputer<_Data> {
  const _AssignedVariablesDataComputer();

  @override
  DataInterpreter<_Data> get dataValidator =>
      const _AssignedVariablesDataInterpreter();

  @override
  void computeUnitData(TestingData testingData, CompilationUnit unit,
      Map<Id, ActualData<_Data>> actualMap) {
    var flowResult =
        testingData.uriToFlowAnalysisData[unit.declaredElement.source.uri];
    _AssignedVariablesDataExtractor(
            unit.declaredElement.source.uri, actualMap, flowResult)
        .run(unit);
  }
}

class _AssignedVariablesDataExtractor extends AstDataExtractor<_Data> {
  final FlowAnalysisDataForTesting _flowResult;

  Declaration _currentDeclaration;

  AssignedVariablesForTesting<AstNode, PromotableElement>
      _currentAssignedVariables;

  _AssignedVariablesDataExtractor(
      Uri uri, Map<Id, ActualData<_Data>> actualMap, this._flowResult)
      : super(uri, actualMap);

  @override
  _Data computeNodeValue(Id id, AstNode node) {
    if (node == _currentDeclaration) {
      return _Data(_convertVars(_currentAssignedVariables.writtenAnywhere),
          _convertVars(_currentAssignedVariables.capturedAnywhere));
    }
    if (node is FunctionExpression && node.parent == _currentDeclaration) {
      // TODO(paulberry): there is extra data here that's unnecessary.  Get rid
      // of it.
      return null;
    }
    if (!_currentAssignedVariables.isTracked(node)) return null;
    return _Data(_convertVars(_currentAssignedVariables.writtenInNode(node)),
        _convertVars(_currentAssignedVariables.capturedInNode(node)));
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit) {
      assert(_currentDeclaration == null);
      _currentDeclaration = node;
      assert(_currentAssignedVariables == null);
      _currentAssignedVariables = _flowResult.assignedVariables[node];
      super.visitFunctionDeclaration(node);
      _currentDeclaration = null;
      _currentAssignedVariables = null;
    } else {
      super.visitFunctionDeclaration(node);
    }
  }

  Set<String> _convertVars(Iterable<PromotableElement> x) =>
      x.map((e) => e.name).toSet();
}

class _AssignedVariablesDataInterpreter implements DataInterpreter<_Data> {
  const _AssignedVariablesDataInterpreter();

  @override
  String getText(_Data actualData) {
    var parts = <String>[];
    if (actualData.assigned.isNotEmpty) {
      parts.add('assigned=${_setToString(actualData.assigned)}');
    }
    if (actualData.captured.isNotEmpty) {
      parts.add('captured=${_setToString(actualData.captured)}');
    }
    if (parts.isEmpty) return 'none';
    return parts.join(', ');
  }

  @override
  String isAsExpected(_Data actualData, String expectedData) {
    var actualDataText = getText(actualData);
    if (actualDataText == expectedData) {
      return null;
    } else {
      return 'Expected "$expectedData", got "$actualDataText"';
    }
  }

  @override
  bool isEmpty(_Data actualData) =>
      actualData.assigned.isEmpty && actualData.captured.isEmpty;

  String _setToString(Set<String> values) {
    List<String> sortedValues = values.toList()..sort();
    return '{${sortedValues.join(', ')}}';
  }
}

class _Data {
  final Set<String> assigned;

  final Set<String> captured;

  _Data(this.assigned, this.captured);
}
