// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/util/ast_data_extractor.dart';
import 'package:front_end/src/testing/id_testing.dart';
import 'package:front_end/src/testing/id.dart' show ActualData, Id;
import '../util/id_testing_helper.dart';

main(List<String> args) async {
  Directory dataDir = new Directory.fromUri(Platform.script.resolve('../../../front_end/test/constants/data'));
  await runTests(dataDir,
      args: args,
      supportedMarkers: sharedMarkers,
      createUriForFileName: createUriForFileName,
      onFailure: onFailure,
      runTest: runTestFor(
          const ConstantsDataComputer(), [analyzerConstantUpdate2018Config]));
}

class ConstantsDataComputer extends DataComputer<String> {
  const ConstantsDataComputer();

  @override
  void computeUnitData(CompilationUnit unit,
      Map<Id, ActualData<String>> actualMap) {
    ConstantsDataExtractor(unit.declaredElement.source.uri, actualMap)
        .run(unit);
  }

  @override
  DataInterpreter<String> get dataValidator => const StringDataInterpreter();
}

class ConstantsDataExtractor extends AstDataExtractor<String> {
  ConstantsDataExtractor(
      Uri uri, Map<Id, ActualData<String>> actualMap)
      : super(uri, actualMap);

  @override
  String computeNodeValue(Id id, AstNode node) {
    print('Examining node $node');
    if (node is Identifier) {
      var element = node.staticElement;
      if (element is PropertyAccessorElement && element.isSynthetic) {
        var variable = element.variable;
        if (!variable.isSynthetic && variable.isConst) {
          var value = variable.constantValue;
          throw '$value';
        }
      }
    }
    // TODO(paulberry): figure out what to do here.
    return null;
  }
}
