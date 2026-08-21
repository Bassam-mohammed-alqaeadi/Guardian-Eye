import 'package:sqflite/sqflite.dart';
import '../domain/audio_monitoring.dart';
import '../domain/guardian_models.dart';
import '../core/database/guardian_database.dart';

class AudioRepository {
  const AudioRepository(this._db);
  final GuardianDatabase _db;

  Future<Database> get _database => _db.database;

  // ── Audio Sessions ─────────────────────────────────────────────────────────

  Future<List<AudioSession>> getSessions(String familyId, {int limit = 50}) async {
    final db = await _database;
    final maps = await db.query(
      'audio_sessions',
      where: 'family_id = ?',
      whereArgs: [familyId],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return maps.map(AudioSession.fromMap).toList();
  }

  Future<AudioSession?> getSessionById(String id) async {
    final db = await _database;
    final maps = await db.query(
      'audio_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AudioSession.fromMap(maps.first);
  }

  Future<void> saveSession(AudioSession session) async {
    final db = await _database;
    await db.insert(
      'audio_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSessionNotes(String sessionId, String notes) async {
    final db = await _database;
    await db.update(
      'audio_sessions',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ── Audio Keywords ─────────────────────────────────────────────────────────

  Future<List<AudioKeyword>> getKeywords(String familyId) async {
    final db = await _database;
    final maps = await db.query(
      'audio_keywords',
      where: 'family_id = ?',
      whereArgs: [familyId],
      orderBy: 'created_at ASC',
    );
    return maps.map(AudioKeyword.fromMap).toList();
  }

  Future<void> saveKeyword(AudioKeyword keyword) async {
    final db = await _database;
    await db.insert(
      'audio_keywords',
      keyword.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteKeyword(String id) async {
    final db = await _database;
    await db.delete(
      'audio_keywords',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleKeyword(String id, bool enabled) async {
    final db = await _database;
    await db.update(
      'audio_keywords',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Audio Policy ───────────────────────────────────────────────────────────

  Future<AudioPolicy> getPolicy(String familyId) async {
    final db = await _database;
    final maps = await db.query(
      'audio_policies',
      where: 'family_id = ?',
      whereArgs: [familyId],
      limit: 1,
    );
    if (maps.isEmpty) {
      return AudioPolicy(familyId: familyId);
    }
    return AudioPolicy.fromMap(maps.first);
  }

  Future<void> savePolicy(AudioPolicy policy) async {
    final db = await _database;
    await db.insert(
      'audio_policies',
      policy.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
