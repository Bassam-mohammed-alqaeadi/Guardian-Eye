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
  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = _pathResolver != null
        ? await _pathResolver!()
        : join(await getDatabasesPath(), 'guardian_eye_pro.db');
    final options = OpenDatabaseOptions(
        version: 21,
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
        'CREATE TABLE family_invitations(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), inviter_member_id TEXT NOT NULL REFERENCES family_members(id), target_email TEXT NOT NULL, proposed_role TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL, accepted_at TEXT, accepted_account_uid TEXT, accepted_member_id TEXT REFERENCES family_members(id), cancelled_at TEXT)');
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
        "CREATE UNIQUE INDEX idx_exception_pending_target ON child_exception_requests(child_device_id, target) WHERE status = 'pending'");
    batch.execute(
        'CREATE INDEX idx_exception_family_status_created ON child_exception_requests(family_id, status, created_at DESC)');
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
        'CREATE TABLE family_rules(rule_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'dailyScreenTime\', action TEXT NOT NULL DEFAULT \'restrict\', enabled INTEGER NOT NULL DEFAULT 1, start_minute INTEGER NOT NULL DEFAULT 0, end_minute INTEGER NOT NULL DEFAULT 0, schedule_kind TEXT NOT NULL DEFAULT \'daily\', weekdays TEXT NOT NULL DEFAULT \'1,2,3,4,5\', oneshot_at TEXT, assigned_child_ids TEXT NOT NULL DEFAULT \'\', app_targets TEXT NOT NULL DEFAULT \'\', category_targets TEXT NOT NULL DEFAULT \'\', geofence_ids TEXT NOT NULL DEFAULT \'\', geofence_trigger TEXT NOT NULL DEFAULT \'entering\', limit_minutes INTEGER, priority INTEGER NOT NULL DEFAULT 50, note TEXT, created_by_member_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, rule_id))');
    batch.execute(
        'CREATE TABLE rule_execution_log(id TEXT PRIMARY KEY, rule_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, outcome TEXT NOT NULL, reason TEXT NOT NULL, evaluated_at TEXT NOT NULL, FOREIGN KEY(family_id, rule_id) REFERENCES family_rules(family_id, rule_id))');
    batch.execute(
        'CREATE INDEX idx_family_rules_family ON family_rules(family_id)');
    batch.execute(
        'CREATE INDEX idx_rule_execution_family_time ON rule_execution_log(family_id, evaluated_at DESC)');
    await batch.commit(noResult: true);
    // Per-recipient acknowledgement tracking on the existing notification
    // channel (NULL preserves legacy rows and outbox semantics).
    await db.execute(
        'ALTER TABLE notification_events ADD COLUMN recipient_id TEXT');
  }

  Future<void> _upgradeSchema(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'CREATE TABLE sos_events(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT, status TEXT NOT NULL, latitude REAL, longitude REAL, accuracy_m REAL, created_at TEXT NOT NULL, delivered_at TEXT)');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE devices ADD COLUMN owner_member_id TEXT');
      await db.execute('ALTER TABLE devices ADD COLUMN revoked_at TEXT');
      await db.execute(
          'ALTER TABLE pairing_sessions ADD COLUMN target_member_id TEXT');
      await db.execute(
          "ALTER TABLE pairing_sessions ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'");
      await db.execute(
          'ALTER TABLE pairing_sessions ADD COLUMN failure_count INTEGER NOT NULL DEFAULT 0');
      await db
          .execute('ALTER TABLE pairing_sessions ADD COLUMN verified_at TEXT');
      await db.execute(
          'ALTER TABLE pairing_sessions ADD COLUMN enrolled_device_id TEXT');
      await db.execute(
          'CREATE INDEX idx_pairing_family_state ON pairing_sessions(family_id, status, expires_at)');
    }
    if (oldVersion < 4) {
      await db.execute(
          'CREATE TABLE policy_overrides(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, allowed INTEGER NOT NULL, expires_at TEXT NOT NULL, revoked_at TEXT, created_by_member_id TEXT NOT NULL, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX idx_policy_overrides_active ON policy_overrides(family_id, target, expires_at)');
    }
    if (oldVersion < 5) {
      await db.execute(
          'CREATE TABLE notification_events(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), incident_id TEXT, sos_id TEXT, kind TEXT NOT NULL, status TEXT NOT NULL, requested_at TEXT NOT NULL, acknowledged_at TEXT, last_error TEXT)');
      await db.execute(
          'CREATE INDEX idx_notifications_family_state ON notification_events(family_id, status, requested_at)');
    }
    if (oldVersion < 6) {
      await db.execute(
          'CREATE TABLE notification_tokens(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT NOT NULL, user_uid TEXT NOT NULL, token TEXT NOT NULL, platform TEXT NOT NULL, status TEXT NOT NULL, updated_at TEXT NOT NULL, revoked_at TEXT)');
      await db.execute(
          'CREATE UNIQUE INDEX idx_notification_token_active ON notification_tokens(device_id, token)');
    }
    if (oldVersion < 7) {
      await db.execute(
          'CREATE TABLE child_device_states(device_id TEXT PRIMARY KEY REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), member_id TEXT NOT NULL, lifecycle TEXT NOT NULL, required_policy_version INTEGER NOT NULL DEFAULT 0, last_valid_policy_at TEXT, last_evaluation_at TEXT, last_decision TEXT, last_sync_at TEXT, failure_code TEXT, updated_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE child_device_policies(device_id TEXT NOT NULL REFERENCES devices(id), policy_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), version INTEGER NOT NULL, payload_json TEXT NOT NULL, delivered_at TEXT NOT NULL, PRIMARY KEY(device_id, policy_id))');
      await db.execute(
          'CREATE TABLE child_enforcement_evaluations(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), outcome TEXT NOT NULL, reason TEXT NOT NULL, policy_id TEXT, policy_version INTEGER, evaluated_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX idx_child_policy_device_version ON child_device_policies(device_id, version DESC)');
      await db.execute(
          'CREATE INDEX idx_child_evaluations_device_time ON child_enforcement_evaluations(device_id, evaluated_at DESC)');
    }
    if (oldVersion < 8) {
      await db.execute(
          'CREATE TABLE child_usage_summaries(device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), day_start TEXT NOT NULL, target TEXT NOT NULL, total_milliseconds INTEGER NOT NULL, last_used_at TEXT, captured_at TEXT NOT NULL, PRIMARY KEY(device_id, day_start, target))');
      await db.execute(
          'CREATE TABLE child_usage_observations(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, total_milliseconds INTEGER NOT NULL, observed_at TEXT NOT NULL, source TEXT NOT NULL, captured_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX idx_child_usage_device_day ON child_usage_summaries(device_id, day_start DESC)');
    }
    if (oldVersion < 9) {
      await db.execute(
          'CREATE TABLE child_usage_evaluations(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, status TEXT NOT NULL, reason TEXT NOT NULL, used_milliseconds INTEGER NOT NULL, limit_milliseconds INTEGER, policy_id TEXT, policy_version INTEGER, evaluated_at TEXT NOT NULL)');
      await db.execute(
          'CREATE INDEX idx_child_usage_evaluations_device_time ON child_usage_evaluations(device_id, evaluated_at DESC)');
    }
    if (oldVersion < 10) {
      await db.execute(
          'CREATE TABLE child_exception_requests(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_device_id TEXT NOT NULL REFERENCES devices(id), child_member_id TEXT NOT NULL REFERENCES family_members(id), child_uid TEXT NOT NULL, target TEXT NOT NULL, policy_id TEXT, requested_duration_minutes INTEGER NOT NULL, reason TEXT NOT NULL, reason_detail TEXT, status TEXT NOT NULL, created_at TEXT NOT NULL, request_expires_at TEXT NOT NULL, reviewed_by_member_id TEXT REFERENCES family_members(id), reviewed_at TEXT, override_id TEXT REFERENCES policy_overrides(id), expires_at TEXT)');
      await db.execute(
          "CREATE UNIQUE INDEX idx_exception_pending_target ON child_exception_requests(child_device_id, target) WHERE status = 'pending'");
      await db.execute(
          'CREATE INDEX idx_exception_family_status_created ON child_exception_requests(family_id, status, created_at DESC)');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE policy_overrides ADD COLUMN child_device_id TEXT REFERENCES devices(id)');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE family_members ADD COLUMN status TEXT NOT NULL DEFAULT \'active\'');
      await db.execute('ALTER TABLE family_members ADD COLUMN account_uid TEXT');
      await db.execute('ALTER TABLE family_members ADD COLUMN invitation_id TEXT');
      await db.execute('ALTER TABLE family_members ADD COLUMN invited_at TEXT');
      await db.execute('ALTER TABLE family_members ADD COLUMN joined_at TEXT');
      await db.execute('ALTER TABLE family_members ADD COLUMN revoked_at TEXT');
      await db.execute('ALTER TABLE family_members ADD COLUMN updated_at TEXT');
      await db.execute(
          'CREATE TABLE family_invitations(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), inviter_member_id TEXT NOT NULL REFERENCES family_members(id), target_email TEXT NOT NULL, proposed_role TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL, accepted_at TEXT, accepted_account_uid TEXT, accepted_member_id TEXT REFERENCES family_members(id), cancelled_at TEXT)');
      await db.execute('CREATE INDEX idx_members_family_status ON family_members(family_id, status)');
      await db.execute("CREATE UNIQUE INDEX idx_members_family_account_active ON family_members(family_id, account_uid) WHERE account_uid IS NOT NULL AND status = 'active'");
      await db.execute('CREATE INDEX idx_invitations_family_status_expiry ON family_invitations(family_id, status, expires_at)');
      await db.execute('CREATE INDEX idx_invitations_target_status ON family_invitations(target_email, status, expires_at)');
    }
    if (oldVersion < 13) {
      await db.execute(
          'CREATE TABLE child_enforcement_states(id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id), family_id TEXT NOT NULL REFERENCES families(id), state TEXT NOT NULL, outcome TEXT, reason TEXT NOT NULL, decided_at TEXT NOT NULL, applied_at TEXT, policy_version INTEGER, enqueued_for_sync INTEGER NOT NULL DEFAULT 0)');
      await db.execute(
          'CREATE INDEX idx_enforcement_states_device_time ON child_enforcement_states(device_id, decided_at DESC)');
    }
    if (oldVersion < 14) {
      // Add device identity fields to incidents for Firestore authorization.
      // SQLite ALTER TABLE only supports ADD COLUMN — no-op if already present
      // (new installs hit onCreate, not onUpgrade).
      await db.execute('ALTER TABLE incidents ADD COLUMN device_id TEXT');
      await db.execute('ALTER TABLE incidents ADD COLUMN actor_uid TEXT');
    }
    if (oldVersion < 15) {
      // FS-002 — Web Filtering tables (see onCreate for schema docs).
      await db.execute(
          'CREATE TABLE web_hits(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, child_display_name TEXT, domain TEXT NOT NULL, category TEXT NOT NULL DEFAULT \'other\', blocked_at TEXT NOT NULL, decision TEXT NOT NULL DEFAULT \'blocked\', overridden_by TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE web_domains(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), domain TEXT NOT NULL, kind TEXT NOT NULL, reason TEXT, enabled INTEGER NOT NULL DEFAULT 1, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE web_category_rules(family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, child_display_name TEXT, category TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, sync_state TEXT NOT NULL DEFAULT \'queued\', updated_at TEXT NOT NULL, PRIMARY KEY(family_id, child_id, category))');
      await db.execute(
          'CREATE TABLE web_settings(family_id TEXT NOT NULL REFERENCES families(id), key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(family_id, key))');
      await db.execute(
          'CREATE INDEX idx_web_hits_family_time ON web_hits(family_id, blocked_at DESC)');
      await db.execute(
          'CREATE INDEX idx_web_domains_family_kind ON web_domains(family_id, kind)');
    }
    if (oldVersion < 16) {
      // FS-001 — Location & Geofencing (see onCreate for schema docs).
      await db.execute(
          'CREATE TABLE location_points(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT, member_id TEXT, latitude REAL NOT NULL, longitude REAL NOT NULL, accuracy_meters REAL NOT NULL DEFAULT 100, captured_at TEXT NOT NULL, battery_level REAL, source TEXT NOT NULL DEFAULT \'device\', sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE geofences(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, radius_meters REAL NOT NULL, alert_on_entry INTEGER NOT NULL DEFAULT 1, alert_on_exit INTEGER NOT NULL DEFAULT 1, member_ids_json TEXT, place_key TEXT, status TEXT NOT NULL DEFAULT \'active\', sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE location_alerts(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), geofence_id TEXT, member_id TEXT, member_display_name TEXT, event_type TEXT NOT NULL, occurred_at TEXT NOT NULL, acknowledged INTEGER NOT NULL DEFAULT 0, acknowledged_at TEXT, device_id TEXT, source TEXT NOT NULL DEFAULT \'geofence\', sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE favorite_places(family_id TEXT NOT NULL REFERENCES families(id), place_key TEXT NOT NULL, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, notes TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', created_at TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(family_id, place_key))');
      await db.execute(
          'CREATE TABLE location_settings(family_id TEXT NOT NULL REFERENCES families(id), key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(family_id, key))');
      await db.execute(
          'CREATE INDEX idx_location_points_family_time ON location_points(family_id, captured_at DESC)');
      await db.execute(
          'CREATE INDEX idx_location_alerts_family_time ON location_alerts(family_id, occurred_at DESC)');
    }
    if (oldVersion < 17) {
      // FS-003 — Application Control (see onCreate for schema docs).
      await db.execute(
          'CREATE TABLE app_policies(family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL DEFAULT \'\', target TEXT NOT NULL, action TEXT NOT NULL, limit_milliseconds INTEGER, rating_max TEXT NOT NULL DEFAULT \'all\', sync_state TEXT NOT NULL DEFAULT \'queued\', updated_at TEXT NOT NULL, PRIMARY KEY(family_id, child_id, target))');
      await db.execute(
          'CREATE TABLE app_allowlist(family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, reason TEXT, added_by TEXT, created_at TEXT NOT NULL, PRIMARY KEY(family_id, target))');
      await db.execute(
          'CREATE TABLE app_block_history(id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), target TEXT NOT NULL, child_id TEXT, event TEXT NOT NULL, reason TEXT, created_at TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE usage_alert_settings(family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT, target TEXT NOT NULL, threshold_milliseconds INTEGER NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL, PRIMARY KEY(family_id, target))');
      await db.execute(
          'CREATE INDEX idx_app_block_history_family_time ON app_block_history(family_id, created_at DESC)');
      await db.execute(
          'CREATE INDEX idx_app_policies_family ON app_policies(family_id)');
    }
    if (oldVersion < 18) {
      // FS-004 — Screenshot & Camera Control (see onCreate for schema docs).
      await db.execute(
          'CREATE TABLE monitoring_shots(family_id TEXT NOT NULL REFERENCES families(id), shot_id TEXT NOT NULL, device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, captured_at TEXT NOT NULL, bytes_length INTEGER NOT NULL DEFAULT 0, mime_type TEXT NOT NULL DEFAULT \'image/png\', request_id TEXT, schedule_id TEXT, is_evidence INTEGER NOT NULL DEFAULT 0, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, shot_id))');
      await db.execute(
          'CREATE TABLE monitoring_sessions(session_id TEXT PRIMARY KEY, family_id TEXT NOT NULL REFERENCES families(id), device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, kind TEXT NOT NULL DEFAULT \'live\', state TEXT NOT NULL DEFAULT \'pending\', started_at TEXT, ended_at TEXT, created_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\')');
      await db.execute(
          'CREATE TABLE monitoring_requests(family_id TEXT NOT NULL REFERENCES families(id), request_id TEXT NOT NULL, device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, kind TEXT NOT NULL, state TEXT NOT NULL DEFAULT \'queued\', reason TEXT, created_at TEXT NOT NULL, delivered_at TEXT, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, request_id))');
      await db.execute(
          'CREATE TABLE monitoring_schedules(family_id TEXT NOT NULL REFERENCES families(id), schedule_id TEXT NOT NULL, device_id TEXT REFERENCES devices(id), child_id TEXT, start_hour INTEGER NOT NULL, end_hour INTEGER NOT NULL, interval_minutes INTEGER NOT NULL DEFAULT 30, enabled INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, schedule_id))');
      await db.execute(
          'CREATE TABLE monitoring_evidence_queue(family_id TEXT NOT NULL REFERENCES families(id), evidence_id TEXT NOT NULL, shot_id TEXT NOT NULL, device_id TEXT NOT NULL REFERENCES devices(id), child_id TEXT, flag_reason TEXT NOT NULL, state TEXT NOT NULL DEFAULT \'queued\', decided_by TEXT, decided_at TEXT, created_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, evidence_id))');
      await db.execute(
          'CREATE INDEX idx_monitoring_shots_family_time ON monitoring_shots(family_id, captured_at DESC)');
      await db.execute(
          'CREATE INDEX idx_monitoring_evidence_family_state ON monitoring_evidence_queue(family_id, state)');
    }
    if (oldVersion < 19) {
      // FS-005 — Special & Custom Modes. Situational modes with schedules,
      // child assignment and honest activation logs (never fake `applied`).
      await db.execute(
          'CREATE TABLE mode_configs(mode_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'custom\', action TEXT NOT NULL DEFAULT \'slowDown\', enabled INTEGER NOT NULL DEFAULT 1, start_minute INTEGER NOT NULL DEFAULT 0, end_minute INTEGER NOT NULL DEFAULT 0, schedule_kind TEXT NOT NULL DEFAULT \'daily\', weekdays TEXT NOT NULL DEFAULT \'1,2,3,4,5\', oneshot_at TEXT, assigned_child_ids TEXT NOT NULL DEFAULT \'\', category_restrictions TEXT NOT NULL DEFAULT \'\', app_restrictions TEXT NOT NULL DEFAULT \'\', priority INTEGER NOT NULL DEFAULT 50, note TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, mode_id))');
      await db.execute(
          'CREATE TABLE mode_activations(activation_id TEXT PRIMARY KEY, mode_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT, state TEXT NOT NULL DEFAULT \'requested\', started_at TEXT NOT NULL, ends_at TEXT, decided_by TEXT, created_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', FOREIGN KEY(family_id, mode_id) REFERENCES mode_configs(family_id, mode_id))');
      await db.execute(
          'CREATE INDEX idx_mode_configs_family ON mode_configs(family_id)');
      await db.execute(
          'CREATE INDEX idx_mode_activations_family_time ON mode_activations(family_id, started_at DESC)');
    }
    if (oldVersion < 20) {
      // FS-006 — SOS & Emergency. Recipient roster with responder roles and
      // per-recipient acknowledgement tracking on SOS notifications.
      await db.execute(
          'CREATE TABLE sos_recipients(family_id TEXT NOT NULL REFERENCES families(id), recipient_id TEXT NOT NULL, role TEXT NOT NULL DEFAULT \'responder\', ordering INTEGER NOT NULL DEFAULT 0, added_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, recipient_id))');
      await db.execute(
          'CREATE INDEX idx_sos_recipients_family ON sos_recipients(family_id, ordering)');
      await db.execute(
          'ALTER TABLE notification_events ADD COLUMN recipient_id TEXT');
    }
    if (oldVersion < 21) {
      // FS-011 — Family Rules & Policy Engine. One coherent, versioned,
      // scheduled rule book per family; the execution log records every
      // honest verdict so nothing is ever silently overridden.
      await db.execute(
          'CREATE TABLE family_rules(rule_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'dailyScreenTime\', action TEXT NOT NULL DEFAULT \'restrict\', enabled INTEGER NOT NULL DEFAULT 1, start_minute INTEGER NOT NULL DEFAULT 0, end_minute INTEGER NOT NULL DEFAULT 0, schedule_kind TEXT NOT NULL DEFAULT \'daily\', weekdays TEXT NOT NULL DEFAULT \'1,2,3,4,5\', oneshot_at TEXT, assigned_child_ids TEXT NOT NULL DEFAULT \'\', app_targets TEXT NOT NULL DEFAULT \'\', category_targets TEXT NOT NULL DEFAULT \'\', geofence_ids TEXT NOT NULL DEFAULT \'\', geofence_trigger TEXT NOT NULL DEFAULT \'entering\', limit_minutes INTEGER, priority INTEGER NOT NULL DEFAULT 50, note TEXT, created_by_member_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT \'queued\', PRIMARY KEY(family_id, rule_id))');
      await db.execute(
          'CREATE TABLE rule_execution_log(id TEXT PRIMARY KEY, rule_id TEXT NOT NULL, family_id TEXT NOT NULL REFERENCES families(id), child_id TEXT NOT NULL, outcome TEXT NOT NULL, reason TEXT NOT NULL, evaluated_at TEXT NOT NULL, FOREIGN KEY(family_id, rule_id) REFERENCES family_rules(family_id, rule_id))');
      await db.execute(
          'CREATE INDEX idx_family_rules_family ON family_rules(family_id)');
      await db.execute(
          'CREATE INDEX idx_rule_execution_family_time ON rule_execution_log(family_id, evaluated_at DESC)');
    }
  }
}
