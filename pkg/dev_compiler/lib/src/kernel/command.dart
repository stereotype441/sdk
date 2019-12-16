// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show json;
import 'dart:io';

import 'package:args/args.dart';
import 'package:build_integration/file_system/multi_root.dart';
import 'package:cli_util/cli_util.dart' show getSdkPath;
import 'package:front_end/src/api_unstable/ddc.dart' as fe;
import 'package:kernel/class_hierarchy.dart';
import 'package:kernel/core_types.dart';
import 'package:kernel/kernel.dart' hide MapEntry;
import 'package:kernel/target/targets.dart';
import 'package:kernel/text/ast_to_text.dart' as kernel show Printer;
import 'package:kernel/binary/ast_to_binary.dart' as kernel show BinaryPrinter;
import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart' show SourceMapBuilder;

import '../compiler/js_names.dart' as js_ast;
import '../compiler/module_builder.dart';
import '../compiler/shared_command.dart';
import '../compiler/shared_compiler.dart';
import '../js_ast/js_ast.dart' as js_ast;
import '../js_ast/js_ast.dart' show js;
import '../js_ast/source_map_printer.dart' show SourceMapPrintingContext;

import 'compiler.dart';
import 'target.dart';

const _binaryName = 'dartdevc -k';

// ignore_for_file: DEPRECATED_MEMBER_USE

/// Invoke the compiler with [args].
///
/// Returns `true` if the program compiled without any fatal errors.
Future<CompilerResult> compile(List<String> args,
    {fe.InitializedCompilerState compilerState,
    bool isWorker = false,
    bool useIncrementalCompiler = false,
    Map<Uri, List<int>> inputDigests}) async {
  try {
    return await _compile(args,
        compilerState: compilerState,
        isWorker: isWorker,
        useIncrementalCompiler: useIncrementalCompiler,
        inputDigests: inputDigests);
  } catch (error, stackTrace) {
    print('''
We're sorry, you've found a bug in our compiler.
You can report this bug at:
    https://github.com/dart-lang/sdk/issues/labels/web-dev-compiler
Please include the information below in your report, along with
any other information that may help us track it down. Thanks!
-------------------- %< --------------------
    $_binaryName arguments: ${args.join(' ')}
    dart --version: ${Platform.version}

$error
$stackTrace
''');
    return CompilerResult(70);
  }
}

String _usageMessage(ArgParser ddcArgParser) =>
    'The Dart Development Compiler compiles Dart sources into a JavaScript '
    'module.\n\n'
    'Usage: $_binaryName [options...] <sources...>\n\n'
    '${ddcArgParser.usage}';

Future<CompilerResult> _compile(List<String> args,
    {fe.InitializedCompilerState compilerState,
    bool isWorker = false,
    bool useIncrementalCompiler = false,
    Map<Uri, List<int>> inputDigests}) async {
  // TODO(jmesserly): refactor options to share code with dartdevc CLI.
  var argParser = ArgParser(allowTrailingOptions: true)
    ..addFlag('help',
        abbr: 'h', help: 'Display this message.', negatable: false)
    ..addMultiOption('out', abbr: 'o', help: 'Output file (required).')
    ..addOption('packages', help: 'The package spec file to use.')
    // TODO(jmesserly): is this still useful for us, or can we remove it now?
    ..addFlag('summarize-text',
        help: 'emit API summary in a .js.txt file',
        defaultsTo: false,
        hide: true)
    ..addFlag('track-widget-creation',
        help: 'enable inspecting of Flutter widgets', hide: true)
    // TODO(jmesserly): add verbose help to show hidden options
    ..addOption('dart-sdk-summary',
        help: 'The path to the Dart SDK summary file.', hide: true)
    ..addOption('multi-root-scheme',
        help: 'The custom scheme to indicate a multi-root uri.',
        defaultsTo: 'org-dartlang-app')
    ..addMultiOption('multi-root',
        help: 'The directories to search when encountering uris with the '
            'specified multi-root scheme.',
        defaultsTo: [Uri.base.path])
    ..addOption('multi-root-output-path',
        help: 'Path to set multi-root files relative to.', hide: true)
    ..addOption('dart-sdk',
        help: '(unsupported with --kernel) path to the Dart SDK.', hide: true)
    ..addFlag('compile-sdk',
        help: 'Build an SDK module.', defaultsTo: false, hide: true)
    ..addOption('libraries-file',
        help: 'The path to the libraries.json file for the sdk.')
    ..addOption('used-inputs-file',
        help: 'If set, the file to record inputs used.', hide: true)
    ..addFlag('kernel',
        abbr: 'k',
        help: 'Deprecated and ignored. To be removed in a future release.',
        hide: true);
  SharedCompilerOptions.addArguments(argParser);
  var declaredVariables = parseAndRemoveDeclaredVariables(args);
  ArgResults argResults;
  try {
    argResults = argParser.parse(filterUnknownArguments(args, argParser));
  } on FormatException catch (error) {
    if (args.any((arg) => arg.contains('ddc_sdk.sum'))) {
      print('Compiling with analyzer based DDC is no longer supported.\n');
      print('The most likely reason you are seeing this message is due to an '
          'old version of build_web_compilers.');
      print('Update your package pubspec.yaml to depend on a newer version of '
          'build_web_compilers:\n\n'
          'dev_dependency:\n'
          '  build_web_compilers: ^2.0.0\n');
      return CompilerResult(64);
    }
    print(error);
    print(_usageMessage(argParser));
    return CompilerResult(64);
  }

  var outPaths = argResults['out'] as List<String>;
  var moduleFormats = parseModuleFormatOption(argResults);
  if (outPaths.isEmpty) {
    print('Please specify the output file location. For example:\n'
        '    -o PATH/TO/OUTPUT_FILE.js');
    return CompilerResult(64);
  } else if (outPaths.length != moduleFormats.length) {
    print('Number of output files (${outPaths.length}) must match '
        'number of module formats (${moduleFormats.length}).');
    return CompilerResult(64);
  }

  if (argResults['help'] as bool || args.isEmpty) {
    print(_usageMessage(argParser));
    return CompilerResult(0);
  }

  // To make the output .dill agnostic of the current working directory,
  // we use a custom-uri scheme for all app URIs (these are files outside the
  // lib folder). The following [FileSystem] will resolve those references to
  // the correct location and keeps the real file location hidden from the
  // front end.
  var multiRootScheme = argResults['multi-root-scheme'] as String;
  var multiRootPaths = (argResults['multi-root'] as Iterable<String>)
      .map(Uri.base.resolve)
      .toList();
  var multiRootOutputPath = argResults['multi-root-output-path'] as String;
  if (multiRootOutputPath == null) {
    if (outPaths.length > 1) {
      print(
          'If multiple output files (found ${outPaths.length}) are specified, '
          'then --multi-root-output-path must be explicitly provided.');
      return CompilerResult(64);
    }
    var jsOutputUri = sourcePathToUri(p.absolute(outPaths.first));
    multiRootOutputPath = _longestPrefixingPath(jsOutputUri, multiRootPaths);
  }

  var fileSystem = MultiRootFileSystem(
      multiRootScheme, multiRootPaths, fe.StandardFileSystem.instance);

  Uri toCustomUri(Uri uri) {
    if (uri.scheme == '') {
      return Uri(scheme: multiRootScheme, path: '/' + uri.path);
    }
    return uri;
  }

  // TODO(jmesserly): this is a workaround for the CFE, which does not
  // understand relative URIs, and we'd like to avoid absolute file URIs
  // being placed in the summary if possible.
  // TODO(jmesserly): investigate if Analyzer has a similar issue.
  Uri sourcePathToCustomUri(String source) {
    return toCustomUri(sourcePathToRelativeUri(source));
  }

  var options = SharedCompilerOptions.fromArguments(argResults);
  var summaryPaths = options.summaryModules.keys.toList();
  var summaryModules = Map.fromIterables(
      summaryPaths.map(sourcePathToUri), options.summaryModules.values);
  var sdkSummaryPath = argResults['dart-sdk-summary'] as String;
  var librarySpecPath = argResults['libraries-file'] as String;
  if (sdkSummaryPath == null) {
    sdkSummaryPath = defaultSdkSummaryPath;
    librarySpecPath ??= defaultLibrarySpecPath;
  }
  var invalidSummary = summaryPaths.any((s) => !s.endsWith('.dill')) ||
      !sdkSummaryPath.endsWith('.dill');
  if (invalidSummary) {
    throw StateError("Non-dill file detected in input: $summaryPaths");
  }

  if (librarySpecPath == null) {
    // TODO(jmesserly): the `isSupported` bit should be included in the SDK
    // summary, but front_end requires a separate file, so we have to work
    // around that, while not requiring yet another command line option.
    //
    // Right now we search two locations: one level above the SDK summary
    // (this works for the build and SDK layouts) or next to the SDK summary
    // (if the user is doing something custom).
    //
    // Another option: we could make an in-memory file with the relevant info.
    librarySpecPath =
        p.join(p.dirname(p.dirname(sdkSummaryPath)), "libraries.json");
    if (!File(librarySpecPath).existsSync()) {
      librarySpecPath = p.join(p.dirname(sdkSummaryPath), "libraries.json");
    }
  }

  /// The .packages file path provided by the user.
  //
  // TODO(jmesserly): the default location is based on the current working
  // directory, to match the behavior of dartanalyzer/dartdevc. However the
  // Dart VM, CFE (and dart2js?) use the script file location instead. The
  // difference may be due to the lack of a single entry point for Analyzer.
  // Ultimately this is just the default behavior; in practice users call DDC
  // through a build tool, which generally passes in `--packages=`.
  //
  // TODO(jmesserly): conceptually CFE should not need a .packages file to
  // resolve package URIs that are in the input summaries, but it seems to.
  // This needs further investigation.
  var packageFile = argResults['packages'] as String ?? _findPackagesFilePath();

  var inputs = argResults.rest.map(sourcePathToCustomUri).toList();

  var succeeded = true;
  void diagnosticMessageHandler(fe.DiagnosticMessage message) {
    if (message.severity == fe.Severity.error) {
      succeeded = false;
    }
    fe.printDiagnosticMessage(message, print);
  }

  var experiments = fe.parseExperimentalFlags(options.experiments,
      onError: stderr.writeln, onWarning: print);

  bool trackWidgetCreation =
      argResults['track-widget-creation'] as bool ?? false;

  var compileSdk = argResults['compile-sdk'] == true;
  var oldCompilerState = compilerState;
  List<Component> doneInputSummaries;
  fe.IncrementalCompiler incrementalCompiler;
  fe.WorkerInputComponent cachedSdkInput;
  bool recordUsedInputs = argResults['used-inputs-file'] != null;
  List<Uri> inputSummaries = summaryModules.keys.toList();
  if (!useIncrementalCompiler) {
    compilerState = await fe.initializeCompiler(
        oldCompilerState,
        compileSdk,
        sourcePathToUri(getSdkPath()),
        compileSdk ? null : sourcePathToUri(sdkSummaryPath),
        sourcePathToUri(packageFile),
        sourcePathToUri(librarySpecPath),
        inputSummaries,
        DevCompilerTarget(TargetFlags(
            trackWidgetCreation: trackWidgetCreation,
            enableNullSafety: options.enableNullSafety)),
        fileSystem: fileSystem,
        experiments: experiments,
        environmentDefines: declaredVariables);
  } else {
    // If digests weren't given and if not in worker mode, create fake data and
    // ensure we don't have a previous state (as that wouldn't be safe with
    // fake input digests).
    if (!isWorker && (inputDigests == null || inputDigests.isEmpty)) {
      oldCompilerState = null;
      inputDigests ??= {};
      if (!compileSdk) {
        inputDigests[sourcePathToUri(sdkSummaryPath)] = const [0];
      }
      for (Uri uri in summaryModules.keys) {
        inputDigests[uri] = const [0];
      }
    }

    doneInputSummaries = List<Component>(summaryModules.length);
    compilerState = await fe.initializeIncrementalCompiler(
        oldCompilerState,
        {
          "trackWidgetCreation=$trackWidgetCreation",
          "multiRootScheme=${fileSystem.markerScheme}",
          "multiRootRoots=${fileSystem.roots}",
        },
        doneInputSummaries,
        compileSdk,
        sourcePathToUri(getSdkPath()),
        compileSdk ? null : sourcePathToUri(sdkSummaryPath),
        sourcePathToUri(packageFile),
        sourcePathToUri(librarySpecPath),
        inputSummaries,
        inputDigests,
        DevCompilerTarget(TargetFlags(
            trackWidgetCreation: trackWidgetCreation,
            enableNullSafety: options.enableNullSafety)),
        fileSystem: fileSystem,
        experiments: experiments,
        environmentDefines: declaredVariables,
        trackNeededDillLibraries: recordUsedInputs);
    incrementalCompiler = compilerState.incrementalCompiler;
    cachedSdkInput =
        compilerState.workerInputCache[sourcePathToUri(sdkSummaryPath)];
  }

  // TODO(jmesserly): is there a cleaner way to do this?
  //
  // Ideally we'd manage our own batch compilation caching rather than rely on
  // `initializeCompiler`. Also we should be able to pass down Components for
  // SDK and summaries.
  //
  fe.DdcResult result;
  if (!useIncrementalCompiler) {
    result = await fe.compile(compilerState, inputs, diagnosticMessageHandler);
  } else {
    compilerState.options.onDiagnostic = diagnosticMessageHandler;
    Component incrementalComponent = await incrementalCompiler.computeDelta(
        entryPoints: inputs, fullComponent: true);
    result = fe.DdcResult(incrementalComponent, cachedSdkInput.component,
        doneInputSummaries, incrementalCompiler.userCode.loader.hierarchy);
  }
  compilerState.options.onDiagnostic = null; // See http://dartbug.com/36983.

  if (result == null || !succeeded) {
    return CompilerResult(1, kernelState: compilerState);
  }

  var component = result.component;
  Set<Library> librariesFromDill = result.computeLibrariesFromDill();
  Component compiledLibraries =
      Component(nameRoot: component.root, uriToSource: component.uriToSource);
  for (Library lib in component.libraries) {
    if (!librariesFromDill.contains(lib)) compiledLibraries.libraries.add(lib);
  }

  if (!options.emitMetadata && _checkForDartMirrorsImport(compiledLibraries)) {
    return CompilerResult(1, kernelState: compilerState);
  }

  // Output files can be written in parallel, so collect the futures.
  var outFiles = <Future>[];
  if (argResults['summarize'] as bool) {
    if (outPaths.length > 1) {
      print(
          'If multiple output files (found ${outPaths.length}) are specified, '
          'the --summarize option is not supported.');
      return CompilerResult(64);
    }
    // TODO(jmesserly): CFE mutates the Kernel tree, so we can't save the dill
    // file if we successfully reused a cached library. If compiler state is
    // unchanged, it means we used the cache.
    //
    // In that case, we need to unbind canonical names, because they could be
    // bound already from the previous compile.
    if (identical(compilerState, oldCompilerState)) {
      component.unbindCanonicalNames();
    }
    var sink = File(p.withoutExtension(outPaths.first) + '.dill').openWrite();
    // TODO(jmesserly): this appears to save external libraries.
    // Do we need to run them through an outlining step so they can be saved?
    kernel.BinaryPrinter(sink).writeComponentFile(component);
    outFiles.add(sink.flush().then((_) => sink.close()));
  }
  if (argResults['summarize-text'] as bool) {
    if (outPaths.length > 1) {
      print(
          'If multiple output files (found ${outPaths.length}) are specified, '
          'the --summarize-text option is not supported.');
      return CompilerResult(64);
    }
    StringBuffer sb = StringBuffer();
    kernel.Printer(sb).writeComponentFile(component);
    outFiles.add(File(outPaths.first + '.txt').writeAsString(sb.toString()));
  }

  var compiler = ProgramCompiler(component, result.classHierarchy, options);

  var jsModule = compiler.emitModule(
      compiledLibraries, result.inputSummaries, inputSummaries, summaryModules);

  // Also the old Analyzer backend had some code to make debugging better when
  // --single-out-file is used, but that option does not appear to be used by
  // any of our build systems.
  for (var i = 0; i < outPaths.length; ++i) {
    var output = outPaths[i];
    var moduleFormat = moduleFormats[i];
    var file = File(output);
    await file.parent.create(recursive: true);
    var jsCode = jsProgramToCode(jsModule, moduleFormat,
        buildSourceMap: options.sourceMap,
        inlineSourceMap: options.inlineSourceMap,
        jsUrl: p.toUri(output).toString(),
        mapUrl: p.toUri(output + '.map').toString(),
        bazelMapping: options.bazelMapping,
        customScheme: multiRootScheme,
        multiRootOutputPath: multiRootOutputPath);

    outFiles.add(file.writeAsString(jsCode.code));
    if (jsCode.sourceMap != null) {
      outFiles.add(
          File(output + '.map').writeAsString(json.encode(jsCode.sourceMap)));
    }
  }

  if (recordUsedInputs) {
    Set<Uri> usedOutlines = Set<Uri>();
    if (useIncrementalCompiler) {
      compilerState.incrementalCompiler
          .updateNeededDillLibrariesWithHierarchy(result.classHierarchy, null);
      for (Library lib
          in compilerState.incrementalCompiler.neededDillLibraries) {
        if (lib.importUri.scheme == "dart") continue;
        Uri uri = compilerState.libraryToInputDill[lib.importUri];
        if (uri == null) {
          throw StateError("Library ${lib.importUri} was recorded as used, "
              "but was not in the list of known libraries.");
        }
        usedOutlines.add(uri);
      }
    } else {
      // Used inputs wasn't recorded: Say we used everything.
      usedOutlines.addAll(summaryModules.keys);
    }

    var outputUsedFile = File(argResults['used-inputs-file'] as String);
    outputUsedFile.createSync(recursive: true);
    outputUsedFile.writeAsStringSync(usedOutlines.join("\n"));
  }

  await Future.wait(outFiles);
  return CompilerResult(0, kernelState: compilerState);
}

// A simplified entrypoint similar to `_compile` that only supports building the
// sdk. Note that some changes in `_compile_` might need to be copied here as
// well.
// TODO(sigmund): refactor the underlying pieces to reduce the code duplication.
Future<CompilerResult> compileSdkFromDill(List<String> args) async {
  var argParser = ArgParser(allowTrailingOptions: true)
    ..addMultiOption('out', abbr: 'o', help: 'Output file (required).')
    ..addOption('multi-root-scheme', defaultsTo: 'org-dartlang-sdk')
    ..addOption('multi-root-output-path',
        help: 'Path to set multi-root files relative to when generating'
            ' source-maps.',
        hide: true);
  SharedCompilerOptions.addArguments(argParser);

  ArgResults argResults;
  try {
    argResults = argParser.parse(filterUnknownArguments(args, argParser));
  } on FormatException catch (error) {
    print(error);
    print(_usageMessage(argParser));
    return CompilerResult(64);
  }

  var outPaths = argResults['out'] as List<String>;
  var moduleFormats = parseModuleFormatOption(argResults);
  if (outPaths.isEmpty) {
    print('Please specify the output file location. For example:\n'
        '    -o PATH/TO/OUTPUT_FILE.js');
    return CompilerResult(64);
  } else if (outPaths.length != moduleFormats.length) {
    print('Number of output files (${outPaths.length}) must match '
        'number of module formats (${moduleFormats.length}).');
    return CompilerResult(64);
  }

  var component = loadComponentFromBinary(argResults.rest[0]);
  var coreTypes = CoreTypes(component);
  var hierarchy = ClassHierarchy(component, coreTypes);
  var multiRootScheme = argResults['multi-root-scheme'] as String;
  var multiRootOutputPath = argResults['multi-root-output-path'] as String;
  var options = SharedCompilerOptions.fromArguments(argResults);

  var compiler =
      ProgramCompiler(component, hierarchy, options, coreTypes: coreTypes);
  var jsModule = compiler.emitModule(component, const [], const [], const {});
  var outFiles = <Future>[];

  // Also the old Analyzer backend had some code to make debugging better when
  // --single-out-file is used, but that option does not appear to be used by
  // any of our build systems.
  for (var i = 0; i < outPaths.length; ++i) {
    var output = outPaths[i];
    var moduleFormat = moduleFormats[i];
    var file = File(output);
    await file.parent.create(recursive: true);
    var jsCode = jsProgramToCode(jsModule, moduleFormat,
        buildSourceMap: options.sourceMap,
        inlineSourceMap: options.inlineSourceMap,
        jsUrl: p.toUri(output).toString(),
        mapUrl: p.toUri(output + '.map').toString(),
        bazelMapping: options.bazelMapping,
        customScheme: multiRootScheme,
        multiRootOutputPath: multiRootOutputPath);

    outFiles.add(file.writeAsString(jsCode.code));
    if (jsCode.sourceMap != null) {
      outFiles.add(
          File(output + '.map').writeAsString(json.encode(jsCode.sourceMap)));
    }
  }
  return CompilerResult(0);
}

/// The output of compiling a JavaScript module in a particular format.
/// This was copied from module_compiler.dart class "JSModuleCode".
class JSCode {
  /// The JavaScript code for this module.
  ///
  /// If a [sourceMap] is available, this will include the `sourceMappingURL`
  /// comment at end of the file.
  final String code;

  /// The JSON of the source map, if generated, otherwise `null`.
  ///
  /// The source paths will initially be absolute paths. They can be adjusted
  /// using [placeSourceMap].
  final Map sourceMap;

  JSCode(this.code, this.sourceMap);
}

JSCode jsProgramToCode(js_ast.Program moduleTree, ModuleFormat format,
    {bool buildSourceMap = false,
    bool inlineSourceMap = false,
    String jsUrl,
    String mapUrl,
    Map<String, String> bazelMapping,
    String customScheme,
    String multiRootOutputPath}) {
  var opts = js_ast.JavaScriptPrintingOptions(
      allowKeywordsInProperties: true, allowSingleLineIfStatements: true);
  js_ast.SimpleJavaScriptPrintingContext printer;
  SourceMapBuilder sourceMap;
  if (buildSourceMap) {
    var sourceMapContext = SourceMapPrintingContext();
    sourceMap = sourceMapContext.sourceMap;
    printer = sourceMapContext;
  } else {
    printer = js_ast.SimpleJavaScriptPrintingContext();
  }

  var tree = transformModuleFormat(format, moduleTree);
  tree.accept(
      js_ast.Printer(opts, printer, localNamer: js_ast.TemporaryNamer(tree)));

  Map builtMap;
  if (buildSourceMap && sourceMap != null) {
    builtMap = placeSourceMap(
        sourceMap.build(jsUrl), mapUrl, bazelMapping, customScheme,
        multiRootOutputPath: multiRootOutputPath);
    var jsDir = p.dirname(p.fromUri(jsUrl));
    var relative = p.relative(p.fromUri(mapUrl), from: jsDir);
    var relativeMapUrl = p.toUri(relative).toString();
    assert(p.dirname(jsUrl) == p.dirname(mapUrl));
    printer.emit('\n//# sourceMappingURL=');
    printer.emit(relativeMapUrl);
    printer.emit('\n');
  }

  var text = printer.getText();
  var rawSourceMap = inlineSourceMap
      ? js.escapedString(json.encode(builtMap), "'").value
      : 'null';
  text = text.replaceFirst(SharedCompiler.sourceMapLocationID, rawSourceMap);

  return JSCode(text, builtMap);
}

/// Parses Dart's non-standard `-Dname=value` syntax for declared variables,
/// and removes them from [args] so the result can be parsed normally.
Map<String, String> parseAndRemoveDeclaredVariables(List<String> args) {
  var declaredVariables = <String, String>{};
  for (int i = 0; i < args.length;) {
    var arg = args[i];
    if (arg.startsWith('-D') && arg.length > 2) {
      var rest = arg.substring(2);
      var eq = rest.indexOf('=');
      if (eq <= 0) {
        var kind = eq == 0 ? 'name' : 'value';
        throw FormatException('no $kind given to -D option `$arg`');
      }
      var name = rest.substring(0, eq);
      var value = rest.substring(eq + 1);
      declaredVariables[name] = value;
      args.removeAt(i);
    } else {
      i++;
    }
  }

  // Add platform defined variables
  declaredVariables.addAll(sdkLibraryVariables);

  return declaredVariables;
}

/// The default path of the kernel summary for the Dart SDK.
final defaultSdkSummaryPath =
    p.join(getSdkPath(), 'lib', '_internal', 'ddc_sdk.dill');

final defaultLibrarySpecPath = p.join(getSdkPath(), 'lib', 'libraries.json');

bool _checkForDartMirrorsImport(Component component) {
  for (var library in component.libraries) {
    if (library.importUri.scheme == 'dart') continue;
    for (var dep in library.dependencies) {
      var uri = dep.targetLibrary.importUri;
      if (uri.scheme == 'dart' && uri.path == 'mirrors') {
        print('${library.importUri}: Error: Cannot import "dart:mirrors" '
            'in web applications (https://goo.gl/R1anEs).');
        return true;
      }
    }
  }
  return false;
}

/// Returns the absolute path to the default `.packages` file, or `null` if one
/// could not be found.
///
/// Checks for a `.packages` file in the current working directory, or in any
/// parent directory.
String _findPackagesFilePath() {
  // TODO(jmesserly): this was copied from package:package_config/discovery.dart
  // Unfortunately the relevant function is not public. CFE APIs require a URI
  // to the .packages file, rather than letting us provide the package map data.
  var dir = Directory.current;
  if (!dir.isAbsolute) dir = dir.absolute;
  if (!dir.existsSync()) return null;

  // Check for $cwd/.packages
  while (true) {
    var file = File(p.join(dir.path, ".packages"));
    if (file.existsSync()) return file.path;

    // If we didn't find it, search the parent directory.
    // Stop the search if we're already at the root.
    var parent = dir.parent;
    if (dir.path == parent.path) return null;
    dir = parent;
  }
}

/// Inputs must be absolute paths. Returns null if no prefixing path is found.
String _longestPrefixingPath(Uri baseUri, List<Uri> prefixingPaths) {
  var basePath = baseUri.path;
  return prefixingPaths.fold(null, (String previousValue, Uri element) {
    if (basePath.startsWith(element.path) &&
        (previousValue == null || previousValue.length < element.path.length)) {
      return element.path;
    }
    return previousValue;
  });
}
