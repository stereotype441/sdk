// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analysis_server/protocol/protocol.dart';
import 'package:analysis_server/src/analysis_server.dart';
import 'package:analysis_server/src/channel/channel.dart';
import 'package:test/test.dart';

/**
 * A mock [ServerCommunicationChannel] for testing [AnalysisServer].
 */
class MockServerChannel implements ServerCommunicationChannel {
  StreamController<Request> requestController = new StreamController<Request>();
  StreamController<Response> responseController =
  new StreamController<Response>.broadcast();
  StreamController<Notification> notificationController =
  new StreamController<Notification>(sync: true);
  Completer<Response> errorCompleter;

  List<Response> responsesReceived = [];
  List<Notification> notificationsReceived = [];

  bool _closed = false;

  String name;

  MockServerChannel();

  @override
  void close() {
    _closed = true;
  }

  void expectMsgCount({responseCount = 0, notificationCount = 0}) {
    expect(responsesReceived, hasLength(responseCount));
    expect(notificationsReceived, hasLength(notificationCount));
  }

  @override
  void listen(void onRequest(Request request),
      {Function onError, void onDone()}) {
    requestController.stream
        .listen(onRequest, onError: onError, onDone: onDone);
  }

  @override
  void sendNotification(Notification notification) {
    // Don't deliver notifications after the connection is closed.
    if (_closed) {
      return;
    }
    notificationsReceived.add(notification);
    if (errorCompleter != null && notification.event == 'server.error') {
      print(
          '[server.error] test: $name message: ${notification.params['message']}');
      errorCompleter.completeError(
          new ServerError(notification.params['message']),
          new StackTrace.fromString(notification.params['stackTrace']));
    }
    // Wrap send notification in future to simulate websocket
    // TODO(scheglov) ask Dan why and decide what to do
//    new Future(() => notificationController.add(notification));
    notificationController.add(notification);
  }

  /**
   * Send the given [request] to the server and return a future that will
   * complete when a response associated with the [request] has been received.
   * The value of the future will be the received response. If [throwOnError] is
   * `true` (the default) then the returned future will throw an exception if a
   * server error is reported before the response has been received.
   */
  Future<Response> sendRequest(Request request, {bool throwOnError = true}) {
    // TODO(brianwilkerson) Attempt to remove the `throwOnError` parameter and
    // have the default behavior be the only behavior.
    // No further requests should be sent after the connection is closed.
    if (_closed) {
      throw new Exception('sendRequest after connection closed');
    }
    // Wrap send request in future to simulate WebSocket.
    new Future(() => requestController.add(request));
    return waitForResponse(request, throwOnError: throwOnError);
  }

  @override
  void sendResponse(Response response) {
    // Don't deliver responses after the connection is closed.
    if (_closed) {
      return;
    }
    responsesReceived.add(response);
    // Wrap send response in future to simulate WebSocket.
    new Future(() => responseController.add(response));
  }

  /**
   * Return a future that will complete when a response associated with the
   * given [request] has been received. The value of the future will be the
   * received response. If [throwOnError] is `true` (the default) then the
   * returned future will throw an exception if a server error is reported
   * before the response has been received.
   *
   * Unlike [sendRequest], this method assumes that the [request] has already
   * been sent to the server.
   */
  Future<Response> waitForResponse(Request request,
      {bool throwOnError = true}) {
    // TODO(brianwilkerson) Attempt to remove the `throwOnError` parameter and
    // have the default behavior be the only behavior.
    String id = request.id;
    Future<Response> response =
    responseController.stream.firstWhere((response) => response.id == id);
    if (throwOnError) {
      errorCompleter = new Completer<Response>();
      try {
        return Future.any([response, errorCompleter.future]);
      } finally {
        errorCompleter = null;
      }
    }
    return response;
  }
}

class ServerError implements Exception {
  final message;

  ServerError(this.message);

  String toString() {
    return "Server Error: $message";
  }
}
