import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'auth_service.dart';
import 'progress_sync_merge.dart';

export 'progress_sync_merge.dart';

/// 云同步阶段（设置页展示）
enum ProgressSyncPhase {
  notConfigured,
  guest,
  idle,
  syncing,
  success,
  error,
}

/// 设置页可读的同步状态快照
class ProgressSyncStatus {
  final ProgressSyncPhase phase;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final int? revision;

  const ProgressSyncStatus({
    required this.phase,
    this.lastSuccessAt,
    this.lastError,
    this.revision,
  });

  String get subtitle {
    switch (phase) {
      case ProgressSyncPhase.notConfigured:
        return '未配置 API_BASE_URL，仅本地存档';
      case ProgressSyncPhase.guest:
        return '游客/未登录，不同步云端';
      case ProgressSyncPhase.syncing:
        return '正在同步…';
      case ProgressSyncPhase.success:
        if (lastSuccessAt == null) return '云同步正常';
        return '上次成功 ${_formatStamp(lastSuccessAt!)}';
      case ProgressSyncPhase.error:
        return lastError == null || lastError!.isEmpty
            ? '同步失败'
            : '同步失败：$lastError';
      case ProgressSyncPhase.idle:
        if (lastSuccessAt != null) {
          return '上次成功 ${_formatStamp(lastSuccessAt!)}';
        }
        if (lastError != null && lastError!.isNotEmpty) {
          return '上次失败：$lastError';
        }
        return '已登录，等待同步';
    }
  }

  static String _formatStamp(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}

/// 进度云同步：GameState 快照 pull/push，游客与未配置后端时 no-op。
///
/// 不上传姿态视频、训练日记或 IMU 流，只同步 `GameState.toJson()` 文本快照。
class ProgressSyncService extends ChangeNotifier {
  ProgressSyncService({
    AuthService? auth,
    Future<SharedPreferences> Function()? prefsFactory,
  })  : _auth = auth ?? AuthService(),
        _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  static final ProgressSyncService instance = ProgressSyncService();

  static const snapshotPath = '/api/v1/progress/snapshot';
  static const eventsPath = '/api/v1/progress/events';
  static const kUpdatedAt = 'fat_battle_sync_updated_at';
  static const kLastOk = 'fat_battle_sync_last_ok';
  static const kLastError = 'fat_battle_sync_last_error';
  static const kRevision = 'fat_battle_sync_revision';

  static const _debounce = Duration(seconds: 2);

  final AuthService _auth;
  final Future<SharedPreferences> Function() _prefsFactory;

  Timer? _debounceTimer;
  Map<String, dynamic>? _pendingJson;
  bool _paused = false;
  bool _syncing = false;

  ProgressSyncPhase _phase = ProgressSyncPhase.idle;
  DateTime? _lastSuccessAt;
  String? _lastError;
  int? _revision;

  ProgressSyncStatus get status => ProgressSyncStatus(
        phase: _phase,
        lastSuccessAt: _lastSuccessAt,
        lastError: _lastError,
        revision: _revision,
      );

  bool get isBackendEnabled => ApiConfig.isBackendEnabled;

  /// 游客 / 未配置后端：整条同步链路 no-op
  Future<bool> get canSync async {
    if (!isBackendEnabled) return false;
    final token = await _auth.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> hydrateStatus() async {
    final prefs = await _prefsFactory();
    _lastSuccessAt = parseSnapshotTime(prefs.getString(kLastOk));
    _lastError = prefs.getString(kLastError);
    _revision = prefs.getInt(kRevision);
    if (!isBackendEnabled) {
      _phase = ProgressSyncPhase.notConfigured;
    } else if (!await canSync) {
      _phase = ProgressSyncPhase.guest;
    } else if (_lastError != null && _lastError!.isNotEmpty) {
      _phase = ProgressSyncPhase.error;
    } else if (_lastSuccessAt != null) {
      _phase = ProgressSyncPhase.success;
    } else {
      _phase = ProgressSyncPhase.idle;
    }
    notifyListeners();
  }

  /// 本地 persist 钩子：盖时间戳并 debounce 推送
  Future<void> onLocalSaved(Map<String, dynamic> json) async {
    if (_paused) return;
    if (!snapshotLooksLikeGame(json)) return;
    final prefs = await _prefsFactory();
    final now = DateTime.now().toUtc();
    await prefs.setString(kUpdatedAt, now.toIso8601String());
    schedulePush(json);
  }

  void schedulePush(Map<String, dynamic> json) {
    if (!isBackendEnabled) return;
    if (_paused) return;
    if (!snapshotLooksLikeGame(json)) return;
    _pendingJson = json;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      final pending = _pendingJson;
      if (pending == null) return;
      unawaited(pushSnapshot(pending));
    });
  }

  /// 登录/注册成功后：拉云端，空则推本地，双边按 updatedAt 合并（不擦首次登录本地档）
  Future<Map<String, dynamic>?> syncAfterLogin({
    required Map<String, dynamic> localJson,
    required bool localHasGame,
    Future<void> Function(Map<String, dynamic> json)? applyRemote,
  }) async {
    if (!await canSync) {
      await hydrateStatus();
      return null;
    }
    _setSyncing();
    try {
      final prefs = await _prefsFactory();
      final localUpdatedAt = parseSnapshotTime(prefs.getString(kUpdatedAt));
      final remote = await _getSnapshot();

      final action = decideSnapshotMerge(
        localHasGame: localHasGame && snapshotLooksLikeGame(localJson),
        localUpdatedAt: localUpdatedAt,
        remoteHasGame: remote != null && snapshotLooksLikeGame(remote.state),
        remoteUpdatedAt: remote?.updatedAt,
      );

      switch (action) {
        case SnapshotMergeAction.applyRemote:
          final state = remote!.state;
          await _writeLocalFromRemote(prefs, state, remote.updatedAt, remote.revision);
          if (applyRemote != null) await applyRemote(state);
          await _markSuccess(prefs, remote.revision);
          return state;
        case SnapshotMergeAction.pushLocal:
          await pushSnapshot(localJson, immediate: true);
          return null;
        case SnapshotMergeAction.keepLocal:
        case SnapshotMergeAction.none:
          await _markSuccess(prefs, remote?.revision);
          return null;
      }
    } catch (e) {
      await _markError('$e');
      return null;
    }
  }

  Future<void> pushSnapshot(
    Map<String, dynamic> json, {
    bool immediate = false,
  }) async {
  Future<Map<String, dynamic>?> pullIfLocalEmpty() async {
    if (!await canSync) return null;
    try {
      final remote = await _getSnapshot();
      if (remote == null || !snapshotLooksLikeGame(remote.state)) return null;
      final prefs = await _prefsFactory();
      await _writeLocalFromRemote(
        prefs,
        remote.state,
        remote.updatedAt,
        remote.revision,
      );
      await _markSuccess(prefs, remote.revision);
      return remote.state;
    } catch (e) {
      await _markError('$e');
      return null;
    }
  }

  /// 设置页「立即同步」：拉云端再按 LWW 合并
  Future<Map<String, dynamic>?> syncNow({
    required Map<String, dynamic> localJson,
    required bool localHasGame,
    Future<void> Function(Map<String, dynamic> json)? applyRemote,
  }) {
    return syncAfterLogin(
      localJson: localJson,
      localHasGame: localHasGame,
      applyRemote: applyRemote,
    );
  }

  /// 尽力上报行为流水（餐食 / 锻炼结算）。失败不阻塞 UI、不改同步相位。
  Future<void> postEvent(String type, Map<String, dynamic> payload, {String? clientId}) async {
    try {
      if (!await canSync) return;
      await _auth.authedPost(eventsPath, body: {
        'type': type,
        'at': DateTime.now().toUtc().toIso8601String(),
        if (clientId != null && clientId.isNotEmpty) 'id': clientId,
        'payload': payload,
      });
    } catch (e) {
      debugPrint('ProgressSyncService.postEvent: $e');
    }
  }

  Future<void> pushSnapshot(
    Map<String, dynamic> json, {
    bool immediate = false,
  }) async {
    if (!immediate && _paused) return;
    if (!await canSync) {
      await hydrateStatus();
      return;
    }
    if (!snapshotLooksLikeGame(json)) return;

    _setSyncing();
    try {
      final prefs = await _prefsFactory();
      final updatedAt =
          parseSnapshotTime(prefs.getString(kUpdatedAt)) ?? DateTime.now().toUtc();
      final resp = await _auth.authedPost(snapshotPath, body: {
        'state': json,
        'updatedAt': updatedAt.toIso8601String(),
      });
      if (resp.statusCode == 409) {
        // 云端更新：不覆盖本机会话，仅记录状态
        await _markError('云端存档更新，本地未覆盖');
        return;
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        await _markError(_extractError(resp.body, '上传失败 HTTP ${resp.statusCode}'));
        return;
      }
      final parsed = _parseEnvelope(resp.body);
      await _markSuccess(prefs, parsed?.revision);
    } catch (e) {
      await _markError('$e');
    }
  }

  Future<_RemoteSnapshot?> _getSnapshot() async {
    final resp = await _auth.authedGet(snapshotPath);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractError(resp.body, '拉取失败 HTTP ${resp.statusCode}'));
    }
    return _parseEnvelope(resp.body);
  }

  _RemoteSnapshot? _parseEnvelope(String body) {
    final data = jsonDecode(body);
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final stateRaw = map['state'] ?? map['gameState'];
    if (stateRaw is! Map) return null;
    return _RemoteSnapshot(
      state: Map<String, dynamic>.from(stateRaw),
      updatedAt: parseSnapshotTime(map['updatedAt']?.toString()),
      revision: map['revision'] is int
          ? map['revision'] as int
          : int.tryParse(map['revision']?.toString() ?? ''),
    );
  }

  Future<void> _writeLocalFromRemote(
    SharedPreferences prefs,
    Map<String, dynamic> state,
    DateTime? updatedAt,
    int? revision,
  ) async {
    _paused = true;
    try {
      await prefs.setString('fat_battle_game', jsonEncode(state));
      if (updatedAt != null) {
        await prefs.setString(kUpdatedAt, updatedAt.toUtc().toIso8601String());
      }
      if (revision != null) {
        await prefs.setInt(kRevision, revision);
        _revision = revision;
      }
    } finally {
      _paused = false;
    }
  }

  void _setSyncing() {
    _syncing = true;
    _phase = ProgressSyncPhase.syncing;
    notifyListeners();
  }

  Future<void> _markSuccess(SharedPreferences prefs, int? revision) async {
    _syncing = false;
    final now = DateTime.now().toUtc();
    _lastSuccessAt = now;
    _lastError = null;
    _phase = ProgressSyncPhase.success;
    if (revision != null) _revision = revision;
    await prefs.setString(kLastOk, now.toIso8601String());
    await prefs.remove(kLastError);
    if (revision != null) await prefs.setInt(kRevision, revision);
    notifyListeners();
  }

  Future<void> _markError(String message) async {
    _syncing = false;
    _lastError = message;
    _phase = ProgressSyncPhase.error;
    try {
      final prefs = await _prefsFactory();
      await prefs.setString(kLastError, message);
    } catch (_) {}
    debugPrint('ProgressSyncService: $message');
    notifyListeners();
  }

  String _extractError(String body, String fallback) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['error'] != null) {
        final err = data['error'].toString();
        if (err.isNotEmpty) return err;
      }
    } catch (_) {}
    return fallback;
  }

  @visibleForTesting
  bool get isSyncing => _syncing;
}

class _RemoteSnapshot {
  final Map<String, dynamic> state;
  final DateTime? updatedAt;
  final int? revision;

  _RemoteSnapshot({required this.state, this.updatedAt, this.revision});
}
