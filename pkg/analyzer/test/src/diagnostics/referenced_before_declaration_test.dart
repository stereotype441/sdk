// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/error/codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ReferencedBeforeDeclarationTest);
  });
}

@reflectiveTest
class ReferencedBeforeDeclarationTest extends DriverResolutionTest {
  test_hideInBlock_comment() async {
    await assertNoErrorsInCode(r'''
main() {
  /// [v] is a variable.
  var v = 2;
}
print(x) {}
''');
  }

  test_hideInBlock_function() async {
    await assertErrorsInCode(r'''
var v = 1;
main() {
  print(v);
  v() {}
}
print(x) {}
''', [
      error(CompileTimeErrorCode.REFERENCED_BEFORE_DECLARATION, 28, 1,
          expectedMessages: [message('/test/lib/test.dart', 34, 1)]),
    ]);
  }

  test_hideInBlock_local() async {
    await assertErrorsInCode(r'''
var v = 1;
main() {
  print(v);
  var v = 2;
}
print(x) {}
''', [
      error(CompileTimeErrorCode.REFERENCED_BEFORE_DECLARATION, 28, 1,
          expectedMessages: [message('/test/lib/test.dart', 38, 1)]),
    ]);
  }

  test_hideInBlock_subBlock() async {
    await assertErrorsInCode(r'''
var v = 1;
main() {
  {
    print(v);
  }
  var v = 2;
}
print(x) {}
''', [
      error(CompileTimeErrorCode.REFERENCED_BEFORE_DECLARATION, 34, 1,
          expectedMessages: [message('/test/lib/test.dart', 48, 1)]),
    ]);
  }

  test_inInitializer_closure() async {
    await assertErrorsInCode(r'''
main() {
  var v = () => v;
}
''', [
      error(CompileTimeErrorCode.REFERENCED_BEFORE_DECLARATION, 25, 1,
          expectedMessages: [message('/test/lib/test.dart', 15, 1)]),
    ]);
  }

  test_inInitializer_directly() async {
    await assertErrorsInCode(r'''
main() {
  var v = v;
}
''', [
      error(CompileTimeErrorCode.REFERENCED_BEFORE_DECLARATION, 19, 1,
          expectedMessages: [message('/test/lib/test.dart', 15, 1)]),
    ]);
  }

  test_type_localFunction() async {
    await assertErrorsInCode(r'''
void testTypeRef() {
  String s = '';
  int String(int x) => x + 1;
  print(s + String);
}
''', [
      error(CompileTimeErrorCode.REFERENCED_BEFORE_DECLARATION, 23, 6,
          expectedMessages: [message('/test/lib/test.dart', 44, 6)]),
    ]);
  }

  test_type_localVariable() async {
    await assertErrorsInCode(r'''
void testTypeRef() {
  String s = '';
  var String = '';
  print(s + String);
}
''', [
      error(CompileTimeErrorCode.REFERENCED_BEFORE_DECLARATION, 23, 6,
          expectedMessages: [message('/test/lib/test.dart', 44, 6)]),
    ]);
  }
}
