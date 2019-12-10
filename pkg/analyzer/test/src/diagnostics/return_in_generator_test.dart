// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/error/codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ReturnInGeneratorTest);
  });
}

@reflectiveTest
class ReturnInGeneratorTest extends DriverResolutionTest {
  test_asyncStar() async {
    await assertErrorsInCode(r'''
f() async* {
  return 0;
}
''', [
      error(CompileTimeErrorCode.RETURN_IN_GENERATOR, 15, 9),
      error(CompileTimeErrorCode.RETURN_IN_GENERATOR, 15, 6),
    ]);
  }

  test_syncStar() async {
    await assertErrorsInCode(r'''
f() sync* {
  return 0;
}
''', [
      error(CompileTimeErrorCode.RETURN_IN_GENERATOR, 14, 9),
      error(CompileTimeErrorCode.RETURN_IN_GENERATOR, 14, 6),
    ]);
  }
}
