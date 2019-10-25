// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/*member: ordinary:assigned={x}*/
ordinary(int x, int y) {
  x = y;
}

/*member: nullAware:assigned={x}*/
nullAware(int? x, int y) {
  x ??= y;
}

/*member: compound:assigned={x}*/
compound(int x, int y) {
  x += y;
}
