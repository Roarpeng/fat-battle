import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';

/// 怪物状态
///
/// 对齐 Web 端 `monsterSlice`，在原 [Monster] 模型基础上扩展阶段（phase）、
/// 狂暴（enraged）与累计受伤（damaged）三项战斗派生状态。
class MonsterState {
  /// 怪物索引（对应 [MonsterConfig] 列表）
  final int index;

  /// 名称
  final String name;

  /// Emoji
  final String emoji;

  /// 最大 HP
  final int maxHp;

  /// 当前 HP
  final int hp;

  /// 等级
  final int level;

  /// 是否 Boss
  final bool isBoss;

  /// 治疗加成（按比例）
  final double healBonus;

  /// 当前护盾值
  final int shield;

  /// 最大护盾值（用于显示百分比）
  final int maxShield;

  /// 阶段：1 = 满血、2 = 中段、3 = 残血
  final int phase;

  /// 是否处于狂暴状态
  final bool enraged;

  /// 累计受伤（用于成就统计）
  final int damaged;

  const MonsterState({
    this.index = 0,
    this.name = '贪吃史莱姆',
    this.emoji = '👾',
    this.maxHp = 100,
    this.hp = 100,
    this.level = 1,
    this.isBoss = false,
    this.healBonus = 0,
    this.shield = 0,
    this.maxShield = 100,
    this.phase = 1,
    this.enraged = false,
    this.damaged = 0,
  });

  MonsterState copyWith({
    int? index,
    String? name,
    String? emoji,
    int? maxHp,
    int? hp,
    int? level,
    bool? isBoss,
    double? healBonus,
    int? shield,
    int? maxShield,
    int? phase,
    bool? enraged,
    int? damaged,
  }) {
    return MonsterState(
      index: index ?? this.index,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      maxHp: maxHp ?? this.maxHp,
      hp: hp ?? this.hp,
      level: level ?? this.level,
      isBoss: isBoss ?? this.isBoss,
      healBonus: healBonus ?? this.healBonus,
      shield: shield ?? this.shield,
      maxShield: maxShield ?? this.maxShield,
      phase: phase ?? this.phase,
      enraged: enraged ?? this.enraged,
      damaged: damaged ?? this.damaged,
    );
  }

  /// HP 百分比
  double get hpPercent => maxHp > 0 ? hp / maxHp : 0;

  /// 护盾百分比
  double get shieldPercent =>
      maxShield > 0 ? (shield / maxShield).clamp(0.0, 1.0) : 0;

  /// 是否拥有护盾
  bool get hasShield => shield > 0;

  /// 是否被击败
  bool get isDead => hp <= 0;

  /// 从基础 [Monster] 模型构造
  factory MonsterState.fromMonster(Monster m) {
    return MonsterState(
      index: m.index,
      name: m.name,
      emoji: m.emoji,
      maxHp: m.maxHp,
      hp: m.hp,
      level: m.level,
      isBoss: m.isBoss,
      healBonus: m.healBonus,
      shield: m.shield,
      maxShield: m.maxHp,
    );
  }

  /// 转回基础 [Monster] 模型
  Monster toMonster() {
    return Monster(
      index: index,
      name: name,
      emoji: emoji,
      maxHp: maxHp,
      hp: hp,
      level: level,
      isBoss: isBoss,
      healBonus: healBonus,
      shield: shield,
    );
  }
}

/// 怪物 Notifier
class MonsterNotifier extends StateNotifier<MonsterState> {
  MonsterNotifier() : super(const MonsterState());

  /// 根据基础 [Monster] 设置当前怪物
  void setMonster(Monster monster) {
    state = MonsterState.fromMonster(monster);
  }

  /// 攻击怪物：先扣护盾，再扣 HP
  ///
  /// 返回实际造成的伤害（用于玩家统计）。
  int attack(int damage) {
    if (damage <= 0 || state.isDead) return 0;

    int newHp = state.hp;
    int newShield = state.shield;
    int actualDealt = 0;

    if (newShield > 0) {
      // 护盾先吸收伤害
      final absorbed = newShield < damage ? newShield : damage;
      newShield -= absorbed;
      final remaining = damage - absorbed;
      // 穿透伤害（护盾减伤率 50%）
      final pierced = (remaining * 0.5).round();
      actualDealt = absorbed + pierced;
      newHp = (newHp - pierced).clamp(0, state.maxHp);
    } else {
      actualDealt = damage;
      newHp = (newHp - damage).clamp(0, state.maxHp);
    }

    final damaged = state.damaged + actualDealt;
    final phase = _calcPhase(newHp, state.maxHp);
    final enraged = newHp > 0 && newHp <= state.maxHp * 0.3;

    state = state.copyWith(
      hp: newHp,
      shield: newShield,
      damaged: damaged,
      phase: phase,
      enraged: enraged,
    );

    return actualDealt;
  }

  /// 增加护盾（暴食惩罚）
  void addShield(int amount) {
    if (amount <= 0) return;
    final newShield = state.shield + amount;
    final newMaxShield =
        state.maxShield < newShield ? newShield : state.maxShield;
    state = state.copyWith(shield: newShield, maxShield: newMaxShield);
  }

  /// 减少护盾
  void reduceShield(int amount) {
    if (amount <= 0) return;
    final newShield = (state.shield - amount).clamp(0, state.maxShield);
    state = state.copyWith(shield: newShield);
  }

  /// 治疗至满血
  void heal() {
    state = state.copyWith(hp: state.maxHp, phase: 1, enraged: false);
  }

  /// 升级（重新生成更高等级的怪物）
  void levelUp() {
    state = state.copyWith(level: state.level + 1);
  }

  /// 生成新怪物
  void spawn(Monster monster) {
    state = MonsterState.fromMonster(monster);
  }

  /// 重置
  void reset() {
    state = const MonsterState();
  }

  int _calcPhase(int hp, int maxHp) {
    if (maxHp <= 0) return 1;
    final percent = hp / maxHp;
    if (percent > 0.66) return 1;
    if (percent > 0.33) return 2;
    return 3;
  }
}

/// 怪物 Provider
final monsterProvider =
    StateNotifierProvider<MonsterNotifier, MonsterState>((ref) {
  return MonsterNotifier();
});
