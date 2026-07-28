import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/game_models.dart';
import 'monster_display.dart';
import 'damage_number.dart';
import 'attack_effect.dart';
import 'energy_shield.dart';

/// 伤害事件（用于触发动画）
class DamageEvent {
  /// 唯一 ID
  final String id;

  ///  数�
  final int value;

  /// 类型
  final DamageType type;

  ///  攻击类型（仅 damage / critical / weak 时有意义�
  final AttackKind? attackKind;

  /// 触发时间
  final DateTime timestamp;

  DamageEvent({
    required this.value,
    required this.type,
    this.attackKind,
    DateTime? timestamp,
  })  : id = '${DateTime.now().microsecondsSinceEpoch}_${timestamp?.hashCode ?? DamageEvent._counter++}',
        timestamp = timestamp ?? DateTime.now();

  static int _counter = 0;
}

/// 怪物战斗状态（聚合展示用）
///
///  简化的怪物状态视图模型，�?[Monster] + 额外动画标志位构�
class MonsterBattleState {
  /// 怪物基础数据
  final Monster monster;

  ///  是否狂暴（HP < 30% 自动判定，或外部传入�
  final bool isEnraged;

  /// 是否处于阶段切换（外部触发）
  final bool isPhaseChanging;

  const MonsterBattleState({
    required this.monster,
    this.isEnraged = false,
    this.isPhaseChanging = false,
  });

  ///  根据 Monster 自动构造（HP < 30% 触发狂暴�
  factory MonsterBattleState.from(Monster monster,
      {bool isPhaseChanging = false}) {
    return MonsterBattleState(
      monster: monster,
      isEnraged: !monster.isBoss ? monster.hpPercent < 0.3 : monster.hpPercent < 0.4,
      isPhaseChanging: isPhaseChanging,
    );
  }

  double get hpPercent => monster.hpPercent;
  bool get hasShield => monster.hasShield;
  bool get isDead => monster.hp <= 0;
}

/// 战斗特效聚合组件
///
/// 设计参�?Web �?BattlePage.tsx 的状态管�?+ BattleEffects.tsx 聚合�?/// - 渲染 HP �?+ 怪物 + 护盾 + 攻击特效 + 伤害飘字
/// - 自动监听 [monster] / [lastDamage] 变化触发动画
/// - 内部维护活跃的伤害飘字队列和攻击特效队列
class BattleEffects extends StatefulWidget {
  ///  怪物战斗状�
  final MonsterBattleState monster;

  /// 最近一次伤害事件（�?null 时触发动画）
  final DamageEvent? lastDamage;

  ///  是否处于护盾破碎状�
  final bool isShieldBreaking;

  /// 怪物 emoji 字号
  final double emojiSize;

  /// 护盾光圈尺寸
  final double shieldSize;

  /// 怪物点击回调
  final VoidCallback? onMonsterTap;

  /// 特效完成回调（伤害飘�?/ 攻击特效全部消失后）
  final VoidCallback? onEffectsCleared;

  const BattleEffects({
    super.key,
    required this.monster,
    this.lastDamage,
    this.isShieldBreaking = false,
    this.emojiSize = 96,
    this.shieldSize = 280,
    this.onMonsterTap,
    this.onEffectsCleared,
  });

  @override
  State<BattleEffects> createState() => _BattleEffectsState();
}

class _BattleEffectsState extends State<BattleEffects> {
  //  活跃的伤害飘�
  final List<DamageEvent> _activeDamageNumbers = [];
  //  活跃的攻击特�
  final List<_AttackEffectEntry> _activeAttackEffects = [];
  //  是否正在受伤（用于触发怪物抖动�
  bool _isMonsterHit = false;
  // 已处理过�?lastDamage ID
  String? _processedDamageId;

  @override
  void initState() {
    super.initState();
    _processDamage(widget.lastDamage);
  }

  @override
  void didUpdateWidget(covariant BattleEffects oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检�?lastDamage 是否变化
    if (widget.lastDamage != null &&
        widget.lastDamage!.id != _processedDamageId) {
      _processDamage(widget.lastDamage);
    }
  }

  ///  处理一次伤害事件：添加到队�
  void _processDamage(DamageEvent? event) {
    if (event == null) return;
    _processedDamageId = event.id;

    // 触发怪物受伤动画
    if (event.type == DamageType.damage ||
        event.type == DamageType.critical ||
        event.type == DamageType.weak) {
      setState(() {
        _isMonsterHit = true;
        _activeDamageNumbers.add(event);
      });
      //  500ms 后清除受伤标�
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _isMonsterHit = false);
        }
      });
    } else if (event.type == DamageType.shield || event.type == DamageType.heal) {
      setState(() {
        _activeDamageNumbers.add(event);
      });
    }

    //  如果是伤害类，触发攻击特�
    if ((event.type == DamageType.damage ||
            event.type == DamageType.critical ||
            event.type == DamageType.weak) &&
        event.attackKind != null) {
      setState(() {
        _activeAttackEffects.add(_AttackEffectEntry(
          id: event.id,
          kind: event.attackKind!,
          damage: event.value,
        ));
      });
    }
  }

  void _removeDamageNumber(String id) {
    setState(() {
      _activeDamageNumbers.removeWhere((e) => e.id == id);
    });
    _maybeNotifyCleared();
  }

  void _removeAttackEffect(String id) {
    setState(() {
      _activeAttackEffects.removeWhere((e) => e.id == id);
    });
    _maybeNotifyCleared();
  }

  void _maybeNotifyCleared() {
    if (_activeDamageNumbers.isEmpty && _activeAttackEffects.isEmpty) {
      widget.onEffectsCleared?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 怪物 + 护盾
        _buildMonsterWithShield(),
        //  攻击特效�
        ..._buildAttackEffects(),
        //  伤害飘字�
        ..._buildDamageNumbers(),
      ],
    );
  }

  /// 怪物 + 护盾（叠加渲染）
  Widget _buildMonsterWithShield() {
    final monster = widget.monster.monster;
    return SizedBox(
      width: widget.shieldSize,
      height: widget.shieldSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          //  护盾光圈（在怪物后方�
          if (widget.monster.hasShield || widget.isShieldBreaking)
            EnergyShield(
              value: monster.shield,
              maxShield: monster.maxHp,
              size: widget.shieldSize,
              isBreaking: widget.isShieldBreaking,
            ),
          // 怪物主体
          MonsterDisplay(
            emoji: monster.emoji,
            hpPercentage: widget.monster.hpPercent,
            isHit: _isMonsterHit,
            isEnraged: widget.monster.isEnraged,
            isDead: widget.monster.isDead,
            isPhaseChanging: widget.monster.isPhaseChanging,
            emojiSize: widget.emojiSize,
            onTap: widget.onMonsterTap,
          ),
        ],
      ),
    );
  }

  ///  攻击特效�
  List<Widget> _buildAttackEffects() {
    return _activeAttackEffects.map((entry) {
      return AttackEffect(
        key: ValueKey('attack_${entry.id}'),
        id: entry.id,
        kind: entry.kind,
        damage: entry.damage,
        onComplete: () => _removeAttackEffect(entry.id),
      );
    }).toList();
  }

  ///  伤害飘字层（覆盖在怪物上方�
  List<Widget> _buildDamageNumbers() {
    return _activeDamageNumbers.map((event) {
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Center(
          child: DamageNumber(
            key: ValueKey('damage_${event.id}'),
            id: event.id,
            value: event.value,
            type: event.type,
            onComplete: () => _removeDamageNumber(event.id),
          ),
        ),
      );
    }).toList();
  }
}

///  攻击特效条目（内部用�
class _AttackEffectEntry {
  final String id;
  final AttackKind kind;
  final int damage;

  const _AttackEffectEntry({
    required this.id,
    required this.kind,
    required this.damage,
  });
}

/// 工具：根据锻�?[ExerciseRecord] 推断攻击类型
///
/// Flutter 端运�?[ExerciseType.type] 映射�?/// - cardio：running / walking / cycling / swimming / jumping_jack / jumprope / hiit
/// - strength：pushup / squat / strength
/// - core：yoga
AttackKind inferAttackKind(String exerciseType) {
  switch (exerciseType) {
    case 'pushup':
    case 'squat':
    case 'strength':
      return AttackKind.strength;
    case 'yoga':
      return AttackKind.core;
    case 'running':
    case 'walking':
    case 'cycling':
    case 'swimming':
    case 'jumping_jack':
    case 'jumprope':
    case 'hiit':
    default:
      return AttackKind.cardio;
  }
}

/// 工具：根据伤害值与上下文判�?[DamageType]
///
/// - 暴击概率�?15%
/// - 护盾被破：shield 类型
/// - 普通伤害：damage
DamageType inferDamageType({
  required int value,
  required bool shieldBroken,
  bool isCritical = false,
}) {
  if (shieldBroken) return DamageType.shield;
  if (isCritical) return DamageType.critical;
  return DamageType.damage;
}
