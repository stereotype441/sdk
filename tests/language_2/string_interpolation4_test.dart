// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// A dollar must be followed by a "{" or an identifier.

class StringInterpolation4NegativeTest {
  static testMain() {
    // Dollar not followed by "{" or identifier.
    print("-" + "$" + "foo");
    //            ^
    // [analyzer] SYNTACTIC_ERROR.MISSING_IDENTIFIER
    // [cfe] A '$' has special meaning inside a string, and must be followed by an identifier or an expression in curly braces ({}).
  }
}

main() {
  StringInterpolation4NegativeTest.testMain();
}
