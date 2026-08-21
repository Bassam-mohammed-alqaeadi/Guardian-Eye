/// FS-016 — what's-new card primitive.
///
/// Builds on [GuardianHeroCard] for the version identity and [GuardianCard]
/// for the body, so the what's-new surface stays on the same 16-radius
/// Material 3 language as the rest of the platform.
library;

import 'package:flutter/material.dart';

import '../../core/theme/guardian_tokens.dart';
import 'guardian_primitives.dart';

/// One released version: identity on a navy hero tile, real change notes,
/// and a single honest dismissal action that writes to `app_identity`.
class WhatsNewVersionCard extends StatelessWidget {
  const WhatsNewVersionCard({
    super.key,
    required this.version,
    required this.title,
    required this.detail,
    required this.onDismiss,
  });

  final String version;
  final String title;
  final String detail;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GuardianHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome_outlined,
                size: 18, color: GuardianTokens.guardianTealLight),
            const SizedBox(width: 8),
            Text('v$version',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontFamily: GuardianTokens.fontFamily)),
            const Spacer(),
            Semantics(
              button: true,
              label: 'Dismissed in a moment',
              child: TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.85)),
                child: const Text('✕', style: TextStyle(fontSize: 13)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: GuardianTokens.fontFamily)),
          const SizedBox(height: 6),
          Text(detail,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontFamily: GuardianTokens.fontFamily)),
        ],
      ),
    );
  }
}
