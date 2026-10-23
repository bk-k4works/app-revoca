import 'dart:convert';

import 'package:focus_voca/data/learning_store.dart';
import 'package:focus_voca/domain/learning.dart';

/// A persistence fake that cannot accidentally share mutable lists with callers.
/// Writes either replace the whole stored snapshot or fail before changing it.
class MemoryStore implements LearningStore {
  MemoryStore({LearningSnapshot initial = const LearningSnapshot()})
    : _snapshot = _clone(initial);

  LearningSnapshot _snapshot;
  bool failNextWrite = false;

  LearningSnapshot get snapshot => _clone(_snapshot);

  static LearningSnapshot _clone(LearningSnapshot value) {
    final json =
        jsonDecode(
              jsonEncode({
                'progress': value.progress
                    .map((item) => item.toJson())
                    .toList(),
                'events': value.events.map((item) => item.toJson()).toList(),
                'activities': value.activities
                    .map((item) => item.toJson())
                    .toList(),
                'session': value.session?.toJson(),
                'examWordIds': value.examWordIds,
                'favoriteWordIds': value.favoriteWordIds,
                'seenHints': value.seenHints,
                'settings': value.settings,
              }),
            )
            as Map<String, dynamic>;
    return LearningSnapshot(
      progress: (json['progress'] as List)
          .map((item) => LearningProgress.fromJson(item))
          .toList(),
      events: (json['events'] as List)
          .map((item) => ReviewEvent.fromJson(item))
          .toList(),
      activities: (json['activities'] as List)
          .map((item) => ActivityEvent.fromJson(item))
          .toList(),
      session: json['session'] == null
          ? null
          : StudySession.fromJson(json['session']),
      examWordIds: List<String>.from(json['examWordIds']),
      favoriteWordIds: List<String>.from(json['favoriteWordIds']),
      seenHints: List<String>.from(json['seenHints']),
      settings: json['settings'] == null
          ? null
          : Map<String, dynamic>.from(json['settings']),
    );
  }

  // The current snapshot with some parts replaced.
  LearningSnapshot _with({
    List<LearningProgress>? progress,
    List<ReviewEvent>? events,
    List<ActivityEvent>? activities,
    StudySession? Function()? session,
    List<String>? examWordIds,
    List<String>? favoriteWordIds,
    List<String>? seenHints,
    Map<String, dynamic>? settings,
  }) => _clone(
    LearningSnapshot(
      progress: progress ?? _snapshot.progress,
      events: events ?? _snapshot.events,
      activities: activities ?? _snapshot.activities,
      session: session == null ? _snapshot.session : session(),
      examWordIds: examWordIds ?? _snapshot.examWordIds,
      favoriteWordIds: favoriteWordIds ?? _snapshot.favoriteWordIds,
      seenHints: seenHints ?? _snapshot.seenHints,
      settings: settings ?? _snapshot.settings,
    ),
  );

  void _beforeWrite() {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Simulated storage write failure');
    }
  }

  @override
  Future<LearningSnapshot> load() async => snapshot;

  @override
  Future<void> migrateSenseIds(
    Map<String, String> migrations,
    Set<String> availableIds,
  ) async {
    if (migrations.isEmpty) return;
    _beforeWrite();
    _snapshot = _clone(
      migrateLearningSnapshot(_snapshot, migrations, availableIds),
    );
  }

  @override
  Future<void> saveSession(StudySession? session) async {
    _beforeWrite();
    _snapshot = _with(session: () => session);
  }

  @override
  Future<void> saveAnswer(
    ReviewEvent event,
    LearningProgress? progress,
    StudySession session,
  ) async {
    _beforeWrite();
    final updatedProgress = {
      for (final item in _snapshot.progress) item.key: item,
    };
    if (progress != null) updatedProgress[progress.key] = progress;
    final updatedEvents = {
      for (final item in _snapshot.events) item.id: item,
      event.id: event,
    };
    _snapshot = _with(
      progress: updatedProgress.values.toList(),
      events: updatedEvents.values.toList(),
      session: () => session,
    );
  }

  @override
  Future<void> saveExamWords(List<String> ids) async {
    _beforeWrite();
    _snapshot = _with(examWordIds: ids);
  }

  @override
  Future<void> saveActivities(
    List<ActivityEvent> activities, {
    StudySession? session,
  }) async {
    _beforeWrite();
    _snapshot = _with(
      activities: {
        for (final item in _snapshot.activities) item.id: item,
        for (final item in activities) item.id: item,
      }.values.toList(),
      session: session == null ? null : () => session,
    );
  }

  @override
  Future<void> saveFavoriteWords(List<String> ids) async {
    _beforeWrite();
    _snapshot = _with(favoriteWordIds: ids);
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    _beforeWrite();
    _snapshot = _with(settings: settings);
  }

  @override
  Future<void> saveSeenHints(List<String> hints) async {
    _beforeWrite();
    _snapshot = _with(seenHints: hints);
  }
}
