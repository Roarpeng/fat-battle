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

  List<QueuedNotification> get pending => List.unmodifiable(_queue);

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
      '减肥大作战',
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
  }) {
    final now = DateTime.now();

    if (_isDnd(now, dndEnabled, dndStart, dndEnd)) {
      return false;
    }

    switch (priority) {
      case NotifyPriority.high:
        return true;
      case NotifyPriority.normal:
        return _isDigestTime(now);
      case NotifyPriority.silent:
        return false;
    }
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
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
