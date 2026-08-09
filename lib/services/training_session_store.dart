import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Mid-workout pause / exit snapshot for the camera coach.
///
/// Persist via [TrainingSessionStore]; restore on re-entry to continue
/// the same exercise (or plan sequence) with accumulated pause bonus.
class TrainingSession {
  static const int currentVersion = 1;

  /// Schema version for forward-compatible migrations.
  final int version;

  /// [ExerciseType.type] id, e.g. `pushup`, `plank`.
  final String exerciseType;

  /// Index into [Exercises.all].
  final int exerciseIndex;

  final String exerciseName;

  /// Index within an active [plan]; `-1` for a single (non-plan) session.
  final int planSeqIndex;

  /// Essentials of the active workout plan; null when not in a plan.
  final TrainingPlanSnapshot? plan;

  /// Reps completed so far for the current exercise (0 for timed).
  final int repCount;

  /// Active training time in seconds, excluding pause gaps.
  final int elapsedActiveSeconds;

  /// When the user paused / exited mid-workout; null if not paused.
  final DateTime? pausedAt;

  /// Extra seconds (or converted reps) granted due to pause gaps.
  /// Capped at [TrainingSessionStore.maxBonusSeconds] when accumulated.
  final int bonusSeconds;

  /// Base target for the current item (seconds if [isTimed], else reps).
  final int target;

  /// true = timed hold (e.g. plank); false = rep-counted.
  final bool isTimed;

  const TrainingSession({
    this.version = currentVersion,
    required this.exerciseType,
    required this.exerciseIndex,
    required this.exerciseName,
    this.planSeqIndex = -1,
    this.plan,
    this.repCount = 0,
    this.elapsedActiveSeconds = 0,
    this.pausedAt,
    this.bonusSeconds = 0,
    required this.target,
    required this.isTimed,
  });

  /// Effective goal after pause bonus.
  ///
  /// Timed: [target] + [bonusSeconds].
  /// Reps: bonus converts at ~1 rep per [TrainingSessionStore.secondsPerBonusRep]
  /// seconds (`bonusSeconds ~/ 4`), then added to [target].
  int get effectiveTarget {
    if (isTimed) return target + bonusSeconds;
    return target +
        (bonusSeconds ~/ TrainingSessionStore.secondsPerBonusRep);
  }

  /// Reps granted from [bonusSeconds] (rep exercises only; 0 when timed).
  int get bonusReps =>
      isTimed ? 0 : bonusSeconds ~/ TrainingSessionStore.secondsPerBonusRep;

  TrainingSession copyWith({
    int? version,
    String? exerciseType,
    int? exerciseIndex,
    String? exerciseName,
    int? planSeqIndex,
    TrainingPlanSnapshot? plan,
    bool clearPlan = false,
    int? repCount,
    int? elapsedActiveSeconds,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    int? bonusSeconds,
    int? target,
    bool? isTimed,
  }) {
    return TrainingSession(
      version: version ?? this.version,
      exerciseType: exerciseType ?? this.exerciseType,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      exerciseName: exerciseName ?? this.exerciseName,
      planSeqIndex: planSeqIndex ?? this.planSeqIndex,
      plan: clearPlan ? null : (plan ?? this.plan),
      repCount: repCount ?? this.repCount,
      elapsedActiveSeconds:
          elapsedActiveSeconds ?? this.elapsedActiveSeconds,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      bonusSeconds: bonusSeconds ?? this.bonusSeconds,
      target: target ?? this.target,
      isTimed: isTimed ?? this.isTimed,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'exerciseType': exerciseType,
        'exerciseIndex': exerciseIndex,
        'exerciseName': exerciseName,
        'planSeqIndex': planSeqIndex,
        'plan': plan?.toJson(),
        'repCount': repCount,
        'elapsedActiveSeconds': elapsedActiveSeconds,
        'pausedAt': pausedAt?.toIso8601String(),
        'bonusSeconds': bonusSeconds,
        'target': target,
        'isTimed': isTimed,
      };

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    final planRaw = json['plan'];
    return TrainingSession(
      version: (json['version'] as num?)?.toInt() ?? currentVersion,
      exerciseType: json['exerciseType'] as String? ?? '',
      exerciseIndex: (json['exerciseIndex'] as num?)?.toInt() ?? 0,
      exerciseName: json['exerciseName'] as String? ?? '',
      planSeqIndex: (json['planSeqIndex'] as num?)?.toInt() ?? -1,
      plan: planRaw is Map<String, dynamic>
          ? TrainingPlanSnapshot.fromJson(planRaw)
          : (planRaw is Map
              ? TrainingPlanSnapshot.fromJson(
                  Map<String, dynamic>.from(planRaw),
                )
              : null),
      repCount: (json['repCount'] as num?)?.toInt() ?? 0,
      elapsedActiveSeconds:
          (json['elapsedActiveSeconds'] as num?)?.toInt() ?? 0,
      pausedAt: _parseIso(json['pausedAt'] as String?),
      bonusSeconds: (json['bonusSeconds'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt() ?? 0,
      isTimed: json['isTimed'] as bool? ?? false,
    );
  }

  static DateTime? _parseIso(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// Lightweight plan essentials for resume (title, rest, item targets).
class TrainingPlanSnapshot {
  final String title;
  final int restSeconds;
  final List<TrainingPlanItemSnapshot> items;

  const TrainingPlanSnapshot({
    required this.title,
    required this.restSeconds,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'restSeconds': restSeconds,
        'items': items.map((e) => e.toJson()).toList(growable: false),
      };

  factory TrainingPlanSnapshot.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <TrainingPlanItemSnapshot>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map<String, dynamic>) {
          items.add(TrainingPlanItemSnapshot.fromJson(entry));
        } else if (entry is Map) {
          items.add(
            TrainingPlanItemSnapshot.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          );
        }
      }
    }
    return TrainingPlanSnapshot(
      title: json['title'] as String? ?? '',
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 15,
      items: items,
    );
  }
}

class TrainingPlanItemSnapshot {
  final int exerciseIndex;
  final int target;
  final bool isTimed;

  const TrainingPlanItemSnapshot({
    required this.exerciseIndex,
    required this.target,
    required this.isTimed,
  });

  Map<String, dynamic> toJson() => {
        'exerciseIndex': exerciseIndex,
        'target': target,
        'isTimed': isTimed,
      };

  factory TrainingPlanItemSnapshot.fromJson(Map<String, dynamic> json) {
    return TrainingPlanItemSnapshot(
      exerciseIndex: (json['exerciseIndex'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt() ?? 0,
      isTimed: json['isTimed'] as bool? ?? false,
    );
  }
}

/// Local persistence for mid-workout pause / exit / resume with pause bonus.
///
/// Uses [SharedPreferences] (already in the project). No UI.
class TrainingSessionStore {
  static const prefKey = 'training_session_v1';

  /// Hard cap on accumulated [TrainingSession.bonusSeconds] per session.
  static const int maxBonusSeconds = 180;

  /// Rep conversion: ~1 bonus rep per this many bonus seconds.
  static const int secondsPerBonusRep = 4;

  SharedPreferences? _prefs;

  /// [prefs] may be injected for tests; otherwise resolved lazily.
  TrainingSessionStore({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Persist [session] (overwrites any previous mid-workout snapshot).
  Future<void> saveSession(TrainingSession session) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(prefKey, jsonEncode(session.toJson()));
  }

  /// Returns the stored session, or null if none / corrupt.
  Future<TrainingSession?> loadSession() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(prefKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return TrainingSession.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  /// Removes any stored mid-workout session.
  Future<void> clearSession() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(prefKey);
  }

  /// Bonus seconds for a single pause gap (before accumulation / cap).
  ///
  /// - &lt; 30s → 0
  /// - 30s – 2min → 15
  /// - 2 – 5min → 30
  /// - 5 – 15min → 45
  /// - &gt; 15min → 60
  static int computeBonusSeconds(Duration pauseGap) {
    final sec = pauseGap.inSeconds;
    if (sec < 30) return 0;
    if (sec < 2 * 60) return 15;
    if (sec < 5 * 60) return 30;
    if (sec < 15 * 60) return 45;
    return 60;
  }

  /// Fold pause-gap bonus into [session.bonusSeconds] (capped at
  /// [maxBonusSeconds]), using [pausedAt] → [now].
  ///
  /// By default clears [TrainingSession.pausedAt] after apply (resume path).
  /// Pass [clearPausedAt]: false to keep the timestamp for UI display.
  /// No-ops (returns [session] unchanged) when [pausedAt] is null.
  static TrainingSession applyPauseBonus(
    TrainingSession session, {
    DateTime? now,
    bool clearPausedAt = true,
  }) {
    final pausedAt = session.pausedAt;
    if (pausedAt == null) return session;

    final gap = (now ?? DateTime.now()).difference(pausedAt);
    final added = computeBonusSeconds(gap);
    final total =
        (session.bonusSeconds + added).clamp(0, maxBonusSeconds);

    return session.copyWith(
      bonusSeconds: total,
      clearPausedAt: clearPausedAt,
    );
  }
}
