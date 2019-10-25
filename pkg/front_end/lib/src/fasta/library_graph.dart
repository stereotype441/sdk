// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.library_graph;

import 'package:front_end/src/fasta/source/source_library_builder.dart'
    show SourceLibraryBuilder;

import 'package:kernel/kernel.dart'
    show Library, LibraryDependency, LibraryPart;

import 'package:kernel/util/graph.dart' show Graph;

class LibraryGraph implements Graph<Uri> {
  final Map<Uri, Library> libraries;

  LibraryGraph(this.libraries);

  Iterable<Uri> get vertices => libraries.keys;

  Iterable<Uri> neighborsOf(Uri vertex) sync* {
    Library library = libraries[vertex];
    if (library == null) {
      throw "Library not found: $vertex";
    }

    // Imports and exports.
    for (LibraryDependency dependency in library.dependencies) {
      Uri uri1 = dependency.targetLibrary.importUri;
      Uri uri2 = dependency.targetLibrary.fileUri;
      if (libraries.containsKey(uri1)) {
        yield uri1;
      } else if (uri2 != null) {
        if (libraries.containsKey(uri2)) {
          yield uri2;
        }
      }
    }

    // Parts.
    // Normally there won't be libraries for these, but if, for instance,
    // the part didn't exist there will be a synthetic library.
    for (LibraryPart part in library.parts) {
      Uri partUri = getPartUri(library.importUri, part.partUri);
      Uri fileUri = getPartUri(library.fileUri, part.partUri);
      if (libraries.containsKey(partUri)) {
        yield partUri;
      } else if (fileUri != partUri && libraries.containsKey(fileUri)) {
        yield fileUri;
      }
    }
  }

  Uri getPartUri(Uri base, String part) {
    try {
      return base.resolve(part);
    } on FormatException {
      // This is also done in [SourceLibraryBuilder.resolve]
      return new Uri(
          scheme: SourceLibraryBuilder.MALFORMED_URI_SCHEME,
          query: Uri.encodeQueryComponent(part));
    }
  }
}
