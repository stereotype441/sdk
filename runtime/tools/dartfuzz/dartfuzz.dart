// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';

import 'dartfuzz_api_table.dart';
import 'dartfuzz_ffi_api.dart';
import 'dartfuzz_type_table.dart';

// Version of DartFuzz. Increase this each time changes are made
// to preserve the property that a given version of DartFuzz yields
// the same fuzzed program for a deterministic random seed.
const String version = '1.61';

// Restriction on statements and expressions.
const int stmtDepth = 1;
const int exprDepth = 2;
const int nestDepth = 1;
const int numStatements = 2;
const int numGlobalVars = 4;
const int numLocalVars = 4;
const int numGlobalMethods = 4;
const int numMethodParams = 4;
const int numClasses = 4;

// Naming conventions.
const varName = 'var';
const paramName = 'par';
const localName = 'loc';
const fieldName = 'fld';
const methodName = 'foo';

// Class that tracks the state of the filter applied to the
// right-hand-side of an assignment in order to avoid generating
// left-hand-side variables.
class RhsFilter {
  RhsFilter(this._remaining, this.lhsVar);
  factory RhsFilter.fromDartType(DartType tp, String lhsVar) {
    if (DartType.isGrowableType(tp)) {
      return RhsFilter(1, lhsVar);
    }
    return null;
  }
  // Clone the current RhsFilter instance and set remaining to 0.
  // This is used for parameter expressions.
  factory RhsFilter.cloneEmpty(RhsFilter rhsFilter) =>
      rhsFilter == null ? null : RhsFilter(0, rhsFilter.lhsVar);
  void consume() => _remaining--;
  bool get shouldFilter => _remaining <= 0;
  // Number of times the lhs variable can still be used on the rhs.
  int _remaining;
  // The name of the lhs variable to be filtered from the rhs.
  final String lhsVar;
}

/// Class that specifies the api for calling library and ffi functions (if
/// enabled).
class DartApi {
  DartApi(bool ffi)
      : intLibs = [
          if (ffi) ...const [
            DartLib('intComputation', 'VIIII'),
            DartLib('takeMaxUint16', 'VI'),
            DartLib('sumPlus42', 'VII'),
            DartLib('returnMaxUint8', 'VV'),
            DartLib('returnMaxUint16', 'VV'),
            DartLib('returnMaxUint32', 'VV'),
            DartLib('returnMinInt8', 'VV'),
            DartLib('returnMinInt16', 'VV'),
            DartLib('returnMinInt32', 'VV'),
            DartLib('takeMinInt16', 'VI'),
            DartLib('takeMinInt32', 'VI'),
            DartLib('uintComputation', 'VIIII'),
            DartLib('sumSmallNumbers', 'VIIIIII'),
            DartLib('takeMinInt8', 'VI'),
            DartLib('takeMaxUint32', 'VI'),
            DartLib('takeMaxUint8', 'VI'),
            DartLib('minInt64', 'VV'),
            DartLib('minInt32', 'VV'),
            // Use small int to avoid overflow divergences due to size
            // differences in intptr_t on 32-bit and 64-bit platforms.
            DartLib('sumManyIntsOdd', 'Viiiiiiiiiii'),
            DartLib('sumManyInts', 'Viiiiiiiiii'),
            DartLib('regress37069', 'Viiiiiiiiiii'),
          ],
          ...DartLib.intLibs,
        ],
        doubleLibs = [
          if (ffi) ...const [
            DartLib('times1_337Float', 'VD'),
            DartLib('sumManyDoubles', 'VDDDDDDDDDD'),
            DartLib('times1_337Double', 'VD'),
            DartLib('sumManyNumbers', 'VIDIDIDIDIDIDIDIDIDID'),
            DartLib('inventFloatValue', 'VV'),
            DartLib('smallDouble', 'VV'),
          ],
          ...DartLib.doubleLibs,
        ];

  final boolLibs = DartLib.boolLibs;
  final stringLibs = DartLib.stringLibs;
  final listLibs = DartLib.listLibs;
  final setLibs = DartLib.setLibs;
  final mapLibs = DartLib.mapLibs;
  final List<DartLib> intLibs;
  final List<DartLib> doubleLibs;
}

/// Class that generates a random, but runnable Dart program for fuzz testing.
class DartFuzz {
  DartFuzz(this.seed, this.fp, this.ffi, this.flatTp, this.file,
      {this.minimize = false, this.smask, this.emask});

  void run() {
    // Initialize program variables.
    rand = Random(seed);
    indent = 0;
    nest = 0;
    currentClass = null;
    currentMethod = null;
    // Setup Dart types.
    dartType = DartType.fromDartConfig(enableFp: fp, disableNesting: flatTp);
    // Setup minimization parameters.
    initMinimization();
    // Setup the library and ffi api.
    api = DartApi(ffi);
    // Setup the types.
    localVars = <DartType>[];
    iterVars = <String>[];
    globalVars = fillTypes1(limit: numGlobalVars);
    globalVars.addAll(dartType.allTypes);
    globalMethods =
        fillTypes2(limit2: numGlobalMethods, limit1: numMethodParams);
    classFields = fillTypes2(limit2: numClasses, limit1: numLocalVars);
    final int numClassMethods = 1 + numClasses - classFields.length;
    classMethods = fillTypes3(classFields.length,
        limit2: numClassMethods, limit1: numMethodParams);
    virtualClassMethods = <Map<int, List<int>>>[];
    classParents = <int>[];
    // Setup optional ffi methods and types.
    final ffiStatus = <bool>[for (final _ in globalMethods) false];
    if (ffi) {
      List<List<DartType>> globalMethodsFfi = fillTypes2(
          limit2: numGlobalMethods, limit1: numMethodParams, isFfi: true);
      for (var m in globalMethodsFfi) {
        globalMethods.add(m);
        ffiStatus.add(true);
      }
    }
    // Generate.
    emitHeader();
    emitVariableDeclarations(varName, globalVars);
    emitMethods(methodName, globalMethods, ffiStatus);
    emitClasses();
    emitMain();
    // Sanity.
    assert(currentClass == null);
    assert(currentMethod == null);
    assert(indent == 0);
    assert(nest == 0);
    assert(localVars.isEmpty);
  }

  //
  // General Helpers.
  //

  BigInt genMask(int m) => BigInt.from(1) << m;
  int choose(int c) => rand.nextInt(c);
  int chooseOneUpTo(int c) => choose(c) + 1;
  bool coinFlip() => rand.nextBool();
  bool rollDice(int c) => (choose(c) == 0);
  double uniform() => rand.nextDouble();

  // Picks one of the given choices.
  T oneOf<T>(List<T> choices) => choices[choose(choices.length)];
  T oneOfSet<T>(Set<T> choices) => choices.elementAt(choose(choices.length));

  //
  // Code Structure Helpers.
  //

  void incIndent() => indent += 2;
  void decIndent() => indent -= 2;

  void emitZero() => emit('0');

  void emitTryCatchFinally(Function tryBody, Function catchBody,
      {Function finallyBody, bool catchOOM = true}) {
    emitLn('try ', newline: false);
    emitBraceWrapped(() => tryBody());
    if (catchOOM) {
      emit(' on OutOfMemoryError ');
      emitBraceWrapped(() => emitLn("exit(${oomExitCode});", newline: false));
    }
    emit(' catch (e, st) ');
    emitBraceWrapped(catchBody);
    if (finallyBody != null) {
      emit(' finally ');
      emitBraceWrapped(finallyBody);
    }
  }

  dynamic emitWrapped(List<String> pair, Function exprEmitter,
      {bool shouldIndent = true}) {
    assert(pair.length == 2);
    emit(pair[0]);
    if (shouldIndent) {
      incIndent();
      emitNewline();
    }
    final result = exprEmitter();
    if (shouldIndent) {
      decIndent();
      emitNewline();
      emitLn(pair[1], newline: false);
    } else {
      emit(pair[1]);
    }
    return result;
  }

  dynamic emitParenWrapped(Function exprEmitter,
      {bool includeSemicolon = false}) {
    final result =
        emitWrapped(const ['(', ')'], exprEmitter, shouldIndent: false);
    if (includeSemicolon) {
      emit(';');
    }
    return result;
  }

  dynamic emitBraceWrapped(Function exprEmitter, {bool shouldIndent = true}) =>
      emitWrapped(const ['{', '}'], exprEmitter, shouldIndent: shouldIndent);

  dynamic emitSquareBraceWrapped(Function exprEmitter) =>
      emitWrapped(const ['[', ']'], exprEmitter, shouldIndent: false);

  dynamic emitCommaSeparated(Function(int) elementBuilder, int length,
      {int start = 0, bool newline = false}) {
    for (int i = start; i < length; ++i) {
      elementBuilder(i);
      if (i + 1 != length) {
        emit(',', newline: newline);
        if (!newline) {
          emit(' ');
        }
      }
    }
  }

  void emitFunctionDefinition(String name, Function body, {String retType}) {
    emitIndentation();
    if (retType != null) {
      emit(retType + ' ');
    }
    emit(name);
    emit('() '); // TODO(bkonyi): handle params

    emitBraceWrapped(body);
  }

  bool emitIfStatement(
      Function ifConditionEmitter, bool Function() ifBodyEmitter,
      {bool Function() elseBodyEmitter}) {
    emitLn('if ', newline: false);
    emitParenWrapped(ifConditionEmitter);
    final bool b1 = emitBraceWrapped(ifBodyEmitter);
    bool b2 = false;
    if (elseBodyEmitter != null) {
      emit(' else ');
      b2 = emitBraceWrapped(elseBodyEmitter);
    }
    return b1 || b2;
  }

  void emitImport(String library, {String asName}) => (asName == null)
      ? emitLn("import '$library';")
      : emitLn("import '$library' as $asName;");

  void emitBinaryComparison(Function e1, String op, Function e2,
      {bool includeSemicolon = false}) {
    e1();
    emit(' $op ');
    e2();
    if (includeSemicolon) {
      emit(';');
    }
  }

  // Randomly specialize interface if possible. E.g. num to int.
  DartType maybeSpecializeInterface(DartType tp) {
    if (!dartType.isSpecializable(tp)) return tp;
    DartType resolvedTp = oneOfSet(dartType.interfaces(tp));
    return resolvedTp;
  }

  //
  // Minimization components.
  //

  void initMinimization() {
    stmtCntr = 0;
    exprCntr = 0;
    skipStmt = false;
    skipExpr = false;
  }

  void emitMinimizedLiteral(DartType tp) {
    switch (tp) {
      case DartType.BOOL:
        emit('true');
        break;
      case DartType.INT:
        emit('1');
        break;
      case DartType.DOUBLE:
        emit('1.0');
        break;
      case DartType.STRING:
        emit('"a"');
        break;
      case DartType.LIST_INT:
        emit('[1]');
        break;
      case DartType.SET_INT:
        emit('{1}');
        break;
      case DartType.MAP_INT_STRING:
        emit('{1: "a"}');
        break;
      default:
        throw 'Unknown DartType ${tp}';
    }
  }

  // Process the opening of a statement.
  // Determine whether the statement should be skipped based on the
  // statement index stored in stmtCntr and the statement mask stored
  // in smask.
  // Returns true if the statement should be skipped.
  bool processStmtOpen() {
    // Do nothing if we are not in minimization mode.
    if (!minimize) {
      return false;
    }
    // Check whether the bit for the current statement number is set in the
    // statement bitmap. If so skip this statement.
    final newMask = genMask(stmtCntr);
    final maskBitSet = (smask & newMask) != BigInt.zero;
    // Statements are nested, therefore masking one statement like e.g.
    // a for loop leads to other statements being omitted.
    // Here we update the statement mask to include the additionally
    // omitted statements.
    if (skipStmt) {
      smask |= newMask;
    }
    // Increase the statement counter.
    stmtCntr++;
    if (!skipStmt && maskBitSet) {
      skipStmt = true;
      return true;
    }
    return false;
  }

  // Process the closing of a statement.
  // The variable resetSkipStmt indicates whether this
  // statement closes the sequence of skipped statement.
  // E.g. the end of a loop where all contained statements
  // were skipped.
  void processStmtClose(bool resetSkipStmt) {
    if (!minimize) {
      return;
    }
    if (resetSkipStmt) {
      skipStmt = false;
    }
  }

  // Process the opening of an expression.
  // Determine whether the expression should be skipped based on the
  // expression index stored in exprCntr and the expression mask stored
  // in emask.
  // Returns true is the expression is skipped.
  bool processExprOpen(DartType tp) {
    // Do nothing if we are not in minimization mode.
    if (!minimize) {
      return false;
    }
    // Check whether the bit for the current expression number is set in the
    // expression bitmap. If so skip this expression.
    final newMask = genMask(exprCntr);
    final maskBitSet = (emask & newMask) != BigInt.zero;
    // Expressions are nested, therefore masking one expression like e.g.
    // a for loop leads to other expressions being omitted.
    // Similarly, if the whole statement is skipped, all the expressions
    // within that statement are implicitly masked.
    // Here we update the expression mask to include the additionally
    // omitted expressions.
    if (skipExpr || skipStmt) {
      emask |= newMask;
    }
    exprCntr++;
    if (skipStmt) {
      return false;
    }
    if (!skipExpr && maskBitSet) {
      emitMinimizedLiteral(tp);
      skipExpr = true;
      return true;
    }
    return false;
  }

  void processExprClose(bool resetExprStmt) {
    if (!minimize || skipStmt) {
      return;
    }
    if (resetExprStmt) {
      skipExpr = false;
    }
  }

  //
  // Program components.
  //

  void emitHeader() {
    emitLn('// The Dart Project Fuzz Tester ($version).');
    emitLn('// Program generated as:');
    emitLn('//   dart dartfuzz.dart --seed $seed --${fp ? "" : "no-"}fp '
        '--${ffi ? "" : "no-"}ffi --${flatTp ? "" : "no-"}flat');
    emitNewline();
    emitImport('dart:async');
    emitImport('dart:cli');
    emitImport('dart:collection');
    emitImport('dart:convert');
    emitImport('dart:core');
    emitImport('dart:io');
    emitImport('dart:isolate');
    emitImport('dart:math');
    emitImport('dart:typed_data');
    if (ffi) {
      emitImport('dart:ffi', asName: 'ffi');
      emitLn(DartFuzzFfiApi.ffiapi);
    }
    emitNewline();
  }

  void emitFfiCast(String dartFuncName, String ffiFuncName, String typeName,
      List<DartType> pars) {
    emit("${pars[0].name} Function");
    emitParenWrapped(() => emitCommaSeparated(
        (int i) => emit('${pars[i].name}'), pars.length,
        start: 1));
    emit(' ${dartFuncName} = ffi.Pointer.fromFunction<${typeName}>');
    emitParenWrapped(() {
      emit('${ffiFuncName}, ');
      emitLiteral(0, pars[0], smallPositiveValue: true);
    });
    emit('.cast<ffi.NativeFunction<${typeName}>>().asFunction();');
    emitNewline();
  }

  void emitMethod(
      String name, int index, List<DartType> method, bool isFfiMethod) {
    final type = method[0].name;
    final methodName = '$name${isFfiMethod ? "Ffi" : ''}$index';
    if (isFfiMethod) {
      emitFfiTypedef("${name}Ffi${index}Type", method);
    }
    emitLn('$type $methodName', newline: false);
    emitParenWrapped(() => emitParDecls(method));
    if (!isFfiMethod && rollDice(10)) {
      // Emit a method using "=>" syntax.
      emit(' => ');
      emitExpr(0, method[0], includeSemicolon: true);
    } else {
      emitBraceWrapped(() {
        assert(localVars.isEmpty);
        if (emitStatements(0)) {
          emitReturn();
        }
        assert(localVars.isEmpty);
      });
    }
    if (isFfiMethod) {
      emitFfiCast("${name}${index}", "${name}Ffi${index}",
          "${name}Ffi${index}Type", method);
    }
    emitNewline();
    emitNewline();
  }

  void emitMethods(String name, List<List<DartType>> methods,
      [List<bool> ffiStatus]) {
    for (int i = 0; i < methods.length; i++) {
      List<DartType> method = methods[i];
      currentMethod = i;
      final bool isFfiMethod = ffiStatus != null && ffiStatus[i];
      emitMethod(name, i, method, isFfiMethod);
      currentMethod = null;
    }
  }

  // Randomly overwrite some methods from the parent classes.
  void emitVirtualMethods() {
    final currentClassTmp = currentClass;
    int parentClass = classParents[currentClass];
    final vcm = <int, List<int>>{};
    // Chase randomly up in class hierarchy.
    while (parentClass >= 0) {
      vcm[parentClass] = <int>[];
      for (int j = 0, n = classMethods[parentClass].length; j < n; j++) {
        if (rollDice(8)) {
          currentClass = parentClass;
          currentMethod = j;
          emitMethod('$methodName${parentClass}_', j,
              classMethods[parentClass][j], false);
          vcm[parentClass].add(currentMethod);
          currentMethod = null;
          currentClass = null;
        }
      }
      if (coinFlip() || classParents.length > parentClass) {
        break;
      } else {
        parentClass = classParents[parentClass];
      }
    }
    currentClass = currentClassTmp;
    virtualClassMethods.add(vcm);
  }

  void emitClasses() {
    assert(classFields.length == classMethods.length);
    for (int i = 0; i < classFields.length; i++) {
      if (i == 0) {
        classParents.add(-1);
        emit('class X0 ');
      } else {
        final int parentClass = choose(i);
        classParents.add(parentClass);
        if (choose(2) != 0) {
          // Inheritance
          emit('class X$i extends X${parentClass} ');
        } else {
          // Mixin
          if (classParents[parentClass] >= 0) {
            emit(
                'class X$i extends X${classParents[parentClass]} with X${parentClass} ');
          } else {
            emit('class X$i with X${parentClass} ');
          }
        }
      }
      emitBraceWrapped(() {
        emitVariableDeclarations('$fieldName${i}_', classFields[i]);
        currentClass = i;
        emitVirtualMethods();
        emitMethods('$methodName${i}_', classMethods[i]);
        emitFunctionDefinition('run', () {
          if (i > 0) {
            // FIXME(bkonyi): fix potential issue where we try to apply a class
            // as a mixin when it calls super.
            emitLn('super.run();');
          }
          assert(localVars.isEmpty);
          emitStatements(0);
          assert(localVars.isEmpty);
        }, retType: 'void');
      });
      currentClass = null;
      emitNewline();
      emitNewline();
    }
  }

  void emitLoadFfiLib() {
    if (ffi) {
      emitLn(
          '// The following throws an uncaught exception if the ffi library ' +
              'is not found.');
      emitLn(
          '// By not catching this exception, we terminate the program with ' +
              'a full stack trace');
      emitLn('// which, in turn, flags the problem prominently');
      emitIfStatement(() => emit('ffiTestFunctions == null'),
          () => emitPrint('Did not load ffi test functions'));
    }
  }

  void emitMain() => emitFunctionDefinition('main', () {
        emitLoadFfiLib();

        // Call each global method once.
        for (int i = 0; i < globalMethods.length; i++) {
          final outputName = '$methodName$i';
          emitTryCatchFinally(() {
            emitCall(1, outputName, globalMethods[i], includeSemicolon: true);
          }, () {
            emitPrint('$outputName throws');
          });
          emitNewline();
        }

        // Call each class method once.
        for (int i = 0; i < classMethods.length; i++) {
          for (int j = 0; j < classMethods[i].length; j++) {
            final outputName = 'X${i}().$methodName${i}_${j}';
            emitNewline();
            emitTryCatchFinally(() {
              emitCall(1, outputName, classMethods[i][j],
                  includeSemicolon: true);
            }, () {
              emitPrint('$outputName() throws');
            });
          }
          // Call each virtual class method once.
          int parentClass = classParents[i];
          while (parentClass >= 0) {
            if (virtualClassMethods[i].containsKey(parentClass)) {
              for (int j = 0;
                  j < virtualClassMethods[i][parentClass].length;
                  j++) {
                final outputName = 'X${i}().$methodName${parentClass}_${j}';
                emitNewline();
                emitTryCatchFinally(
                    () => emitCall(1, outputName, classMethods[parentClass][j],
                        includeSemicolon: true),
                    () => emitPrint('$outputName() throws'));
              }
            }
            parentClass = classParents[parentClass];
          }
        }

        emitNewline();
        emitTryCatchFinally(() {
          emitLn('X${classFields.length - 1}().run();', newline: false);
        }, () {
          emitPrint('X${classFields.length - 1}().run() throws');
        });

        emitNewline();
        emitTryCatchFinally(() {
          String body = '';
          for (int i = 0; i < globalVars.length; i++) {
            body += '\$$varName$i\\n';
          }
          emitPrint('$body');
        }, () => emitPrint('print throws'));
      });

  //
  // Declarations.
  //

  void emitVariableDeclarations(String name, List<DartType> vars) {
    for (int i = 0; i < vars.length; i++) {
      DartType tp = vars[i];
      final varName = '$name$i';
      emitVariableDeclaration(varName, tp,
          initializerEmitter: () => emitConstructorOrLiteral(0, tp));
    }
    emitNewline();
  }

  void emitVariableDeclaration(String name, DartType tp,
      {Function initializerEmitter,
      bool indent = true,
      bool newline = true,
      bool includeSemicolon = true}) {
    final typeName = tp.name;
    if (indent) {
      emitIndentation();
    }
    emit('$typeName $name', newline: false);
    if (initializerEmitter != null) {
      emit(' = ');
      initializerEmitter();
    }
    if (includeSemicolon) {
      emit(';', newline: newline);
    }
  }

  void emitParDecls(List<DartType> pars) => emitCommaSeparated((int i) {
        DartType tp = pars[i];
        emit('${tp.name} $paramName$i');
      }, pars.length, start: 1);

  //
  // Comments (for FE and analysis tools).
  //

  void emitComment() {
    switch (choose(4)) {
      case 0:
        emitLn('// Single-line comment.');
        break;
      case 1:
        emitLn('/// Single-line documentation comment.');
        break;
      case 2:
        emitLn('/*');
        emitLn(' * Multi-line');
        emitLn(' * comment.');
        emitLn(' */');
        break;
      default:
        emitLn('/**');
        emitLn(' ** Multi-line');
        emitLn(' ** documentation comment.');
        emitLn(' */');
        break;
    }
  }

  //
  // Statements.
  //

  // Emit an assignment statement.
  bool emitAssign() {
    // Select a type at random.
    final tp = oneOfSet(dartType.allTypes);
    String assignOp;
    if (DartType.isGrowableType(tp)) {
      // Assignments like *= and += on growable types (String, List, ...)
      // may lead to OOM, especially within loops.
      // TODO: Implement a more specific heuristic that selectively allows
      // modifying assignment operators (like += *=) for growable types.
      assignOp = '=';
    } else {
      // Select one of the assign operations for the given type.
      assignOp = oneOfSet(dartType.assignOps(tp));
      if (assignOp == null) {
        throw 'No assign operation for ${tp.name}';
      }
    }
    emitIndentation();
    // Emit a variable of the lhs type.
    final emittedVar = emitVar(0, tp, isLhs: true);
    RhsFilter rhsFilter = RhsFilter.fromDartType(tp, emittedVar);
    emit(" $assignOp ");
    // Select one of the possible rhs types for the given lhs type and assign
    // operation.
    DartType rhsType = oneOfSet(dartType.assignOpRhs(tp, assignOp));
    if (rhsType == null) {
      throw 'No rhs type for assign ${tp.name} $assignOp';
    }

    emitExpr(0, rhsType, rhsFilter: rhsFilter, includeSemicolon: true);
    return true;
  }

  // Emit a print statement.
  bool emitPrint([String body]) {
    emitLn('print', newline: false);
    emitParenWrapped(() {
      if (body != null) {
        emit("'$body'");
      } else {
        DartType tp = oneOfSet(dartType.allTypes);
        emitExpr(0, tp);
      }
    }, includeSemicolon: true);
    return true;
  }

  // Emit a return statement.
  bool emitReturn() {
    List<DartType> proto = getCurrentProto();
    if (proto == null) {
      emitLn('return;');
    } else {
      emitLn('return ', newline: false);
      emitExpr(0, proto[0], includeSemicolon: true);
    }
    return false;
  }

  // Emit a throw statement.
  bool emitThrow() {
    DartType tp = oneOfSet(dartType.allTypes);
    emitLn('throw ', newline: false);
    emitExpr(0, tp, includeSemicolon: true);
    return false;
  }

  // Emit a one-way if statement.
  bool emitIf1(int depth) => emitIfStatement(
      () => emitExpr(0, DartType.BOOL), () => emitStatements(depth + 1));

  // Emit a two-way if statement.
  bool emitIf2(int depth) => emitIfStatement(
      () => emitExpr(0, DartType.BOOL), () => emitStatements(depth + 1),
      elseBodyEmitter: () => emitStatements(depth + 1));

  // Emit a simple increasing for-loop.
  bool emitFor(int depth) {
    // Make deep nesting of loops increasingly unlikely.
    if (choose(nest + 1) > nestDepth) {
      return emitAssign();
    }
    final int i = localVars.length;
    emitLn('for ', newline: false);
    emitParenWrapped(() {
      final name = '$localName$i';
      emitVariableDeclaration(name, DartType.INT,
          initializerEmitter: emitZero, newline: false, indent: false);
      emitBinaryComparison(() => emit(name), '<', emitSmallPositiveInt,
          includeSemicolon: true);
      emit('$name++');
    });
    emitBraceWrapped(() {
      nest++;
      iterVars.add('$localName$i');
      localVars.add(DartType.INT);
      emitStatements(depth + 1);
      localVars.removeLast();
      iterVars.removeLast();
      nest--;
    });
    return true;
  }

  // Emit a simple membership for-in-loop.
  bool emitForIn(int depth) {
    // Make deep nesting of loops increasingly unlikely.
    if (choose(nest + 1) > nestDepth) {
      return emitAssign();
    }
    final int i = localVars.length;
    // Select one iterable type to be used in 'for in' statement.
    final iterType = oneOfSet(dartType.iterableTypes1);
    // Get the element type contained within the iterable type.
    final elementType = dartType.elementType(iterType);
    if (elementType == null) {
      throw 'No element type for iteration type ${iterType.name}';
    }
    emitLn('for ', newline: false);
    emitParenWrapped(() {
      emit('${elementType.name} $localName$i in ');
      localVars.add(null); // declared, but don't use
      emitExpr(0, iterType);
      localVars.removeLast(); // will get type
    });
    emitBraceWrapped(() {
      nest++;
      localVars.add(elementType);
      emitStatements(depth + 1);
      localVars.removeLast();
      nest--;
    });
    return true;
  }

  // Emit a simple membership forEach loop.
  bool emitForEach(int depth) {
    // Make deep nesting of loops increasingly unlikely.
    if (choose(nest + 1) > nestDepth) {
      return emitAssign();
    }
    emitIndentation();

    // Select one map type to be used in forEach loop.
    final mapType = oneOfSet(dartType.mapTypes);
    final emittedVar = emitScalarVar(mapType, isLhs: false);
    iterVars.add(emittedVar);
    emit('.forEach');
    final i = localVars.length;
    final j = i + 1;
    emitParenWrapped(() {
      emitParenWrapped(() => emit('$localName$i, $localName$j'));
      emitBraceWrapped(() {
        final int nestTmp = nest;
        // Reset, since forEach cannot break out of own or enclosing context.
        nest = 0;
        // Get the type of the map key and add it to the local variables.
        localVars.add(dartType.indexType(mapType));
        // Get the type of the map values and add it to the local variables.
        localVars.add(dartType.elementType(mapType));
        emitStatements(depth + 1);
        localVars.removeLast();
        localVars.removeLast();
        nest = nestTmp;
      });
    }, includeSemicolon: true);
    return true;
  }

  // Emit a while-loop.
  bool emitWhile(int depth) {
    // Make deep nesting of loops increasingly unlikely.
    if (choose(nest + 1) > nestDepth) {
      return emitAssign();
    }
    final int i = localVars.length;
    emitIndentation();
    emitBraceWrapped(() {
      final name = '$localName$i';
      emitVariableDeclaration(name, DartType.INT,
          initializerEmitter: () => emitSmallPositiveInt());
      emitLn('while ', newline: false);
      emitParenWrapped(
          () => emitBinaryComparison(() => emit('--$name'), '>', emitZero));
      emitBraceWrapped(() {
        nest++;
        iterVars.add(name);
        localVars.add(DartType.INT);
        emitStatements(depth + 1);
        localVars.removeLast();
        iterVars.removeLast();
        nest--;
      });
    });
    return true;
  }

  // Emit a do-while-loop.
  bool emitDoWhile(int depth) {
    // Make deep nesting of loops increasingly unlikely.
    if (choose(nest + 1) > nestDepth) {
      return emitAssign();
    }
    final int i = localVars.length;
    emitIndentation();
    emitBraceWrapped(() {
      final name = '$localName$i';
      emitVariableDeclaration(name, DartType.INT, initializerEmitter: emitZero);
      emitLn('do ', newline: false);
      emitBraceWrapped(() {
        nest++;
        iterVars.add(name);
        localVars.add(DartType.INT);
        emitStatements(depth + 1);
        localVars.removeLast();
        iterVars.removeLast();
        nest--;
      });
      emit(' while ');
      emitParenWrapped(
          () => emitBinaryComparison(
              () => emit('++$name'), '<', emitSmallPositiveInt),
          includeSemicolon: true);
    });
    emitNewline();
    return true;
  }

  // Emit a break/continue when inside iteration.
  bool emitBreakOrContinue(int depth) {
    if (nest > 0) {
      switch (choose(2)) {
        case 0:
          emitLn('continue;');
          return false;
        default:
          emitLn('break;');
          return false;
      }
    }
    return emitAssign(); // resort to assignment
  }

  // Emit a switch statement.
  bool emitSwitch(int depth) {
    emitCase(Function bodyEmitter, {int kase}) {
      if (kase == null) {
        emitLn('default: ', newline: false);
      } else {
        emitLn('case $kase: ', newline: false);
      }
      emitBraceWrapped(() {
        bodyEmitter();
        emitNewline();
        emitLn('break;',
            newline: false); // always generate, avoid FE complaints
      });
    }

    emitLn('switch ', newline: false);
    emitParenWrapped(() => emitExpr(0, DartType.INT));
    emitBraceWrapped(() {
      int start = choose(1 << 32);
      int step = chooseOneUpTo(10);
      final maxCases = 3;
      for (int i = 0; i < maxCases; i++, start += step) {
        emitCase(() => emitStatement(depth + 1),
            kase: (i == 2 && coinFlip()) ? null : start);
        if (i + 1 != maxCases) {
          emitNewline();
        }
      }
    });
    return true;
  }

  // Emit a new program scope that introduces a new local variable.
  bool emitScope(int depth) {
    emitIndentation();
    emitBraceWrapped(() {
      DartType tp = oneOfSet(dartType.allTypes);
      final int i = localVars.length;
      final name = '$localName$i';
      emitVariableDeclaration(name, tp, initializerEmitter: () {
        localVars.add(null); // declared, but don't use
        emitExpr(0, tp);
        localVars.removeLast(); // will get type
      });
      localVars.add(tp);
      emitStatements(depth + 1);
      localVars.removeLast();
    });
    return true;
  }

  // Emit try/catch/finally.
  bool emitTryCatch(int depth) {
    final emitStatementsClosure = () => emitStatements(depth + 1);
    emitLn('try ', newline: false);
    emitBraceWrapped(emitStatementsClosure);
    emit(' catch (exception, stackTrace) ', newline: false);
    emitBraceWrapped(emitStatementsClosure);
    if (coinFlip()) {
      emit(' finally ', newline: false);
      emitBraceWrapped(emitStatementsClosure);
    }
    return true;
  }

  // Emit a single statement.
  bool emitSingleStatement(int depth) {
    // Throw in a comment every once in a while.
    if (rollDice(10)) {
      emitComment();
    }
    // Continuing nested statements becomes less likely as the depth grows.
    if (choose(depth + 1) > stmtDepth) {
      return emitAssign();
    }
    // Possibly nested statement.
    switch (choose(16)) {
      // Favors assignment.
      case 0:
        return emitPrint();
      case 1:
        return emitReturn();
      case 2:
        return emitThrow();
      case 3:
        return emitIf1(depth);
      case 4:
        return emitIf2(depth);
      case 5:
        return emitFor(depth);
      case 6:
        return emitForIn(depth);
      case 7:
        return emitWhile(depth);
      case 8:
        return emitDoWhile(depth);
      case 9:
        return emitBreakOrContinue(depth);
      case 10:
        return emitSwitch(depth);
      case 11:
        return emitScope(depth);
      case 12:
        return emitTryCatch(depth);
      case 13:
        return emitForEach(depth);
      default:
        return emitAssign();
    }
  }

  // Emit a statement (main entry).
  // Returns true if code *may* fall-through
  // (not made too advanced to avoid FE complaints).
  bool emitStatement(int depth) {
    final resetSkipStmt = processStmtOpen();
    bool ret = emitSingleStatement(depth);
    processStmtClose(resetSkipStmt);
    return ret;
  }

  // Emit statements. Returns true if code may fall-through.
  bool emitStatements(int depth) {
    int s = chooseOneUpTo(numStatements);
    for (int i = 0; i < s; i++) {
      if (!emitStatement(depth)) {
        return false; // rest would be dead code
      }
      if (i + 1 != s) {
        emitNewline();
      }
    }
    return true;
  }

  //
  // Expressions.
  //

  void emitBool() => emit(coinFlip() ? 'true' : 'false');

  void emitSmallPositiveInt({int limit = 50, bool includeSemicolon = false}) {
    emit('${choose(limit)}');
    if (includeSemicolon) {
      emit(';');
    }
  }

  void emitSmallNegativeInt() => emit('-${choose(100)}');

  void emitInt() {
    switch (choose(7)) {
      // Favors small ints.
      case 0:
      case 1:
      case 2:
        emitSmallPositiveInt();
        break;
      case 3:
      case 4:
      case 5:
        emitSmallNegativeInt();
        break;
      default:
        emit('${oneOf(interestingIntegers)}');
        break;
    }
  }

  void emitDouble() => emit('${uniform()}');

  void emitNum({bool smallPositiveValue = false}) {
    if (!fp || coinFlip()) {
      if (smallPositiveValue) {
        emitSmallPositiveInt();
      } else {
        emitInt();
      }
    } else {
      emitDouble();
    }
  }

  void emitChar() {
    switch (choose(10)) {
      // Favors regular char.
      case 0:
        emit(oneOf(interestingChars));
        break;
      default:
        emit(regularChars[choose(regularChars.length)]);
        break;
    }
  }

  void emitString({int length = 8}) {
    final n = choose(length);
    emit("'");
    for (int i = 0; i < n; i++) {
      emitChar();
    }
    emit("'");
  }

  void emitElementExpr(int depth, DartType tp, {RhsFilter rhsFilter}) {
    // This check determines whether we are emitting a global variable.
    // I.e. whenever we are not currently emitting part of a class.
    if (currentMethod != null) {
      emitExpr(depth, tp, rhsFilter: rhsFilter);
    } else {
      emitLiteral(depth, tp, rhsFilter: rhsFilter);
    }
  }

  void emitElement(int depth, DartType tp, {RhsFilter rhsFilter}) {
    // Get the element type contained in type tp.
    // E.g. element type of List<String> is String.
    final elementType = dartType.elementType(tp);
    // Decide whether we need to generate Map or List/Set type elements.
    if (DartType.isMapType(tp)) {
      // Emit construct for the map key type.
      final indexType = dartType.indexType(tp);
      emitIndentation();
      emitElementExpr(depth, indexType, rhsFilter: rhsFilter);
      emit(' : ');
      // Emit construct for the map value type.
      emitElementExpr(depth, elementType, rhsFilter: rhsFilter);
    } else {
      // List and Set types.
      emitElementExpr(depth, elementType, rhsFilter: rhsFilter);
    }
  }

  void emitCollectionElement(int depth, DartType tp, {RhsFilter rhsFilter}) {
    int r = (depth <= exprDepth) ? choose(10) : 10;
    // TODO (felih): disable complex collection constructs for new types for
    // now.
    if (!{DartType.MAP_INT_STRING, DartType.LIST_INT, DartType.SET_INT}
        .contains(tp)) {
      emitElement(depth, tp, rhsFilter: rhsFilter);
      return;
    }
    switch (r) {
      // Favors elements over control-flow collections.
      case 0:
        // TODO (ajcbik): Remove restriction once compiler is fixed.
        if (depth < 2) {
          emitLn('...', newline: false); // spread
          emitCollection(depth + 1, tp, rhsFilter: rhsFilter);
        } else {
          emitElement(depth, tp, rhsFilter: rhsFilter);
        }
        break;
      case 1:
        emitLn('if ', newline: false);
        emitParenWrapped(() =>
            emitElementExpr(depth + 1, DartType.BOOL, rhsFilter: rhsFilter));
        emitCollectionElement(depth + 1, tp, rhsFilter: rhsFilter);
        if (coinFlip()) {
          emitNewline();
          emitLn('else ', newline: false);
          emitCollectionElement(depth + 1, tp, rhsFilter: rhsFilter);
        }
        break;
      case 2:
        {
          final int i = localVars.length;
          // TODO (felih): update to use new type system. Add types like
          // LIST_STRING etc.
          emitLn('for ', newline: false);
          emitParenWrapped(() {
            final local = '$localName$i';
            iterVars.add(local);
            // For-loop (induction, list, set).
            localVars.add(null); // declared, but don't use
            switch (choose(3)) {
              case 0:
                emitVariableDeclaration(local, DartType.INT,
                    initializerEmitter: emitZero, indent: false);
                emitBinaryComparison(() => emit(local), '<',
                    () => emitSmallPositiveInt(limit: 16),
                    includeSemicolon: true);
                emit('$local++');
                break;
              case 1:
                emitVariableDeclaration(local, DartType.INT,
                    includeSemicolon: false, indent: false);
                emit(' in ');
                emitCollection(depth + 1, DartType.LIST_INT,
                    rhsFilter: rhsFilter);
                break;
              default:
                emitVariableDeclaration(local, DartType.INT,
                    includeSemicolon: false, indent: false);
                emit(' in ');
                emitCollection(depth + 1, DartType.SET_INT,
                    rhsFilter: rhsFilter);
                break;
            }
            localVars.removeLast(); // will get type
          });
          nest++;
          localVars.add(DartType.INT);
          emitNewline();
          emitCollectionElement(depth + 1, tp, rhsFilter: rhsFilter);
          localVars.removeLast();
          iterVars.removeLast();
          nest--;
          break;
        }
      default:
        emitElement(depth, tp, rhsFilter: rhsFilter);
        break;
    }
  }

  void emitCollection(int depth, DartType tp, {RhsFilter rhsFilter}) =>
      emitWrapped(DartType.isListType(tp) ? const ['[', ']'] : const ['{', '}'],
          () {
        // Collection length decreases as depth increases.
        int collectionLength = max(1, 8 - depth);
        emitCommaSeparated(
            (int _) => emitCollectionElement(depth, tp, rhsFilter: rhsFilter),
            chooseOneUpTo(collectionLength),
            newline: DartType.isMapType(tp));
      }, shouldIndent: DartType.isMapType(tp));

  void emitLiteral(int depth, DartType tp,
      {bool smallPositiveValue = false, RhsFilter rhsFilter}) {
    // Randomly specialize interface if possible. E.g. num to int.
    tp = maybeSpecializeInterface(tp);
    if (tp == DartType.BOOL) {
      emitBool();
    } else if (tp == DartType.INT) {
      if (smallPositiveValue) {
        emitSmallPositiveInt();
      } else {
        emitInt();
      }
    } else if (tp == DartType.DOUBLE) {
      emitDouble();
    } else if (tp == DartType.NUM) {
      emitNum(smallPositiveValue: smallPositiveValue);
    } else if (tp == DartType.STRING) {
      emitString();
    } else if (dartType.constructors(tp).isNotEmpty) {
      // Constructors serve as literals for non trivially constructable types.
      // Important note: We have to test for existence of a non trivial
      // constructor before testing for list type assiciation, since some types
      // like ListInt32 are of list type but can not be constructed
      // from a literal.
      emitConstructorOrLiteral(depth + 1, tp, rhsFilter: rhsFilter);
    } else if (DartType.isCollectionType(tp)) {
      final resetExprStmt = processExprOpen(tp);
      emitCollection(depth + 1, tp, rhsFilter: rhsFilter);
      processExprClose(resetExprStmt);
    } else {
      throw 'Can not emit literal for type ${tp.name}';
    }
  }

  // Emit a constructor for a type, this can either be a trivial constructor
  // (i.e. parsed from a literal) or an actual function invocation.
  void emitConstructorOrLiteral(int depth, DartType tp,
      {RhsFilter rhsFilter, bool includeSemicolon = false}) {
    // If there is at least one non trivial constructor for the type tp
    // select one of these constructors.
    if (dartType.hasConstructor(tp)) {
      String constructor = oneOfSet(dartType.constructors(tp));
      // There are two types of constructors, named constructors and 'empty'
      // constructors (e.g. X.fromList(...) and new X(...) respectively).
      // Empty constructors are invoked with new + type name, non-empty
      // constructors are static functions of the type.
      if (constructor.isNotEmpty) {
        emit('${tp.name}.${constructor}');
      } else {
        // New is no longer necessary as of Dart 2, but is still supported.
        // Emit a `new` once in a while to ensure it's covered.
        emit('${rollDice(10) ? "new " : ""}${tp.name}');
      }
      emitParenWrapped(() {
        // Iterate over constructor parameters.
        List<DartType> constructorParameters =
            dartType.constructorParameters(tp, constructor);
        if (constructorParameters == null) {
          throw 'No constructor parameters for ${tp.name}.$constructor';
        }
        emitCommaSeparated((int i) {
          // If we are emitting a constructor parameter, we want to use small
          // values to avoid programs that run out of memory.
          // TODO (felih): maybe allow occasionally?
          emitLiteral(depth + 1, constructorParameters[i],
              smallPositiveValue: true, rhsFilter: rhsFilter);
        }, constructorParameters.length);
      });
    } else {
      // Otherwise type can be constructed from a literal.
      emitLiteral(depth + 1, tp, rhsFilter: rhsFilter);
    }
    if (includeSemicolon) {
      emit(';');
    }
  }

  String emitScalarVar(DartType tp, {bool isLhs = false, RhsFilter rhsFilter}) {
    // Randomly specialize interface type, unless emitting left hand side.
    if (!isLhs) tp = maybeSpecializeInterface(tp);
    // Collect all choices from globals, fields, locals, and parameters.
    Set<String> choices = <String>{};
    for (int i = 0; i < globalVars.length; i++) {
      if (tp == globalVars[i]) choices.add('$varName$i');
    }
    for (int i = 0; i < localVars.length; i++) {
      if (tp == localVars[i]) choices.add('$localName$i');
    }
    List<DartType> fields = getCurrentFields();
    if (fields != null) {
      for (int i = 0; i < fields.length; i++) {
        if (tp == fields[i]) choices.add('$fieldName${currentClass}_$i');
      }
    }
    List<DartType> proto = getCurrentProto();
    if (proto != null) {
      for (int i = 1; i < proto.length; i++) {
        if (tp == proto[i]) choices.add('$paramName$i');
      }
    }
    // Make modification of the iteration variable from the loop
    // body less likely.
    if (isLhs) {
      if (!rollDice(100)) {
        Set<String> cleanChoices = choices.difference(Set.from(iterVars));
        if (cleanChoices.isNotEmpty) {
          choices = cleanChoices;
        }
      }
    }
    // Filter out the current lhs of the expression to avoid recursive
    // assignments of the form x = x * x.
    if (rhsFilter != null && rhsFilter.shouldFilter) {
      Set<String> cleanChoices = choices.difference({rhsFilter.lhsVar});
      // If we have other choices of variables, use those.
      if (cleanChoices.isNotEmpty) {
        choices = cleanChoices;
      } else if (!isLhs) {
        // If we are emitting an rhs variable, we can emit a terminal.
        // note that if the variable type is a collection, this might
        // still result in a recursion.
        emitLiteral(0, tp);
        return null;
      }
      // Otherwise we have to risk creating a recursion.
    }
    // Then pick one.
    if (choices.isEmpty) {
      throw 'No variable to emit for type ${tp.name}';
    }
    final emittedVar = '${choices.elementAt(choose(choices.length))}';
    if (rhsFilter != null && (emittedVar == rhsFilter.lhsVar)) {
      rhsFilter.consume();
    }
    emit(emittedVar);
    return emittedVar;
  }

  String emitSubscriptedVar(int depth, DartType tp,
      {bool isLhs = false, RhsFilter rhsFilter}) {
    String ret;
    // Check if type tp is an indexable element of some other type.
    if (dartType.isIndexableElementType(tp)) {
      // Select a list or map type that contains elements of type tp.
      final iterType = oneOfSet(dartType.indexableElementTypes(tp));
      // Get the index type for the respective list or map type.
      final indexType = dartType.indexType(iterType);
      // Emit a variable of the selected list or map type.
      ret = emitScalarVar(iterType, isLhs: isLhs, rhsFilter: rhsFilter);
      emitSquareBraceWrapped(() =>
          // Emit an expression resolving into the index type.
          emitExpr(depth + 1, indexType));
    } else {
      ret = emitScalarVar(tp,
          isLhs: isLhs, rhsFilter: rhsFilter); // resort to scalar
    }
    return ret;
  }

  String emitVar(int depth, DartType tp,
      {bool isLhs = false, RhsFilter rhsFilter}) {
    switch (choose(2)) {
      case 0:
        return emitScalarVar(tp, isLhs: isLhs, rhsFilter: rhsFilter);
        break;
      default:
        return emitSubscriptedVar(depth, tp,
            isLhs: isLhs, rhsFilter: rhsFilter);
        break;
    }
  }

  void emitTerminal(int depth, DartType tp, {RhsFilter rhsFilter}) {
    switch (choose(2)) {
      case 0:
        emitLiteral(depth, tp, rhsFilter: rhsFilter);
        break;
      default:
        emitVar(depth, tp, rhsFilter: rhsFilter);
        break;
    }
  }

  void emitExprList(int depth, List<DartType> proto, {RhsFilter rhsFilter}) =>
      emitParenWrapped(() {
        emitCommaSeparated((int i) {
          emitExpr(depth, proto[i], rhsFilter: rhsFilter);
        }, proto.length, start: 1);
      });

  // Emit expression with unary operator: (~(x))
  void emitUnaryExpr(int depth, DartType tp, {RhsFilter rhsFilter}) {
    if (dartType.uniOps(tp).isEmpty) {
      return emitTerminal(depth, tp, rhsFilter: rhsFilter);
    }
    emitParenWrapped(() {
      emit(oneOfSet(dartType.uniOps(tp)));
      emitParenWrapped(() => emitExpr(depth + 1, tp, rhsFilter: rhsFilter));
    });
  }

  // Emit expression with binary operator: (x + y)
  void emitBinaryExpr(int depth, DartType tp, {RhsFilter rhsFilter}) {
    if (dartType.binOps(tp).isEmpty) {
      return emitLiteral(depth, tp);
    }

    String binop = oneOfSet(dartType.binOps(tp));
    List<DartType> binOpParams = oneOfSet(dartType.binOpParameters(tp, binop));

    // Avoid recursive assignments of the form a = a * 100.
    if (binop == "*") {
      rhsFilter?.consume();
    }

    // Reduce the number of operations of type growable * large value
    // as these might lead to timeouts and/or oom errors.
    if (binop == "*" &&
        DartType.isGrowableType(binOpParams[0]) &&
        dartType.isInterfaceOfType(binOpParams[1], DartType.NUM)) {
      emitParenWrapped(() {
        emitExpr(depth + 1, binOpParams[0], rhsFilter: rhsFilter);
        emit(' $binop ');
        emitLiteral(depth + 1, binOpParams[1], smallPositiveValue: true);
      });
    } else if (binop == "*" &&
        DartType.isGrowableType(binOpParams[1]) &&
        dartType.isInterfaceOfType(binOpParams[0], DartType.NUM)) {
      emitParenWrapped(() {
        emitLiteral(depth + 1, binOpParams[0], smallPositiveValue: true);
        emit(' $binop ');
        emitExpr(depth + 1, binOpParams[1], rhsFilter: rhsFilter);
      });
    } else {
      emitParenWrapped(() {
        emitExpr(depth + 1, binOpParams[0], rhsFilter: rhsFilter);
        emit(' $binop ');
        emitExpr(depth + 1, binOpParams[1], rhsFilter: rhsFilter);
      });
    }
  }

  // Emit expression with ternary operator: (b ? x : y)
  void emitTernaryExpr(int depth, DartType tp, {RhsFilter rhsFilter}) =>
      emitParenWrapped(() {
        emitExpr(depth + 1, DartType.BOOL, rhsFilter: rhsFilter);
        emit(' ? ');
        emitExpr(depth + 1, tp, rhsFilter: rhsFilter);
        emit(' : ');
        emitExpr(depth + 1, tp, rhsFilter: rhsFilter);
      });

  // Emit expression with pre/post-increment/decrement operator: (x++)
  void emitPreOrPostExpr(int depth, DartType tp, {RhsFilter rhsFilter}) {
    if (tp == DartType.INT) {
      emitParenWrapped(() {
        bool pre = coinFlip();
        if (pre) {
          emitPreOrPostOp(tp);
        }
        emitScalarVar(tp, isLhs: true);
        if (!pre) {
          emitPreOrPostOp(tp);
        }
      });
    } else {
      emitTerminal(depth, tp, rhsFilter: rhsFilter); // resort to terminal
    }
  }

  // Emit library call.
  void emitLibraryCall(int depth, DartType tp, {RhsFilter rhsFilter}) {
    DartLib lib = getLibraryMethod(tp);
    if (lib == null) {
      // no matching lib: resort to literal.
      emitLiteral(depth + 1, tp, rhsFilter: rhsFilter);
      return;
    }
    emitParenWrapped(() {
      String proto = lib.proto;
      // Receiver.
      if (proto[0] != 'V') {
        emitParenWrapped(
            () => emitArg(depth + 1, proto[0], rhsFilter: rhsFilter));
        emit('.');
      }
      // Call.
      emit('${lib.name}');
      // Parameters.
      if (proto[1] != 'v') {
        emitParenWrapped(() {
          if (proto[1] != 'V') {
            emitCommaSeparated(
                (int i) => emitArg(depth + 1, proto[i], rhsFilter: rhsFilter),
                proto.length,
                start: 1);
          }
        });
      }
      // Add cast to avoid error of double or int being interpreted as num.
      if (dartType.isInterfaceOfType(tp, DartType.NUM)) {
        emit(' as ${tp.name}');
      }
    });
  }

  // Emit call to a specific method.
  void emitCall(int depth, String name, List<DartType> proto,
      {RhsFilter rhsFilter, bool includeSemicolon = false}) {
    emitLn(name, newline: false);
    emitExprList(depth + 1, proto, rhsFilter: rhsFilter);
    if (includeSemicolon) {
      emit(';');
    }
  }

  // Helper for a method call.
  bool pickedCall(
      int depth, DartType tp, String name, List<List<DartType>> protos, int m,
      {RhsFilter rhsFilter}) {
    for (int i = m - 1; i >= 0; i--) {
      if (tp == protos[i][0]) {
        emitCall(depth + 1, "$name$i", protos[i], rhsFilter: rhsFilter);
        return true;
      }
    }
    return false;
  }

  // Emit method call within the program.
  void emitMethodCall(int depth, DartType tp, {RhsFilter rhsFilter}) {
    // Only call backward to avoid infinite recursion.
    if (currentClass == null) {
      // Outside a class but inside a method: call backward in global methods.
      if (currentMethod != null &&
          pickedCall(depth, tp, methodName, globalMethods, currentMethod,
              rhsFilter: rhsFilter)) {
        return;
      }
    } else {
      int classIndex = currentClass;
      // Chase randomly up in class hierarchy.
      while (classParents[classIndex] > 0) {
        if (coinFlip()) {
          break;
        }
        classIndex = classParents[classIndex];
      }
      int m1 = 0;
      // Inside a class: try to call backwards into current or parent class
      // methods first.
      if (currentMethod == null || classIndex != currentClass) {
        // If currently emitting the 'run' method or calling into a parent class
        // pick any of the current or parent class methods respectively.
        m1 = classMethods[classIndex].length;
      } else {
        // If calling into the current class from any method other than 'run'
        // pick one of the already emitted methods
        // (to avoid infinite recursions).
        m1 = currentMethod;
      }
      final int m2 = globalMethods.length;
      if (pickedCall(depth, tp, '$methodName${classIndex}_',
              classMethods[classIndex], m1, rhsFilter: rhsFilter) ||
          pickedCall(depth, tp, methodName, globalMethods, m2,
              rhsFilter: rhsFilter)) {
        return;
      }
    }
    emitTerminal(depth, tp, rhsFilter: rhsFilter); // resort to terminal.
  }

  // Emit expression.
  void emitExpr(int depth, DartType tp,
      {RhsFilter rhsFilter, bool includeSemicolon = false}) {
    final resetExprStmt = processExprOpen(tp);
    // Continuing nested expressions becomes less likely as the depth grows.
    if (choose(depth + 1) > exprDepth) {
      emitTerminal(depth, tp, rhsFilter: rhsFilter);
    } else {
      // Possibly nested expression.
      switch (choose(7)) {
        case 0:
          emitUnaryExpr(depth, tp, rhsFilter: rhsFilter);
          break;
        case 1:
          emitBinaryExpr(depth, tp, rhsFilter: rhsFilter);
          break;
        case 2:
          emitTernaryExpr(depth, tp, rhsFilter: rhsFilter);
          break;
        case 3:
          emitPreOrPostExpr(depth, tp, rhsFilter: rhsFilter);
          break;
        case 4:
          emitLibraryCall(depth, tp,
              rhsFilter: RhsFilter.cloneEmpty(rhsFilter));
          break;
        case 5:
          emitMethodCall(depth, tp, rhsFilter: RhsFilter.cloneEmpty(rhsFilter));
          break;
        default:
          emitTerminal(depth, tp, rhsFilter: rhsFilter);
          break;
      }
    }
    processExprClose(resetExprStmt);
    if (includeSemicolon) {
      emit(';');
    }
  }

  //
  // Operators.
  //

  // Emit same type in-out increment operator.
  void emitPreOrPostOp(DartType tp) {
    assert(tp == DartType.INT);
    emit(oneOf(const <String>['++', '--']));
  }

  // Emit one type in, boolean out operator.
  void emitRelOp(DartType tp) {
    if (tp == DartType.INT || tp == DartType.DOUBLE) {
      emit(oneOf(const <String>[' > ', ' >= ', ' < ', ' <= ', ' != ', ' == ']));
    } else {
      emit(oneOf(const <String>[' != ', ' == ']));
    }
  }

  //
  // Library methods.
  //

  // Get a library method that returns given type.
  DartLib getLibraryMethod(DartType tp) {
    if (tp == DartType.BOOL) {
      return oneOf(api.boolLibs);
    } else if (tp == DartType.INT) {
      return oneOf(api.intLibs);
    } else if (tp == DartType.DOUBLE) {
      return oneOf(api.doubleLibs);
    } else if (tp == DartType.STRING) {
      return oneOf(DartLib.stringLibs);
    } else if (tp == DartType.LIST_INT) {
      return oneOf(DartLib.listLibs);
    } else if (tp == DartType.SET_INT) {
      return oneOf(DartLib.setLibs);
    } else if (tp == DartType.MAP_INT_STRING) {
      return oneOf(DartLib.mapLibs);
    }
    // No library method available that returns this type.
    return null;
  }

  // Emit a library argument, possibly subject to restrictions.
  void emitArg(int depth, String p, {RhsFilter rhsFilter}) {
    switch (p) {
      case 'B':
        emitExpr(depth, DartType.BOOL);
        break;
      case 'i': // emit small int
        emitSmallPositiveInt();
        break;
      case 'I':
        emitExpr(depth, DartType.INT);
        break;
      case 'D':
        emitExpr(depth, fp ? DartType.DOUBLE : DartType.INT);
        break;
      case 'S':
        emitExpr(depth, DartType.STRING, rhsFilter: rhsFilter);
        break;
      case 's': // emit small string
        emitString(length: 2);
        break;
      case 'L':
        emitExpr(depth, DartType.LIST_INT, rhsFilter: rhsFilter);
        break;
      case 'X':
        emitExpr(depth, DartType.SET_INT, rhsFilter: rhsFilter);
        break;
      case 'M':
        emitExpr(depth, DartType.MAP_INT_STRING, rhsFilter: rhsFilter);
        break;
      default:
        throw ArgumentError('Invalid p value: $p');
    }
  }

  //
  // Types.
  //

  List<DartType> fillTypes1({int limit = 4, bool isFfi = false}) {
    final list = <DartType>[];
    for (int i = 0, n = chooseOneUpTo(limit); i < n; i++) {
      if (isFfi) {
        list.add(fp ? oneOf([DartType.INT, DartType.DOUBLE]) : DartType.INT);
      } else {
        list.add(oneOfSet(dartType.allTypes));
      }
    }
    return list;
  }

  List<List<DartType>> fillTypes2(
      {bool isFfi = false, int limit2 = 4, int limit1 = 4}) {
    final list = <List<DartType>>[];
    for (int i = 0, n = chooseOneUpTo(limit2); i < n; i++) {
      list.add(fillTypes1(limit: limit1, isFfi: isFfi));
    }
    return list;
  }

  List<List<List<DartType>>> fillTypes3(int n,
      {int limit2 = 4, int limit1 = 4}) {
    final list = <List<List<DartType>>>[];
    for (int i = 0; i < n; i++) {
      list.add(fillTypes2(limit2: limit2, limit1: limit1));
    }
    return list;
  }

  List<DartType> getCurrentProto() {
    if (currentClass != null) {
      if (currentMethod != null) {
        return classMethods[currentClass][currentMethod];
      }
    } else if (currentMethod != null) {
      return globalMethods[currentMethod];
    }
    return null;
  }

  List<DartType> getCurrentFields() {
    if (currentClass != null) {
      return classFields[currentClass];
    }
    return null;
  }

  void emitFfiType(DartType tp) {
    if (tp == DartType.INT) {
      emit(oneOf(
          const <String>['ffi.Int8', 'ffi.Int16', 'ffi.Int32', 'ffi.Int64']));
    } else if (tp == DartType.DOUBLE) {
      emit(oneOf(const <String>['ffi.Float', 'ffi.Double']));
    } else {
      throw 'Invalid FFI type ${tp.name}';
    }
  }

  void emitFfiTypedef(String typeName, List<DartType> pars) {
    emit("typedef ${typeName} = ");
    emitFfiType(pars[0]);
    emit(' Function');
    emitParenWrapped(
        () => emitCommaSeparated((int i) => emitFfiType(pars[i]), pars.length,
            start: 1),
        includeSemicolon: true);
    emitNewline();
    emitNewline();
  }

  //
  // Output.
  //

  // Emits a newline to the program.
  void emitNewline() => emit('', newline: true);

  // Emits indentation based on the current indentation count.
  void emitIndentation() => file.writeStringSync(' ' * indent);

  // Emits indented line to append to program.
  void emitLn(String line, {bool newline = true}) {
    emitIndentation();
    emit(line, newline: newline);
  }

  // Emits text to append to program.
  void emit(String txt, {bool newline = false}) {
    if (skipStmt || skipExpr) {
      return;
    }
    file.writeStringSync(txt);
    if (newline) {
      file.writeStringSync('\n');
    }
  }

  // Special return code to handle oom errors.
  static const oomExitCode = 254;

  // Random seed used to generate program.
  final int seed;

  // Enables floating-point operations.
  final bool fp;

  // Enables FFI method calls.
  final bool ffi;

  // Disables nested types.
  final bool flatTp;

  // File used for output.
  final RandomAccessFile file;

  // Library and ffi api.
  DartApi api;

  // Program variables.
  Random rand;
  int indent;
  int nest;
  int currentClass;
  int currentMethod;

  // DartType instance.
  DartType dartType;

  // Types of local variables currently in scope.
  List<DartType> localVars;

  // Types of global variables.
  List<DartType> globalVars;

  // Names of currently active iterator variables.
  // These are tracked to avoid modifications within the loop body,
  // which can lead to infinite loops.
  List<String> iterVars;

  // Prototypes of all global methods (first element is return type).
  List<List<DartType>> globalMethods;

  // Types of fields over all classes.
  List<List<DartType>> classFields;

  // Prototypes of all methods over all classes (first element is return type).
  List<List<List<DartType>>> classMethods;

  // List of virtual functions per class. Map is from parent class index to List
  // of overloaded functions from that parent.
  List<Map<int, List<int>>> virtualClassMethods;

  // Parent class indices for all classes.
  List<int> classParents;

  // Minimization mode extensions.
  final bool minimize;
  BigInt smask;
  BigInt emask;
  bool skipStmt;
  bool skipExpr;
  bool skipExprCntr;
  int stmtCntr;
  int exprCntr;

  // Interesting characters.
  static const List<String> interestingChars = [
    '\\u2665',
    '\\u{1f600}', // rune
  ];

  // Regular characters.
  static const regularChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#&()+- ';

  // Interesting integer values.
  static const List<int> interestingIntegers = [
    0x0000000000000000,
    0x0000000000000001,
    0x000000007fffffff,
    0x0000000080000000,
    0x0000000080000001,
    0x00000000ffffffff,
    0x0000000100000000,
    0x0000000100000001,
    0x000000017fffffff,
    0x0000000180000000,
    0x0000000180000001,
    0x00000001ffffffff,
    0x7fffffff00000000,
    0x7fffffff00000001,
    0x7fffffff7fffffff,
    0x7fffffff80000000,
    0x7fffffff80000001,
    0x7fffffffffffffff,
    0x8000000000000000,
    0x8000000000000001,
    0x800000007fffffff,
    0x8000000080000000,
    0x8000000080000001,
    0x80000000ffffffff,
    0x8000000100000000,
    0x8000000100000001,
    0x800000017fffffff,
    0x8000000180000000,
    0x8000000180000001,
    0x80000001ffffffff,
    0xffffffff00000000,
    0xffffffff00000001,
    0xffffffff7fffffff,
    0xffffffff80000000,
    0xffffffff80000001,
    0xffffffffffffffff
  ];
}

// Generate seed. By default (no user-defined nonzero seed given),
// pick the system's best way of seeding randomness and then pick
// a user-visible nonzero seed.
int getSeed(String userSeed) {
  int seed = int.parse(userSeed);
  if (seed == 0) {
    final rand = Random();
    while (seed == 0) {
      seed = rand.nextInt(1 << 32);
    }
  }
  return seed;
}

/// Main driver when dartfuzz.dart is run stand-alone.
main(List<String> arguments) {
  const kSeed = 'seed';
  const kFp = 'fp';
  const kFfi = 'ffi';
  const kFlat = 'flat';
  const kMini = 'mini';
  const kSMask = 'smask';
  const kEMask = 'emask';
  final parser = ArgParser()
    ..addOption(kSeed,
        help: 'random seed (0 forces time-based seed)', defaultsTo: '0')
    ..addFlag(kFp, help: 'enables floating-point operations', defaultsTo: true)
    ..addFlag(kFfi,
        help: 'enables FFI method calls (default: off)', defaultsTo: false)
    ..addFlag(kFlat,
        help: 'enables flat types (default: off)', defaultsTo: false)
    // Minimization mode extensions.
    ..addFlag(kMini,
        help: 'enables minimization mode (default: off)', defaultsTo: false)
    ..addOption(kSMask,
        help: 'Bitmask indicating which statements to omit'
            '(Bit=1 omits)',
        defaultsTo: '0')
    ..addOption(kEMask,
        help: 'Bitmask indicating which expressions to omit'
            '(Bit=1 omits)',
        defaultsTo: '0');
  try {
    final results = parser.parse(arguments);
    final seed = getSeed(results[kSeed]);
    final fp = results[kFp];
    final ffi = results[kFfi];
    final flatTp = results[kFlat];
    final file = File(results.rest.single).openSync(mode: FileMode.write);
    final minimize = results[kMini];
    final smask = BigInt.parse(results[kSMask]);
    final emask = BigInt.parse(results[kEMask]);
    final dartFuzz = DartFuzz(seed, fp, ffi, flatTp, file,
        minimize: minimize, smask: smask, emask: emask);
    dartFuzz.run();
    file.closeSync();
    // Print information that will be parsed by minimize.py
    if (minimize) {
      // Updated statement mask.
      // This might be different from the input parameter --smask
      // since masking a statement that contains nested statements leads to
      // those being masked as well.
      print(dartFuzz.smask.toRadixString(10));
      // Total number of statements in the generated program.
      print(dartFuzz.stmtCntr);
      // Updated expression mask.
      // This might be different from the input parameter --emask
      // since masking a statement that contains expressions or
      // an expression that contains nested expressions leads to
      // those being masked as well.
      print(dartFuzz.emask.toRadixString(10));
      // Total number of expressions in the generated program.
      print(dartFuzz.exprCntr);
    }
  } catch (e) {
    print('Usage: dart dartfuzz.dart [OPTIONS] FILENAME\n${parser.usage}\n$e');
    exitCode = 255;
  }
}
