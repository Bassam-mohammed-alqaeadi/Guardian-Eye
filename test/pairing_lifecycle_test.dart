import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

void main() {
  test('pairing code is hashed deterministically and raw code is not its hash',
      () {
    const code = '017203';
    expect(PairingRepository.hashPairingCode(code),
        PairingRepository.hashPairingCode(code));
    expect(PairingRepository.hashPairingCode(code), isNot(code));
  });

  test('pairing lifecycle permits enrollment only after a verified request',
      () {
    expect(
        PairingLifecycle.canTransition(
            PairingState.pending, PairingState.verified),
        isTrue);
    expect(
        PairingLifecycle.canTransition(
            PairingState.verified, PairingState.enrolled),
        isTrue);
    expect(
        PairingLifecycle.canTransition(
            PairingState.expired, PairingState.enrolled),
        isFalse);
    expect(
        PairingLifecycle.canTransition(
            PairingState.enrolled, PairingState.revoked),
        isTrue);
  });
}
