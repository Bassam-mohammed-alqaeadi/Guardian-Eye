import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/remote_provisioning_service.dart';

/// Scripted in-memory Dio adapter so the service is tested without a network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map _bodyOf(Object? data) =>
    data is String ? jsonDecode(data) as Map : (data as Map);

Dio _dio(HttpClientAdapter adapter) => Dio(BaseOptions(baseUrl: 'https://backend.test'))
  ..httpClientAdapter = adapter;

RemoteProvisioningService _service(
  _FakeAdapter adapter, {
  bool available = true,
}) =>
    RemoteProvisioningService(
      client: _dio(adapter),
      idToken: () async => 'firebase-id-token-1',
      available: available,
      baseUrl: 'https://backend.test',
    );

void main() {
  group('RemoteProvisioningService (Guardian Backend)', () {
    test('issue sends the Firebase ID token and parses the provisioning code',
        () async {
      final adapter = _FakeAdapter((options) async {
        expect(options.uri.path, '/api/provision-child');
        expect(options.headers['Authorization'], 'Bearer firebase-id-token-1');
        final body = _bodyOf(options.data);
        expect(body['familyId'], 'fam-1');
        expect(body['targetMemberId'], 'child-local-1');
        expect(body['displayName'], 'KidA');
        return _json(201, {
          'pairingId': 'pair-1',
          'provisioningCode': '123456',
          'expiresAt': '2026-08-16T12:00:00.000Z',
        });
      });
      final service = _service(adapter);

      final issue = await service.issue(
        familyId: 'fam-1',
        targetMemberId: 'child-local-1',
        displayName: 'KidA',
      );

      expect(issue.pairingId, 'pair-1');
      expect(issue.code, '123456');
      expect(issue.expiresAt.isUtc, isTrue);
      expect(adapter.requests.single.headers['Authorization'],
          'Bearer firebase-id-token-1');
    });

    test('issue is unavailable when Firebase is not configured', () async {
      final adapter = _FakeAdapter((_) async => _json(500, {'error': 'x'}));
      final service = _service(adapter, available: false);

      expect(
        () => service.issue(
            familyId: 'f', targetMemberId: 'c', displayName: 'K'),
        throwsA(isA<RemoteProvisioningUnavailableException>()),
      );
      expect(adapter.requests, isEmpty);
    });

    test('issue maps server rejection to an honest exception', () async {
      final adapter = _FakeAdapter(
          (_) async => _json(403, {'error': 'parent_not_authorized'}));
      final service = _service(adapter);

      expect(
        () => service.issue(
            familyId: 'f', targetMemberId: 'c', displayName: 'K'),
        throwsA(isA<RemoteProvisioningException>()
            .having((e) => e.reason, 'reason', 'parent_not_authorized')),
      );
    });

    test('issue maps network failure to server_unreachable', () async {
      final adapter = _FakeAdapter((_) async {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/provision-child'),
          reason: 'offline',
        );
      });
      final service = _service(adapter);

      expect(
        () => service.issue(
            familyId: 'f', targetMemberId: 'c', displayName: 'K'),
        throwsA(isA<RemoteProvisioningException>()
            .having((e) => e.reason, 'reason', 'server_unreachable')),
      );
    });

    test('redeem sends the token and reports enrolled on success', () async {
      final adapter = _FakeAdapter((options) async {
        expect(options.uri.path, '/api/redeem-child');
        expect(options.headers['Authorization'], 'Bearer firebase-id-token-1');
        final body = _bodyOf(options.data);
        expect(body['provisioningCode'], '123456');
        expect(body['deviceId'], 'device-1');
        expect(body['pairingId'], 'pair-1');
        return _json(200, {
          'success': true,
          'state': 'enrolled',
          'childUid': 'child-uid-1',
          'deviceId': 'device-1',
          'targetMemberId': 'child-local-1',
        });
      });
      final service = _service(adapter);

      final result = await service.redeem(
        familyId: 'fam-1',
        pairingId: 'pair-1',
        code: '123456',
        deviceId: 'device-1',
      );

      expect(result.succeeded, isTrue);
      expect(result.state, RemoteRedeemState.enrolled);
      expect(result.deviceId, 'device-1');
      expect(result.targetMemberId, 'child-local-1');
    });

    test('redeem maps every backend error honestly', () async {
      Future<RemoteRedeemState> redeemReturning(int status, String code) async {
        final adapter = _FakeAdapter(
            (_) async => _json(status, {'error': code, 'message': code}));
        final service = _service(adapter);
        final result = await service.redeem(
          familyId: 'fam-1',
          pairingId: 'pair-1',
          code: '123456',
          deviceId: 'device-1',
        );
        return result.state;
      }

      expect(await redeemReturning(400, 'invalid_code'),
          RemoteRedeemState.invalidCode);
      expect(await redeemReturning(410, 'expired'), RemoteRedeemState.expired);
      expect(await redeemReturning(403, 'locked'), RemoteRedeemState.locked);
      expect(await redeemReturning(409, 'already_used'),
          RemoteRedeemState.alreadyUsed);
      expect(await redeemReturning(409, 'device_conflict'),
          RemoteRedeemState.deviceConflict);
      expect(await redeemReturning(409, 'member_conflict'),
          RemoteRedeemState.memberConflict);
      expect(await redeemReturning(401, 'unauthenticated'),
          RemoteRedeemState.unauthenticated);
      expect(await redeemReturning(403, 'parent_not_authorized'),
          RemoteRedeemState.unauthorized);
      expect(await redeemReturning(500, 'server_error'),
          RemoteRedeemState.unknown);
    });

    test('redeem reports networkUnavailable on connection failure', () async {
      final adapter = _FakeAdapter((_) async {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/redeem-child'),
          reason: 'offline',
        );
      });
      final service = _service(adapter);

      final result = await service.redeem(
        familyId: 'fam-1',
        pairingId: 'pair-1',
        code: '123456',
        deviceId: 'device-1',
      );

      expect(result.state, RemoteRedeemState.networkUnavailable);
      expect(result.succeeded, isFalse);
    });
  });
}
