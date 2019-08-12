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
    defineReflectiveTests(AmbiguousExtensionMethodAccessTest);
  });
}

@reflectiveTest
class AmbiguousExtensionMethodAccessTest extends DriverResolutionTest {
  @override
  AnalysisOptionsImpl get analysisOptions => AnalysisOptionsImpl()
    ..contextFeatures = new FeatureSet.forTesting(
        sdkVersion: '2.3.0', additionalFeatures: [Feature.extension_methods]);

  test_call() async {
    await assertErrorsInCode('''
class A {}

extension E1 on A {
  int call() => 0;
}

extension E2 on A {
  int call() => 0;
}

int f(A a) => a();
''', [
      error(CompileTimeErrorCode.AMBIGUOUS_EXTENSION_METHOD_ACCESS, 110, 1),
    ]);
  }

  test_getter() async {
    await assertErrorsInCode('''
class A {}

extension E1 on A {
  void get a => 1;
}

extension E2 on A {
  void get a => 2;
}

f(A a) {
  a.a;
}
''', [
      error(CompileTimeErrorCode.AMBIGUOUS_EXTENSION_METHOD_ACCESS, 109, 1),
    ]);
  }

  test_method() async {
    await assertErrorsInCode('''
class A {}

extension E1 on A {
  void a() {}
}

extension E2 on A {
  void a() {}
}

f(A a) {
  a.a();
}
''', [
      error(CompileTimeErrorCode.AMBIGUOUS_EXTENSION_METHOD_ACCESS, 99, 1),
    ]);
  }

  test_operator_binary() async {
    // There is no error reported.
    await assertErrorsInCode('''
class A {}

extension E1 on A {
  A operator +(A a) => a;
}

extension E2 on A {
  A operator +(A a) => a;
}

A f(A a) => a + a;
''', [
      error(CompileTimeErrorCode.AMBIGUOUS_EXTENSION_METHOD_ACCESS, 122, 5),
    ]);
  }

  test_operator_index() async {
    await assertErrorsInCode('''
class A {}

extension E1 on A {
  int operator [](int i) => 0;
}

extension E2 on A {
  int operator [](int i) => 0;
}

int f(A a) => a[0];
''', [
      error(CompileTimeErrorCode.AMBIGUOUS_EXTENSION_METHOD_ACCESS, 134, 1),
    ]);
  }

  test_operator_unary() async {
    await assertErrorsInCode('''
class A {}

extension E1 on A {
  int operator -() => 0;
}

extension E2 on A {
  int operator -() => 0;
}

int f(A a) => -a;
''', [
      error(CompileTimeErrorCode.AMBIGUOUS_EXTENSION_METHOD_ACCESS, 123, 1),
    ]);
  }

  test_setter() async {
    await assertErrorsInCode('''
class A {}

extension E1 on A {
  set a(x) {}
}

extension E2 on A {
  set a(x) {}
}

f(A a) {
  a.a = 3;
}
''', [
      error(CompileTimeErrorCode.AMBIGUOUS_EXTENSION_METHOD_ACCESS, 99, 1),
    ]);
  }
}
