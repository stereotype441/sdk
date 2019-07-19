// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UndefinedExtensionGetterTest);
  });
}

@reflectiveTest
class UndefinedExtensionGetterTest extends DriverResolutionTest {
  @override
  AnalysisOptionsImpl get analysisOptions => AnalysisOptionsImpl()
    ..contextFeatures = new FeatureSet.forTesting(
        sdkVersion: '2.3.0', additionalFeatures: [Feature.extension_methods]);

  test_defined() async {
    await assertNoErrorsInCode('''
extension E on String {
  int get g => 0;
}
f() {
  E('a').g;
}
''');
  }

  test_undefined() async {
    await assertErrorsInCode('''
extension E on String {}
f() {
  E('a').g;
}
''', [
      error(CompileTimeErrorCode.UNDEFINED_EXTENSION_GETTER, 40, 1),
    ]);
  }

  test_undefined_withSetter() async {
    await assertErrorsInCode('''
extension E on String {
  void set s(int x) {}
}
f() {
  E('a').s += 1;
}
''', [
      error(CompileTimeErrorCode.UNDEFINED_EXTENSION_GETTER, 64, 1),
    ]);
  }
}
