// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:linter/src/utils.dart';

/// Generate issue labeler workflow config data.
main(List<String> args) async {
  var client = http.Client();
  var req = await client.get(
      Uri.parse('https://dart-lang.github.io/linter/lints/machine/rules.json'));

  var machine = json.decode(req.body) as Iterable;

  var coreLints = <String>[];
  var recommendedLints = <String>[];
  var flutterLints = <String>[];
  for (var entry in machine) {
    var sets = entry['sets'] as List;
    if (sets.contains('core')) {
      coreLints.add(entry['name'] as String);
    } else if (sets.contains('recommended')) {
      recommendedLints.add(entry['name'] as String);
    } else if (sets.contains('flutter')) {
      flutterLints.add(entry['name'] as String);
    }
  }

  // todo(pq): consider a local cache of internally available rules.

  printToConsole('# Auto-generated by `tool/labeler/issue_config.dart`');

  printToConsole('\nset-core:');
  printToConsole("  - '(${coreLints.sorted().join('|')})'");
  printToConsole('\nset-recommended:');
  printToConsole("  - '(${recommendedLints.sorted().join('|')})'");
  printToConsole('\nset-flutter:');
  printToConsole("  - '(${flutterLints.sorted().join('|')})'");
}
