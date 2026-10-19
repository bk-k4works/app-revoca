/// How much and how the student studies; saved with the learning records.
class StudySettings {
  const StudySettings({
    this.dailyNewLimit = 20,
    this.sessionSize = 5,
    this.autoPlayWord = false,
    this.autoAdvance = false,
    this.reminder = false,
    this.reminderMinutes = 20 * 60,
  });

  static const dailyNewOptions = [10, 20, 30, 50];
  static const sessionSizeOptions = [5, 10, 15];

  /// New senses the today card introduces per day.
  final int dailyNewLimit;

  /// Senses in one round of learn, recall and spelling.
  final int sessionSize;

  /// Say the word when a learn card or recall question appears, and after a
  /// spelling answer. Never before a spelling answer, which it would give away.
  final bool autoPlayWord;

  /// Move on shortly after a correct answer; a wrong answer always waits.
  final bool autoAdvance;

  /// A daily reminder at [reminderMinutes] after midnight, local time.
  final bool reminder;
  final int reminderMinutes;

  StudySettings copyWith({
    int? dailyNewLimit,
    int? sessionSize,
    bool? autoPlayWord,
    bool? autoAdvance,
    bool? reminder,
    int? reminderMinutes,
  }) => StudySettings(
    dailyNewLimit: dailyNewLimit ?? this.dailyNewLimit,
    sessionSize: sessionSize ?? this.sessionSize,
    autoPlayWord: autoPlayWord ?? this.autoPlayWord,
    autoAdvance: autoAdvance ?? this.autoAdvance,
    reminder: reminder ?? this.reminder,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
  );

  Map<String, dynamic> toJson() => {
    'dailyNewLimit': dailyNewLimit,
    'sessionSize': sessionSize,
    'autoPlayWord': autoPlayWord,
    'autoAdvance': autoAdvance,
    'reminder': reminder,
    'reminderMinutes': reminderMinutes,
  };

  /// Unknown or out-of-range values fall back to the defaults, so an older or
  /// damaged record never blocks studying.
  factory StudySettings.fromJson(Map<String, dynamic>? json) {
    const defaults = StudySettings();
    if (json == null) return defaults;
    T pick<T>(String key, T fallback, [bool Function(T value)? valid]) {
      final value = json[key];
      return value is T && (valid == null || valid(value)) ? value : fallback;
    }

    return StudySettings(
      dailyNewLimit: pick(
        'dailyNewLimit',
        defaults.dailyNewLimit,
        dailyNewOptions.contains,
      ),
      sessionSize: pick(
        'sessionSize',
        defaults.sessionSize,
        sessionSizeOptions.contains,
      ),
      autoPlayWord: pick('autoPlayWord', defaults.autoPlayWord),
      autoAdvance: pick('autoAdvance', defaults.autoAdvance),
      reminder: pick('reminder', defaults.reminder),
      reminderMinutes: pick(
        'reminderMinutes',
        defaults.reminderMinutes,
        (m) => m >= 0 && m < 24 * 60,
      ),
    );
  }
}
