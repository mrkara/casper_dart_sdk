import 'dart:convert';
import 'dart:io';

import 'package:casper_dart_sdk/src/http/http_server_proxy.dart';
import 'package:test/test.dart';

void main() {
  test('spaces concurrent RPC requests by the configured minimum interval',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'result': {'ok': true},
      }));
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final proxy = JsonRpcHttpServerProxy(
      Uri.parse('http://${server.address.address}:${server.port}/rpc'),
      const <String, String>{},
      const Duration(milliseconds: 200),
    );

    final elapsed = Stopwatch()..start();
    await Future.wait([
      proxy.callRaw('test.first'),
      proxy.callRaw('test.second'),
    ]);

    expect(
      elapsed.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 200)),
    );
  });
}
