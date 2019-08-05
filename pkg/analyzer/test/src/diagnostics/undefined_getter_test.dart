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
    defineReflectiveTests(UndefinedGetterTest);
    defineReflectiveTests(UndefinedGetterWithExtensionMethodsTest);
  });
}

@reflectiveTest
class UndefinedGetterTest extends DriverResolutionTest {
  test_ifElement_inList_notPromoted() async {
    await assertErrorsInCode('''
f(int x) {
  return [if (x is String) x.length];
}
''', [
      error(StaticTypeWarningCode.UNDEFINED_GETTER, 40, 6),
    ]);
  }

  test_ifElement_inList_promoted() async {
    await assertNoErrorsInCode('''
f(Object x) {
  return [if (x is String) x.length];
}
''');
  }

  test_ifElement_inMap_notPromoted() async {
    await assertErrorsInCode('''
f(int x) {
  return {if (x is String) x : x.length};
}
''', [
      error(StaticTypeWarningCode.UNDEFINED_GETTER, 44, 6),
    ]);
  }

  test_ifElement_inMap_promoted() async {
    await assertNoErrorsInCode('''
f(Object x) {
  return {if (x is String) x : x.length};
}
''');
  }

  test_ifElement_inSet_notPromoted() async {
    await assertErrorsInCode('''
f(int x) {
  return {if (x is String) x.length};
}
''', [
      error(StaticTypeWarningCode.UNDEFINED_GETTER, 40, 6),
    ]);
  }

  test_ifElement_inSet_promoted() async {
    await assertNoErrorsInCode('''
f(Object x) {
  return {if (x is String) x.length};
}
''');
  }

  test_ifStatement_notPromoted() async {
    await assertErrorsInCode('''
f(int x) {
  if (x is String) {
    x.length;
  }
}
''', [
      error(StaticTypeWarningCode.UNDEFINED_GETTER, 38, 6),
    ]);
  }

  test_ifStatement_promoted() async {
    await assertNoErrorsInCode('''
f(Object x) {
  if (x is String) {
    x.length;
  }
}
''');
  }

  test_nullMember_undefined() async {
    await assertErrorsInCode(r'''
m() {
  Null _null;
  _null.foo;
}
''', [
      error(StaticTypeWarningCode.UNDEFINED_GETTER, 28, 3),
    ]);
  }

  test_promotedTypeParameter_regress35305() async {
    await assertErrorsInCode(r'''
void f<X extends num, Y extends X>(Y y) {
  if (y is int) {
    y.isEven;
  }
}
''', [
      error(StaticTypeWarningCode.UNDEFINED_GETTER, 66, 6),
    ]);
  }
}

@reflectiveTest
class UndefinedGetterWithExtensionMethodsTest extends UndefinedGetterTest {
  @override
  AnalysisOptionsImpl get analysisOptions => AnalysisOptionsImpl()
    ..contextFeatures = new FeatureSet.forTesting(
        sdkVersion: '2.3.0', additionalFeatures: [Feature.extension_methods]);

  test_withExtension() async {
    await assertErrorsInCode(r'''
class C {}

extension E on C {}

f(C c) {
  c.a;
}
''', [
      error(StaticTypeWarningCode.UNDEFINED_GETTER, 46, 1),
    ]);
  }
}
