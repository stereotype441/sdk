// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/protocol/protocol.dart';
import 'package:analysis_server/protocol/protocol_constants.dart';
import 'package:analysis_server/protocol/protocol_generated.dart';
import 'package:analysis_server/src/analysis_server.dart';
import 'package:analysis_server/src/utilities/mocks.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/instrumentation/instrumentation.dart';
import 'package:analyzer/src/dart/sdk/sdk.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MigrationTest);
  });
}

class MigrationBase {
  ResourceProvider resourceProvider = PhysicalResourceProvider.INSTANCE;
  MockServerChannel serverChannel;
  AnalysisServer server;

  AnalysisServer createAnalysisServer() {
    //
    // Create server
    //
    AnalysisServerOptions options = new AnalysisServerOptions();
    String sdkPath = FolderBasedDartSdk.defaultSdkDirectory(
      PhysicalResourceProvider.INSTANCE,
    ).path;
    return new AnalysisServer(serverChannel, resourceProvider, options,
        new DartSdkManager(sdkPath, true), InstrumentationService.NULL_SERVICE);
  }

  void processNotification(Notification notification) {
    if (notification.event == SERVER_NOTIFICATION_ERROR) {
      fail('${notification.toJson()}');
    }
  }

  Future<Response> sendAnalysisSetAnalysisRoots(List<String> directories) {
    var request =
        AnalysisSetAnalysisRootsParams(directories, []).toRequest('0');
    return waitResponse(request);
  }

  Future<Response> sendEditDartfix(List<String> directories, String outputDir) {
    var request = EditDartfixParams(directories,
            includedFixes: ['non-nullable'], outputDir: outputDir, port: 10501)
        .toRequest('1');
    return waitResponse(request);
  }

  void setUp() {
    serverChannel = new MockServerChannel();
    server = createAnalysisServer();
    server.pluginManager = new TestPluginManager();
    // listen for notifications
    Stream<Notification> notificationStream =
        serverChannel.notificationController.stream;
    notificationStream.listen((Notification notification) {
      processNotification(notification);
    });
  }

  void tearDown() {
    server.done();
    server = null;
    serverChannel = null;
  }

  /// Returns a [Future] that completes when the server's analysis is complete.
  Future waitForTasksFinished() {
    return server.onAnalysisComplete;
  }

  /// Completes with a successful [Response] for the given [request].
  Future<Response> waitResponse(Request request,
      {bool throwOnError = true}) async {
    return serverChannel.sendRequest(request, throwOnError: throwOnError);
  }
}

@reflectiveTest
class MigrationTest extends MigrationBase {
//  @soloTest
  test_charcode() async {
    List<String> packageRoots = [
      '/Users/brianwilkerson/src/dart/sdk/sdk/third_party/pkg/charcode'
    ];
    String outputDir = '/Users/brianwilkerson/temp/migration/charcode';
    await sendAnalysisSetAnalysisRoots(packageRoots);
    await sendEditDartfix(packageRoots, outputDir);
  }

//  @soloTest
  test_collection() async {
    List<String> packageRoots = [
      '/Users/brianwilkerson/src/dart/sdk/sdk/third_party/pkg/collection'
    ];
    String outputDir = '/Users/brianwilkerson/temp/migration/collection';
    await sendAnalysisSetAnalysisRoots(packageRoots);
    await sendEditDartfix(packageRoots, outputDir);
  }

//  @soloTest
  test_logging() async {
    List<String> packageRoots = [
      '/Users/brianwilkerson/src/dart/sdk/sdk/third_party/pkg/logging'
    ];
    String outputDir = '/Users/brianwilkerson/temp/migration/logging';
    await sendAnalysisSetAnalysisRoots(packageRoots);
    await sendEditDartfix(packageRoots, outputDir);
  }

  @soloTest
  test_logging_sample() async {
    List<String> packageRoots = [
      '/usr/local/google/home/paulberry/logging-sample'
    ];
    String outputDir =
        '/usr/local/google/home/paulberry/tmp/nnbd_migration/logging-sample';
    await sendAnalysisSetAnalysisRoots(packageRoots);
    await sendEditDartfix(packageRoots, outputDir);
  }

//  @soloTest
  test_meta() async {
    List<String> packageRoots = [
      '/Users/brianwilkerson/src/dart/sdk/sdk/pkg/meta'
    ];
    String outputDir = '/Users/brianwilkerson/temp/migration/meta';
    await sendAnalysisSetAnalysisRoots(packageRoots);
    await sendEditDartfix(packageRoots, outputDir);
  }

//  @soloTest
  test_path() async {
    List<String> packageRoots = [
      '/Users/brianwilkerson/src/dart/sdk/sdk/third_party/pkg/path'
    ];
    String outputDir = '/Users/brianwilkerson/temp/migration/path';
    await sendAnalysisSetAnalysisRoots(packageRoots);
    await sendEditDartfix(packageRoots, outputDir);
  }

//  @soloTest
  test_pedantic() async {
    List<String> packageRoots = [
      '/Users/brianwilkerson/src/dart/sdk/sdk/third_party/pkg/pedantic'
    ];
    String outputDir = '/Users/brianwilkerson/temp/migration/pedantic';
    await sendAnalysisSetAnalysisRoots(packageRoots);
    await sendEditDartfix(packageRoots, outputDir);
  }

//  @soloTest
  test_term_glyph() async {
    List<String> packageRoots = ['/Users/brianwilkerson/src/dart/term_glyph'];
    String outputDir = '/Users/brianwilkerson/temp/migration/term_glyph';
    await sendAnalysisSetAnalysisRoots(packageRoots);
    await sendEditDartfix(packageRoots, outputDir);
  }

//  @soloTest
  test_typed_data() async {
    List<String> packageRoots = [
      '/Users/brianwilkerson/src/dart/sdk/sdk/pkg/typed_data'
    ];
    String outputDir = '/Users/brianwilkerson/temp/migration/typed_data';
    await sendAnalysisSetAnalysisRoots(packageRoots);
    await sendEditDartfix(packageRoots, outputDir);
  }

//  @soloTest
  test_vector_math_dart() async {
    // Times out.
    List<String> packageRoots = [
      '/Users/brianwilkerson/src/dart/vector_math.dart'
    ];
    String outputDir = '/Users/brianwilkerson/temp/migration/vector_math.dart';
    await sendAnalysisSetAnalysisRoots(packageRoots);
    await sendEditDartfix(packageRoots, outputDir);
  }
}
