import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class GuardianDatabase {
  GuardianDatabase._(
      {DatabaseFactory? factory, Future<String> Function()? pathResolver})
      : _factory = factory,
        _pathResolver = pathResolver;
  GuardianDatabase.forTesting(
      {required DatabaseFactory factory,
      required Future<String> Function() pathResolver})
      : _factory = factory,
        _pathResolver = pathResolver;
  static final GuardianDatabase instance = GuardianDatabase._();
  Database? _database;
  final DatabaseFactory? _factory;
  final Future<String> Function()? _pathResolver;

  /// Synchronous access to the already-initialized database, or `null` if it has not been opened yet. Repositories that need a [Database] today must first ensure initialization via [initialize] and then read this.
  Database? get activeDatabase => _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = _pathResolver != null
        ? await _pathResolver!()
        : join(await getDatabasesPath(), 'guardian_eye_pro.db');
    final options = OpenDatabaseOptions(
        version: 31,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema);
    _database = _factory == null
        ? await openDatabase(path,
            version: options.version,
            onConfigure: options.onConfigure,
            onCreate: options.onCreate,
            onUpgrade: options.onUpgrade)
        : await _factory!.openDatabase(path, options: options);
    return _database!;
  }

  Future<void> initialize() async => database;
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();
    batch.execute(
        'CREATE TABLE families(id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at TEXT NOT NULL, archived_at TEXT)');
    batch.execute(
        "CREATE TABLE family_members(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), display_name TEXT NOT NULL, role TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'active', account_uid TEXT, invitation_id TEXT, invited_at TEXT, joined_at TEXT, revoked_at TEXT, updated_at TEXT, created_at TEXT NOT NULL)");
    batch.execute(
        'CREATE TABLE family_invitations(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), inviter_member_id TEXT NOT NULL REFERENCES family_members(id), target_email TEXT NOT NULL, proposed_role TEXT NOT NULL, status TEXT NOT NULL, code TEXT UNIQUE, created_at TEXT NOT NULL, expires_at TEXT NOT NULL, accepted_at TEXT, accepted_account_uid TEXT, accepted_member_id TEXT REFERENCES family_members(id), cancelled_at TEXT)');
    batch.execute(
        'CREATE TABLE devices(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), member_id TEXT NOT NULL, owner_member_id TEXT, role TEXT NOT NULL, sync_state TEXT NOT NULL, last_synced_at TEXT, revoked_at TEXT, created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE policies(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, priority INTEGER NOT NULL, enabled INTEGER NOT NULL, schedule_json TEXT NOT NULL, rules_json TEXT NOT NULL, version INTEGER NOT NULL, updated_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE policy_overrides(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, allowed INTEGER NOT NULL, expires_at TEXT NOT NULL, revoked_at TEXT, created_by_member_id TEXT NOT NULL, child_device_id TEXT REFERENCES devices(id), created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE incidents(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), category TEXT NOT NULL, severity TEXT NOT NULL, confidence REAL NOT NULL, source TEXT NOT NULL, evidence_reference TEXT, status TEXT NOT NULL, observed_at TEXT NOT NULL, model_version TEXT NOT NULL, device_id TEXT, actor_uid TEXT, created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE pairing_sessions(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), target_member_id TEXT, code_hash TEXT NOT NULL, requested_role TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'pending\', failure_count INTEGER NOT NULL DEFAULT 0, verified_at TEXT, enrolled_device_id TEXT, expires_at TEXT NOT NULL, revoked_at TEXT, created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE messages(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), sender_member_id TEXT NOT NULL, body TEXT NOT NULL, delivery_state TEXT NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE locations(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, accuracy_m REAL NOT NULL, captured_at TEXT NOT NULL, created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE sos_events(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT, status TEXT NOT NULL, latitude REAL, longitude REAL, accuracy_m REAL, created_at TEXT NOT NULL, delivered_at TEXT)');
    batch.execute(
        'CREATE TABLE notification_events(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), incident_id TEXT, sos_id TEXT, kind TEXT NOT NULL, status TEXT NOT NULL, requested_at TEXT NOT NULL, acknowledged_at TEXT, last_error TEXT)');
    batch.execute(
        'CREATE TABLE notification_tokens(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT NOT NULL, user_uid TEXT NOT NULL, token TEXT NOT NULL, platform TEXT NOT NULL, status TEXT NOT NULL, updated_at TEXT NOT NULL, revoked_at TEXT)');
    batch.execute(
        'CREATE TABLE outbox(id TEXT PRIMARY KEY, aggregate_type TEXT NOT NULL, aggregate_id TEXT NOT NULL, operation TEXT NOT NULL, payload_json TEXT NOT NULL, idempotency_key TEXT NOT NULL UNIQUE, state TEXT NOT NULL, attempt_count INTEGER NOT NULL DEFAULT 0, next_attempt_at TEXT NOT NULL, last_error TEXT, created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE child_device_states(device_id TEXT PRIMARY KEY REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), member_id TEXT NOT NULL, lifecycle TEXT NOT NULL, required_policy_version INTEGER NOT NULL DEFAULT 0, last_valid_policy_at TEXT, last_evaluation_at TEXT, last_decision TEXT, last_sync_at TEXT, failure_code TEXT, updated_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE child_device_policies(device_id TEXT NOT NULL REFERENCES devices(id), policy_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), version INTEGER NOT NULL, payload_json TEXT NOT NULL, delivered_at TEXT NOT NULL, PRIMARY KEY(device_id, policy_id))');
    batch.execute(
        'CREATE TABLE child_enforcement_evaluations(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), outcome TEXT NOT NULL, reason TEXT NOT NULL, policy_id TEXT, policy_version INTEGER, evaluated_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE child_usage_summaries(device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), day_start TEXT NOT NULL, target TEXT NOT NULL, total_milliseconds INTEGER NOT NULL, last_used_at TEXT, captured_at TEXT NOT NULL, PRIMARY KEY(device_id, day_start, target))');
    batch.execute(
        'CREATE TABLE child_usage_observations(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, total_milliseconds INTEGER NOT NULL, observed_at TEXT NOT NULL, source TEXT NOT NULL, captured_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE child_usage_evaluations(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, status TEXT NOT NULL, reason TEXT NOT NULL, used_milliseconds INTEGER NOT NULL, limit_milliseconds INTEGER, policy_id TEXT, policy_version INTEGER, evaluated_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE child_exception_requests(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_device_id TEXT NOT NULL REFERENCES devices(id), child_member_id TEXT NOT NULL REFERENCES family_members(id), child_uid TEXT NOT NULL, target TEXT NOT NULL, policy_id TEXT, requested_duration_minutes INTEGER NOT NULL, reason TEXT NOT NULL, reason_detail TEXT, status TEXT NOT NULL, created_at TEXT NOT NULL, request_expires_at TEXT NOT NULL, reviewed_by_member_id TEXT REFERENCES family_members(id), reviewed_at TEXT, override_id TEXT REFERENCES policy_overrides(id), expires_at TEXT)');
    batch.execute(
        'CREATE INDEX idx_members_family ON family_members(family_id)');
    batch.execute(
        'CREATE INDEX idx_members_family_status ON family_members(family_id, status)');
    batch.execute(
        'CREATE UNIQUE INDEX idx_members_family_account_active ON family_members(family_id, account_uid) WHERE account_uid IS NOT NULL AND status = \'active\'');
    batch.execute(
        'CREATE INDEX idx_invitations_family_status_expiry ON family_invitations(family_id, status, expires_at)');
    batch.execute(
        'CREATE INDEX idx_invitations_target_status ON family_invitations(target_email, status, expires_at)');
    batch.execute(
        'CREATE INDEX idx_incidents_family_time ON incidents(family_id, observed_at DESC)');
    batch.execute(
        'CREATE INDEX idx_outbox_state_next ON outbox(state, next_attempt_at)');
    batch.execute(
        'CREATE INDEX idx_child_policy_device_version ON child_device_policies(device_id, version DESC)');
    batch.execute(
        'CREATE INDEX idx_child_evaluations_device_time ON child_enforcement_evaluations(device_id, evaluated_at DESC)');
    batch.execute(
        'CREATE INDEX idx_child_usage_device_day ON child_usage_summaries(device_id, day_start DESC)');
    batch.execute(
        'CREATE INDEX idx_child_usage_evaluations_device_time ON child_usage_evaluations(device_id, evaluated_at DESC)');
    batch.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_exception_pending_target ON child_exception_requests(child_device_id, target) WHERE status = 'pending'");
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_exception_family_status_created ON child_exception_requests(family_id, status, created_at DESC)');
    batch.execute(
        'CREATE TABLE child_enforcement_states(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), state TEXT NOT NULL, outcome TEXT, reason TEXT NOT NULL, decided_at TEXT NOT NULL, applied_at TEXT, policy_version INTEGER, enqueued_for_sync INTEGER NOT NULL DEFAULT 0)');
    batch.execute(
        'CREATE INDEX idx_enforcement_states_device_time ON child_enforcement_states(device_id, decided_at DESC)');
    // FS-002 — Web Filtering tables: observed block events (hits),
    // parent-managed blocked/trusted domains, per-child category rules,
    // and family web settings.
    batch.execute(
        'CREATE TABLE web_hits(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, child_display_name TEXT, domain TEXT NOT NULL, category TEXT NOT NULL DEFAULT \'other\', blocked_at TEXT NOT NULL, decision TEXT NOT NULL DEFAULT \'blocked\', overridden_by TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE web_domains(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), domain TEXT NOT NULL, kind TEXT NOT NULL, reason TEXT, enabled INTEGER NOT NULL DEFAULT 1, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE web_category_rules(family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, child_display_name TEXT, category TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, sync_state TEXT NOT NULL DEFAULT \'queued\', updated_at TEXT NOT NULL, PRIMARY KEY(family_id, child_id, category))');
    batch.execute(
        'CREATE TABLE web_settings(family_id TEXT NOT NULL REFERENCES families(id), key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(family_id, key))');
    batch.execute(
        'CREATE INDEX idx_web_hits_family_time ON web_hits(family_id, blocked_at DESC)');
    batch.execute(
        'CREATE INDEX idx_web_domains_family_kind ON web_domains(family_id, kind)');
    // FS-001 — Location & Geofencing tables: consent-gated location updates
    // (location_points), parent-managed geofences, geofence entry/exit
    // alerts, named favorite places that geofences anchor to, and family
    // location settings. Location documents are device-written and
    // parent-read; geofence documents are parent-written. Every location
    // write enters the outbox through the same honesty rhythm as the rest
    // of the platform: local SQLite first, sync_state 'queued' until the
    // server confirms.
    batch.execute(
        'CREATE TABLE location_points(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT, member_id TEXT, latitude REAL NOT NULL, longitude REAL NOT NULL, accuracy_meters REAL NOT NULL DEFAULT 100, captured_at TEXT NOT NULL, battery_level REAL, source TEXT NOT NULL DEFAULT \'device\', sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE geofences(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, radius_meters REAL NOT NULL, alert_on_entry INTEGER NOT NULL DEFAULT 1, alert_on_exit INTEGER NOT NULL DEFAULT 1, member_ids_json TEXT, place_key TEXT, status TEXT NOT NULL DEFAULT \'active\', sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE location_alerts(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), geofence_id TEXT, member_id TEXT, member_display_name TEXT, event_type TEXT NOT NULL, occurred_at TEXT NOT NULL, acknowledged INTEGER NOT NULL DEFAULT 0, acknowledged_at TEXT, device_id TEXT, source TEXT NOT NULL DEFAULT \'geofence\', sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE favorite_places(family_id TEXT NOT NULL REFERENCES families(id), place_key TEXT NOT NULL, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, notes TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(family_id, place_key))');
    batch.execute(
        'CREATE TABLE location_settings(family_id TEXT NOT NULL REFERENCES families(id), key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(family_id, key))');
    batch.execute(
        'CREATE INDEX idx_location_points_family_time ON location_points(family_id, captured_at DESC)');
    batch.execute(
        'CREATE INDEX idx_location_alerts_family_time ON location_alerts(family_id, occurred_at DESC)');
    // FS-003 — Application Control tables: per-app block/allow/limit
    // policies (app_policies), trusted apps that survive mode changes
    // (app_allowlist), an honest audit log of enforcement events
    // (app_block_history), and per-app usage alert thresholds
    // (usage_alert_settings). Policies are parent-written; device agents
    // read them to enforce on the child's device and write block history.
    // Every write enters the outbox through the same honesty rhythm as
    // the rest of the platform: local SQLite first, sync_state 'queued'
    // until the server confirms.
    batch.execute(
        'CREATE TABLE app_policies(family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL DEFAULT \'\', target TEXT NOT NULL, action TEXT NOT NULL, limit_milliseconds INTEGER, rating_max TEXT NOT NULL DEFAULT \'all\', sync_state TEXT NOT NULL DEFAULT \'queued\', updated_at TEXT NOT NULL, PRIMARY KEY(family_id, child_id, target))');
    batch.execute(
        'CREATE TABLE app_allowlist(family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, reason TEXT, added_by TEXT, created_at TEXT NOT NULL, PRIMARY KEY(family_id, target))');
    batch.execute(
        'CREATE TABLE app_block_history(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, child_id TEXT, event TEXT NOT NULL, reason TEXT, created_at TEXT NOT NULL)');
    batch.execute(
        'CREATE TABLE usage_alert_settings(family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT, target TEXT NOT NULL, threshold_milliseconds INTEGER NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL, PRIMARY KEY(family_id, target))');
    batch.execute(
        'CREATE INDEX idx_app_block_history_family_time ON app_block_history(family_id, created_at DESC)');
    batch.execute(
        'CREATE INDEX idx_app_policies_family ON app_policies(family_id)');
    // FS-004 — Screenshot & Camera Control.
    batch.execute(
        'CREATE TABLE monitoring_shots(family_id TEXT NOT NULL REFERENCES families(id), shot_id TEXT NOT NULL, device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, captured_at TEXT NOT NULL, bytes_length INTEGER NOT NULL DEFAULT 0, mime_type TEXT NOT NULL DEFAULT \'image/png\', request_id TEXT, schedule_id TEXT, is_evidence INTEGER NOT NULL DEFAULT 0, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, shot_id))');
    batch.execute(
        'CREATE TABLE monitoring_sessions(session_id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, kind TEXT NOT NULL DEFAULT \'live\', state TEXT NOT NULL DEFAULT \'pending\', started_at TEXT, ended_at TEXT, created_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\')');
    batch.execute(
        'CREATE TABLE monitoring_requests(family_id TEXT NOT NULL REFERENCES families(id), request_id TEXT NOT NULL, device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, kind TEXT NOT NULL, state TEXT NOT NULL DEFAULT \'queued\', reason TEXT, created_at TEXT NOT NULL, delivered_at TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, request_id))');
    batch.execute(
        'CREATE TABLE monitoring_schedules(family_id TEXT NOT NULL REFERENCES families(id), schedule_id TEXT NOT NULL, device_id TEXT REFERENCES devices(id), child_id TEXT, start_hour INTEGER NOT NULL, end_hour INTEGER NOT NULL, interval_minutes INTEGER NOT NULL DEFAULT 30, enabled INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, schedule_id))');
    batch.execute(
        'CREATE TABLE monitoring_evidence_queue(family_id TEXT NOT NULL REFERENCES families(id), evidence_id TEXT NOT NULL, shot_id TEXT NOT NULL, device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, flag_reason TEXT NOT NULL, state TEXT NOT NULL DEFAULT \'queued\', decided_by TEXT, decided_at TEXT, created_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, evidence_id))');
    batch.execute(
        'CREATE INDEX idx_monitoring_shots_family_time ON monitoring_shots(family_id, captured_at DESC)');
    batch.execute(
        'CREATE INDEX idx_monitoring_evidence_family_state ON monitoring_evidence_queue(family_id, state)');
    // FS-005 — Special & Custom Modes (schema docs in the v19 upgrade block).
    batch.execute(
        'CREATE TABLE mode_configs(mode_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'custom\', action TEXT NOT NULL DEFAULT \'slowDown\', enabled INTEGER NOT NULL DEFAULT 1, start_minute INTEGER NOT NULL DEFAULT 0, end_minute INTEGER NOT NULL DEFAULT 0, schedule_kind TEXT NOT NULL DEFAULT \'daily\', weekdays TEXT NOT NULL DEFAULT \'1,2,3,4,5\', oneshot_at TEXT, assigned_child_ids TEXT NOT NULL DEFAULT \'\', category_restrictions TEXT NOT NULL DEFAULT \'\', app_restrictions TEXT NOT NULL DEFAULT \'\', priority INTEGER NOT NULL DEFAULT 50, note TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, mode_id))');
    batch.execute(
        'CREATE TABLE mode_activations(activation_id TEXT PRIMARY KEY, mode_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT, state TEXT NOT NULL DEFAULT \'requested\', started_at TEXT NOT NULL, ends_at TEXT, decided_by TEXT, created_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', FOREIGN KEY(family_id, mode_id) REFERENCES mode_configs(family_id, mode_id))');
    batch.execute(
        'CREATE INDEX idx_mode_configs_family ON mode_configs(family_id)');
    batch.execute(
        'CREATE INDEX idx_mode_activations_family_time ON mode_activations(family_id, started_at DESC)');
    // FS-006 — SOS & Emergency. Recipient roster with responder roles for the
    // readiness drill, plus per-recipient acknowledgement rows on the SOS
    // notification channel (recipient_id NULL preserves legacy rows).
    batch.execute(
        'CREATE TABLE sos_recipients(family_id TEXT NOT NULL REFERENCES families(id), recipient_id TEXT NOT NULL, role TEXT NOT NULL DEFAULT \'responder\', ordering INTEGER NOT NULL DEFAULT 0, added_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, recipient_id))');
    batch.execute(
        'CREATE INDEX idx_sos_recipients_family ON sos_recipients(family_id, ordering)');
    // FS-011 — Family Rules & Policy Engine. One coherent rule book per
    // family plus the honest execution log that records every verdict.
    batch.execute(
        'CREATE TABLE family_rules(rule_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'dailyScreenTime\', action TEXT NOT NULL DEFAULT \'restrict\', enabled INTEGER NOT NULL DEFAULT 1, start_minute INTEGER NOT NULL DEFAULT 0, end_minute INTEGER NOT NULL DEFAULT 0, schedule_kind TEXT NOT NULL DEFAULT \'daily\', weekdays TEXT NOT NULL DEFAULT \'1,2,3,4,5\', oneshot_at TEXT, assigned_child_ids TEXT NOT NULL DEFAULT \'\', app_targets TEXT NOT NULL DEFAULT \'\', category_targets TEXT NOT NULL DEFAULT \'\', geofence_ids TEXT NOT NULL DEFAULT \'\', geofence_trigger TEXT NOT NULL DEFAULT \'entering\', limit_minutes INTEGER, linked_task_id TEXT NOT NULL DEFAULT \'\', priority INTEGER NOT NULL DEFAULT 50, note TEXT, created_by_member_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, rule_id))');
    batch.execute(
        'CREATE TABLE rule_execution_log(id TEXT PRIMARY KEY, rule_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, outcome TEXT NOT NULL, reason TEXT NOT NULL, evaluated_at TEXT NOT NULL, FOREIGN KEY(family_id, rule_id) REFERENCES family_rules(family_id, rule_id))');
    batch.execute(
        'CREATE INDEX idx_family_rules_family ON family_rules(family_id)');
    batch.execute(
        'CREATE INDEX idx_rule_execution_family_time ON rule_execution_log(family_id, evaluated_at DESC)');
    // FS-007 — Family Tasks & Daily Schedules. Concrete, scheduled asks
    // (homework, prayers, chores...) with an honest status machine; a
    // parent-linked `taskGated` rule stays locked until the task shows a
    // `completed` action in the append-only log below. Nothing is ever
    // marked done silently.
    batch.execute(
        'CREATE TABLE tasks(task_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), title TEXT NOT NULL, description TEXT, due_minute INTEGER NOT NULL DEFAULT 0, due_date TEXT NOT NULL, recurrence TEXT NOT NULL DEFAULT \'none\', weekdays TEXT NOT NULL DEFAULT \'1,2,3,4,5\', assigned_child_ids TEXT NOT NULL DEFAULT \'\', linked_rule_id TEXT, status TEXT NOT NULL DEFAULT \'scheduled\', created_by_member_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, task_id))');
    batch.execute(
        'CREATE TABLE task_completion_log(id TEXT PRIMARY KEY, task_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, action TEXT NOT NULL, actor_member_id TEXT NOT NULL, acted_at TEXT NOT NULL, note TEXT, FOREIGN KEY(family_id, task_id) REFERENCES tasks(family_id, task_id))');
    batch.execute('CREATE INDEX idx_tasks_family ON tasks(family_id)');
    batch.execute(
        'CREATE INDEX idx_task_completion_family_time ON task_completion_log(family_id, acted_at DESC)');
    // FS-008 — Family Points & Rewards. An append-only ledger is the only
    // source of a child's balance (sum of rows, never a separately
    // writable field); redemptions are pending claims a parent decides,
    // and a spend row is written only after an approval decision.
    batch.execute(
        'CREATE TABLE reward_points_ledger(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, delta INTEGER NOT NULL, reason TEXT NOT NULL, reference_id TEXT, balance_after INTEGER NOT NULL, acted_by TEXT NOT NULL, acted_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\')');
    batch.execute(
        'CREATE TABLE family_rewards(reward_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, description TEXT, cost_points INTEGER NOT NULL, expiry_days INTEGER, enabled INTEGER NOT NULL DEFAULT 1, created_by_member_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, reward_id))');
    batch.execute(
        'CREATE TABLE reward_pending_claims(claim_id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), reward_id TEXT NOT NULL, child_id TEXT NOT NULL, requested_at TEXT NOT NULL, decided_by TEXT, decision TEXT, decided_at TEXT, ledger_row_id TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', FOREIGN KEY(family_id, reward_id) REFERENCES family_rewards(family_id, reward_id))');
    batch.execute(
        'CREATE INDEX idx_reward_ledger_family_child ON reward_points_ledger(family_id, child_id)');
    batch.execute(
        'CREATE INDEX idx_reward_ledger_family_time ON reward_points_ledger(family_id, acted_at DESC)');
    batch.execute(
        'CREATE INDEX idx_reward_pending_claims_family_state ON reward_pending_claims(family_id, decision)');
    await batch.commit(noResult: true);
    // Per-recipient acknowledgement tracking on the existing notification
    // channel (NULL preserves legacy rows and outbox semantics).
    await db.execute(
        'ALTER TABLE notification_events ADD COLUMN recipient_id TEXT');

    // Phases 9 / Guardian AI / FS-013 / ST — tables also covered by _upgradeSchema migrations v25..v28 (idempotent).
    await db.execute(
        'CREATE TABLE IF NOT EXISTS family_events(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), member_id TEXT, child_id TEXT, device_id TEXT, type TEXT NOT NULL, privacy_class TEXT NOT NULL DEFAULT \'operational\', attributes_json TEXT NOT NULL DEFAULT \'{}\', occurred_at TEXT NOT NULL, created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_family_events_family_occurred ON family_events(family_id, occurred_at DESC)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS normalized_signals(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT, signal_key TEXT NOT NULL, weight REAL NOT NULL DEFAULT 1.0, occurred_at TEXT NOT NULL, outcome TEXT NOT NULL DEFAULT \'allowed\', privacy_class TEXT NOT NULL DEFAULT \'operational\', source_event_id TEXT, reject_reason TEXT, consent_scope TEXT NOT NULL DEFAULT \'{}\', created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_normalized_signals_key ON normalized_signals(family_id, signal_key, occurred_at DESC)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS ai_consent_scopes(family_id TEXT PRIMARY KEY REFERENCES families(id), consent_scope TEXT NOT NULL DEFAULT \'{}\', updated_at TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS source_event_tracking(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), source_event_id TEXT NOT NULL, created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_source_events_family ON source_event_tracking(family_id, source_event_id)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS ai_risk_states(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, level TEXT NOT NULL DEFAULT \'safe\', deterministic_only INTEGER NOT NULL DEFAULT 1, contributors_json TEXT NOT NULL DEFAULT \'[]\', evaluated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ai_risk_states_family ON ai_risk_states(family_id, child_id, evaluated_at DESC)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS ai_behavior_profiles(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, weekday INTEGER NOT NULL, hour INTEGER NOT NULL, usage_seconds REAL NOT NULL DEFAULT 0.0, deviation_percent REAL NOT NULL DEFAULT 0.0, window_start TEXT NOT NULL, window_end TEXT NOT NULL, created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ai_behavior_profile ON ai_behavior_profiles(family_id, child_id, weekday, hour)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS ai_insights(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), category TEXT NOT NULL, severity TEXT NOT NULL DEFAULT \'info\', title TEXT NOT NULL, body TEXT NOT NULL, evidence_json TEXT NOT NULL DEFAULT \'[]\', created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ai_insights_family ON ai_insights(family_id, created_at DESC)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS ai_detections(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT, category TEXT NOT NULL, severity_band TEXT NOT NULL, confidence_band TEXT NOT NULL, source TEXT NOT NULL, model_version TEXT NOT NULL, reference_id TEXT, detected_at TEXT NOT NULL, reviewed INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ai_detections_family ON ai_detections(family_id, detected_at DESC)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS ai_copilot_suggestions(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), period TEXT NOT NULL, period_start TEXT NOT NULL, period_end TEXT NOT NULL, body_json TEXT NOT NULL DEFAULT \'\', evidence_json TEXT NOT NULL DEFAULT \'[]\', data_sufficiency TEXT NOT NULL DEFAULT \'insufficient\', status TEXT NOT NULL DEFAULT \'proposed\', applied_at TEXT, dismissed_at TEXT, outcome_note TEXT, effect_after_days TEXT, created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ai_copilot_suggestions_family ON ai_copilot_suggestions(family_id, created_at DESC)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS ai_policy_proposals(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), title TEXT NOT NULL, body TEXT, rationale TEXT, status TEXT NOT NULL DEFAULT \'pending\', reason_json TEXT NOT NULL DEFAULT \'[]\', applied_at TEXT, dismissed_at TEXT, outcome_note TEXT, effect_after_days TEXT, created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ai_policy_proposals_family ON ai_policy_proposals(family_id, status, created_at DESC)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS couple_linking(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), partner_member_id TEXT NOT NULL, request_state TEXT NOT NULL DEFAULT \'requested\', requested_by TEXT, requested_at TEXT NOT NULL, responded_at TEXT, created_at TEXT NOT NULL DEFAULT \'\')');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_couple_linking_family ON couple_linking(family_id, request_state)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS couple_proposals(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), kind TEXT NOT NULL, title TEXT NOT NULL, body TEXT, proposed_by TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'pending\', reviewed_by TEXT, reviewed_at TEXT, expires_at TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT \'\')');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_couple_proposals_family ON couple_proposals(family_id, status, expires_at)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS couple_routines(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), title TEXT NOT NULL, assigned_child_ids TEXT NOT NULL DEFAULT \'\', weekdays TEXT NOT NULL DEFAULT \'\', start_minute INTEGER NOT NULL, end_minute INTEGER NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, created_by TEXT, created_at TEXT NOT NULL DEFAULT \'\', updated_at TEXT NOT NULL DEFAULT \'\')');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_couple_routines_family ON couple_routines(family_id, enabled)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS couple_responsibilities(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), area TEXT NOT NULL, owner_member_id TEXT NOT NULL, delegate_member_id TEXT, effective_from TEXT NOT NULL, effective_until TEXT, created_at TEXT NOT NULL DEFAULT \'\')');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_couple_responsibilities_family ON couple_responsibilities(family_id, area)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS couple_handovers(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), from_member_id TEXT NOT NULL, to_member_id TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'pending\', requested_at TEXT NOT NULL, completed_at TEXT, created_at TEXT NOT NULL DEFAULT \'\')');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_couple_handovers_family_status ON couple_handovers(family_id, status, requested_at DESC)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS subscription_entitlements(family_id TEXT NOT NULL REFERENCES families(id), feature TEXT NOT NULL, granted INTEGER NOT NULL DEFAULT 0, policy TEXT NOT NULL DEFAULT \'local\', granted_at TEXT, expires_at TEXT, PRIMARY KEY(family_id, feature))');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS subscription_usage_limits(family_id TEXT NOT NULL REFERENCES families(id), feature TEXT NOT NULL, used INTEGER NOT NULL DEFAULT 0, limit_ INTEGER NOT NULL DEFAULT 0, period_start TEXT NOT NULL, period_end TEXT NOT NULL, PRIMARY KEY(family_id, feature))');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS billing_records(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), kind TEXT NOT NULL DEFAULT \'purchase\', amount_minor_units INTEGER NOT NULL DEFAULT 0, currency TEXT NOT NULL DEFAULT \'USD\', status TEXT NOT NULL DEFAULT \'pending\', reference TEXT, created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_billing_family_time ON billing_records(family_id, created_at DESC)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS notification_settings(key TEXT PRIMARY KEY, render_enabled INTEGER NOT NULL DEFAULT 1, dispatch_enabled INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL)');
    // Phase 3 — stable device identity for FCM token registration. One row
    // keyed by 'device_id'; generated once and reused until the app is
    // reinstalled. Preferences stay decoupled from this identity.
    await db.execute(
        'CREATE TABLE IF NOT EXISTS app_identity(key TEXT PRIMARY KEY, value TEXT NOT NULL, created_at TEXT NOT NULL)');
    // FS-010 — ephemeral family chat. Fresh installs get these tables in the
    // same pass; legacy upgrades reach the identical shape via the v30
    // incremental migration below (bit-identical DDL).
    await db.execute(
        'CREATE TABLE IF NOT EXISTS chat_threads(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), type TEXT NOT NULL, member_id TEXT, expiration_window TEXT NOT NULL DEFAULT \'hours24\', created_by_member_id TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_chat_threads_family ON chat_threads(family_id)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS chat_messages(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), thread_id TEXT NOT NULL REFERENCES chat_threads(id), sender_member_id TEXT NOT NULL, body TEXT NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL, state TEXT NOT NULL DEFAULT \'queued\', idempotency_key TEXT NOT NULL UNIQUE, outbox_event_id TEXT)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_chat_messages_thread_time ON chat_messages(thread_id, created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_chat_messages_expiry ON chat_messages(thread_id, expires_at)');
  }

  /// Foundational schema guard (Phase 4 migration compatibility gate).
  ///
  /// Nine foundational tables — `families`, `family_members`, `devices`,
  /// `policies`, `incidents`, `pairing_sessions`, `messages`, `locations`,
  /// and `outbox` — historically existed only in the fresh-install path
  /// (`_createSchema`). A legacy app upgrading from a schema version earlier
  /// than the one that introduced these tables would crash on any write.
  ///
  /// This guard runs BEFORE every incremental migration inside
  /// `_upgradeSchema` and creates exactly those missing tables, plus the
  /// indexes the query layer assumes, using `CREATE ... IF NOT EXISTS` with
  /// the CURRENT column set. It is fully idempotent, alters no data, deletes
  /// nothing, references no repository or privacy operation, and fails
  /// closed (throws without side effects if the DDL is invalid).
  Future<void> _ensureFoundationalSchema(Database db) async {
    for (final statement in _foundationalSchemaStatements) {
      await db.execute(statement);
    }
  }

  /// Verifies the nine foundational tables and their indexes exist on the
  /// open database. Used by tests to prove the migration guard succeeded
  /// and by the privacy purge engine to refuse to touch a legacy database
  /// whose foundational schema could not be recovered.
  Future<bool> verifyBaseSchema() async {
    final db = await database;
    final tables = await db.query('sqlite_master',
        columns: ['name'], where: "type = 'table'");
    final names = tables.map((final row) => row['name'] as String).toSet();
    if (!_expectedFoundationalTables.every(names.contains)) return false;
    for (final name in _expectedFoundationalIndexes) {
      final rows = await db.query('sqlite_master',
          columns: ['name'],
          where: "type = 'index' AND name = ?",
          whereArgs: [name]);
      if (rows.isEmpty) return false;
    }
    return true;
  }

  static const Set<String> _expectedFoundationalTables = <String>{
    'families',
    'family_members',
    'devices',
    'policies',
    'incidents',
    'pairing_sessions',
    'messages',
    'locations',
    'outbox',
  };

  static const Set<String> _expectedFoundationalIndexes = <String>{
    'idx_members_family',
    'idx_incidents_family_time',
    'idx_outbox_state_next',
  };

  // Column sets below are copied VERBATIM from the fresh-install schema
  // (`_createSchema`) so legacy upgrades reach bit-identical table shapes.
  static const List<String> _foundationalSchemaStatements = <String>[
    // Test-only accessor below; the list itself stays private to prevent
    // accidental mutation by repository code.
    'CREATE TABLE IF NOT EXISTS families(id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at TEXT NOT NULL, archived_at TEXT)',
    'CREATE TABLE IF NOT EXISTS family_members(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), display_name TEXT NOT NULL, role TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'active\', account_uid TEXT, invitation_id TEXT, invited_at TEXT, joined_at TEXT, revoked_at TEXT, updated_at TEXT, created_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS devices(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), member_id TEXT NOT NULL, owner_member_id TEXT, role TEXT NOT NULL, sync_state TEXT NOT NULL, last_synced_at TEXT, revoked_at TEXT, created_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS policies(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, priority INTEGER NOT NULL, enabled INTEGER NOT NULL, schedule_json TEXT NOT NULL, rules_json TEXT NOT NULL, version INTEGER NOT NULL, updated_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS incidents(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), category TEXT NOT NULL, severity TEXT NOT NULL, confidence REAL NOT NULL, source TEXT NOT NULL, evidence_reference TEXT, status TEXT NOT NULL, observed_at TEXT NOT NULL, model_version TEXT NOT NULL, device_id TEXT, actor_uid TEXT, created_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS pairing_sessions(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), target_member_id TEXT, code_hash TEXT NOT NULL, requested_role TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'pending\', failure_count INTEGER NOT NULL DEFAULT 0, verified_at TEXT, enrolled_device_id TEXT, expires_at TEXT NOT NULL, revoked_at TEXT, created_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS messages(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), sender_member_id TEXT NOT NULL, body TEXT NOT NULL, delivery_state TEXT NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS locations(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, accuracy_m REAL NOT NULL, captured_at TEXT NOT NULL, created_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS outbox(id TEXT PRIMARY KEY, aggregate_type TEXT NOT NULL, aggregate_id TEXT NOT NULL, operation TEXT NOT NULL, payload_json TEXT NOT NULL, idempotency_key TEXT NOT NULL UNIQUE, state TEXT NOT NULL, attempt_count INTEGER NOT NULL DEFAULT 0, next_attempt_at TEXT NOT NULL, last_error TEXT, created_at TEXT NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_members_family ON family_members(family_id)',
    'CREATE INDEX IF NOT EXISTS idx_incidents_family_time ON incidents(family_id, observed_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_outbox_state_next ON outbox(state, next_attempt_at)',
  ];

  /// Test-only read-only view of the guard's DDL statements, used by the
  /// migration gate suite to prove the no-destructive invariant.
  @visibleForTesting
  static List<String> get foundationalSchemaStatementsForTesting =>
      List<String>.unmodifiable(_foundationalSchemaStatements);

  /// Adds [column] to [table] only when the column does not already exist.
  /// Legacy incremental migrations (`ALTER TABLE ... ADD COLUMN`) would fail
  /// on a legacy database that already reached v29 via another channel; this
  /// keeps those migrations idempotent.
  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final rows = await db.query('pragma_table_info(\'$table\')',
        columns: ['name'], where: "name = ?", whereArgs: [column]);
    if (rows.isEmpty) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _upgradeSchema(
      Database db, int oldVersion, int newVersion) async {
    // Phase 4 migration gate: guarantee the nine foundational tables and
    // their indexes exist before any incremental migration runs.
    await _ensureFoundationalSchema(db);
    if (oldVersion < 2) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS sos_events(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT, status TEXT NOT NULL, latitude REAL, longitude REAL, accuracy_m REAL, created_at TEXT NOT NULL, delivered_at TEXT)');
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'devices', 'owner_member_id', 'TEXT');
      await _addColumnIfMissing(db, 'devices', 'revoked_at', 'TEXT');
      await _addColumnIfMissing(
          db, 'pairing_sessions', 'target_member_id', 'TEXT');
      await _addColumnIfMissing(
          db, 'pairing_sessions', 'status', "TEXT NOT NULL DEFAULT 'pending'");
      await _addColumnIfMissing(db, 'pairing_sessions', 'failure_count',
          'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'pairing_sessions', 'verified_at', 'TEXT');
      await _addColumnIfMissing(
          db, 'pairing_sessions', 'enrolled_device_id', 'TEXT');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pairing_family_state ON pairing_sessions(family_id, status, expires_at)');
    }
    if (oldVersion < 4) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS policy_overrides(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, allowed INTEGER NOT NULL, expires_at TEXT NOT NULL, revoked_at TEXT, created_by_member_id TEXT NOT NULL, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_policy_overrides_active ON policy_overrides(family_id, target, expires_at)');
    }
    if (oldVersion < 5) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS notification_events(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), incident_id TEXT, sos_id TEXT, kind TEXT NOT NULL, status TEXT NOT NULL, requested_at TEXT NOT NULL, acknowledged_at TEXT, last_error TEXT)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_notifications_family_state ON notification_events(family_id, status, requested_at)');
    }
    if (oldVersion < 6) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS notification_tokens(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT NOT NULL, user_uid TEXT NOT NULL, token TEXT NOT NULL, platform TEXT NOT NULL, status TEXT NOT NULL, updated_at TEXT NOT NULL, revoked_at TEXT)');
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_notification_token_active ON notification_tokens(device_id, token)');
    }
    if (oldVersion < 7) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS child_device_states(device_id TEXT PRIMARY KEY REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), member_id TEXT NOT NULL, lifecycle TEXT NOT NULL, required_policy_version INTEGER NOT NULL DEFAULT 0, last_valid_policy_at TEXT, last_evaluation_at TEXT, last_decision TEXT, last_sync_at TEXT, failure_code TEXT, updated_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS child_device_policies(device_id TEXT NOT NULL REFERENCES devices(id), policy_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), version INTEGER NOT NULL, payload_json TEXT NOT NULL, delivered_at TEXT NOT NULL, PRIMARY KEY(device_id, policy_id))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS child_enforcement_evaluations(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), outcome TEXT NOT NULL, reason TEXT NOT NULL, policy_id TEXT, policy_version INTEGER, evaluated_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_child_policy_device_version ON child_device_policies(device_id, version DESC)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_child_evaluations_device_time ON child_enforcement_evaluations(device_id, evaluated_at DESC)');
    }
    if (oldVersion < 8) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS child_usage_summaries(device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), day_start TEXT NOT NULL, target TEXT NOT NULL, total_milliseconds INTEGER NOT NULL, last_used_at TEXT, captured_at TEXT NOT NULL, PRIMARY KEY(device_id, day_start, target))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS child_usage_observations(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, total_milliseconds INTEGER NOT NULL, observed_at TEXT NOT NULL, source TEXT NOT NULL, captured_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_child_usage_device_day ON child_usage_summaries(device_id, day_start DESC)');
    }
    if (oldVersion < 9) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS child_usage_evaluations(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, status TEXT NOT NULL, reason TEXT NOT NULL, used_milliseconds INTEGER NOT NULL, limit_milliseconds INTEGER, policy_id TEXT, policy_version INTEGER, evaluated_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_child_usage_evaluations_device_time ON child_usage_evaluations(device_id, evaluated_at DESC)');
    }
    if (oldVersion < 10) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS child_exception_requests(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_device_id TEXT NOT NULL REFERENCES devices(id), child_member_id TEXT NOT NULL REFERENCES family_members(id), child_uid TEXT NOT NULL, target TEXT NOT NULL, policy_id TEXT, requested_duration_minutes INTEGER NOT NULL, reason TEXT NOT NULL, reason_detail TEXT, status TEXT NOT NULL, created_at TEXT NOT NULL, request_expires_at TEXT NOT NULL, reviewed_by_member_id TEXT REFERENCES family_members(id), reviewed_at TEXT, override_id TEXT REFERENCES policy_overrides(id), expires_at TEXT)');
      await db.execute(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_exception_pending_target ON child_exception_requests(child_device_id, target) WHERE status = 'pending'");
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_exception_family_status_created ON child_exception_requests(family_id, status, created_at DESC)');
    }
    if (oldVersion < 11) {
      await _addColumnIfMissing(db, 'policy_overrides', 'child_device_id',
          'TEXT REFERENCES devices(id)');
    }
    if (oldVersion < 12) {
      await _addColumnIfMissing(
          db, 'family_members', 'status', "TEXT NOT NULL DEFAULT 'active'");
      await _addColumnIfMissing(db, 'family_members', 'account_uid', 'TEXT');
      await _addColumnIfMissing(db, 'family_members', 'invitation_id', 'TEXT');
      await _addColumnIfMissing(db, 'family_members', 'invited_at', 'TEXT');
      await _addColumnIfMissing(db, 'family_members', 'joined_at', 'TEXT');
      await _addColumnIfMissing(db, 'family_members', 'revoked_at', 'TEXT');
      await _addColumnIfMissing(db, 'family_members', 'updated_at', 'TEXT');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS family_invitations(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), inviter_member_id TEXT NOT NULL REFERENCES family_members(id), target_email TEXT NOT NULL, proposed_role TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL, accepted_at TEXT, accepted_account_uid TEXT, accepted_member_id TEXT REFERENCES family_members(id), cancelled_at TEXT)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_members_family_status ON family_members(family_id, status)');
      await db.execute(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_members_family_account_active ON family_members(family_id, account_uid) WHERE account_uid IS NOT NULL AND status = 'active'");
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_invitations_family_status_expiry ON family_invitations(family_id, status, expires_at)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_invitations_target_status ON family_invitations(target_email, status, expires_at)');
    }
    if (oldVersion < 13) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS child_enforcement_states(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), state TEXT NOT NULL, outcome TEXT, reason TEXT NOT NULL, decided_at TEXT NOT NULL, applied_at TEXT, policy_version INTEGER, enqueued_for_sync INTEGER NOT NULL DEFAULT 0)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_enforcement_states_device_time ON child_enforcement_states(device_id, decided_at DESC)');
    }
    if (oldVersion < 14) {
      // Add device identity fields to incidents for Firestore authorization.
      // Column presence is checked explicitly because legacy databases that
      // passed through the foundational schema guard (v29) already contain
      // these columns from the current full table definitions.
      await _addColumnIfMissing(db, 'incidents', 'device_id', 'TEXT');
      await _addColumnIfMissing(db, 'incidents', 'actor_uid', 'TEXT');
    }
    if (oldVersion < 15) {
      // FS-002 — Web Filtering tables (see onCreate for schema docs).
      await db.execute(
          'CREATE TABLE IF NOT EXISTS web_hits(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, child_display_name TEXT, domain TEXT NOT NULL, category TEXT NOT NULL DEFAULT \'other\', blocked_at TEXT NOT NULL, decision TEXT NOT NULL DEFAULT \'blocked\', overridden_by TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS web_domains(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), domain TEXT NOT NULL, kind TEXT NOT NULL, reason TEXT, enabled INTEGER NOT NULL DEFAULT 1, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS web_category_rules(family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, child_display_name TEXT, category TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, sync_state TEXT NOT NULL DEFAULT \'queued\', updated_at TEXT NOT NULL, PRIMARY KEY(family_id, child_id, category))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS web_settings(family_id TEXT NOT NULL REFERENCES families(id), key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(family_id, key))');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_web_hits_family_time ON web_hits(family_id, blocked_at DESC)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_web_domains_family_kind ON web_domains(family_id, kind)');
    }
    if (oldVersion < 16) {
      // FS-001 — Location & Geofencing (see onCreate for schema docs).
      await db.execute(
          'CREATE TABLE IF NOT EXISTS location_points(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT, member_id TEXT, latitude REAL NOT NULL, longitude REAL NOT NULL, accuracy_meters REAL NOT NULL DEFAULT 100, captured_at TEXT NOT NULL, battery_level REAL, source TEXT NOT NULL DEFAULT \'device\', sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS geofences(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, radius_meters REAL NOT NULL, alert_on_entry INTEGER NOT NULL DEFAULT 1, alert_on_exit INTEGER NOT NULL DEFAULT 1, member_ids_json TEXT, place_key TEXT, status TEXT NOT NULL DEFAULT \'active\', sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS location_alerts(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), geofence_id TEXT, member_id TEXT, member_display_name TEXT, event_type TEXT NOT NULL, occurred_at TEXT NOT NULL, acknowledged INTEGER NOT NULL DEFAULT 0, acknowledged_at TEXT, device_id TEXT, source TEXT NOT NULL DEFAULT \'geofence\', sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS favorite_places(family_id TEXT NOT NULL REFERENCES families(id), place_key TEXT NOT NULL, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, notes TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(family_id, place_key))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS location_settings(family_id TEXT NOT NULL REFERENCES families(id), key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(family_id, key))');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_location_points_family_time ON location_points(family_id, captured_at DESC)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_location_alerts_family_time ON location_alerts(family_id, occurred_at DESC)');
    }
    if (oldVersion < 17) {
      // FS-003 — Application Control (see onCreate for schema docs).
      await db.execute(
          'CREATE TABLE IF NOT EXISTS app_policies(family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL DEFAULT \'\', target TEXT NOT NULL, action TEXT NOT NULL, limit_milliseconds INTEGER, rating_max TEXT NOT NULL DEFAULT \'all\', sync_state TEXT NOT NULL DEFAULT \'queued\', updated_at TEXT NOT NULL, PRIMARY KEY(family_id, child_id, target))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS app_allowlist(family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, reason TEXT, added_by TEXT, created_at TEXT NOT NULL, PRIMARY KEY(family_id, target))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS app_block_history(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, child_id TEXT, event TEXT NOT NULL, reason TEXT, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS usage_alert_settings(family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT, target TEXT NOT NULL, threshold_milliseconds INTEGER NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL, PRIMARY KEY(family_id, target))');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_app_block_history_family_time ON app_block_history(family_id, created_at DESC)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_app_policies_family ON app_policies(family_id)');
    }
    if (oldVersion < 18) {
      // FS-004 — Screenshot & Camera Control (see onCreate for schema docs).
      await db.execute(
          'CREATE TABLE IF NOT EXISTS monitoring_shots(family_id TEXT NOT NULL REFERENCES families(id), shot_id TEXT NOT NULL, device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, captured_at TEXT NOT NULL, bytes_length INTEGER NOT NULL DEFAULT 0, mime_type TEXT NOT NULL DEFAULT \'image/png\', request_id TEXT, schedule_id TEXT, is_evidence INTEGER NOT NULL DEFAULT 0, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, shot_id))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS monitoring_sessions(session_id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, kind TEXT NOT NULL DEFAULT \'live\', state TEXT NOT NULL DEFAULT \'pending\', started_at TEXT, ended_at TEXT, created_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\')');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS monitoring_requests(family_id TEXT NOT NULL REFERENCES families(id), request_id TEXT NOT NULL, device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, kind TEXT NOT NULL, state TEXT NOT NULL DEFAULT \'queued\', reason TEXT, created_at TEXT NOT NULL, delivered_at TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, request_id))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS monitoring_schedules(family_id TEXT NOT NULL REFERENCES families(id), schedule_id TEXT NOT NULL, device_id TEXT REFERENCES devices(id), child_id TEXT, start_hour INTEGER NOT NULL, end_hour INTEGER NOT NULL, interval_minutes INTEGER NOT NULL DEFAULT 30, enabled INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, schedule_id))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS monitoring_evidence_queue(family_id TEXT NOT NULL REFERENCES families(id), evidence_id TEXT NOT NULL, shot_id TEXT NOT NULL, device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, flag_reason TEXT NOT NULL, state TEXT NOT NULL DEFAULT \'queued\', decided_by TEXT, decided_at TEXT, created_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, evidence_id))');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_monitoring_shots_family_time ON monitoring_shots(family_id, captured_at DESC)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_monitoring_evidence_family_state ON monitoring_evidence_queue(family_id, state)');
    }
    if (oldVersion < 19) {
      // FS-005 — Special & Custom Modes. Situational modes with schedules,
      // child assignment and honest activation logs (never fake `applied`).
      await db.execute(
          'CREATE TABLE IF NOT EXISTS mode_configs(mode_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'custom\', action TEXT NOT NULL DEFAULT \'slowDown\', enabled INTEGER NOT NULL DEFAULT 1, start_minute INTEGER NOT NULL DEFAULT 0, end_minute INTEGER NOT NULL DEFAULT 0, schedule_kind TEXT NOT NULL DEFAULT \'daily\', weekdays TEXT NOT NULL DEFAULT \'1,2,3,4,5\', oneshot_at TEXT, assigned_child_ids TEXT NOT NULL DEFAULT \'\', category_restrictions TEXT NOT NULL DEFAULT \'\', app_restrictions TEXT NOT NULL DEFAULT \'\', priority INTEGER NOT NULL DEFAULT 50, note TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, mode_id))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS mode_activations(activation_id TEXT PRIMARY KEY, mode_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT, state TEXT NOT NULL DEFAULT \'requested\', started_at TEXT NOT NULL, ends_at TEXT, decided_by TEXT, created_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', FOREIGN KEY(family_id, mode_id) REFERENCES mode_configs(family_id, mode_id))');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_mode_configs_family ON mode_configs(family_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_mode_activations_family_time ON mode_activations(family_id, started_at DESC)');
    }
    if (oldVersion < 20) {
      // FS-006 — SOS & Emergency. Recipient roster with responder roles and
      // per-recipient acknowledgement tracking on SOS notifications. Every
      // DDL statement here is idempotent: legacy databases that passed
      // through the foundational schema guard (v29) already carry these.
      await db.execute(
          'CREATE TABLE IF NOT EXISTS sos_recipients(family_id TEXT NOT NULL REFERENCES families(id), recipient_id TEXT NOT NULL, role TEXT NOT NULL DEFAULT \'responder\', ordering INTEGER NOT NULL DEFAULT 0, added_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, recipient_id))');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sos_recipients_family ON sos_recipients(family_id, ordering)');
      await _addColumnIfMissing(
          db, 'notification_events', 'recipient_id', 'TEXT');
    }
    if (oldVersion < 21) {
      // FS-011 — Family Rules & Policy Engine. One coherent, versioned,
      // scheduled rule book per family; the execution log records every
      // honest verdict so nothing is ever silently overridden.
      await db.execute(
          'CREATE TABLE IF NOT EXISTS family_rules(rule_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'dailyScreenTime\', action TEXT NOT NULL DEFAULT \'restrict\', enabled INTEGER NOT NULL DEFAULT 1, start_minute INTEGER NOT NULL DEFAULT 0, end_minute INTEGER NOT NULL DEFAULT 0, schedule_kind TEXT NOT NULL DEFAULT \'daily\', weekdays TEXT NOT NULL DEFAULT \'1,2,3,4,5\', oneshot_at TEXT, assigned_child_ids TEXT NOT NULL DEFAULT \'\', app_targets TEXT NOT NULL DEFAULT \'\', category_targets TEXT NOT NULL DEFAULT \'\', geofence_ids TEXT NOT NULL DEFAULT \'\', geofence_trigger TEXT NOT NULL DEFAULT \'entering\', limit_minutes INTEGER, linked_task_id TEXT NOT NULL DEFAULT \'\', priority INTEGER NOT NULL DEFAULT 50, note TEXT, created_by_member_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, rule_id))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS rule_execution_log(id TEXT PRIMARY KEY, rule_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, outcome TEXT NOT NULL, reason TEXT NOT NULL, evaluated_at TEXT NOT NULL, FOREIGN KEY(family_id, rule_id) REFERENCES family_rules(family_id, rule_id))');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_family_rules_family ON family_rules(family_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_rule_execution_family_time ON rule_execution_log(family_id, evaluated_at DESC)');
    }
    if (oldVersion < 22) {
      // FS-007 — Family Tasks & Daily Schedules. Honest task status
      // machine plus an append-only completion log that `taskGated`
      // FS-011 rules read to open their gates.
      await db.execute(
          'CREATE TABLE IF NOT EXISTS tasks(task_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), title TEXT NOT NULL, description TEXT, due_minute INTEGER NOT NULL DEFAULT 0, due_date TEXT NOT NULL, recurrence TEXT NOT NULL DEFAULT \'none\', weekdays TEXT NOT NULL DEFAULT \'1,2,3,4,5\', assigned_child_ids TEXT NOT NULL DEFAULT \'\', linked_rule_id TEXT, status TEXT NOT NULL DEFAULT \'scheduled\', created_by_member_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, task_id))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS task_completion_log(id TEXT PRIMARY KEY, task_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, action TEXT NOT NULL, actor_member_id TEXT NOT NULL, acted_at TEXT NOT NULL, note TEXT, FOREIGN KEY(family_id, task_id) REFERENCES tasks(family_id, task_id))');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_family ON tasks(family_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_task_completion_family_time ON task_completion_log(family_id, acted_at DESC)');
    }
    if (oldVersion < 23) {
      // FS-008 — Family Points & Rewards. Append-only points ledger as
      // the sole balance source, the parent-authored catalog, and pending
      // redemption claims a parent decides before any deduction.
      await db.execute(
          'CREATE TABLE IF NOT EXISTS reward_points_ledger(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, delta INTEGER NOT NULL, reason TEXT NOT NULL, reference_id TEXT, balance_after INTEGER NOT NULL, acted_by TEXT NOT NULL, acted_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\')');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS family_rewards(reward_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, description TEXT, cost_points INTEGER NOT NULL, expiry_days INTEGER, enabled INTEGER NOT NULL DEFAULT 1, created_by_member_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, reward_id))');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS reward_pending_claims(claim_id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), reward_id TEXT NOT NULL, child_id TEXT NOT NULL, requested_at TEXT NOT NULL, decided_by TEXT, decision TEXT, decided_at TEXT, ledger_row_id TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', FOREIGN KEY(family_id, reward_id) REFERENCES family_rewards(family_id, reward_id))');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_reward_ledger_family_child ON reward_points_ledger(family_id, child_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_reward_ledger_family_time ON reward_points_ledger(family_id, acted_at DESC)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_reward_pending_claims_family_state ON reward_pending_claims(family_id, decision)');
    }
    if (oldVersion < 24) {
      // FS-007 bridge: `taskGated` FS-011 rules carry the id of the task
      // whose honest completion log opens the gate. Idempotent: only adds
      // the column when the schema does not already carry it.
      final cols = await db.rawQuery('PRAGMA table_info(family_rules)');
      if (!cols.any((Map r) => r['name'] == 'linked_task_id')) {
        await db.execute(
            "ALTER TABLE family_rules ADD COLUMN linked_task_id TEXT NOT NULL DEFAULT ''");
      }
    }

    if (oldVersion < 25) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS family_events(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), member_id TEXT, child_id TEXT, device_id TEXT, type TEXT NOT NULL, privacy_class TEXT NOT NULL DEFAULT \'operational\', attributes_json TEXT NOT NULL DEFAULT \'{}\', occurred_at TEXT NOT NULL, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_family_events_family_occurred ON family_events(family_id, occurred_at DESC)');
    }
    if (oldVersion < 25) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS normalized_signals(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT, signal_key TEXT NOT NULL, weight REAL NOT NULL DEFAULT 1.0, occurred_at TEXT NOT NULL, outcome TEXT NOT NULL DEFAULT \'allowed\', privacy_class TEXT NOT NULL DEFAULT \'operational\', source_event_id TEXT, reject_reason TEXT, consent_scope TEXT NOT NULL DEFAULT \'{}\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_normalized_signals_key ON normalized_signals(family_id, signal_key, occurred_at DESC)');
    }
    if (oldVersion < 25) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS ai_consent_scopes(family_id TEXT PRIMARY KEY REFERENCES families(id), consent_scope TEXT NOT NULL DEFAULT \'{}\', updated_at TEXT NOT NULL)');
    }
    if (oldVersion < 25) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS source_event_tracking(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), source_event_id TEXT NOT NULL, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_source_events_family ON source_event_tracking(family_id, source_event_id)');
    }
    if (oldVersion < 26) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS ai_risk_states(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, level TEXT NOT NULL DEFAULT \'safe\', deterministic_only INTEGER NOT NULL DEFAULT 1, contributors_json TEXT NOT NULL DEFAULT \'[]\', evaluated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ai_risk_states_family ON ai_risk_states(family_id, child_id, evaluated_at DESC)');
    }
    if (oldVersion < 26) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS ai_behavior_profiles(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, weekday INTEGER NOT NULL, hour INTEGER NOT NULL, usage_seconds REAL NOT NULL DEFAULT 0.0, deviation_percent REAL NOT NULL DEFAULT 0.0, window_start TEXT NOT NULL, window_end TEXT NOT NULL, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ai_behavior_profile ON ai_behavior_profiles(family_id, child_id, weekday, hour)');
    }
    if (oldVersion < 26) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS ai_insights(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), category TEXT NOT NULL, severity TEXT NOT NULL DEFAULT \'info\', title TEXT NOT NULL, body TEXT NOT NULL, evidence_json TEXT NOT NULL DEFAULT \'[]\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ai_insights_family ON ai_insights(family_id, created_at DESC)');
    }
    if (oldVersion < 26) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS ai_detections(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT, category TEXT NOT NULL, severity_band TEXT NOT NULL, confidence_band TEXT NOT NULL, source TEXT NOT NULL, model_version TEXT NOT NULL, reference_id TEXT, detected_at TEXT NOT NULL, reviewed INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ai_detections_family ON ai_detections(family_id, detected_at DESC)');
    }
    if (oldVersion < 26) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS ai_copilot_suggestions(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), period TEXT NOT NULL, period_start TEXT NOT NULL, period_end TEXT NOT NULL, body_json TEXT NOT NULL DEFAULT \'\', evidence_json TEXT NOT NULL DEFAULT \'[]\', data_sufficiency TEXT NOT NULL DEFAULT \'insufficient\', status TEXT NOT NULL DEFAULT \'proposed\', applied_at TEXT, dismissed_at TEXT, outcome_note TEXT, effect_after_days TEXT, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ai_copilot_suggestions_family ON ai_copilot_suggestions(family_id, created_at DESC)');
    }
    if (oldVersion < 26) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS ai_policy_proposals(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), title TEXT NOT NULL, body TEXT, rationale TEXT, status TEXT NOT NULL DEFAULT \'pending\', reason_json TEXT NOT NULL DEFAULT \'[]\', applied_at TEXT, dismissed_at TEXT, outcome_note TEXT, effect_after_days TEXT, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ai_policy_proposals_family ON ai_policy_proposals(family_id, status, created_at DESC)');
    }
    if (oldVersion < 27) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS couple_linking(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), partner_member_id TEXT NOT NULL, request_state TEXT NOT NULL DEFAULT \'requested\', requested_by TEXT, requested_at TEXT NOT NULL, responded_at TEXT, created_at TEXT NOT NULL DEFAULT \'\')');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_couple_linking_family ON couple_linking(family_id, request_state)');
    }
    if (oldVersion < 27) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS couple_proposals(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), kind TEXT NOT NULL, title TEXT NOT NULL, body TEXT, proposed_by TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'pending\', reviewed_by TEXT, reviewed_at TEXT, expires_at TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT \'\')');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_couple_proposals_family ON couple_proposals(family_id, status, expires_at)');
    }
    if (oldVersion < 27) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS couple_routines(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), title TEXT NOT NULL, assigned_child_ids TEXT NOT NULL DEFAULT \'\', weekdays TEXT NOT NULL DEFAULT \'\', start_minute INTEGER NOT NULL, end_minute INTEGER NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, created_by TEXT, created_at TEXT NOT NULL DEFAULT \'\', updated_at TEXT NOT NULL DEFAULT \'\')');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_couple_routines_family ON couple_routines(family_id, enabled)');
    }
    if (oldVersion < 27) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS couple_responsibilities(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), area TEXT NOT NULL, owner_member_id TEXT NOT NULL, delegate_member_id TEXT, effective_from TEXT NOT NULL, effective_until TEXT, created_at TEXT NOT NULL DEFAULT \'\')');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_couple_responsibilities_family ON couple_responsibilities(family_id, area)');
    }
    if (oldVersion < 27) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS couple_handovers(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), from_member_id TEXT NOT NULL, to_member_id TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'pending\', requested_at TEXT NOT NULL, completed_at TEXT, created_at TEXT NOT NULL DEFAULT \'\')');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_couple_handovers_family_status ON couple_handovers(family_id, status, requested_at DESC)');
    }
    if (oldVersion < 28) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS subscription_entitlements(family_id TEXT NOT NULL REFERENCES families(id), feature TEXT NOT NULL, granted INTEGER NOT NULL DEFAULT 0, policy TEXT NOT NULL DEFAULT \'local\', granted_at TEXT, expires_at TEXT, PRIMARY KEY(family_id, feature))');
    }
    if (oldVersion < 28) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS subscription_usage_limits(family_id TEXT NOT NULL REFERENCES families(id), feature TEXT NOT NULL, used INTEGER NOT NULL DEFAULT 0, limit_ INTEGER NOT NULL DEFAULT 0, period_start TEXT NOT NULL, period_end TEXT NOT NULL, PRIMARY KEY(family_id, feature))');
    }
    if (oldVersion < 28) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS billing_records(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), kind TEXT NOT NULL DEFAULT \'purchase\', amount_minor_units INTEGER NOT NULL DEFAULT 0, currency TEXT NOT NULL DEFAULT \'USD\', status TEXT NOT NULL DEFAULT \'pending\', reference TEXT, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_billing_family_time ON billing_records(family_id, created_at DESC)');
    }
    // Phase 3 — notification preferences. One row keyed by 'notification';
    // preferences are per-user-per-device, never shared between families.
    // CREATE IF NOT EXISTS keeps this idempotent across any version path.
    if (oldVersion < 29) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS notification_settings(key TEXT PRIMARY KEY, render_enabled INTEGER NOT NULL DEFAULT 1, dispatch_enabled INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL)');
    }
    // Phase 3 — stable device identity for FCM token registration.
    if (oldVersion < 29) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS app_identity(key TEXT PRIMARY KEY, value TEXT NOT NULL, created_at TEXT NOT NULL)');
    }
    // FS-010 — Ephemeral Family Chat. Two new tables: role-scoped threads
    // (`chat_threads`) and the messages themselves (`chat_messages`). The
    // foundational `messages` table (v1) is left untouched — it carries its
    // own legacy contract and is already classified as purged in the
    // Phase 4C purge domain contract.
    //
    // Expiration is timezone-independent: `expires_at` is always a UTC
    // instant (`created_at + approved window`) and expiry is evaluated in
    // UTC at read/query time. Expired rows are never surfaced as active.
    if (oldVersion < 30) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS chat_threads(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), type TEXT NOT NULL, member_id TEXT, expiration_window TEXT NOT NULL DEFAULT \'hours24\', created_by_member_id TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_chat_threads_family ON chat_threads(family_id)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS chat_messages(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), thread_id TEXT NOT NULL REFERENCES chat_threads(id), sender_member_id TEXT NOT NULL, body TEXT NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL, state TEXT NOT NULL DEFAULT \'queued\', idempotency_key TEXT NOT NULL UNIQUE, outbox_event_id TEXT)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_chat_messages_thread_time ON chat_messages(thread_id, created_at DESC)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_chat_messages_expiry ON chat_messages(thread_id, expires_at)');
    }

    // FS-014 — PD-003 Join Existing Family. Adds a human-readable invitation
    // code (e.g. 6-digit) to support joining without an email deep link.
    // Existing invitations get a null code; new invitations will generate
    // one during creation.
    if (oldVersion < 31) {
      // FS-014 PD-003 Join Existing Family. Column presence is checked
      // explicitly because legacy databases that passed through the foundational
      // schema guard (v29) might not carry family_invitations yet if they
      // never crossed the v12 threshold.
      final tables = await db.query('sqlite_master',
          columns: ['name'],
          where: "type = 'table' AND name = ?",
          whereArgs: ['family_invitations']);
      if (tables.isNotEmpty) {
        await _addColumnIfMissing(db, 'family_invitations', 'code', 'TEXT');
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_family_invitations_code ON family_invitations(code) WHERE code IS NOT NULL');
      }
    }
  }
}
