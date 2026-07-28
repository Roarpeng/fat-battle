import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_provider.dart' show sharedPreferencesProvider;

/// SharedPreferences key for companion snapshot.
const _companionPrefsKey = 'fat_battle_companion';

/// 战斗宠物类型
enum CompanionMood {
  happy,
  normal,
  sad,
  tired,
}

extension CompanionMoodExt on CompanionMood {
  String get emoji {
    switch (this) {
      case CompanionMood.happy:
        return '😄';
      case CompanionMood.normal:
        return '🙂';
      case CompanionMood.sad:
        return '😢';
      case CompanionMood.tired:
        return '😴';
    }
  }

  String get label {
    switch (this) {
      case CompanionMood.happy:
        return '开心';
      case CompanionMood.normal:
        return '正常';
      case CompanionMood.sad:
        return '饥饿';
      case CompanionMood.tired:
        return '疲惫';
    }
  }
}

/// 战斗宠物
class CompanionPet {
  /// 宠物定义 ID（如 cat/dog/dragon）
  final String defId;

  /// 名称
  final String name;

  /// Emoji
  final String emoji;

  /// 等级
  final int level;

  /// 当前经验值
  final int xp;

  /// 升到下一级所需经验
  final int xpToNext;

  /// 当前心情
  final CompanionMood mood;

  /// 饥饿度（0-100，100 为最饿）
  final int hunger;

  /// 体力（0-100，0 为精疲力尽）
  final int energy;

  /// 皮肤等级（1-10，由怪物掉落解锁）
  final int skinLevel;

  /// 对话等级（1-10，由怪物掉落解锁）
  final int dialogueLevel;

  /// 是否已激活（玩家拥有）
  final bool owned;

  const CompanionPet({
    this.defId = 'cat',
    this.name = '小猫崽',
    this.emoji = '🐱',
    this.level = 1,
    this.xp = 0,
    this.xpToNext = 100,
    this.mood = CompanionMood.normal,
    this.hunger = 50,
    this.energy = 100,
    this.skinLevel = 1,
    this.dialogueLevel = 1,
    this.owned = false,
  });

  CompanionPet copyWith({
    String? defId,
    String? name,
    String? emoji,
    int? level,
    int? xp,
    int? xpToNext,
    CompanionMood? mood,
    int? hunger,
    int? energy,
    int? skinLevel,
    int? dialogueLevel,
    bool? owned,
  }) {
    return CompanionPet(
      defId: defId ?? this.defId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpToNext: xpToNext ?? this.xpToNext,
      mood: mood ?? this.mood,
      hunger: hunger ?? this.hunger,
      energy: energy ?? this.energy,
      skinLevel: skinLevel ?? this.skinLevel,
      dialogueLevel: dialogueLevel ?? this.dialogueLevel,
      owned: owned ?? this.owned,
    );
  }

  Map<String, dynamic> toJson() => {
        'defId': defId,
        'name': name,
        'emoji': emoji,
        'level': level,
        'xp': xp,
        'xpToNext': xpToNext,
        'mood': mood.index,
        'hunger': hunger,
        'energy': energy,
        'skinLevel': skinLevel,
        'dialogueLevel': dialogueLevel,
        'owned': owned,
      };

  factory CompanionPet.fromJson(Map<String, dynamic> json) {
    final moodIdx = (json['mood'] as num?)?.toInt() ?? 1;
    return CompanionPet(
      defId: json['defId'] as String? ?? 'cat',
      name: json['name'] as String? ?? '小猫崽',
      emoji: json['emoji'] as String? ?? '🐱',
      level: (json['level'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      xpToNext: (json['xpToNext'] as num?)?.toInt() ?? 100,
      mood: CompanionMood.values[
          moodIdx.clamp(0, CompanionMood.values.length - 1)],
      hunger: (json['hunger'] as num?)?.toInt() ?? 50,
      energy: (json['energy'] as num?)?.toInt() ?? 100,
      skinLevel: (json['skinLevel'] as num?)?.toInt() ?? 1,
      dialogueLevel: (json['dialogueLevel'] as num?)?.toInt() ?? 1,
      owned: json['owned'] as bool? ?? false,
    );
  }
}

/// 战斗宠物状态
///
/// 对齐 Web 端 `companionSlice`，管理宠物列表、当前激活宠物、累计怪物掉落
/// 与待领取掉落。
class CompanionState {
  /// 所有宠物列表（含未解锁）
  final List<CompanionPet> pets;

  /// 当前激活的宠物索引
  final int activeIndex;

  /// 累计怪物掉落数量（用于升级皮肤和对话）
  final int monsterDrops;

  /// 待领取的掉落数量
  final int pendingDrops;

  /// 最近一次活跃日期（YYYY-MM-DD）
  final String lastActiveDate;

  const CompanionState({
    this.pets = const [
      CompanionPet(defId: 'cat', name: '小猫崽', emoji: '🐱', owned: true),
      CompanionPet(defId: 'dog', name: '忠诚犬', emoji: '🐶', owned: false),
      CompanionPet(defId: 'dragon', name: '幼龙', emoji: '🐲', owned: false),
      CompanionPet(defId: 'owl', name: '智慧猫头鹰', emoji: '🦉', owned: false),
    ],
    this.activeIndex = 0,
    this.monsterDrops = 0,
    this.pendingDrops = 0,
    this.lastActiveDate = '',
  });

  CompanionState copyWith({
    List<CompanionPet>? pets,
    int? activeIndex,
    int? monsterDrops,
    int? pendingDrops,
    String? lastActiveDate,
  }) {
    return CompanionState(
      pets: pets ?? this.pets,
      activeIndex: activeIndex ?? this.activeIndex,
      monsterDrops: monsterDrops ?? this.monsterDrops,
      pendingDrops: pendingDrops ?? this.pendingDrops,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    );
  }

  /// 获取当前激活的宠物
  CompanionPet? get activePet {
    if (pets.isEmpty || activeIndex < 0 || activeIndex >= pets.length) {
      return null;
    }
    return pets[activeIndex];
  }

  Map<String, dynamic> toJson() => {
        'pets': pets.map((p) => p.toJson()).toList(),
        'activeIndex': activeIndex,
        'monsterDrops': monsterDrops,
        'pendingDrops': pendingDrops,
        'lastActiveDate': lastActiveDate,
      };

  factory CompanionState.fromJson(Map<String, dynamic> json) {
    final petsRaw = json['pets'] as List?;
    final pets = petsRaw
            ?.whereType<Map>()
            .map((e) => CompanionPet.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const CompanionState().pets;
    return CompanionState(
      pets: pets,
      activeIndex: (json['activeIndex'] as num?)?.toInt() ?? 0,
      monsterDrops: (json['monsterDrops'] as num?)?.toInt() ?? 0,
      pendingDrops: (json['pendingDrops'] as num?)?.toInt() ?? 0,
      lastActiveDate: json['lastActiveDate'] as String? ?? '',
    );
  }
}

/// 战斗宠物 Notifier（带 SharedPreferences 持久化）
class CompanionNotifier extends StateNotifier<CompanionState> {
  CompanionNotifier(this.prefs) : super(const CompanionState()) {
    _loadSync();
  }

  final SharedPreferences? prefs;

  void _loadSync() {
    if (prefs == null) return;
    try {
      final raw = prefs!.getString(_companionPrefsKey);
      if (raw == null || raw.isEmpty) return;
      state = CompanionState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[companion] 加载失败: $e');
    }
  }

  Future<void> _persist() async {
    if (prefs == null) return;
    try {
      await prefs!.setString(_companionPrefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('[companion] 保存失败: $e');
    }
  }

  /// 切换激活宠物
  void switchPet(int index) {
    if (index < 0 || index >= state.pets.length) return;
    if (!state.pets[index].owned) return;
    state = state.copyWith(activeIndex: index);
    _persist();
  }

  /// 解锁新宠物
  void unlockPet(CompanionPet pet) {
    final pets = List<CompanionPet>.from(state.pets);
    final idx = pets.indexWhere((p) => p.defId == pet.defId);
    if (idx < 0) {
      pets.add(pet.copyWith(owned: true));
    } else {
      pets[idx] = pets[idx].copyWith(owned: true);
    }
    state = state.copyWith(pets: pets);
    _persist();
  }

  /// 喂食宠物（消耗饮食卡路里）
  void feed({int calories = 0}) {
    final pets = List<CompanionPet>.from(state.pets);
    final idx = state.activeIndex;
    if (idx < 0 || idx >= pets.length) return;
    final pet = pets[idx];
    pets[idx] = pet.copyWith(
      hunger: (pet.hunger - 10).clamp(0, 100),
      mood: _determineMood(
        hunger: (pet.hunger - 10).clamp(0, 100),
        energy: pet.energy,
      ),
    );
    state = state.copyWith(
      pets: pets,
      lastActiveDate: _todayStr(),
    );
    _persist();
  }

  /// 与宠物一起锻炼（获得经验）
  void exerciseWithCompanion(int duration) {
    final pets = List<CompanionPet>.from(state.pets);
    final idx = state.activeIndex;
    if (idx < 0 || idx >= pets.length) return;

    final xpGain = (duration * 2).round();
    var pet = pets[idx].copyWith(
      energy: (pets[idx].energy - 5).clamp(0, 100),
      xp: pets[idx].xp + xpGain,
    );
    pet = _checkLevelUp(pet);
    pets[idx] = pet.copyWith(
      mood: _determineMood(hunger: pet.hunger, energy: pet.energy),
    );
    state = state.copyWith(
      pets: pets,
      lastActiveDate: _todayStr(),
    );
    _persist();
  }

  /// 抚摸宠物（心情变开心）
  void pet() {
    final pets = List<CompanionPet>.from(state.pets);
    final idx = state.activeIndex;
    if (idx < 0 || idx >= pets.length) return;
    pets[idx] = pets[idx].copyWith(mood: CompanionMood.happy);
    state = state.copyWith(
      pets: pets,
      lastActiveDate: _todayStr(),
    );
    _persist();
  }

  /// 更新宠物心情
  void updateMood() {
    final pets = List<CompanionPet>.from(state.pets);
    final idx = state.activeIndex;
    if (idx < 0 || idx >= pets.length) return;
    pets[idx] = pets[idx].copyWith(
      mood: _determineMood(
        hunger: pets[idx].hunger,
        energy: pets[idx].energy,
      ),
    );
    state = state.copyWith(pets: pets, lastActiveDate: _todayStr());
    _persist();
  }

  /// 添加待领取掉落
  void addPendingDrops(int drops) {
    if (drops <= 0) return;
    state = state.copyWith(pendingDrops: state.pendingDrops + drops);
    _persist();
  }

  /// 领取所有掉落，升级皮肤和对话等级
  void collectDrops() {
    if (state.pendingDrops <= 0) return;
    final totalDrops = state.monsterDrops + state.pendingDrops;
    final newSkinLevel = (1 + totalDrops ~/ 8).clamp(1, 10);
    final newDialogueLevel = (1 + totalDrops ~/ 12).clamp(1, 10);

    final pets = List<CompanionPet>.from(state.pets);
    final idx = state.activeIndex;
    if (idx >= 0 && idx < pets.length) {
      pets[idx] = pets[idx].copyWith(
        skinLevel: newSkinLevel,
        dialogueLevel: newDialogueLevel,
        mood: CompanionMood.happy,
      );
    }
    state = state.copyWith(
      pets: pets,
      monsterDrops: totalDrops,
      pendingDrops: 0,
      lastActiveDate: _todayStr(),
    );
    _persist();
  }

  /// 重置
  void reset() {
    state = const CompanionState();
    _persist();
  }

  CompanionPet _checkLevelUp(CompanionPet pet) {
    int level = pet.level;
    int xp = pet.xp;
    int xpToNext = pet.xpToNext;

    while (xp >= xpToNext) {
      xp -= xpToNext;
      level += 1;
      xpToNext = level * 100;
    }
    return pet.copyWith(level: level, xp: xp, xpToNext: xpToNext);
  }

  CompanionMood _determineMood({required int hunger, required int energy}) {
    if (hunger > 80) return CompanionMood.sad;
    if (energy < 20) return CompanionMood.tired;
    if (hunger < 30 && energy > 50) return CompanionMood.happy;
    return CompanionMood.normal;
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// 战斗宠物 Provider
final companionProvider =
    StateNotifierProvider<CompanionNotifier, CompanionState>((ref) {
  return CompanionNotifier(ref.watch(sharedPreferencesProvider));
});
