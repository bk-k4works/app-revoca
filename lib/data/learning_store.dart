import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../domain/learning.dart';

class LearningSnapshot {
  const LearningSnapshot({
    this.progress = const [],
    this.events = const [],
    this.activities = const [],
    this.session,
    this.examWordIds = const [],
    this.favoriteWordIds = const [],
    this.seenHints = const [],
    this.settings,
  });
  final List<LearningProgress> progress;
  final List<ReviewEvent> events;
  final List<ActivityEvent> activities;
  final StudySession? session;
  final List<String> examWordIds;

  /// Starred senses, most recently starred first.
  final List<String> favoriteWordIds;

  /// One-time guidance the student has already been shown.
  final List<String> seenHints;

  /// Saved [StudySettings] as JSON, or null before anything was changed.
  final Map<String, dynamic>? settings;
}

abstract interface class LearningStore {
  Future<void> migrateSenseIds(
    Map<String, String> migrations,
    Set<String> availableIds,
  );
  Future<LearningSnapshot> load();
  Future<void> saveSession(StudySession? session);
  Future<void> saveAnswer(
    ReviewEvent event,
    LearningProgress? progress,
    StudySession session,
  );
  Future<void> saveExamWords(List<String> ids);

  /// Stores [activities]; when [session] is given it is saved in the same
  /// write, otherwise the saved session is left as it is.
  Future<void> saveActivities(
    List<ActivityEvent> activities, {
    StudySession? session,
  });
  Future<void> saveFavoriteWords(List<String> ids);
  Future<void> saveSeenHints(List<String> hints);
  Future<void> saveSettings(Map<String, dynamic> settings);
}

/// Resolve chains first, preserve history for unavailable successors, and merge
/// progress collisions by the most recent review without creating new events.
LearningSnapshot migrateLearningSnapshot(
  LearningSnapshot snapshot,
  Map<String, String> migrations,
  Set<String> availableIds,
) {
  String resolve(String id) {
    var value = id;
    final seen = <String>{};
    while (migrations.containsKey(value)) {
      if (!seen.add(value)) {
        throw const FormatException('Cyclic sense migration.');
      }
      value = migrations[value]!;
    }
    return availableIds.contains(value) ? value : id;
  }

  for (final id in migrations.keys) {
    resolve(id);
  }
  final progress = <String, LearningProgress>{};
  for (final old in snapshot.progress) {
    final updated = LearningProgress.fromJson({
      ...old.toJson(),
      'wordId': resolve(old.wordId),
    });
    final existing = progress[updated.key];
    if (existing == null ||
        updated.lastReviewedAt.isAfter(existing.lastReviewedAt) ||
        (updated.lastReviewedAt == existing.lastReviewedAt &&
            updated.level < existing.level)) {
      progress[updated.key] = updated;
    }
  }
  final session = snapshot.session?.toJson();
  if (session != null) {
    session['wordIds'] = snapshot.session!.wordIds.map(resolve).toList();
    session['learningWordIds'] = snapshot.session!.learningWordIds
        .map(resolve)
        .toList();
    session['answers'] = snapshot.session!.answers
        .map((a) => {...a.toJson(), 'wordId': resolve(a.wordId)})
        .toList();
    if (snapshot.session!.stage == SessionStage.recall) {
      session['lastAnswer'] = resolve(snapshot.session!.lastAnswer);
    }
  }
  return LearningSnapshot(
    progress: progress.values.toList(),
    events: snapshot.events
        .map(
          (e) => ReviewEvent.fromJson({
            ...e.toJson(),
            'wordId': resolve(e.wordId),
          }),
        )
        .toList(),
    activities: snapshot.activities
        .map(
          (e) => ActivityEvent.fromJson({
            ...e.toJson(),
            'wordId': resolve(e.wordId),
          }),
        )
        .toList(),
    session: session == null ? null : StudySession.fromJson(session),
    examWordIds: snapshot.examWordIds.map(resolve).toSet().toList(),
    favoriteWordIds: snapshot.favoriteWordIds.map(resolve).toSet().toList(),
    seenHints: snapshot.seenHints,
    settings: snapshot.settings,
  );
}

class SqliteLearningStore implements LearningStore {
  SqliteLearningStore(this.database);
  final Database database;

  static Future<SqliteLearningStore> open({
    String filename = 'focus_voca_v1.db',
  }) async {
    final db = await openDatabase(
      path.join(await getDatabasesPath(), filename),
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createActivityTable(db);
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE progress (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE review_events (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE app_state (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        );
        await _createActivityTable(db);
      },
    );
    return SqliteLearningStore(db);
  }

  // Version 2: learn cards and listening, kept apart from answers.
  static Future<void> _createActivityTable(Database db) => db.execute(
    'CREATE TABLE activity_events (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
  );

  @override
  Future<LearningSnapshot> load() => _load(database);

  Future<LearningSnapshot> _load(DatabaseExecutor executor) async {
    final progress = await executor.query('progress');
    final events = await executor.query('review_events');
    final activities = await executor.query('activity_events');
    final state = {
      for (final row in await executor.query('app_state'))
        row['id'] as String: jsonDecode(row['payload'] as String),
    };
    return LearningSnapshot(
      progress: progress
          .map(
            (r) =>
                LearningProgress.fromJson(jsonDecode(r['payload'] as String)),
          )
          .toList(),
      events: events
          .map((r) => ReviewEvent.fromJson(jsonDecode(r['payload'] as String)))
          .toList(),
      activities: activities
          .map(
            (r) => ActivityEvent.fromJson(jsonDecode(r['payload'] as String)),
          )
          .toList(),
      session: state['session'] == null
          ? null
          : StudySession.fromJson(state['session']),
      examWordIds: List<String>.from(state['exam'] ?? []),
      favoriteWordIds: List<String>.from(state['favorites'] ?? []),
      seenHints: List<String>.from(state['hints'] ?? []),
      settings: state['settings'] is Map
          ? Map<String, dynamic>.from(state['settings'])
          : null,
    );
  }

  @override
  Future<void> migrateSenseIds(
    Map<String, String> migrations,
    Set<String> availableIds,
  ) async {
    if (migrations.isEmpty) return;
    await database.transaction((txn) async {
      final updated = migrateLearningSnapshot(
        await _load(txn),
        migrations,
        availableIds,
      );
      var activeSession = updated.session;
      final unavailable =
          activeSession?.wordIds
              .where((id) => !availableIds.contains(id))
              .toList() ??
          <String>[];
      final knownIds = {...migrations.keys, ...migrations.values};
      if (unavailable.isNotEmpty && unavailable.every(knownIds.contains)) {
        // A smaller release may temporarily omit a legacy sense. Preserve the
        // complete session separately instead of blocking startup or deleting it.
        await _put(
          txn,
          'app_state',
          'suspended_session:${activeSession!.id}',
          activeSession.toJson(),
        );
        activeSession = null;
      }
      if (activeSession == null) {
        final suspended = await txn.query(
          'app_state',
          where: "id LIKE 'suspended_session:%'",
          orderBy: 'rowid DESC',
        );
        for (final row in suspended) {
          final saved = StudySession.fromJson(
            jsonDecode(row['payload'] as String),
          );
          final restored = migrateLearningSnapshot(
            LearningSnapshot(session: saved),
            migrations,
            availableIds,
          ).session!;
          if (restored.wordIds.every(availableIds.contains)) {
            activeSession = restored;
            await txn.delete(
              'app_state',
              where: 'id=?',
              whereArgs: [row['id']],
            );
            break;
          }
        }
      }
      await txn.delete('progress');
      for (final item in updated.progress) {
        await _put(txn, 'progress', item.key, item.toJson());
      }
      for (final item in updated.events) {
        await _put(txn, 'review_events', item.id, item.toJson());
      }
      for (final item in updated.activities) {
        await _put(txn, 'activity_events', item.id, item.toJson());
      }
      await _put(txn, 'app_state', 'session', activeSession?.toJson());
      await _put(txn, 'app_state', 'exam', updated.examWordIds);
      await _put(txn, 'app_state', 'favorites', updated.favoriteWordIds);
    });
  }

  Future<void> _put(
    DatabaseExecutor db,
    String table,
    String id,
    Object? value,
  ) async {
    await db.insert(table, {
      'id': id,
      'payload': jsonEncode(value),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> saveSession(StudySession? session) =>
      _put(database, 'app_state', 'session', session?.toJson());

  @override
  Future<void> saveAnswer(
    ReviewEvent event,
    LearningProgress? progress,
    StudySession session,
  ) => database.transaction((txn) async {
    await _put(txn, 'review_events', event.id, event.toJson());
    if (progress != null) {
      await _put(txn, 'progress', progress.key, progress.toJson());
    }
    await _put(txn, 'app_state', 'session', session.toJson());
  });

  @override
  Future<void> saveExamWords(List<String> ids) =>
      _put(database, 'app_state', 'exam', ids);

  @override
  Future<void> saveActivities(
    List<ActivityEvent> activities, {
    StudySession? session,
  }) => database.transaction((txn) async {
    for (final item in activities) {
      await _put(txn, 'activity_events', item.id, item.toJson());
    }
    if (session != null) {
      await _put(txn, 'app_state', 'session', session.toJson());
    }
  });

  @override
  Future<void> saveFavoriteWords(List<String> ids) =>
      _put(database, 'app_state', 'favorites', ids);

  @override
  Future<void> saveSeenHints(List<String> hints) =>
      _put(database, 'app_state', 'hints', hints);

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) =>
      _put(database, 'app_state', 'settings', settings);
}
