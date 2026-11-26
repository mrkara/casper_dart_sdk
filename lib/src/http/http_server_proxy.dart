import 'dart:async';
import 'dart:convert';

import 'package:jsonrpc2/jsonrpc2.dart';
import 'package:http/http.dart' as http;

///  Exceptions on the remote end will throw RpcException.
class JsonRpcHttpServerProxy extends ServerProxyBase {
  Map<String, String> additionalHeaders;
  final Duration minimumRequestInterval;
  final Stopwatch _requestClock = Stopwatch()..start();
  Future<void> _requestQueue = Future<void>.value();
  Duration? _lastRequestStartedAt;

  JsonRpcHttpServerProxy(url, [
    this.additionalHeaders = const <String, String>{},
    this.minimumRequestInterval = Duration.zero,
  ]) : super(url);

  Future<void> _waitForRequestSlot() async {
    if (minimumRequestInterval <= Duration.zero) {
      return;
    }

    final previousRequest = _requestQueue;
    final slot = Completer<void>();
    _requestQueue = slot.future;

    try {
      await previousRequest;
      final lastRequestStartedAt = _lastRequestStartedAt;
      if (lastRequestStartedAt != null) {
        final elapsed = _requestClock.elapsed - lastRequestStartedAt;
        final remaining = minimumRequestInterval - elapsed;
        if (remaining > Duration.zero) {
          await Future<void>.delayed(remaining);
        }
      }
      _lastRequestStartedAt = _requestClock.elapsed;
    } finally {
      slot.complete();
    }
  }

  /// Returns a Future with the JSON-RPC response
  @override
  Future<String> transmit(String package) async {
    await _waitForRequestSlot();
    var headers = {'Content-Type': 'application/json'};
    if (additionalHeaders.isNotEmpty) {
      headers.addAll(additionalHeaders);
    }

    var response = await http.post(resource, body: utf8.encode(package), headers: headers);
    final body = response.body;

    if (response.statusCode == 204 || body.isEmpty) {
      return '';
    } else {
      return body;
    }
  }

  /// Returns a Future with raw string response from the RPC server
  Future<String> callRaw(String method, [dynamic params]) async {
    var package = json.encode(JsonRpcMethod(method, params, serverVersion: "2.0"));

    var resp = await transmit(package);
    return resp;
  }
}

/// See the documentation in [BatchServerProxyBase]
class BatchJsonRpcHttpServerProxy extends BatchServerProxyBase {
  /// constructor
  BatchJsonRpcHttpServerProxy(String url, [additionalHeaders = const <String, String>{}]) {
    super.proxy = JsonRpcHttpServerProxy(url, additionalHeaders);
  }
}
