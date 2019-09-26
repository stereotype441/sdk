// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/protocol_server.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:meta/meta.dart';
import 'package:nnbd_migration/instrumentation.dart';
import 'package:nnbd_migration/nnbd_migration.dart';
import 'package:nnbd_migration/src/edge_builder.dart';
import 'package:nnbd_migration/src/fix_builder.dart';
import 'package:nnbd_migration/src/node_builder.dart';
import 'package:nnbd_migration/src/nullability_node.dart';
import 'package:nnbd_migration/src/potential_modification.dart';
import 'package:nnbd_migration/src/variables.dart';

/// Implementation of the [NullabilityMigration] public API.
class NullabilityMigrationImpl implements NullabilityMigration {
  final NullabilityMigrationListener listener;

  Variables _variables;

  final NullabilityGraph _graph;

  final bool _permissive;

  final NullabilityMigrationInstrumentation _instrumentation;

  bool _propagated = false;

  /// Prepares to perform nullability migration.
  ///
  /// If [permissive] is `true`, exception handling logic will try to proceed
  /// as far as possible even though the migration algorithm is not yet
  /// complete.  TODO(paulberry): remove this mode once the migration algorithm
  /// is fully implemented.
  NullabilityMigrationImpl(NullabilityMigrationListener listener,
      {bool permissive: false,
      NullabilityMigrationInstrumentation instrumentation})
      : this._(listener, NullabilityGraph(instrumentation: instrumentation),
            permissive, instrumentation);

  NullabilityMigrationImpl._(
      this.listener, this._graph, this._permissive, this._instrumentation) {
    _instrumentation?.immutableNodes(_graph.never, _graph.always);
  }

  void finishInput(ResolvedUnitResult result) {
    if (_variables != null) {
      if (!_propagated) _propagate();
      var unit = result.unit;
      unit.accept(FixBuilder(
          listener, unit.declaredElement.source, result.lineInfo, _variables));
    }
  }

  void prepareInput(ResolvedUnitResult result) {
    _variables ??= Variables(_graph, result.typeProvider,
        instrumentation: _instrumentation);
    var unit = result.unit;
    unit.accept(NodeBuilder(_variables, unit.declaredElement.source,
        _permissive ? listener : null, _graph, result.typeProvider,
        instrumentation: _instrumentation));
  }

  void processInput(ResolvedUnitResult result) {
    var unit = result.unit;
    unit.accept(EdgeBuilder(result.typeProvider, result.typeSystem, _variables,
        _graph, unit.declaredElement.source, _permissive ? listener : null,
        instrumentation: _instrumentation));
  }

  void _propagate() {
    _propagated = true;
    _graph.propagate();
    if (_graph.unsatisfiedSubstitutions.isNotEmpty) {
      // TODO(paulberry): for now we just ignore unsatisfied substitutions, to
      // work around https://github.com/dart-lang/sdk/issues/38257
      // throw new UnimplementedError('Need to report unsatisfied substitutions');
    }
    // TODO(paulberry): it would be nice to report on unsatisfied edges as well,
    // however, since every `!` we add has an unsatisfied edge associated with
    // it, we can't report on every unsatisfied edge.  We need to figure out a
    // way to report unsatisfied edges that isn't too overwhelming.
  }

  @visibleForTesting
  static void broadcast(
      Variables variables,
      NullabilityMigrationListener listener,
      NullabilityMigrationInstrumentation instrumentation) {
    throw UnimplementedError('TODO(paulberry)');
  }
}

/// Implementation of [SingleNullabilityFix] used internally by
/// [NullabilityMigration].
class _SingleNullabilityFix extends SingleNullabilityFix {
  @override
  final Source source;

  @override
  final NullabilityFixDescription description;

  Location _location;

  factory _SingleNullabilityFix(Source source,
      PotentialModification potentialModification, LineInfo lineInfo) {
    Location location;

    if (potentialModification.modifications.isNotEmpty) {
      final locationInfo = lineInfo
          .getLocation(potentialModification.modifications.first.offset);
      location = new Location(
        source.fullName,
        potentialModification.modifications.first.offset,
        potentialModification.modifications.first.length,
        locationInfo.lineNumber,
        locationInfo.columnNumber,
      );
    }

    return _SingleNullabilityFix._(source, potentialModification.description,
        location: location);
  }

  _SingleNullabilityFix._(this.source, this.description, {Location location})
      : this._location = location;

  Location get location => _location;
}
