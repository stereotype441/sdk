// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.builtin_type_builder;

import 'package:kernel/ast.dart' show DartType;

import 'builder.dart' show LibraryBuilder, TypeBuilder, TypeDeclarationBuilder;

abstract class BuiltinTypeBuilder extends TypeDeclarationBuilder {
  final DartType type;

  BuiltinTypeBuilder(
      String name, this.type, LibraryBuilder compilationUnit, int charOffset)
      : super(null, 0, name, compilationUnit, charOffset);

  DartType buildType(LibraryBuilder library, List<TypeBuilder> arguments) =>
      type;

  DartType buildTypesWithBuiltArguments(
      LibraryBuilder library, List<DartType> arguments) {
    return type;
  }

  String get debugName => "BuiltinTypeBuilder";
}
