/// 运动游戏化逻辑类，独立于相机/IMU/手动模式，可在各模式间复用。
///
/// 核心职责：
/// - 连击（Combo）计数与倍率计算
/// - 体力消耗与恢复
/// - 暂停检测（人物丢失/返回帧计数）
/// - 准备倒计时
/// - 动作质量评分（角度、深度、身体线条）
class ExerciseGameLogic {
  // ===========================================================================
  // 常量
  // ===========================================================================

  /// 最大体力值
  static const double maxStamina = 100.0;

  /// 每次动作消耗的体力
  static const double staminaPerRep = 8.0;

  /// 每帧恢复的体力值
  static const double staminaRecoveryPerFrame = 0.8;

  /// 连击窗口（毫秒）：在此时间内再次成功动作则连击
  static const int comboWindowMs = 3000;

  /// 连击倍率：每 N 次连击增加 0.2x
  static const int combosPerTier = 5;

  /// 连击倍率增量
  static const double multiplierPerTier = 0.2;

  /// 最大连击倍率
  static const double maxMultiplier = 2.0;

  /// 人物丢失帧数阈值：超过此帧数触发暂停
  static const int personLostThreshold = 15;

  /// 人物返回帧数阈值：超过此帧数恢复播放
  static const int personReturnThreshold = 5;

  /// 准备倒计时时长（秒）
  static const double prepareDurationSec = 2.0;

  // ===========================================================================
  // 连击状态
  // ===========================================================================

  /// 当前连击次数
  int comboCount = 0;

  /// 当前连击倍率（基础 1.0，范围 1.0 ~ 2.0）
  double comboMultiplier = 1.0;

  /// 上一次连击时间戳（毫秒，DateTime.millisecondsSinceEpoch）
  int lastComboTime = 0;

  // ===========================================================================
  // 体力状态
  // ===========================================================================

  /// 当前体力值（最大值 100）
  double stamina = maxStamina;

  /// 体力是否已耗尽
  bool staminaDepleted = false;

  // ===========================================================================
  // 暂停状态
  // ===========================================================================

  /// 当前是否处于暂停态
  bool isPaused = false;

  /// 连续丢失人物的帧数
  int personLostFrames = 0;

  /// 人物重新出现后的连续帧数
  int personReturnedFrames = 0;

  // ===========================================================================
  // 准备状态
  // ===========================================================================

  /// 是否正在准备倒计时
  bool isPreparing = false;

  /// 准备开始的时间点
  DateTime? prepareStartTime;

  /// 准备进度（0.0 ~ 1.0）
  double prepareProgress = 0.0;

  // ===========================================================================
  // 质量评分
  // ===========================================================================

  /// 最近一次动作质量评分（0 ~ 100）
  int lastRepQuality = 0;

  /// 最近一次动作等级（S / A / B / C / D）
  String lastRepGrade = 'D';

  // ===========================================================================
  // 回调函数 — 供 UI 层绑定以响应状态变化
  // ===========================================================================

  /// 连击变化回调 (comboCount, comboMultiplier)
  void Function(int comboCount, double multiplier)? onComboChanged;

  /// 体力变化回调 (currentStamina, isDepleted)
  void Function(double stamina, bool depleted)? onStaminaChanged;

  /// 暂停状态变化回调 (isPaused)
  void Function(bool paused)? onPauseChanged;

  /// 准备进度回调 (progress 0.0~1.0)
  void Function(double progress)? onPrepareProgress;

  /// 动作质量评分回调 (qualityScore, grade)
  void Function(int quality, String grade)? onQualityScored;

  // ===========================================================================
  /// 处理一次动作成功完成。
  ///
  /// 逻辑：
  /// 1. 检查体力是否耗尽，耗尽则返回 false
  /// 2. 消耗体力
  /// 3. 判断是否在连击窗口内，更新连击计数与倍率
  /// 4. 触发相关回调
  ///
  /// 返回 true 表示动作被接受，false 表示体力不足拒绝动作。
  bool handleRepSuccess() {
    // 体力耗尽，无法完成动作
    if (staminaDepleted) {
      return false;
    }

    // 消耗体力，不低于 0
    stamina = (stamina - staminaPerRep).clamp(0.0, maxStamina);

    // ---- 连击判定 ----
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lastComboTime > 0 && (now - lastComboTime) <= comboWindowMs) {
      // 在 3 秒窗口内，连击 +1
      comboCount++;
    } else {
      // 超出窗口或首次动作，重置连击
      comboCount = 1;
    }

    lastComboTime = now;

    // 计算连击倍率：基础 1.0，每 5 连击 +0.2x，上限 2.0x
    comboMultiplier =
        (1.0 + (comboCount ~/ combosPerTier) * multiplierPerTier)
            .clamp(1.0, maxMultiplier);

    // 体力耗尽判定
    if (stamina <= 0.0) {
      staminaDepleted = true;
    }

    // 触发回调
    onComboChanged?.call(comboCount, comboMultiplier);
    onStaminaChanged?.call(stamina, staminaDepleted);

    return true;
  }

  // ===========================================================================
  /// 每帧调用以恢复体力。
  ///
  /// 每次调用恢复 [staminaRecoveryPerFrame] 点体力，上限 [maxStamina]。
  /// 当体力恢复至 > 0 时自动清除耗尽标记。
  void recoverStamina() {
    stamina += staminaRecoveryPerFrame;
    if (stamina > maxStamina) {
      stamina = maxStamina;
    }

    // 体力恢复后清除耗尽标记
    if (stamina > 0.0 && staminaDepleted) {
      staminaDepleted = false;
    }

    onStaminaChanged?.call(stamina, staminaDepleted);
  }

  // ===========================================================================
  /// 根据人物检测状态更新暂停逻辑。
  ///
  /// - 连续 [personLostThreshold] 帧无人 -> 进入暂停
  /// - 暂停后连续 [personReturnThreshold] 帧有人 -> 退出暂停
  void updatePauseState(bool hasPerson) {
    if (!hasPerson) {
      // 人物丢失：累加丢失帧数
      personReturnedFrames = 0;
      personLostFrames++;

      if (personLostFrames >= personLostThreshold && !isPaused) {
        isPaused = true;
        onPauseChanged?.call(true);
      }
    } else {
      // 人物存在
      if (isPaused) {
        // 暂停中人物回归：累加返回帧数
        personReturnedFrames++;

        if (personReturnedFrames >= personReturnThreshold) {
          // 达到恢复阈值：退出暂停
          isPaused = false;
          personLostFrames = 0;
          personReturnedFrames = 0;
          onPauseChanged?.call(false);
        }
      } else {
        // 正常运行中人物存在：重置丢失计数
        personLostFrames = 0;
      }
    }
  }

  // ===========================================================================
  /// 获取暂停/恢复进度（0.0 ~ 1.0）。
  ///
  /// - 未暂停时：进度朝向暂停阈值（personLostFrames / threshold）
  /// - 暂停中时：进度朝向恢复阈值（personReturnedFrames / threshold）
  double getPauseProgress() {
    if (isPaused) {
      // 恢复进度
      return (personReturnedFrames / personReturnThreshold).clamp(0.0, 1.0);
    } else {
      // 丢失进度
      return (personLostFrames / personLostThreshold).clamp(0.0, 1.0);
    }
  }

  // ===========================================================================
  /// 开始准备倒计时（2 秒）。
  void startPrepare() {
    isPreparing = true;
    prepareStartTime = DateTime.now();
    prepareProgress = 0.0;
    onPrepareProgress?.call(0.0);
  }

  // ===========================================================================
  /// 更新准备倒计时状态，每帧调用。
  ///
  /// [hasPerson] 人物是否仍在画面中。准备期间人物丢失则取消准备。
  ///
  /// 返回 true 表示准备倒计时已完成（2 秒已过且人物始终存在）。
  bool updatePrepareState(bool hasPerson) {
    if (!isPreparing) {
      return false;
    }

    if (!hasPerson) {
      // 准备期间人物丢失，取消准备
      isPreparing = false;
      prepareProgress = 0.0;
      onPrepareProgress?.call(0.0);
      return false;
    }

    // 计算已过时间
    final elapsed =
        DateTime.now().difference(prepareStartTime!).inMilliseconds / 1000.0;
    prepareProgress = (elapsed / prepareDurationSec).clamp(0.0, 1.0);
    onPrepareProgress?.call(prepareProgress);

    if (elapsed >= prepareDurationSec) {
      // 准备完成
      isPreparing = false;
      return true;
    }

    return false;
  }

  // ===========================================================================
  /// 计算动作质量评分。
  ///
  /// 参数：
  /// - [exercise]  动作名称（squat / pushup / lunge / situp / plank / jumping_jack / burpee）
  /// - [angle]     关节角度（度），实际测量值
  /// - [depth]     动作深度（0.0 ~ 1.0），实际测量值
  /// - [bodyLine]  身体线条垂直度（0.0 ~ 1.0），1.0 表示完美直线
  ///
  /// 评分逻辑：
  /// - 不同动作有不同的理想参数
  /// - 加权计算各项偏差得分（角度 40%、深度 30%、身体线条 30%）
  /// - 综合得分映射至 S / A / B / C / D 等级
  void calcQualityScore(
    String exercise,
    double angle,
    double depth,
    double bodyLine,
  ) {
    // 获取该动作的理想参数
    final ideal = _getIdealParams(exercise);

    // ---- 各项评分（0 ~ 100） ----
    // 角度评分：每偏离 1° 扣 2 分，最多扣到 0
    final angleDeviation = (angle - ideal.idealAngle).abs();
    final angleScore = (100 - angleDeviation * 2.0).clamp(0.0, 100.0);

    // 深度评分：每偏离 0.01 扣 2 分
    final depthDeviation = (depth - ideal.idealDepth).abs();
    final depthScore = (100 - depthDeviation * 200.0).clamp(0.0, 100.0);

    // 身体线条评分：每偏离 0.01 扣 2 分
    final bodyLineDeviation = (bodyLine - ideal.idealBodyLine).abs();
    final bodyLineScore =
        (100 - bodyLineDeviation * 200.0).clamp(0.0, 100.0);

    // ---- 加权综合得分 ----
    final rawScore = angleScore * 0.40 + depthScore * 0.30 + bodyLineScore * 0.30;
    final finalScore = rawScore.round().clamp(0, 100);

    // ---- 等级映射 ----
    final grade = _mapGrade(finalScore);

    // 存储最近一次结果
    lastRepQuality = finalScore;
    lastRepGrade = grade;

    // 触发回调
    onQualityScored?.call(finalScore, grade);
  }

  // ===========================================================================
  /// 重置所有状态，准备开始新动作或新一轮训练。
  void reset() {
    // 连击
    comboCount = 0;
    comboMultiplier = 1.0;
    lastComboTime = 0;

    // 体力
    stamina = maxStamina;
    staminaDepleted = false;

    // 暂停
    isPaused = false;
    personLostFrames = 0;
    personReturnedFrames = 0;

    // 准备
    isPreparing = false;
    prepareStartTime = null;
    prepareProgress = 0.0;

    // 质量评分
    lastRepQuality = 0;
    lastRepGrade = 'D';
  }

  // ===========================================================================
  // 私有辅助
  // ===========================================================================

  /// 各动作的理想参数
  IdealParams _getIdealParams(String exercise) {
    switch (exercise.toLowerCase()) {
      case 'squat':
        return const IdealParams(idealAngle: 90, idealDepth: 0.8, idealBodyLine: 0.90);
      case 'pushup':
        return const IdealParams(idealAngle: 90, idealDepth: 0.7, idealBodyLine: 0.95);
      case 'lunge':
        return const IdealParams(idealAngle: 90, idealDepth: 0.75, idealBodyLine: 0.85);
      case 'situp':
        return const IdealParams(idealAngle: 45, idealDepth: 0.8, idealBodyLine: 0.50);
      case 'plank':
        // 平板支撑：身体线条最重要，角度/深度次要
        return const IdealParams(idealAngle: 0, idealDepth: 0.0, idealBodyLine: 0.98);
      case 'jumping_jack':
        return const IdealParams(idealAngle: 45, idealDepth: 0.6, idealBodyLine: 0.90);
      case 'burpee':
        return const IdealParams(idealAngle: 45, idealDepth: 0.9, idealBodyLine: 0.80);
      default:
        // 未知动作使用通用默认值
        return const IdealParams(idealAngle: 90, idealDepth: 0.7, idealBodyLine: 0.85);
    }
  }

  /// 将 0~100 分数映射为 S / A / B / C / D 等级
  String _mapGrade(int score) {
    if (score >= 90) return 'S';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    return 'D';
  }
}

/// 动作理想参数（内部使用）
class IdealParams {
  /// 理想关节角度（度）
  final double idealAngle;

  /// 理想动作深度（0.0 ~ 1.0）
  final double idealDepth;

  /// 理想身体线条垂直度（0.0 ~ 1.0）
  final double idealBodyLine;

  const IdealParams({
    required this.idealAngle,
    required this.idealDepth,
    required this.idealBodyLine,
  });
}
