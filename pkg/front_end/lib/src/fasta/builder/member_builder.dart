// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.member_builder;

import '../problems.dart' show unsupported;

import 'builder.dart'
    show ClassBuilder, Builder, LibraryBuilder, ModifierBuilder;

import 'declaration_builder.dart';
import 'extension_builder.dart';

abstract class MemberBuilder extends ModifierBuilder {
  /// For top-level members, the parent is set correctly during
  /// construction. However, for class members, the parent is initially the
  /// library and updated later.
  @override
  Builder parent;

  @override
  String get name;

  MemberBuilder(this.parent, int charOffset) : super(parent, charOffset);

  bool get isDeclarationInstanceMember => isDeclarationMember && !isStatic;

  @override
  bool get isClassInstanceMember => isClassMember && !isStatic;

  @override
  bool get isExtensionInstanceMember => isExtensionMember && !isStatic;

  @override
  bool get isDeclarationMember => parent is DeclarationBuilder;

  @override
  bool get isClassMember => parent is ClassBuilder;

  @override
  bool get isExtensionMember => parent is ExtensionBuilder;

  @override
  bool get isTopLevel => !isDeclarationMember;

  @override
  bool get isNative => false;

  bool get isRedirectingGenerativeConstructor => false;

  LibraryBuilder get library {
    if (parent is LibraryBuilder) {
      LibraryBuilder library = parent;
      return library.partOfLibrary ?? library;
    } else {
      ClassBuilder cls = parent;
      return cls.library;
    }
  }

  void buildOutlineExpressions(LibraryBuilder library) {}

  @override
  String get fullNameForErrors => name;

  void inferType() => unsupported("inferType", charOffset, fileUri);

  void inferCopiedType(covariant Object other) {
    unsupported("inferType", charOffset, fileUri);
  }
}
