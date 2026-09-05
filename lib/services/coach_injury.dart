import 'camera_move_fsm.dart';

/// 伤病过滤：可选膝盖 / 腰腹标记，默认全部动作可用。
class InjuryFlags {
  /// 膝盖不适：去掉深蹲、弓步、高抬腿、波比等负重/冲击屈膝。
  final bool kneeIssue;

  /// 腰腹不适：去掉平板、登山跑、波比等核心屈曲。
  final bool waistIssue;

  const InjuryFlags({
    this.kneeIssue = false,
    this.waistIssue = false,
  });

  bool get hasAny => kneeIssue || waistIssue;

  /// 需要从处方中剔除的摄像头动作 type。
  Set<String> get excludedTypes {
    final out = <String>{};
    if (kneeIssue) {
      out.addAll(kneeTypes);
    }
    if (waistIssue) {
      out.addAll(waistTypes);
    }
    return out;
  }

  static List<String> get kneeTypes =>
      CameraGuidableCatalog.kneeLoadTypes().toList(growable: false);

  static List<String> get waistTypes =>
      CameraGuidableCatalog.waistLoadTypes().toList(growable: false);
}

/// 从处方候选 type 列表中去掉伤病动作。
List<String> filterInjuredTypes(
  Iterable<String> types, {
  InjuryFlags flags = const InjuryFlags(),
}) {
  if (!flags.hasAny) return List<String>.from(types);
  final banned = flags.excludedTypes;
  return types.where((t) => !banned.contains(t)).toList();
}
