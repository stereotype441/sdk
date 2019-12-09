// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/dart/error/hint_codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(BadDartLanguageOverrideTest);
  });
}

@reflectiveTest
class BadDartLanguageOverrideTest extends DriverResolutionTest {
  test_correct_withMultipleWhitespace() async {
    await assertNoErrorsInCode(r'''
//  @dart  =  2.0  
int i = 0;
''');
  }

  test_correct_withoutWhitespace() async {
    await assertNoErrorsInCode(r'''
//@dart=2.0
int i = 0;
''');
  }

  test_correct_withWhitespace() async {
    await assertNoErrorsInCode(r'''
// @dart = 2.0
int i = 0;
''');
  }

  test_embeddedInBlockComment() async {
    await assertNoErrorsInCode(r'''
/**
 *  // @dart = 2.0
 */
int i = 0;
''');
  }

  test_embeddedInBlockComment_noLeadingAsterisk() async {
    await assertNoErrorsInCode(r'''
/* Big comment.
// @dart = 2.0
 */
int i = 0;
''');
  }

  test_invalidOverrideFollowsValidOverride() async {
    await assertNoErrorsInCode(r'''
// @dart = 2.0
// comment.
// @dart >= 2.0
int i = 0;
''');
  }

  test_missingAtSign() async {
    await assertErrorsInCode(r'''
// dart = 2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_AT_SIGN, 0, 13)]);
  }

  test_missingSeparator() async {
    await assertErrorsInCode(r'''
// @dart 2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_EQUALS, 0, 12)]);
  }

  test_nonVersionOverride_atDart2js() async {
    await assertNoErrorsInCode(r'''
/// @dart2js.
int i = 0;
''');
  }

  test_nonVersionOverride_dart2js() async {
    await assertNoErrorsInCode(r'''
/// dart2js.
int i = 0;
''');
  }

  test_nonVersionOverride_empty() async {
    await assertNoErrorsInCode(r'''
///
int i = 0;
''');
  }

  test_nonVersionOverride_noNumbers() async {
    await assertNoErrorsInCode(r'''
// @dart
int i = 0;
''');
  }

  test_nonVersionOverride_noSeparatorOrNumber() async {
    await assertNoErrorsInCode(r'''
/// dart is great.
int i = 0;
''');
  }

  test_nonVersionOverride_onlyWhitespace() async {
    await assertNoErrorsInCode(r'''
///  

int i = 0;
''');
  }

  test_nonVersionOverride_otherText() async {
    await assertNoErrorsInCode(r'''
// @dart is great
int i = 0;
''');
  }

  test_noWhitespace() async {
    await assertNoErrorsInCode(r'''
//@dart=2.0
int i = 0;
''');
  }

  test_separatorIsTooLong() async {
    await assertErrorsInCode(r'''
// @dart >= 2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_EQUALS, 0, 15)]);
  }

  test_shebangLine() async {
    await assertNoErrorsInCode(r'''
#!/usr/bin/dart
// @dart = 2.0
int i = 0;
''');
  }

  test_shebangLine_wrongCase() async {
    await assertErrorsInCode(r'''
#!/usr/bin/dart
// @Dart = 2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_LOWER_CASE, 16, 14)]);
  }

  test_tooManySlashes() async {
    await assertErrorsInCode(r'''
/// @dart = 2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_TWO_SLASHES, 0, 15)]);
  }

  test_wrongAtSignPosition() async {
    await assertErrorsInCode(r'''
// dart @ 2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_AT_SIGN, 0, 13)]);
  }

  test_wrongCase_firstComment() async {
    await assertErrorsInCode(r'''
// @Dart = 2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_LOWER_CASE, 0, 14)]);
  }

  test_wrongCase_multilineComment() async {
    await assertErrorsInCode(r'''
// Copyright
// @Dart = 2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_LOWER_CASE, 13, 14)]);
  }

  test_wrongCase_secondComment() async {
    await assertErrorsInCode(r'''
// Copyright

// @Dart = 2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_LOWER_CASE, 14, 14)]);
  }

  test_wrongSeparator_noSpace() async {
    await assertErrorsInCode(r'''
// @dart:2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_EQUALS, 0, 12)]);
  }

  test_wrongSeparator_withSpace() async {
    await assertErrorsInCode(r'''
// @dart : 2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_EQUALS, 0, 14)]);
  }

  test_wrongVersion_extraSpecificity() async {
    await assertErrorsInCode(r'''
// @dart = 2.0.0
int i = 0;
''', [
      error(
          HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_TRAILING_CHARACTERS, 0, 16)
    ]);
  }

  test_wrongVersion_noMinorVersion() async {
    await assertErrorsInCode(r'''
// @dart = 2
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_NUMBER, 0, 12)]);
  }

  test_wrongVersion_prefixCharacter() async {
    await assertErrorsInCode(r'''
// @dart = v2.0
int i = 0;
''', [error(HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_PREFIX, 0, 15)]);
  }

  test_wrongVersion_tooManyDigits() async {
    await assertErrorsInCode(r'''
// @dart = 2.00
int i = 0;
''', [
      error(
          HintCode.INVALID_LANGUAGE_VERSION_OVERRIDE_TRAILING_CHARACTERS, 0, 15)
    ]);
  }
}
