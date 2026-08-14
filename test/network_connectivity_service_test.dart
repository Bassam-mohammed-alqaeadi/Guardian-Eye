import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/core/platform/network_connectivity_service.dart';

void main() {
  test('onlineChanges emits the snapshot then only genuine transitions',
      () async {
    final service = NetworkConnectivityService(
      checkConnectivity: () async => [ConnectivityResult.none],
      connectivityStream: Stream.fromIterable([
        [ConnectivityResult.none],
        [ConnectivityResult.wifi],
        [ConnectivityResult.wifi], // duplicate online — suppressed
        [ConnectivityResult.mobile],
        [ConnectivityResult.none],
        [ConnectivityResult.wifi],
      ]),
    );

    final events = await service.onlineChanges.toList();
    // Initial offline, one offline→online, one online→offline, one back.
    expect(events, [false, true, false, true]);
  });

  test('isOnline is fail-closed when the platform is unavailable', () async {
    final service = NetworkConnectivityService(
      checkConnectivity: () async => throw StateError('no_platform'),
    );
    expect(await service.isOnline(), isFalse);
  });

  test('isOnline reports any non-none result as online', () async {
    final service = NetworkConnectivityService(
      checkConnectivity: () async => [ConnectivityResult.vpn],
    );
    expect(await service.isOnline(), isTrue);
  });

  test('onlineChanges survives a broken platform stream', () async {
    final service = NetworkConnectivityService(
      checkConnectivity: () async => [ConnectivityResult.none],
      connectivityStream: Stream<List<ConnectivityResult>>.error(
          StateError('channel_unavailable')),
    );

    final events = await service.onlineChanges.toList();
    expect(events, [false]);
  });
}
