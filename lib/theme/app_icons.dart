import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// 锻造工坊 · 统一矢量图标体系
///
/// 将原本散落在各处的 emoji 图标（运动/成就/商店/角色/餐次）
/// 统一收敛为 Material 矢量图标，保证跨设备渲染一致、跟随主题着色。
class AppIcons {
  AppIcons._();

  // ===== 运动类型 =====
  static const Map<String, IconData> _exercise = {
    'pushup': Icons.fitness_center,
    'squat': Icons.accessibility_new,
    'jumping_jack': Icons.sports_gymnastics,
    'running': Icons.directions_run,
    'walking': Icons.directions_walk,
    'cycling': Icons.pedal_bike,
    'swimming': Icons.pool,
    'yoga': Icons.self_improvement,
    'hiit': Icons.local_fire_department,
    'jumprope': Icons.timer,
    'strength': Icons.fitness_center,
    'highknee': Icons.directions_run,
    'plank': Icons.self_improvement,
    'burpee': Icons.bolt,
    'lunge': Icons.sports_martial_arts,
    'mountainclimber': Icons.terrain,
  };

  /// 按运动 type 取图标
  static IconData exercise(String type) =>
      _exercise[type] ?? Icons.fitness_center;

  /// 按运动名称取图标（统计页历史记录只有名称）
  static IconData exerciseByName(String name) {
    for (final e in Exercises.all) {
      if (e.name == name) return exercise(e.type);
    }
    return Icons.fitness_center;
  }

  // ===== 成就 =====
  static const Map<String, IconData> _achievement = {
    'first_kill': Icons.military_tech,
    'kill_5': Icons.workspace_premium,
    'kill_10': Icons.shield,
    'streak_3': Icons.local_fire_department,
    'streak_7': Icons.star,
    'streak_30': Icons.emoji_events,
    'exercise_1000': Icons.fitness_center,
    'coins_1000': Icons.paid,
    'boss_kill': Icons.whatshot,
    'weight_5': Icons.trending_down,
    'day_7': Icons.calendar_today,
    'day_30': Icons.date_range,
  };

  static IconData achievement(String id) =>
      _achievement[id] ?? Icons.emoji_events;

  // ===== 商店物品 =====
  static const Map<String, IconData> _shop = {
    'avatar': Icons.face,
    'skin': Icons.palette,
    'voice': Icons.volume_up,
    'checkin': Icons.confirmation_number,
  };

  static IconData shop(String id) => _shop[id] ?? Icons.storefront;

  // ===== 角色风格 =====
  static IconData characterStyle(CharacterStyle style) {
    switch (style) {
      case CharacterStyle.pet:
        return Icons.pets;
      case CharacterStyle.warrior:
        return Icons.shield;
      case CharacterStyle.mage:
        return Icons.auto_awesome;
      case CharacterStyle.assassin:
        return Icons.visibility_off;
    }
  }

  // ===== 餐次 =====
  static IconData meal(MealType meal) {
    switch (meal) {
      case MealType.breakfast:
        return Icons.free_breakfast;
      case MealType.lunch:
        return Icons.wb_sunny;
      case MealType.dinner:
        return Icons.nightlight_round;
      case MealType.snack:
        return Icons.cookie;
    }
  }
}
