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
                'session': value.session?.toJson(),
                'examWordIds': value.examWordIds,
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
      session: json['session'] == null
          ? null
          : StudySession.fromJson(json['session']),
      examWordIds: List<String>.from(json['examWordIds']),
    );
  }

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
    _snapshot = _clone(
      LearningSnapshot(
        progress: _snapshot.progress,
        events: _snapshot.events,
        session: session,
        examWordIds: _snapshot.examWordIds,
      ),
    );
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
    _snapshot = _clone(
      LearningSnapshot(
        progress: updatedProgress.values.toList(),
        events: updatedEvents.values.toList(),
        session: session,
        examWordIds: _snapshot.examWordIds,
      ),
    );
  }

  @override
  Future<void> saveExamWords(List<String> ids) async {
    _beforeWrite();
    _snapshot = _clone(
      LearningSnapshot(
        progress: _snapshot.progress,
        events: _snapshot.events,
        session: _snapshot.session,
        examWordIds: ids,
      ),
    );
  }
}
