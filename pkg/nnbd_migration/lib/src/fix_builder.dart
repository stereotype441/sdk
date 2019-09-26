// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/protocol_server.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/handle.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:front_end/src/scanner/token.dart';
import 'package:meta/meta.dart';
import 'package:meta/meta.dart';
import 'package:nnbd_migration/instrumentation.dart';
import 'package:nnbd_migration/instrumentation.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:nnbd_migration/src/conditional_discard.dart';
import 'package:nnbd_migration/src/decorated_type.dart';
import 'package:nnbd_migration/src/expression_checks.dart';
import 'package:nnbd_migration/src/nullability_migration_impl.dart';
import 'package:nnbd_migration/src/nullability_node.dart';
import 'package:nnbd_migration/src/potential_modification.dart';
import 'package:nnbd_migration/src/utilities/annotation_tracker.dart';
import 'package:nnbd_migration/src/utilities/permissive_mode.dart';
import 'package:nnbd_migration/src/variables.dart';

class FixBuilder extends GeneralizingAstVisitor<void> {
  final NullabilityMigrationListener _listener;

  final Source _source;

  final LineInfo _lineInfo;

  final Variables _variables;

  FixBuilder(this._listener, this._source, this._lineInfo, this._variables);

  @override
  void visitDefaultFormalParameter(DefaultFormalParameter node) {
    var element = node.declaredElement;
    var decoratedType = _variables.decoratedElementType(element);
    if (node.defaultValue != null) {
      return null;
    } else if (node.declaredElement.hasRequired) {
      // TODO(paulberry): change `@required` to `required`.  See
      // https://github.com/dart-lang/sdk/issues/38462
      return null;
    } else if (!decoratedType.node.isNullable) {
      var offset = node.offset;
      var method = element.enclosingElement;
      var fix = _SingleNullabilityFix(
          _source,
          _lineInfo,
          offset,
          0,
          NullabilityFixDescription.addRequired(
              method.enclosingElement.name, method.name, element.name));
      _listener.addFix(fix);
      _listener.addEdit(fix, SourceEdit(offset, 0, 'required '));
    }
  }

  @override
  void visitTypeAnnotation(TypeAnnotation node) {
    super.visitTypeAnnotation(node);
    var decoratedType = _variables.decoratedTypeAnnotation(_source, node);
    if (decoratedType != null && decoratedType.node.isNullable) {
      var type = decoratedType.type;
      if (type.isDynamic || type.isVoid) {
        // `void` and `dynamic` are always nullable so nothing needs to be
        // changed.
      } else {
        var offset = node.end;
        var fix = _SingleNullabilityFix(_source, _lineInfo, offset, 0,
            NullabilityFixDescription.makeTypeNullable(type.toString()));
        _listener.addFix(fix);
        _listener.addEdit(fix, SourceEdit(offset, 0, '?'));
      }
    }
  }

  @override
  void visitTypeName(TypeName node) => visitTypeAnnotation(node);
}

/// Implementation of [SingleNullabilityFix] used internally by
/// [NullabilityMigration].
class _SingleNullabilityFix extends SingleNullabilityFix {
  @override
  final Source source;

  @override
  final NullabilityFixDescription description;

  Location _location;

  factory _SingleNullabilityFix(Source source, LineInfo lineInfo, int offset,
      int length, NullabilityFixDescription description) {
    Location location;

    final locationInfo = lineInfo.getLocation(offset);
    location = new Location(
      source.fullName,
      offset,
      length,
      locationInfo.lineNumber,
      locationInfo.columnNumber,
    );

    return _SingleNullabilityFix._(source, description, location: location);
  }

  _SingleNullabilityFix._(this.source, this.description, {Location location})
      : this._location = location;

  Location get location => _location;
}
