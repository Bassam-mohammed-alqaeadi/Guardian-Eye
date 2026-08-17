import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/notification_contract.dart';

void main() {
  test('RenderNotificationGateway posts /api/notify with the ID token and '
      'reports the backend response', () async {
    Map<String, dynamic>? capturedData;
    Map<String, dynamic>? capturedHeaders;
    final dio = Dio();
    final adapter = dio.httpClientAdapter = _FakeAdapter((options) {
      capturedData = options.data as Map<String, dynamic>?;
      capturedHeaders = options.headers;
      return Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {'sent': 1, 'failed': 0, 'invalidTokensRemoved': 0},
      );
    });
    expect(adapter, isNotNull);

    final gateway = RenderNotificationGateway(
      client: dio,
      idToken: _token,
      baseUrl: 'https://backend.test',
      available: true,
    );

    final result = await gateway.requestServerDispatch(const NotificationDispatchRequest(
      familyId: 'family-a',
      kind: 'sos',
      sosId: 'sos-1',
      title: 'SOS alert',
      body: 'Child needs help',
    ));

    expect(result.accepted, isTrue);
    expect(result.reason, 'sent:1 failed:0 invalidRemoved:0');
    expect(capturedData?['familyId'], 'family-a');
    expect(capturedData?['kind'], 'sos');
    expect(capturedData?['sosId'], 'sos-1');
    expect(capturedData?['incidentId'], isNull);
    expect(capturedData?['title'], 'SOS alert');
    expect(capturedHeaders?['Authorization'], 'Bearer test-id-token');
  });

  test('RenderNotificationGateway reports no_tokens honestly without claiming '
      'delivery', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((options) => Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {'sent': 0, 'failed': 0, 'invalidTokensRemoved': 0, 'reason': 'no_tokens'},
        ));
    final gateway = RenderNotificationGateway(
      client: dio,
      idToken: _token,
      baseUrl: 'https://backend.test',
      available: true,
    );
    final result = await gateway.requestServerDispatch(const NotificationDispatchRequest(
      familyId: 'family-a',
      kind: 'incident',
      incidentId: 'inc-1',
      title: 'Alert',
      body: 'Incident',
    ));
    expect(result.accepted, isTrue); // backend accepted the request; no tokens yet
    expect(result.reason, 'sent:0 failed:0 invalidRemoved:0');
  });

  test('RenderNotificationGateway maps non-member rejection honestly', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((options) =>
        throw DioException(
            requestOptions: options,
            response: Response<dynamic>(
                requestOptions: options,
                statusCode: 403,
                data: {'error': 'not_a_member', 'message': 'Caller is not an active member'})));
    final gateway = RenderNotificationGateway(
      client: dio,
      idToken: _token,
      baseUrl: 'https://backend.test',
      available: true,
    );
    final result = await gateway.requestServerDispatch(const NotificationDispatchRequest(
      familyId: 'family-a',
      kind: 'sos',
      title: 'SOS',
      body: 'Help',
    ));
    expect(result.accepted, isFalse);
    expect(result.reason, 'not_a_member');
  });

  test('RenderNotificationGateway is a clean no-op when unavailable', () async {
    const gateway = RenderNotificationGateway(
      available: false,
      baseUrl: 'https://backend.test',
    );
    final result = await gateway.requestServerDispatch(const NotificationDispatchRequest(
      familyId: 'family-a',
      kind: 'sos',
      title: 'SOS',
      body: 'Help',
    ));
    expect(result.accepted, isFalse);
    expect(result.reason, 'firebase_or_auth_unavailable');
  });

  test('GuardedFcmNotificationGateway never claims delivery', () async {
    const gateway = GuardedFcmNotificationGateway();
    final result = await gateway.requestServerDispatch(const NotificationDispatchRequest(
      familyId: 'family-a',
      kind: 'sos',
      title: 'SOS',
      body: 'Help',
    ));
    expect(result.accepted, isFalse);
    expect(result.reason, 'firebase_or_auth_unavailable');
  });
}

Future<String> _token() async => 'test-id-token';

typedef _Handler =
    Response<dynamic> Function(RequestOptions options);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);
  final _Handler _handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final response = _handler(options);
    return ResponseBody.fromString(
        response.data == null ? '{}' : jsonEncode(response.data),
        response.statusCode ?? 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}
