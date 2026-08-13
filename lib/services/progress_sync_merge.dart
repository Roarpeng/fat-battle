/// 登录后 / 双边都有存档时的合并动作（按 updatedAt last-write-wins）
enum SnapshotMergeAction {
  /// 双边皆空，无需同步
  none,

  /// 采用云端快照写入本地
  applyRemote,

  /// 把本地快照推到云端
  pushLocal,

  /// 保留本地且不推（时间戳相等，或本地缺时间戳时避免擦档）
  keepLocal,
}

/// 纯函数：决定本地 vs 云端快照如何合并。
///
/// - 云端空、本地有档 → 推本地（首次登录不擦本地）
/// - 本地空、云端有档 → 拉云端（重装恢复）
/// - 双边都有 → 比较 [localUpdatedAt] / [remoteUpdatedAt]
/// - 本地缺时间戳且双边都有 → [keepLocal]（不因首次登录抹掉本机进度）
SnapshotMergeAction decideSnapshotMerge({
  required bool localHasGame,
  required DateTime? localUpdatedAt,
  required bool remoteHasGame,
  required DateTime? remoteUpdatedAt,
}) {
  if (!localHasGame && !remoteHasGame) return SnapshotMergeAction.none;
  if (localHasGame && !remoteHasGame) return SnapshotMergeAction.pushLocal;
  if (!localHasGame && remoteHasGame) return SnapshotMergeAction.applyRemote;

  // 双边都有
  if (localUpdatedAt == null) return SnapshotMergeAction.keepLocal;
  if (remoteUpdatedAt == null) return SnapshotMergeAction.pushLocal;
  if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
    return SnapshotMergeAction.pushLocal;
  }
  if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
    return SnapshotMergeAction.applyRemote;
  }
  return SnapshotMergeAction.keepLocal;
}

/// GameState JSON 是否像一份有效存档（有 lastDate）
bool snapshotLooksLikeGame(Map<String, dynamic>? json) {
  if (json == null || json.isEmpty) return false;
  final lastDate = json['lastDate']?.toString() ?? '';
  return lastDate.isNotEmpty;
}

DateTime? parseSnapshotTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
}
