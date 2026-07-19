import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

/// 战斗宠物 Notifier
class CompanionNotifier extends StateNotifier<CompanionState> {
  CompanionNotifier() : super(const CompanionState());

  /// 切换激活宠物
  void switchPet(int index) {
    if (index < 0 || index >= state.pets.length) return;
    if (!state.pets[index].owned) return;
    state = state.copyWith(activeIndex: index);
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
  }

  /// 添加待领取掉落
  void addPendingDrops(int drops) {
    if (drops <= 0) return;
    state = state.copyWith(pendingDrops: state.pendingDrops + drops);
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
  }

  /// 重置
  void reset() {
    state = const CompanionState();
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
  return CompanionNotifier();
});
