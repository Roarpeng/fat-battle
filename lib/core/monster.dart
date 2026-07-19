import '../constants/app_constants.dart';
import 'core_types.dart';

/// 怪物生成 —— 纯函数实现。
///
/// 对应 web/src/core/monster.ts，并内联了 web/src/data/monsters.ts 中的
/// `MONSTER_DEFS` / `SEASONAL_MONSTERS` 数据与 `getMonsterDefByLevel` /
/// `calculateMonsterHp` / `calculateMonsterShield` 辅助函数，
/// 使本文件不依赖 Web 端 data 层。

// ========== 怪物定义数据 ==========

/// 基础怪物定义表。
/// 对应 web/src/data/monsters.ts 中的 `MONSTER_DEFS`。
const List<MonsterDef> _monsterDefs = [
  // ---- 小怪 (Minion) ----
  MonsterDef(
    id: 'slime',
    name: '懒惰史莱姆',
    emoji: '🟢',
    tier: MonsterTier.minion,
    weakness: ExerciseCategory.cardio,
    affinity: ExerciseCategory.core,
    baseHp: 100,
    hpPerLevel: 30,
    baseAttack: 5,
    description: '软绵绵的果冻怪，看上去人畜无害，但会让你越来越懒。',
    enrageThreshold: 0.2,
    enrageMultiplier: 1.3,
    coinMultiplier: 1,
    baseShield: 20,
    shieldPerLevel: 5,
    shieldReductionRate: 0.15,
  ),
  MonsterDef(
    id: 'goblin',
    name: '贪吃哥布林',
    emoji: '👺',
    tier: MonsterTier.minion,
    weakness: ExerciseCategory.strength,
    affinity: ExerciseCategory.cardio,
    baseHp: 120,
    hpPerLevel: 35,
    baseAttack: 8,
    description: '矮小的美食强盗，专门偷吃你的健康餐。',
    enrageThreshold: 0.2,
    enrageMultiplier: 1.3,
    coinMultiplier: 1,
    baseShield: 25,
    shieldPerLevel: 6,
    shieldReductionRate: 0.18,
  ),
  MonsterDef(
    id: 'ghost',
    name: '肥胖幽灵',
    emoji: '👻',
    tier: MonsterTier.minion,
    weakness: ExerciseCategory.core,
    affinity: ExerciseCategory.strength,
    baseHp: 110,
    hpPerLevel: 32,
    baseAttack: 7,
    description: '飘荡的脂肪之魂，你的每一口夜宵都在喂养它。',
    enrageThreshold: 0.2,
    enrageMultiplier: 1.4,
    coinMultiplier: 1,
    baseShield: 22,
    shieldPerLevel: 5,
    shieldReductionRate: 0.16,
  ),
  MonsterDef(
    id: 'skeleton',
    name: '碳水骷髅',
    emoji: '💀',
    tier: MonsterTier.minion,
    weakness: ExerciseCategory.cardio,
    affinity: ExerciseCategory.core,
    baseHp: 130,
    hpPerLevel: 38,
    baseAttack: 10,
    description: '由精制碳水构成的骨架，坚硬但脆弱。',
    enrageThreshold: 0.25,
    enrageMultiplier: 1.3,
    coinMultiplier: 1,
    baseShield: 28,
    shieldPerLevel: 6,
    shieldReductionRate: 0.2,
  ),

  // ---- 精英怪 (Elite) ----
  MonsterDef(
    id: 'orc',
    name: '油腻兽人',
    emoji: '👹',
    tier: MonsterTier.elite,
    weakness: ExerciseCategory.strength,
    affinity: ExerciseCategory.cardio,
    baseHp: 250,
    hpPerLevel: 50,
    baseAttack: 15,
    description: '浑身油脂的肌肉兽人，防御力极强，需要力量型运动才能击穿。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.5,
    coinMultiplier: 2,
    baseShield: 75,
    shieldPerLevel: 12,
    shieldReductionRate: 0.28,
    phases: [
      MonsterPhase(
        name: '正常状态',
        hpThreshold: 1.0,
        emoji: '👹',
        damageBonus: 1.0,
        desc: '油腻兽人正在观察你的动作。',
      ),
      MonsterPhase(
        name: '油脂爆发',
        hpThreshold: 0.5,
        emoji: '😤',
        damageBonus: 1.3,
        desc: '兽人进入油脂爆发状态，攻击力提升！',
      ),
    ],
  ),
  MonsterDef(
    id: 'vampire',
    name: '甜点吸血鬼',
    emoji: '🧛',
    tier: MonsterTier.elite,
    weakness: ExerciseCategory.core,
    affinity: ExerciseCategory.strength,
    baseHp: 280,
    hpPerLevel: 55,
    baseAttack: 18,
    description: '以甜点为食的暗夜贵族，会在你吃甜食时回复生命。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.5,
    coinMultiplier: 2,
    baseShield: 85,
    shieldPerLevel: 14,
    shieldReductionRate: 0.3,
    phases: [
      MonsterPhase(
        name: '优雅形态',
        hpThreshold: 1.0,
        emoji: '🧛',
        damageBonus: 1.0,
        desc: '吸血鬼优雅地品鉴着你的意志力。',
      ),
      MonsterPhase(
        name: '嗜血形态',
        hpThreshold: 0.5,
        emoji: '🦇',
        damageBonus: 1.4,
        desc: '吸血鬼露出獠牙，进入嗜血狂暴！',
      ),
    ],
  ),
  MonsterDef(
    id: 'dragon',
    name: '脂肪巨龙',
    emoji: '🐉',
    tier: MonsterTier.elite,
    weakness: ExerciseCategory.cardio,
    affinity: ExerciseCategory.strength,
    baseHp: 320,
    hpPerLevel: 60,
    baseAttack: 20,
    description: '千年脂肪凝结的巨龙，需要大量有氧运动才能消耗它的体力。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.6,
    coinMultiplier: 2,
    baseShield: 100,
    shieldPerLevel: 15,
    shieldReductionRate: 0.32,
    phases: [
      MonsterPhase(
        name: '慵懒形态',
        hpThreshold: 1.0,
        emoji: '🐉',
        damageBonus: 1.0,
        desc: '巨龙慵懒地趴在脂肪堆上。',
      ),
      MonsterPhase(
        name: '怒火形态',
        hpThreshold: 0.5,
        emoji: '🔥',
        damageBonus: 1.5,
        desc: '巨龙喷出卡路里火焰，怒火中烧！',
      ),
    ],
  ),

  // ---- BOSS ----
  MonsterDef(
    id: 'calorie_demon',
    name: '卡路里魔王',
    emoji: '👿',
    tier: MonsterTier.boss,
    weakness: ExerciseCategory.strength,
    affinity: ExerciseCategory.cardio,
    baseHp: 500,
    hpPerLevel: 80,
    baseAttack: 25,
    description: '卡路里的化身，所有过量饮食的最终产物。力量型运动是它的克星。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.8,
    coinMultiplier: 3,
    baseShield: 180,
    shieldPerLevel: 25,
    shieldReductionRate: 0.35,
    phases: [
      MonsterPhase(
        name: '傲慢阶段',
        hpThreshold: 1.0,
        emoji: '👿',
        damageBonus: 1.0,
        desc: '卡路里魔王傲慢地看着你，认为你不可能坚持下来。',
      ),
      MonsterPhase(
        name: '暴食阶段',
        hpThreshold: 0.6,
        emoji: '😤',
        damageBonus: 1.3,
        desc: '魔王进入暴食状态，试图用美食诱惑你放弃！',
      ),
      MonsterPhase(
        name: '虚弱阶段',
        hpThreshold: 0.25,
        emoji: '😵',
        damageBonus: 0.8,
        desc: '魔王的脂肪护甲破碎，露出虚弱的核心！此时伤害加成！',
      ),
    ],
  ),
  MonsterDef(
    id: 'glutton_lord',
    name: '暴食魔王',
    emoji: '😋',
    tier: MonsterTier.boss,
    weakness: ExerciseCategory.core,
    affinity: ExerciseCategory.strength,
    baseHp: 550,
    hpPerLevel: 90,
    baseAttack: 28,
    description: '永远无法满足的暴食之主，核心训练能击碎它贪婪的核心。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.8,
    coinMultiplier: 3,
    baseShield: 200,
    shieldPerLevel: 28,
    shieldReductionRate: 0.35,
    phases: [
      MonsterPhase(
        name: '盛宴阶段',
        hpThreshold: 1.0,
        emoji: '😋',
        damageBonus: 1.0,
        desc: '暴食魔王正在享用盛宴，无暇顾及你。',
      ),
      MonsterPhase(
        name: '饥饿阶段',
        hpThreshold: 0.55,
        emoji: '🤤',
        damageBonus: 1.4,
        desc: '魔王陷入饥饿狂暴，攻击力大幅提升！',
      ),
      MonsterPhase(
        name: '消化不良阶段',
        hpThreshold: 0.2,
        emoji: '🤢',
        damageBonus: 0.7,
        desc: '魔王消化不良，核心暴露！全力输出！',
      ),
    ],
  ),

  // ---- 最终BOSS ----
  MonsterDef(
    id: 'sloth_king',
    name: '懒惰之王',
    emoji: '👑',
    tier: MonsterTier.finalboss,
    weakness: ExerciseCategory.cardio,
    affinity: ExerciseCategory.core,
    baseHp: 1000,
    hpPerLevel: 150,
    baseAttack: 35,
    description: '懒惰的终极化身。它不攻击你，只是让你放弃。只有有氧运动能唤醒你的意志。',
    enrageThreshold: 0.25,
    enrageMultiplier: 2.0,
    coinMultiplier: 5,
    baseShield: 450,
    shieldPerLevel: 45,
    shieldReductionRate: 0.4,
    phases: [
      MonsterPhase(
        name: '慵懒王座',
        hpThreshold: 1.0,
        emoji: '👑',
        damageBonus: 1.0,
        desc: '懒惰之王坐在沙发上，懒洋洋地看着你挣扎。',
      ),
      MonsterPhase(
        name: '烦躁阶段',
        hpThreshold: 0.65,
        emoji: '😒',
        damageBonus: 1.2,
        desc: '你的坚持让懒惰之王开始烦躁了。',
      ),
      MonsterPhase(
        name: '恐慌阶段',
        hpThreshold: 0.35,
        emoji: '😱',
        damageBonus: 1.6,
        desc: '懒惰之王发现你真的要改变了！它开始疯狂反击！',
      ),
      MonsterPhase(
        name: '崩溃阶段',
        hpThreshold: 0.1,
        emoji: '💀',
        damageBonus: 0.5,
        desc: '懒惰之王的王座崩塌！给予最后一击！',
      ),
    ],
  ),
  MonsterDef(
    id: 'desire_lord',
    name: '欲望之主',
    emoji: '😈',
    tier: MonsterTier.finalboss,
    weakness: ExerciseCategory.strength,
    affinity: ExerciseCategory.cardio,
    baseHp: 1200,
    hpPerLevel: 180,
    baseAttack: 40,
    description: '所有食欲和惰欲的源头。力量训练能斩断它的欲望锁链。',
    enrageThreshold: 0.2,
    enrageMultiplier: 2.2,
    coinMultiplier: 5,
    baseShield: 550,
    shieldPerLevel: 55,
    shieldReductionRate: 0.42,
    phases: [
      MonsterPhase(
        name: '诱惑阶段',
        hpThreshold: 1.0,
        emoji: '😈',
        damageBonus: 1.0,
        desc: '欲望之主用美食和安逸诱惑你放弃。',
      ),
      MonsterPhase(
        name: '威压阶段',
        hpThreshold: 0.6,
        emoji: '🔥',
        damageBonus: 1.4,
        desc: '欲望之主释放欲望威压，试图压垮你的意志！',
      ),
      MonsterPhase(
        name: '狂暴阶段',
        hpThreshold: 0.3,
        emoji: '💢',
        damageBonus: 1.8,
        desc: '欲望之主彻底狂暴！但它的防御已经破碎！',
      ),
      MonsterPhase(
        name: '消散阶段',
        hpThreshold: 0.08,
        emoji: '🌫️',
        damageBonus: 0.3,
        desc: '欲望之主正在消散...最后一击！',
      ),
    ],
  ),
];

/// 赛季限定怪物定义表。
/// 对应 web/src/data/monsters.ts 中的 `SEASONAL_MONSTERS`。
const List<MonsterDef> _seasonalMonsters = [
  MonsterDef(
    id: 'sakura_spirit',
    name: '樱花精灵',
    emoji: '🌸',
    tier: MonsterTier.elite,
    weakness: ExerciseCategory.cardio,
    affinity: ExerciseCategory.core,
    baseHp: 300,
    hpPerLevel: 50,
    baseAttack: 15,
    description: '春季限定！樱花飘落间的慵懒精灵，用有氧运动唤醒它的活力。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.4,
    coinMultiplier: 3,
    baseShield: 80,
    shieldPerLevel: 12,
    shieldReductionRate: 0.28,
    season: Season.spring,
    phases: [
      MonsterPhase(name: '花眠', hpThreshold: 1.0, emoji: '🌸', damageBonus: 1.0, desc: '樱花精灵在花瓣中沉睡。'),
      MonsterPhase(name: '花舞', hpThreshold: 0.5, emoji: '🌺', damageBonus: 1.3, desc: '樱花精灵翩翩起舞，速度加快！'),
    ],
  ),
  MonsterDef(
    id: 'icecream_titan',
    name: '冰沙巨魔',
    emoji: '🍧',
    tier: MonsterTier.boss,
    weakness: ExerciseCategory.strength,
    affinity: ExerciseCategory.cardio,
    baseHp: 600,
    hpPerLevel: 100,
    baseAttack: 30,
    description: '夏季限定！由冰淇淋和冷饮凝结而成的巨魔，力量训练能打碎它的冰甲。',
    enrageThreshold: 0.25,
    enrageMultiplier: 1.7,
    coinMultiplier: 4,
    baseShield: 210,
    shieldPerLevel: 28,
    shieldReductionRate: 0.35,
    season: Season.summer,
    phases: [
      MonsterPhase(name: '冰封', hpThreshold: 1.0, emoji: '🍧', damageBonus: 1.0, desc: '冰沙巨魔的冰甲闪闪发光。'),
      MonsterPhase(name: '融化', hpThreshold: 0.5, emoji: '🧊', damageBonus: 1.3, desc: '冰甲开始融化，但巨魔更加凶猛！'),
      MonsterPhase(name: '蒸发', hpThreshold: 0.2, emoji: '💨', damageBonus: 0.6, desc: '巨魔正在蒸发！全力输出！'),
    ],
  ),
  MonsterDef(
    id: 'pumpkin_knight',
    name: '南瓜骑士',
    emoji: '🎃',
    tier: MonsterTier.elite,
    weakness: ExerciseCategory.strength,
    affinity: ExerciseCategory.cardio,
    baseHp: 350,
    hpPerLevel: 60,
    baseAttack: 18,
    description: '秋季限定！丰收季的守护者，用甜食堆砌的盔甲坚不可摧。',
    enrageThreshold: 0.3,
    enrageMultiplier: 1.5,
    coinMultiplier: 3,
    baseShield: 100,
    shieldPerLevel: 15,
    shieldReductionRate: 0.3,
    season: Season.autumn,
    phases: [
      MonsterPhase(name: '丰收', hpThreshold: 1.0, emoji: '🎃', damageBonus: 1.0, desc: '南瓜骑士守护着丰收的甜食。'),
      MonsterPhase(name: '枯萎', hpThreshold: 0.5, emoji: '🍂', damageBonus: 1.4, desc: '南瓜开始枯萎，骑士陷入狂暴！'),
    ],
  ),
  MonsterDef(
    id: 'frost_troll',
    name: '寒霜巨魔',
    emoji: '❄️',
    tier: MonsterTier.boss,
    weakness: ExerciseCategory.core,
    affinity: ExerciseCategory.strength,
    baseHp: 650,
    hpPerLevel: 110,
    baseAttack: 32,
    description: '冬季限定！由冬季惰性凝聚的巨魔，核心训练能击碎它的冰核。',
    enrageThreshold: 0.25,
    enrageMultiplier: 1.7,
    coinMultiplier: 4,
    baseShield: 230,
    shieldPerLevel: 30,
    shieldReductionRate: 0.35,
    season: Season.winter,
    phases: [
      MonsterPhase(name: '冰封', hpThreshold: 1.0, emoji: '❄️', damageBonus: 1.0, desc: '寒霜巨魔在暴风雪中沉睡。'),
      MonsterPhase(name: '觉醒', hpThreshold: 0.5, emoji: '🥶', damageBonus: 1.4, desc: '巨魔被惊醒，暴风雪肆虐！'),
      MonsterPhase(name: '碎裂', hpThreshold: 0.2, emoji: '💠', damageBonus: 0.5, desc: '冰核暴露！一击必杀！'),
    ],
  ),
];

// ========== 内部辅助函数（来自 data/monsters.ts） ==========

/// 根据等级获取怪物定义。
/// 对应 web/src/data/monsters.ts 中的 `getMonsterDefByLevel`。
MonsterDef _getMonsterDefByLevel(int level) {
  final allMonsters = [..._monsterDefs, ..._seasonalMonsters];

  // 每10级 = BOSS
  if (level % 10 == 0) {
    final bosses = allMonsters.where((m) => m.tier == MonsterTier.boss).toList();
    final idx = (level ~/ 10 - 1) % bosses.length;
    return bosses[idx];
  }
  // 每5级 = 精英
  if (level % 5 == 0) {
    final elites = allMonsters.where((m) => m.tier == MonsterTier.elite).toList();
    final idx = (level ~/ 5 - 1) % elites.length;
    return elites[idx];
  }
  // Level >= 50 = 最终BOSS（非 5/10 倍数的等级）
  if (level >= 50) {
    final finalBosses = allMonsters.where((m) => m.tier == MonsterTier.finalboss).toList();
    final idx = ((level - 50) ~/ 10) % finalBosses.length;
    return finalBosses[idx];
  }
  // 其余 = 小怪
  final minions = allMonsters.where((m) => m.tier == MonsterTier.minion).toList();
  final idx = (level - 1) % minions.length;
  return minions[idx];
}

/// 计算怪物在指定等级的 HP。
/// 对应 web/src/data/monsters.ts 中的 `calculateMonsterHp`。
int _calculateMonsterHp(MonsterDef def, int level, Difficulty difficulty) {
  final diffMultiplier = difficulty == Difficulty.easy
      ? 0.7
      : (difficulty == Difficulty.hard ? 1.3 : 1.0);
  return ((def.baseHp + def.hpPerLevel * (level - 1)) * diffMultiplier).round();
}

// ========== 公共纯函数 ==========

/// 生成怪物完整状态（提取自 `game-utils.generateMonster`）。
///
/// 护盾完全来自过量卡路里，初始为 0。
/// `maxShield` 初始为 0，会随护盾增长动态调整。
///
/// [level] 怪物等级（决定怪物定义与 HP/护盾成长）
/// [difficulty] 难度，影响 HP 与护盾基数，默认 `Difficulty.normal`
/// [hpMultiplier] AI 教练动态 HP 倍率，默认 1
MonsterState generateMonster(
  int level, [
  Difficulty difficulty = Difficulty.normal,
  double hpMultiplier = 1.0,
]) {
  final def = _getMonsterDefByLevel(level);
  final maxHp = (_calculateMonsterHp(def, level, difficulty) * hpMultiplier).round();
  final hpPercentage = 1.0;
  final phases = def.phases;
  final currentPhase = phases.isNotEmpty ? phases[0] : null;
  final isEnraged = hpPercentage <= def.enrageThreshold;

  return MonsterState(
    hp: maxHp,
    maxHp: maxHp,
    level: level,
    name: def.name,
    emoji: def.emoji,
    type: def.id,
    defId: def.id,
    tier: def.tier,
    weakness: def.weakness,
    affinity: def.affinity,
    baseAttack: def.baseAttack,
    description: def.description,
    enrageThreshold: def.enrageThreshold,
    enrageMultiplier: def.enrageMultiplier,
    coinMultiplier: def.coinMultiplier,
    phaseIndex: 0,
    phaseName: currentPhase?.name ?? '',
    phaseEmoji: currentPhase?.emoji ?? def.emoji,
    isEnraged: isEnraged,
    season: def.season,
    hpMultiplier: hpMultiplier,
    isPhantom: false,
    // 护盾系统：护盾完全来自过量卡路里，初始为 0
    shield: 0,
    maxShield: 0,
    shieldReductionRate: def.shieldReductionRate,
  );
}

/// 根据当前 HP 百分比更新怪物阶段与狂暴状态（纯函数版本）。
///
/// 提取自 `game-utils.updateMonsterPhase`，去除对完整 monster 对象的依赖，
/// 仅需 HP 百分比与可选阶段定义，便于双端复用。
///
/// [hpPercent] 当前 HP 占最大 HP 的比例 (0-1)
/// [phases] 阶段定义数组（来自怪物定义），默认空数组
/// [enrageThreshold] 狂暴阈值，默认 0.3
/// 返回阶段索引、阶段名、阶段 emoji、是否狂暴。
MonsterPhaseInfo updateMonsterPhase(
  double hpPercent, [
  List<MonsterPhase> phases = const [],
  double enrageThreshold = 0.3,
]) {
  var phaseIndex = 0;
  var phaseName = '';
  var phaseEmoji = '';

  if (phases.isNotEmpty) {
    for (var i = 0; i < phases.length; i++) {
      if (hpPercent <= phases[i].hpThreshold) {
        phaseIndex = i;
        phaseName = phases[i].name;
        phaseEmoji = phases[i].emoji;
      }
    }
  }

  final isEnraged = hpPercent <= enrageThreshold;

  return MonsterPhaseInfo(
    phaseIndex: phaseIndex,
    phaseName: phaseName,
    phaseEmoji: phaseEmoji,
    isEnraged: isEnraged,
  );
}

/// 怪物阶段信息（`updateMonsterPhase` 的返回值）。
class MonsterPhaseInfo {
  final int phaseIndex;
  final String phaseName;
  final String phaseEmoji;
  final bool isEnraged;

  const MonsterPhaseInfo({
    required this.phaseIndex,
    required this.phaseName,
    required this.phaseEmoji,
    required this.isEnraged,
  });
}

/// 判断怪物是否处于狂暴状态（提取自 `data/monsters.isMonsterEnraged` 的纯函数版本）。
///
/// [hpPercent] 当前 HP 占最大 HP 的比例 (0-1)
/// [enrageThreshold] 狂暴阈值，默认 0.3
/// 返回 HP 百分比 <= 阈值时返回 true。
bool isMonsterEnraged(double hpPercent, [double enrageThreshold = 0.3]) {
  return hpPercent <= enrageThreshold;
}
