class OutboxRetryPolicy {
  const OutboxRetryPolicy(
      {this.maxAttempts = 8, this.baseDelay = const Duration(seconds: 30)});
  final int maxAttempts;
  final Duration baseDelay;

  bool canRetry(int attemptCount) => attemptCount < maxAttempts;
  Duration delayForAttempt(int attemptCount) {
    final exponent = attemptCount.clamp(0, 8);
    return Duration(seconds: baseDelay.inSeconds * (1 << exponent));
  }

  DateTime nextAttemptAt(DateTime now, int attemptCount) =>
      now.toUtc().add(delayForAttempt(attemptCount));
}
