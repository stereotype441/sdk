// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:markdown/markdown.dart';
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';

import 'common/generate_common.dart';
import 'dart/generate_dart.dart' as dart show Api, api, DartGenerator;
import 'java/generate_java.dart' as java show Api, api, JavaGenerator;

final bool _stampPubspecVersion = false;

/// Parse the 'service.md' into a model and generate both Dart and Java
/// libraries.
main(List<String> args) async {
  bool generateJava = false;
  if (args.length != 0) {
    if ((args.length == 1) && (args.first == '--generate-java')) {
      generateJava = true;
    } else {
      print('Invalid options: $args. Usage: dart generate [--generate-java].');
      return;
    }
  }
  String appDirPath = dirname(Platform.script.toFilePath());

  // Parse service.md into a model.
  var file =
      new File(join(appDirPath, '../../../runtime/vm/service/service.md'));
  var document = new Document();
  StringBuffer buf = new StringBuffer(file.readAsStringSync());
  buf.writeln();
  buf.write(
      new File(join(appDirPath, 'service_undocumented.md')).readAsStringSync());
  var nodes = document.parseLines(buf.toString().split('\n'));
  print('Parsed ${file.path}.');
  print('Service protocol version ${ApiParseUtil.parseVersionString(nodes)}.');

  // Generate code from the model.
  await _generateDart(appDirPath, nodes);
  if (generateJava) {
    await _generateJava(appDirPath, nodes);
  }
  await _generateAsserts(appDirPath, nodes);
}

_generateDart(String appDirPath, List<Node> nodes) async {
  print('');
  var outDirPath = normalize(join(appDirPath, '..', 'lib'));
  var outDir = new Directory(outDirPath);
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  var outputFile = new File(join(outDirPath, 'vm_service.dart'));
  var generator = new dart.DartGenerator();
  dart.api = new dart.Api();
  dart.api.parse(nodes);
  dart.api.generate(generator);
  outputFile.writeAsStringSync(generator.toString());
  Process.runSync('dartfmt', ['-w', outDirPath]);

  if (_stampPubspecVersion) {
    // Update the pubspec file.
    Version version = ApiParseUtil.parseVersionSemVer(nodes);
    _stampPubspec(version);

    // Validate that the changelog contains an entry for the current version.
    _checkUpdateChangelog(version);
  }

  print('Wrote Dart to ${outputFile.path}.');
}

_generateJava(String appDirPath, List<Node> nodes) async {
  print('');
  var srcDirPath = normalize(join(appDirPath, '..', 'java', 'src', 'gen'));
  assert(new Directory(srcDirPath).existsSync());
  var generator = new java.JavaGenerator(srcDirPath);
  java.api = new java.Api();
  java.api.parse(nodes);
  java.api.generate(generator);

  // Generate a version file.
  Version version = ApiParseUtil.parseVersionSemVer(nodes);
  File file = new File(join('java', 'version.properties'));
  file.writeAsStringSync('version=${version.major}.${version.minor}\n');

  print('Wrote Java to $srcDirPath.');
}

_generateAsserts(String appDirPath, List<Node> nodes) async {
  print('');
  var outDirPath = normalize(join(appDirPath, '..', 'example'));
  var outDir = new Directory(outDirPath);
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  var outputFile = new File(join(outDirPath, 'vm_service_assert.dart'));
  var generator = new dart.DartGenerator();
  dart.api = new dart.Api();
  dart.api.parse(nodes);
  dart.api.generateAsserts(generator);
  outputFile.writeAsStringSync(generator.toString());
  Process.runSync('dartfmt', ['-w', outDirPath]);

  if (_stampPubspecVersion) {
    // Update the pubspec file.
    Version version = ApiParseUtil.parseVersionSemVer(nodes);
    _stampPubspec(version);

    // Validate that the changelog contains an entry for the current version.
    _checkUpdateChangelog(version);
  }

  print('Wrote Dart to ${outputFile.path}.');
}

// Push the major and minor versions into the pubspec.
void _stampPubspec(Version version) {
  final String pattern = 'version: ';
  File file = new File('pubspec.yaml');
  String text = file.readAsStringSync();
  bool found = false;

  text = text.split('\n').map((line) {
    if (line.startsWith(pattern)) {
      found = true;
      Version v = new Version.parse(line.substring(pattern.length));
      String pre = v.preRelease.isEmpty ? null : v.preRelease.join('-');
      String build = v.build.isEmpty ? null : v.build.join('+');
      v = new Version(version.major, version.minor, v.patch,
          pre: pre, build: build);
      return '${pattern}${v.toString()}';
    } else {
      return line;
    }
  }).join('\n');

  if (!found) throw '`${pattern}` not found';

  file.writeAsStringSync(text);
}

void _checkUpdateChangelog(Version version) {
  // Look for `## major.minor`.
  String check = '## ${version.major}.${version.minor}';

  File file = new File('CHANGELOG.md');
  String text = file.readAsStringSync();
  bool containsReleaseNotes =
      text.split('\n').any((line) => line.startsWith(check));
  if (!containsReleaseNotes) {
    throw '`${check}` not found in the CHANGELOG.md file';
  }
}
