// TODO(multitest): This was automatically migrated from a multitest and may
// contain strange or dead code.

// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Test privacy issue for enums.

library enum_private_test;

import 'package:expect/expect.dart';

import 'enum_private_lib.dart';

enum Enum1 {
  _A,
  _B,
}

main() {
  Expect.equals('Enum1._A,Enum1._B', Enum1.values.join(','));


}
