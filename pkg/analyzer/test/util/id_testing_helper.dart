// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(paulberry,johnniwinther): Use the code for extraction of test data from
// annotated code from CFE.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart' hide Annotation;
import 'package:front_end/src/testing/annotated_code_helper.dart';
import 'package:front_end/src/testing/id.dart'
    show ActualData, Id, IdValue, MemberId, NodeId;
import 'package:front_end/src/testing/id_testing.dart';

class AnalyzerCompiledData<T> extends CompiledData<T> {
  // TODO(johnniwinther,paulberry): Maybe this should have access to the
  // [ResolvedUnitResult] instead.
  final Map<Uri, AnnotatedCode> code;

  AnalyzerCompiledData(
      this.code,
      Uri mainUri,
      Map<Uri, Map<Id, ActualData<T>>> actualMaps,
      Map<Id, ActualData<T>> globalData)
      : super(mainUri, actualMaps, globalData);

  @override
  int getOffsetFromId(Id id, Uri uri) {
    if (id is NodeId) {
      return id.value;
    } else if (id is MemberId) {
      if (id.className != null) {
        throw UnimplementedError('TODO(paulberry): handle class members');
      }
      var name = id.memberName;
      var unit =
          parseString(content: code[uri].sourceCode, throwIfDiagnostics: false)
              .unit;
      for (var declaration in unit.declarations) {
        if (declaration is FunctionDeclaration) {
          if (declaration.name.name == name) {
            return declaration.offset;
          }
        }
      }
      throw StateError('Member not found: $name');
    } else {
      throw StateError('Unexpected id ${id.runtimeType}');
    }
  }

  @override
  void reportError(Uri uri, int offset, String message) {
    print('$offset: $message');
  }
}

void onFailure(String message) {
  throw StateError(message);
}

class TestConfig {
  final String marker;
  final String name;
  final FeatureSet featureSet;

  TestConfig(this.marker, this.name, {FeatureSet featureSet}) : featureSet = featureSet ?? FeatureSet.fromEnableFlags([]);
}

/// Creates a test runner for [dataComputer] on [testedConfigs].
RunTestFunction runTestFor<T>(
    DataComputer<T> dataComputer, List<TestConfig> testedConfigs) {
  return (TestData testData,
      {bool testAfterFailures, bool verbose, bool printCode}) {
    return runTest(testData, dataComputer, testedConfigs,
        testAfterFailures: testAfterFailures,
        verbose: verbose,
        printCode: printCode,
        onFailure: onFailure);
  };
}

/// Runs [dataComputer] on [testData] for all [testedConfigs].
///
/// Returns `true` if an error was encountered.
Future<bool> runTest<T>(TestData testData, DataComputer<T> dataComputer,
    List<TestConfig> testedConfigs,
    {bool testAfterFailures,
      bool verbose,
      bool printCode,
      bool forUserLibrariesOnly: true,
      Iterable<Id> globalIds: const <Id>[],
      void onFailure(String message)}) async {
  bool hasFailures = false;
  for (TestConfig config in testedConfigs) {
    if (await runTestForConfig(testData, dataComputer, config,
        fatalErrors: !testAfterFailures,
        onFailure: onFailure,
        verbose: verbose,
        printCode: printCode)) {
      hasFailures = true;
    }
  }
  return hasFailures;
}

Future<bool> checkTests<T>(
    Uri testFileUri,
    String rawCode,
    Future<ResolvedUnitResult> resultComputer(String rawCode),
    DataComputer<T> dataComputer) async {
  if (false) { // TODO(paulberry): old
    AnnotatedCode code =
    new AnnotatedCode.fromText(rawCode, commentStart, commentEnd);
    var result = await resultComputer(code.sourceCode);
    var uri = result.libraryElement.source.uri;
    var marker = 'normal';
    Map<String, MemberAnnotations<IdValue>> expectedMaps = {
      marker: new MemberAnnotations<IdValue>(),
    };
    computeExpectedMap(uri, code, expectedMaps, onFailure: onFailure);
    MemberAnnotations<IdValue> annotations = expectedMaps[marker];
    Map<Id, ActualData<T>> actualMap = {};
    dataComputer.computeUnitData(result.unit, actualMap);
    Map<Uri, AnnotatedCode> codeMap = {uri: code};
    var compiledData =
    AnalyzerCompiledData<T>(codeMap, uri, {uri: actualMap}, {});
    return await checkCode(marker, uri, codeMap, annotations, compiledData,
        dataComputer.dataValidator,
        onFailure: onFailure);
  } else {
    var testData = TestData(testFileUri, testFileUri, memorySourceFiles, code, expectedMaps, libFileNames)
  }
}

/// Runs [dataComputer] on [testData] for [config].
///
/// Returns `true` if an error was encountered.
Future<bool> runTestForConfig<T>(
    TestData testData, DataComputer<T> dataComputer, TestConfig config,
    {bool fatalErrors,
      bool verbose,
      bool printCode,
      bool forUserLibrariesOnly: true,
      Iterable<Id> globalIds: const <Id>[],
      void onFailure(String message)}) async {
  MemberAnnotations<IdValue> memberAnnotations =
  testData.expectedMaps[config.marker];
  Iterable<Id> globalIds = memberAnnotations.globalData.keys;
  CompilerOptions options = new CompilerOptions();
  options.debugDump = printCode;
  options.experimentalFlags.addAll(config.experimentalFlags);
  CompilerResult compilerResult = await compileScript(
      testData.memorySourceFiles,
      options: options,
      retainDataForTesting: true);
  Component component = compilerResult.component;
  Map<Uri, Map<Id, ActualData<T>>> actualMaps = <Uri, Map<Id, ActualData<T>>>{};
  Map<Id, ActualData<T>> globalData = <Id, ActualData<T>>{};

  Map<Id, ActualData<T>> actualMapFor(TreeNode node) {
    Uri uri = node is Library ? node.fileUri : node.location.file;
    return actualMaps.putIfAbsent(uri, () => <Id, ActualData<T>>{});
  }

  void processMember(Member member, Map<Id, ActualData<T>> actualMap) {
    if (member.enclosingClass != null) {
      if (member.enclosingClass.isEnum) {
        if (member is Constructor ||
            member.isInstanceMember ||
            member.name == 'values') {
          return;
        }
      }
      if (member is Constructor && member.enclosingClass.isMixinApplication) {
        return;
      }
    }
    dataComputer.computeMemberData(compilerResult, member, actualMap,
        verbose: verbose);
  }

  void processClass(Class cls, Map<Id, ActualData<T>> actualMap) {
    dataComputer.computeClassData(compilerResult, cls, actualMap,
        verbose: verbose);
  }

  bool excludeLibrary(Library library) {
    return forUserLibrariesOnly &&
        (library.importUri.scheme == 'dart' ||
            library.importUri.scheme == 'package');
  }

  for (Library library in component.libraries) {
    if (excludeLibrary(library)) continue;
    dataComputer.computeLibraryData(
        compilerResult, library, actualMapFor(library));
    for (Class cls in library.classes) {
      processClass(cls, actualMapFor(cls));
      for (Member member in cls.members) {
        processMember(member, actualMapFor(member));
      }
    }
    for (Member member in library.members) {
      processMember(member, actualMapFor(member));
    }
  }

  List<Uri> globalLibraries = <Uri>[
    Uri.parse('dart:core'),
    Uri.parse('dart:collection'),
    Uri.parse('dart:async'),
  ];

  Class getGlobalClass(String className) {
    Class cls;
    for (Uri uri in globalLibraries) {
      Library library = lookupLibrary(component, uri);
      if (library != null) {
        cls ??= lookupClass(library, className);
      }
    }
    if (cls == null) {
      throw "Global class '$className' not found in the global "
          "libraries: ${globalLibraries.join(', ')}";
    }
    return cls;
  }

  Member getGlobalMember(String memberName) {
    Member member;
    for (Uri uri in globalLibraries) {
      Library library = lookupLibrary(component, uri);
      if (library != null) {
        member ??= lookupLibraryMember(library, memberName);
      }
    }
    if (member == null) {
      throw "Global member '$memberName' not found in the global "
          "libraries: ${globalLibraries.join(', ')}";
    }
    return member;
  }

  for (Id id in globalIds) {
    if (id is MemberId) {
      Member member;
      if (id.className != null) {
        Class cls = getGlobalClass(id.className);
        member = lookupClassMember(cls, id.memberName);
        if (member == null) {
          throw "Global member '${id.memberName}' not found in class $cls.";
        }
      } else {
        member = getGlobalMember(id.memberName);
      }
      processMember(member, globalData);
    } else if (id is ClassId) {
      Class cls = getGlobalClass(id.className);
      processClass(cls, globalData);
    } else {
      throw new UnsupportedError("Unexpected global id: $id");
    }
  }

  CfeCompiledData compiledData = new CfeCompiledData<T>(
      compilerResult, testData.testFileUri, actualMaps, globalData);

  return checkCode(config.name, testData.testFileUri, testData.code,
      memberAnnotations, compiledData, dataComputer.dataValidator,
      fatalErrors: fatalErrors, onFailure: onFailure);
}

/// Test configuration used for testing CFE with constant evaluation.
final TestConfig analyzerConstantUpdate2018Config = TestConfig(
    analyzerMarker, 'analyzer with constant-update-2018',
    featureSet: FeatureSet.forTesting(sdkVersion: '2.2.2', additionalFeatures: [Feature.constant_update_2018]));

/// Creates the testing URI used for [fileName] in annotated tests.
Uri createUriForFileName(String fileName, {bool isLib}) => _toTestUri(fileName);

/// A fake absolute directory used as the root of a memory-file system in ID
/// tests.
Uri _defaultDir = Uri.parse('file:///a/b/c/');

/// Convert relative file paths into an absolute Uri as expected by the test
/// helpers.
Uri _toTestUri(String relativePath) => _defaultDir.resolve(relativePath);

abstract class DataComputer<T> {
  const DataComputer();

  DataInterpreter<T> get dataValidator;

  /// Function that computes a data mapping for [unit].
  ///
  /// Fills [actualMap] with the data and [sourceSpanMap] with the source spans
  /// for the data origin.
  void computeUnitData(CompilationUnit unit, Map<Id, ActualData<T>> actualMap);
}
