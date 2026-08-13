/// 纠姿口令：只复用 ML Kit 已有反馈（出画 / 远近 / 深蹲深度），不新增视觉模型。
enum CoachCueKind {
  outOfFrame,
  tooClose,
  tooFar,
  squatDepth,
  none,
}

class CoachCue {
  final CoachCueKind kind;
  final String spoken;

  const CoachCue(this.kind, this.spoken);

  bool get isEmpty => kind == CoachCueKind.none;
}

/// 将检测器原文 / 门控 tip 映射成可播报的具体口令。
CoachCue resolveCoachCue({
  String? formTip,
  String? liveFeedback,
  String? exerciseType,
}) {
  final tip = formTip ?? '';
  if (tip == 'out_of_frame') {
    return const CoachCue(CoachCueKind.outOfFrame, '出画面了，请重新走进镜头');
  }
  if (tip == 'too_close') {
    return const CoachCue(CoachCueKind.tooClose, '太近了，请再退后几步');
  }
  if (tip == 'too_far') {
    return const CoachCue(CoachCueKind.tooFar, '太远了，请再靠近一点');
  }

  final fb = liveFeedback ?? '';
  if (fb.contains('全身入镜') || fb.contains('出画面') || fb.contains('走进画面')) {
    return const CoachCue(CoachCueKind.outOfFrame, '出画面了，请重新走进镜头');
  }
  if (fb.contains('太近')) {
    return const CoachCue(CoachCueKind.tooClose, '太近了，请再退后几步');
  }
  if (fb.contains('太远')) {
    return const CoachCue(CoachCueKind.tooFar, '太远了，请再靠近一点');
  }

  final type = exerciseType ?? '';
  final depthLike = fb.contains('幅度不够') ||
      fb.contains('再蹲低') ||
      fb.contains('再蹲深') ||
      fb.contains('幅度有点浅');
  if (depthLike && (type == 'squat' || type == 'lunge' || type.isEmpty)) {
    if (type == 'lunge') {
      return const CoachCue(CoachCueKind.squatDepth, '弓步再低一点，前膝大约九十度');
    }
    return const CoachCue(CoachCueKind.squatDepth, '蹲再低一点，大腿尽量平行地面');
  }

  return const CoachCue(CoachCueKind.none, '');
}
