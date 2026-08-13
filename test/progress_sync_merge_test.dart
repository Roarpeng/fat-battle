import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/services/progress_sync_merge.dart';

void main() {
  group('decideSnapshotMerge', () {
    test('双边皆空 → none', () {
      expect(
        decideSnapshotMerge(
          localHasGame: false,
          localUpdatedAt: null,
          remoteHasGame: false,
          remoteUpdatedAt: null,
        ),
        SnapshotMergeAction.none,
      );
    });

    test('首次登录：云端空、本地有档 → 推本地（不擦本地）', () {
      expect(
        decideSnapshotMerge(
          localHasGame: true,
          localUpdatedAt: DateTime.utc(2026, 8, 13),
          remoteHasGame: false,
          remoteUpdatedAt: null,
        ),
        SnapshotMergeAction.pushLocal,
      );
    });

    test('重装恢复：本地空、云端有档 → 拉云端', () {
      expect(
        decideSnapshotMerge(
          localHasGame: false,
          localUpdatedAt: null,
          remoteHasGame: true,
          remoteUpdatedAt: DateTime.utc(2026, 8, 1),
        ),
        SnapshotMergeAction.applyRemote,
      );
    });

    test('双边都有且本地更新 → 推本地', () {
      expect(
        decideSnapshotMerge(
          localHasGame: true,
          localUpdatedAt: DateTime.utc(2026, 8, 13, 12),
          remoteHasGame: true,
          remoteUpdatedAt: DateTime.utc(2026, 8, 13, 10),
        ),
        SnapshotMergeAction.pushLocal,
      );
    });

    test('双边都有且云端更新 → 拉云端', () {
      expect(
        decideSnapshotMerge(
          localHasGame: true,
          localUpdatedAt: DateTime.utc(2026, 8, 13, 10),
          remoteHasGame: true,
          remoteUpdatedAt: DateTime.utc(2026, 8, 13, 12),
        ),
        SnapshotMergeAction.applyRemote,
      );
    });

    test('时间戳相等 → 保留本地', () {
      final t = DateTime.utc(2026, 8, 13, 12);
      expect(
        decideSnapshotMerge(
          localHasGame: true,
          localUpdatedAt: t,
          remoteHasGame: true,
          remoteUpdatedAt: t,
        ),
        SnapshotMergeAction.keepLocal,
      );
    });

    test('首次登录缺本地时间戳且双边都有 → 保留本地（不擦档）', () {
      expect(
        decideSnapshotMerge(
          localHasGame: true,
          localUpdatedAt: null,
          remoteHasGame: true,
          remoteUpdatedAt: DateTime.utc(2026, 8, 1),
        ),
        SnapshotMergeAction.keepLocal,
      );
    });
  });

  group('snapshotLooksLikeGame', () {
    test('空 JSON 不是存档', () {
      expect(snapshotLooksLikeGame(null), isFalse);
      expect(snapshotLooksLikeGame({}), isFalse);
      expect(snapshotLooksLikeGame({'lastDate': ''}), isFalse);
    });

    test('有 lastDate 视为有效存档', () {
      expect(snapshotLooksLikeGame({'lastDate': '2026-08-13'}), isTrue);
    });
  });

  group('parseSnapshotTime', () {
    test('解析 RFC3339 为 UTC', () {
      final t = parseSnapshotTime('2026-08-13T04:00:00Z');
      expect(t, DateTime.utc(2026, 8, 13, 4));
    });

    test('空字符串返回 null', () {
      expect(parseSnapshotTime(null), isNull);
      expect(parseSnapshotTime(''), isNull);
      expect(parseSnapshotTime('not-a-date'), isNull);
    });
  });
}
