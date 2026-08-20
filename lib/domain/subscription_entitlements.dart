/// ST-001 — Subscription & Entitlements.
///
/// Governance:
///
/// 1. Entitlements are the single source of truth for feature access.
///    UI reads [Entitlement.granted] — nothing is gated by hard-coded
///    plan checks.
/// 2. Usage meters enforce feature limits (e.g. max children) through
///    explicit counters. When [UsageMeter.isOverLimit] the honest state
///    is shown with the exact limit, never a silent block.
/// 3. Billing records are append-only. Refunds are separate rows with a
///    negative amount and `refund` kind.
///
/// This module is local-first (offline-capable entitlements). Cloud
/// purchase verification plugs into the same repository contract later
/// without touching the UI.
library subscription_entitlements;

enum SubscriptionTier { free, premium, familyPro }

/// Every feature the platform gates. New gates are added here and in
/// the provider table — never inline in widgets.
class EntitlementFeature {
  EntitlementFeature._();

  static const String aiInsights = 'ai.insights';
  static const String aiCopilot = 'ai.copilot';
  static const String aiPolicyProposals = 'ai.policy.proposals';
  static const String aiTransparency = 'ai.transparency';
  static const String coupleHarmony = 'couple.harmony';
  static const String reportsPdfExport = 'reports.pdf_export';
  static const String unlimitedChildren = 'children.unlimited';
  static const String backgroundTracking = 'tracking.background';
}

/// Plan caps used to derive meters. `maxChildren` of null means the plan
/// imposes no cap for that resource.
class SubscriptionPlanCaps {
  const SubscriptionPlanCaps({
    required this.tier,
    this.maxChildren,
    this.aiEnabled = false,
    this.coupleEnabled = false,
    this.pdfExportEnabled = false,
    this.backgroundTrackingEnabled = false,
  });

  final SubscriptionTier tier;
  final int? maxChildren;
  final bool aiEnabled;
  final bool coupleEnabled;
  final bool pdfExportEnabled;
  final bool backgroundTrackingEnabled;

  static const SubscriptionPlanCaps free = SubscriptionPlanCaps(
    tier: SubscriptionTier.free,
    maxChildren: 2,
    aiEnabled: false,
    coupleEnabled: false,
    pdfExportEnabled: false,
    backgroundTrackingEnabled: false,
  );

  static const SubscriptionPlanCaps premium = SubscriptionPlanCaps(
    tier: SubscriptionTier.premium,
    maxChildren: 5,
    aiEnabled: true,
    coupleEnabled: true,
    pdfExportEnabled: true,
    backgroundTrackingEnabled: false,
  );

  static const SubscriptionPlanCaps familyPro = SubscriptionPlanCaps(
    tier: SubscriptionTier.familyPro,
    maxChildren: null,
    aiEnabled: true,
    coupleEnabled: true,
    pdfExportEnabled: true,
    backgroundTrackingEnabled: true,
  );

  static SubscriptionPlanCaps forTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return free;
      case SubscriptionTier.premium:
        return premium;
      case SubscriptionTier.familyPro:
        return familyPro;
    }
  }
}

/// One feature grant for the family. A missing row means not granted;
/// `expiresAt` renders the honest "until X" state.
class Entitlement {
  const Entitlement({
    required this.familyId,
    required this.feature,
    required this.granted,
    required this.policyKey,
    this.grantedAt,
    this.expiresAt,
  });

  final String familyId;
  final String feature;
  final bool granted;
  final String policyKey;
  final DateTime? grantedAt;
  final DateTime? expiresAt;

  factory Entitlement.fromJson(Map<String, Object?> row) => Entitlement(
        familyId: row['family_id']! as String,
        feature: row['feature']! as String,
        granted: (row['granted'] as int) == 1,
        policyKey: row['policy']! as String,
        grantedAt: row['granted_at'] == null
            ? null
            : DateTime.parse(row['granted_at']! as String),
        expiresAt: row['expires_at'] == null
            ? null
            : DateTime.parse(row['expires_at']! as String),
      );

  Map<String, Object?> toJson() => {
        'family_id': familyId,
        'feature': feature,
        'granted': granted ? 1 : 0,
        'policy': policyKey,
        'granted_at': grantedAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
      };
}

/// Rolling usage meter for one capped feature (e.g. children enrolled).
class UsageMeter {
  const UsageMeter({
    required this.familyId,
    required this.feature,
    required this.used,
    required this.limit,
    required this.periodStart,
    required this.periodEnd,
  });

  final String familyId;
  final String feature;
  final int used;
  final int limit;
  final DateTime periodStart;
  final DateTime periodEnd;

  bool get isOverLimit => used >= limit;
  int get remaining => (limit - used).clamp(0, limit);

  /// Note: the SQL column is named `limit_` to avoid the reserved word
  /// `limit`; serialization uses the same key so the repository works
  /// unchanged on both reads and writes.
  factory UsageMeter.fromJson(Map<String, Object?> row) => UsageMeter(
        familyId: row['family_id']! as String,
        feature: row['feature']! as String,
        used: row['used']! as int,
        limit: (row['limit_'] ?? row['limit'])! as int,
        periodStart: DateTime.parse(row['period_start']! as String),
        periodEnd: DateTime.parse(row['period_end']! as String),
      );

  Map<String, Object?> toJson() => {
        'family_id': familyId,
        'feature': feature,
        'used': used,
        'limit_': limit,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
      };
}

/// Append-only billing record. Refunds are separate rows with
/// `refund` kind and negative minor units.
class BillingRecord {
  const BillingRecord({
    required this.id,
    required this.familyId,
    required this.kind,
    required this.amountMinorUnits,
    required this.currency,
    required this.status,
    this.reference,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String kind;
  final int amountMinorUnits;
  final String currency;
  final String status;
  final String? reference;
  final DateTime createdAt;

  bool get isRefund => kind == 'refund';

  factory BillingRecord.fromJson(Map<String, Object?> row) => BillingRecord(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        kind: row['kind']! as String,
        amountMinorUnits: row['amount_minor_units']! as int,
        currency: row['currency']! as String,
        status: row['status']! as String,
        reference: row['reference'] as String?,
        createdAt: DateTime.parse(row['created_at']! as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'kind': kind,
        'amount_minor_units': amountMinorUnits,
        'currency': currency,
        'status': status,
        'reference': reference,
        'created_at': createdAt.toIso8601String(),
      };
}
