// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'source_span.dart';

/// Print a message with a source location.
void reportHere(SourceSpan node, String debugMessage) {
  print('${node.begin}: $debugMessage');
}
