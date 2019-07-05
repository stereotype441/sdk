// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/*strong.member: method:direct,explicit=[method.T],needsArgs*/
/*omit.member: method:direct,explicit=[method.T],needsArgs*/
method<T>(T t) => t is T;

main() {
  method<int>(0);
}
