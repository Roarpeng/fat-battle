import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

enum NotificationType { digest, reminder, achievement, system }

enum NotifyPriority { silent, normal, high }

class QueuedNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final NotifyPriority priority;
  final DateTime createdAt;

  const QueuedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.priority,
    required this.createdAt,
  });
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  final List<QueuedNotification> _queue = [];
  /// DND 时段内暂存的 silent 通知，等待 DND 结束后发送
  final List<QueuedNotification> _dndHoldQueue = [];

  List<QueuedNotification> get pending => List.unmodifiable(_queue);
  List<QueuedNotification> get dndHeld => List.unmodifiable(_dndHoldQueue);

  Future<void> init() async {
    if (_initialized) return;
    
    try {
      tz.initializeTimeZones();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );
      
      await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
      _initialized = true;
    } catch (e) {
      _initialized = false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) await init();
    
    bool result = false;
    
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      result = await androidImplementation.requestNotificationsPermission() ?? false;
    }

    if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      if (iosImplementation != null) {
        result = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ?? false;
      }
    }

    return result;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    NotificationType type = NotificationType.system,
  }) async {
    if (!_initialized) await init();
    
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'fat_battle_channel',
      '塑身工坊',
      channelDescription: '减肥大作战游戏通知',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails();
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );
    
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    NotificationType type = NotificationType.reminder,
  }) async {
    if (!_initialized) await init();
    
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'fat_battle_reminder',
      '提醒通知',
      channelDescription: '饮食与锻炼提醒',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails();
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );
    
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: type == NotificationType.reminder
          ? DateTimeComponents.time
          : null,
    );
  }

  Future<void> cancelNotification(int id) async {
    if (!_initialized) await init();
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    if (!_initialized) await init();
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  bool _isDnd(DateTime now, bool dndEnabled, String dndStart, String dndEnd) {
    if (!dndEnabled) return false;

    final start = _parseTime(dndStart);
    final end = _parseTime(dndEnd);
    final current = now.hour * 60 + now.minute;

    if (start <= end) {
      return current >= start && current < end;
    } else {
      return current >= start || current < end;
    }
  }

  int _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  bool _isDigestTime(DateTime now) {
    final hour = now.hour;
    return hour == 13 || hour == 20;
  }

  bool shouldNotifyNow({
    required NotifyPriority priority,
    required bool dndEnabled,
    required String dndStart,
    required String dndEnd,
    QueuedNotification? notification,
  }) {
    final now = DateTime.now();
    final inDnd = _isDnd(now, dndEnabled, dndStart, dndEnd);

    switch (priority) {
      case NotifyPriority.high:
        // 高优先级：DND 时段外直接发送；DND 内暂存
        if (inDnd && notification != null) {
          _dndHoldQueue.add(notification);
        }
        return !inDnd;
      case NotifyPriority.normal:
        if (inDnd) return false;
        return _isDigestTime(now);
      case NotifyPriority.silent:
        // silent 通知：DND 时段内暂存，时段结束后可通过 flushDndHold 取出
        if (inDnd && notification != null) {
          _dndHoldQueue.add(notification);
          return false;
        }
        return true;
    }
  }

  /// DND 结束后调用，释放暂存的通知
  List<QueuedNotification> flushDndHold() {
    final toSend = <QueuedNotification>[];
    toSend.addAll(_dndHoldQueue);
    _dndHoldQueue.clear();
    return toSend;
  }

  void queue(QueuedNotification notification) {
    _queue.add(notification);
  }

  List<QueuedNotification> flushDigest({
    required bool dndEnabled,
    required String dndStart,
    required String dndEnd,
  }) {
    final now = DateTime.now();
    if (_isDnd(now, dndEnabled, dndStart, dndEnd)) return [];

    final toSend = <QueuedNotification>[];
    toSend.addAll(_queue);
    _queue.clear();
    return toSend;
  }

  String buildDailyDigestTitle(int caloriesRemaining, int monsterHp, int maxHp) {
    if (caloriesRemaining > 0) {
      return '还剩 ${caloriesRemaining} 千卡额度，今天稳了 ✨';
    } else {
      return '超出 ${-caloriesRemaining} 千卡，去走走就能破防';
    }
  }

  String buildDailyDigestBody(int eaten, int burned, int damage) {
    return '摄入 ${eaten}kcal · 消耗 ${burned}kcal · 伤害 ${damage}';
  }

  /// 办公健康提醒：站立/喝水等周期性提醒
  Future<void> scheduleHealthReminder({
    required String type,
    required int intervalMinutes,
    int startHour = 9,
    int endHour = 18,
  }) async {
    if (!_initialized) await init();

    final now = DateTime.now();
    final title = type == 'stand'
        ? '🧍 该站起来活动一下了'
        : type == 'water'
            ? '💧 记得喝水哦'
            : '🏃 休息一下，动动身体';
    final body = type == 'stand'
        ? '久坐超过${intervalMinutes}分钟，站起来走动2分钟有助于健康'
        : type == 'water'
            ? '保持充足饮水，有助于新陈代谢'
            : '每隔一段时间活动一下，缓解疲劳';

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'fat_battle_health',
      '健康提醒',
      channelDescription: '办公健康提醒（站立/喝水）',
      importance: Importance.low,
      priority: Priority.low,
    );

    final DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails();

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    // 从当前时间到结束时间，每隔 intervalMinutes 安排一次提醒
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      startHour,
    );

    // 如果当前时间已经超过开始时间，从下一个整点间隔开始
    if (now.isAfter(scheduledTime)) {
      final minutesPassed = now.hour * 60 + now.minute - startHour * 60;
      final intervalsPassed = (minutesPassed / intervalMinutes).ceil();
      scheduledTime = scheduledTime.add(
        Duration(minutes: intervalsPassed * intervalMinutes),
      );
    }

    int notificationId = type.hashCode;

    while (scheduledTime.hour < endHour) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId++,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      scheduledTime = scheduledTime.add(Duration(minutes: intervalMinutes));
    }
  }

  /// 取消所有健康提醒通知
  Future<void> cancelHealthReminders() async {
    if (!_initialized) await init();
    await _flutterLocalNotificationsPlugin.cancel(0); // stand
    await _flutterLocalNotificationsPlugin.cancel(1); // water
    await _flutterLocalNotificationsPlugin.cancel(2); // move
    // 取消由 scheduleHealthReminder 生成的通知（id >= hashCode）
    // 由于 id 是动态的，这里取消一个合理的范围
    for (var id = 'stand'.hashCode; id < 'stand'.hashCode + 100; id++) {
      await _flutterLocalNotificationsPlugin.cancel(id);
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
