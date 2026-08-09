import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 姿态教练入镜/引导诊断日记。
///
/// 写入应用文档目录，可分享给开发排查；同时 `debugPrint` 方便 adb logcat。
class PoseCoachDiary {
  PoseCoachDiary._();
  static final PoseCoachDiary instance = PoseCoachDiary._();

  static const String tag = 'PoseCoachDiary';
  static const int _maxLines = 2000;

  final List<String> _lines = [];
  final ValueNotifier<String> liveStatus = ValueNotifier<String>('日记未开始');
  String? _sessionId;
  String? _filePath;
  String? _publicCopyPath;
  IOSink? _sink;
  DateTime? _lastPoseLogAt;
  String? _lastPoseSignature;

  bool get isActive => _sessionId != null;
  String? get filePath => _filePath;

  Future<void> startSession({
    required String engine,
    required String exerciseType,
    String? note,
  }) async {
    await endSession(reason: 'restart');
    final now = DateTime.now();
    _sessionId =
        '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    _lines.clear();
    _lastPoseLogAt = null;
    _lastPoseSignature = null;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pose_coach_diary_$_sessionId.txt');
      _filePath = file.path;
      _sink = file.openWrite(mode: FileMode.writeOnly);
      // 同步到公共 Download，adb shell cat 可读（应用外部 files 在部分机型 shell 无权限）
      try {
        final download = Directory('/sdcard/Download');
        if (await download.exists()) {
          _publicCopyPath =
              '${download.path}/pose_coach_diary_$_sessionId.txt';
        } else {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            _publicCopyPath =
                '${ext.path}/pose_coach_diary_$_sessionId.txt';
          }
        }
      } catch (_) {}
    } catch (e) {
      _filePath = null;
      _sink = null;
      debugPrint('[$tag] open file failed: $e');
    }

    log(
      'SESSION_START',
      'engine=$engine exercise=$exerciseType '
      'note=${note ?? "-"} path=${_filePath ?? "memory-only"}',
    );
    liveStatus.value = '日记已开始 · 等待关键点';
  }

  void log(String event, [String detail = '']) {
    if (_sessionId == null && event != 'SESSION_START') {
      // 允许在未显式 start 时也落内存，避免丢关键早期日志
      _sessionId ??= 'adhoc';
    }
    final ts = DateTime.now().toIso8601String();
    final line = detail.isEmpty ? '[$ts] $event' : '[$ts] $event | $detail';
    _lines.add(line);
    if (_lines.length > _maxLines) {
      _lines.removeRange(0, _lines.length - _maxLines);
    }
    _sink?.writeln(line);
    debugPrint('[$tag] $event ${detail.isEmpty ? "" : detail}');
  }

  /// 高频关键点摘要：默认最多约 2Hz，或签名变化时立即记一条。
  void logPoseFrame({
    required String phase,
    required int keypointCount,
    required double alignment,
    required bool tooClose,
    required String hint,
    String? sample,
    String? imageSize,
  }) {
    final sig =
        '$phase|$keypointCount|${alignment.toStringAsFixed(2)}|$tooClose|$hint';
    final now = DateTime.now();
    final due = _lastPoseLogAt == null ||
        now.difference(_lastPoseLogAt!) >= const Duration(milliseconds: 500) ||
        sig != _lastPoseSignature;
    if (!due) {
      liveStatus.value =
          '阶段:$phase 关键点:$keypointCount 对齐:${(alignment * 100).round()}% '
          '${tooClose ? "太近" : "距离OK"}';
      return;
    }
    _lastPoseLogAt = now;
    _lastPoseSignature = sig;
    log(
      'POSE',
      'phase=$phase kp=$keypointCount align=${alignment.toStringAsFixed(3)} '
      'tooClose=$tooClose hint="$hint" '
      'img=${imageSize ?? "-"} sample=${sample ?? "-"}',
    );
    liveStatus.value =
        '阶段:$phase 关键点:$keypointCount 对齐:${(alignment * 100).round()}% '
        '${tooClose ? "太近" : "距离OK"}';
  }

  void logPhase(String from, String to, [String detail = '']) {
    log('PHASE', '$from → $to ${detail.isEmpty ? "" : detail}');
    liveStatus.value = '阶段切换: $to';
  }

  Future<String?> endSession({String reason = 'stop'}) async {
    if (_sessionId == null) return _filePath;
    log('SESSION_END', 'reason=$reason lines=${_lines.length}');
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;

    // 拷贝到 Download 供 adb / 文件管理器读取
    try {
      if (_filePath != null && _publicCopyPath != null) {
        await File(_filePath!).copy(_publicCopyPath!);
        log('PUBLIC_COPY', _publicCopyPath!);
      }
    } catch (e) {
      debugPrint('[$tag] public copy failed: $e');
    }

    final path = _filePath;
    _sessionId = null;
    liveStatus.value = path == null ? '日记已结束(仅内存)' : '日记已保存';
    return path;
  }

  /// 分享当前日记文件；若只有内存则先落临时文件。
  Future<void> share() async {
    try {
      await _sink?.flush();
      var path = _filePath;
      if (path == null || !File(path).existsSync()) {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/pose_coach_diary_${DateTime.now().millisecondsSinceEpoch}.txt',
        );
        await file.writeAsString(_lines.join('\n'));
        path = file.path;
        _filePath = path;
      }
      await Share.shareXFiles(
        [XFile(path)],
        text: '塑身工坊姿态教练诊断日记',
        subject: 'pose_coach_diary',
      );
      log('SHARE', 'path=$path');
    } catch (e) {
      log('SHARE_FAIL', '$e');
      rethrow;
    }
  }

  String dumpMemory() => _lines.join('\n');

  static String _two(int n) => n.toString().padLeft(2, '0');
}
