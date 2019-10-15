// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:meta/meta.dart';

import 'package:compiler/src/dart2js.dart' as dart2js_main;

class SpawnLatencyAndMemory {
  SpawnLatencyAndMemory(this.name);

  Future<ResultMessageLatencyAndMemory> run() async {
    final completerResult = Completer();
    final receivePort = ReceivePort()..listen(completerResult.complete);
    final Completer<DateTime> isolateExitedCompleter = Completer<DateTime>();
    final onExitReceivePort = ReceivePort()
      ..listen((_) {
        isolateExitedCompleter.complete(DateTime.now());
      });
    final DateTime beforeSpawn = DateTime.now();
    await Isolate.spawn(
        isolateCompiler,
        StartMessageLatencyAndMemory(
            receivePort.sendPort, beforeSpawn, ProcessInfo.currentRss),
        onExit: onExitReceivePort.sendPort,
        onError: onExitReceivePort.sendPort);
    final DateTime afterSpawn = DateTime.now();

    final ResultMessageLatencyAndMemory result = await completerResult.future;
    receivePort.close();
    final DateTime isolateExited = await isolateExitedCompleter.future;
    result.timeToExitUs = isolateExited.difference(beforeSpawn).inMicroseconds;
    result.timeToIsolateSpawnUs =
        afterSpawn.difference(beforeSpawn).inMicroseconds;
    onExitReceivePort.close();

    return result;
  }

  Future<AggregatedResultMessageLatencyAndMemory> measureFor(
      int minimumMillis) async {
    final minimumMicros = minimumMillis * 1000;
    final watch = Stopwatch()..start();
    final Metric toAfterIsolateSpawnUs = LatencyMetric("${name}ToAfterSpawn");
    final Metric toStartRunningCodeUs = LatencyMetric("${name}ToStartRunning");
    final Metric toFinishRunningCodeUs =
        LatencyMetric("${name}ToFinishRunning");
    final Metric toExitUs = LatencyMetric("${name}ToExit");
    final Metric deltaRss = MemoryMetric("${name}Delta");
    while (watch.elapsedMicroseconds < minimumMicros) {
      final ResultMessageLatencyAndMemory result = await run();
      toAfterIsolateSpawnUs.add(result.timeToIsolateSpawnUs);
      toStartRunningCodeUs.add(result.timeToStartRunningCodeUs);
      toFinishRunningCodeUs.add(result.timeToFinishRunningCodeUs);
      toExitUs.add(result.timeToExitUs);
      deltaRss.add(result.deltaRss);
    }
    return AggregatedResultMessageLatencyAndMemory(toAfterIsolateSpawnUs,
        toStartRunningCodeUs, toFinishRunningCodeUs, toExitUs, deltaRss);
  }

  Future<AggregatedResultMessageLatencyAndMemory> measure() async {
    await measureFor(500); // warm-up
    return measureFor(4000); // actual measurement
  }

  Future<void> report() async {
    final AggregatedResultMessageLatencyAndMemory result = await measure();
    print(result);
  }

  final String name;
  RawReceivePort receivePort;
}

class Metric {
  Metric({@required this.prefix, @required this.suffix});

  void add(int value) {
    if (value > max) {
      max = value;
    }
    sum += value;
    sumOfSquares += value * value;
    count++;
  }

  double _average() => sum / count;
  double _rms() => sqrt(sumOfSquares / count);

  toString() => "$prefix): ${_average()}$suffix\n"
      "${prefix}Max): $max$suffix\n"
      "${prefix}RMS): ${_rms()}$suffix";

  final String prefix;
  final String suffix;
  int max = 0;
  double sum = 0;
  double sumOfSquares = 0;
  int count = 0;
}

class LatencyMetric extends Metric {
  LatencyMetric(String name) : super(prefix: "${name}(Latency", suffix: " us.");
}

class MemoryMetric extends Metric {
  MemoryMetric(String name) : super(prefix: "${name}Rss(MemoryUse", suffix: "");

  toString() => "$prefix): ${_average()}$suffix\n";
}

class StartMessageLatencyAndMemory {
  StartMessageLatencyAndMemory(this.sendPort, this.spawned, this.rss);

  final SendPort sendPort;
  final DateTime spawned;
  final int rss;
}

class ResultMessageLatencyAndMemory {
  ResultMessageLatencyAndMemory(
      {this.timeToStartRunningCodeUs,
      this.timeToFinishRunningCodeUs,
      this.deltaRss});

  final int timeToStartRunningCodeUs;
  final int timeToFinishRunningCodeUs;
  final int deltaRss;

  int timeToIsolateSpawnUs;
  int timeToExitUs;
}

class AggregatedResultMessageLatencyAndMemory {
  AggregatedResultMessageLatencyAndMemory(
    this.toAfterIsolateSpawnUs,
    this.toStartRunningCodeUs,
    this.toFinishRunningCodeUs,
    this.toExitUs,
    this.deltaRss,
  );

  String toString() => """$toAfterIsolateSpawnUs
$toStartRunningCodeUs
$toFinishRunningCodeUs
$toExitUs
$deltaRss""";

  final Metric toAfterIsolateSpawnUs;
  final Metric toStartRunningCodeUs;
  final Metric toFinishRunningCodeUs;
  final Metric toExitUs;
  final Metric deltaRss;
}

Future<void> isolateCompiler(StartMessageLatencyAndMemory start) async {
  final DateTime timeRunningCodeUs = DateTime.now();
  await runZoned(
      () => dart2js_main.internalMain(<String>[
            "benchmarks/IsolateSpawn/dart/helloworld.dart",
            '--libraries-spec=sdk/lib/libraries.json'
          ]),
      zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {}));
  final DateTime timeFinishRunningCodeUs = DateTime.now();
  start.sendPort.send(ResultMessageLatencyAndMemory(
      timeToStartRunningCodeUs:
          timeRunningCodeUs.difference(start.spawned).inMicroseconds,
      timeToFinishRunningCodeUs:
          timeFinishRunningCodeUs.difference(start.spawned).inMicroseconds,
      deltaRss: ProcessInfo.currentRss - start.rss));
}

Future<void> main() async {
  await SpawnLatencyAndMemory("IsolateSpawn.Dart2JS").report();
}
