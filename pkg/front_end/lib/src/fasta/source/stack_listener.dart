// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.stack_listener;

import 'package:_fe_analyzer_shared/src/parser/parser.dart'
    show Listener, MemberKind, Parser, lengthOfSpan;

import 'package:_fe_analyzer_shared/src/parser/identifier_context.dart'
    show IdentifierContext;

import 'package:_fe_analyzer_shared/src/scanner/scanner.dart' show Token;

import 'package:kernel/ast.dart'
    show AsyncMarker, Expression, FunctionNode, TreeNode;

import '../fasta_codes.dart'
    show
        Code,
        LocatedMessage,
        Message,
        codeCatchSyntaxExtraParameters,
        codeNativeClauseShouldBeAnnotation,
        templateInternalProblemStackNotEmpty;

import '../problems.dart'
    show internalProblem, unhandled, unimplemented, unsupported;

import '../quote.dart' show unescapeString;

import 'stack_listener_2.dart';

import 'value_kinds.dart';

export 'stack_listener_2.dart';

/// Helper constant for popping a list of the top of a [Stack].  This helper
/// returns null instead of empty lists, and the lists returned are of fixed
/// length.
class FixedNullableList<T> {
  const FixedNullableList();

  List<T> pop(Stack stack, int count, [NullValue nullValue]) {
    if (count == 0) return null;
    return stack.popList(count, new List<T>(count), nullValue);
  }

  List<T> popPadded(Stack stack, int count, int padding,
      [NullValue nullValue]) {
    if (count + padding == 0) return null;
    return stack.popList(count, new List<T>(count + padding), nullValue);
  }
}

/// Helper constant for popping a list of the top of a [Stack].  This helper
/// returns growable lists (also when empty).
class GrowableList<T> {
  const GrowableList();

  List<T> pop(Stack stack, int count, [NullValue nullValue]) {
    return stack.popList(
        count, new List<T>.filled(count, null, growable: true), nullValue);
  }
}

/// A null-aware alternative to `token.offset`.  If [token] is `null`, returns
/// `TreeNode.noOffset`.
int offsetForToken(Token token) {
  return token == null ? TreeNode.noOffset : token.offset;
}
