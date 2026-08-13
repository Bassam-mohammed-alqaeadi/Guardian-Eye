import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/sync_services.dart';

void main() {
  test(
      'outbox delay increases deterministically and stops after the configured attempt limit',
      () {
    const policy =
        OutboxRetryPolicy(maxAttempts: 3, baseDelay: Duration(seconds: 10));
    expect(policy.delayForAttempt(0), const Duration(seconds: 10));
    expect(policy.delayForAttempt(2), const Duration(seconds: 40));
    expect(policy.canRetry(2), isTrue);
    expect(policy.canRetry(3), isFalse);
  });

  test('outbox retry time is UTC and can be derived after process recovery',
      () {
    const policy = OutboxRetryPolicy(baseDelay: Duration(minutes: 1));
    final now = DateTime.utc(2026, 8, 12, 12);
    expect(policy.nextAttemptAt(now, 1), DateTime.utc(2026, 8, 12, 12, 2));
  });
}
