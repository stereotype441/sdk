// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/dart/analysis/testing_data.dart';
import 'package:analyzer/src/util/ast_data_extractor.dart';
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
    _AssignedVariablesDataExtractor(unit.declaredElement.source.uri, actualMap)
        .run(unit);
  }
}

class _AssignedVariablesDataExtractor extends AstDataExtractor<_Data> {
  _AssignedVariablesDataExtractor(Uri uri, Map<Id, ActualData<_Data>> actualMap)
      : super(uri, actualMap);

  @override
  _Data computeNodeValue(Id id, AstNode node) {
    throw UnimplementedError('TODO(paulberry)');
  }
}

class _AssignedVariablesDataInterpreter implements DataInterpreter<_Data> {
  const _AssignedVariablesDataInterpreter();

  @override
  String getText(_Data actualData) {
    throw UnimplementedError('TODO(paulberry)');
  }

  @override
  String isAsExpected(_Data actualData, String expectedData) {
    throw UnimplementedError('TODO(paulberry)');
  }

  @override
  bool isEmpty(_Data actualData) => throw UnimplementedError('TODO(paulberry)');
}

class _Data {
  final Set<String> assigned;

  final Set<String> captured;

  _Data(this.assigned, this.captured);
}
