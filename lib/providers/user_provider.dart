import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// 性别枚举
///
/// 对齐 Web 端 `UserInfo.gender` 字段，Flutter 端原 [User] 模型未包含该字段，
/// 因此在新的子 Provider 中独立定义。
enum Gender {
  male,
  female,
  other,
}

extension GenderExt on Gender {
  String get label {
    switch (this) {
      case Gender.male:
        return '男';
      case Gender.female:
        return '女';
      case Gender.other:
        return '其他';
    }
  }
}

/// 用户信息状态
///
/// 对齐 Web 端 `userSlice`，仅包含用户的"档案信息"和"偏好设置"，
/// 不包含游戏进度（kills/streak/coins 等）—— 那些归属 [ProgressState]。
class UserState {
  // 基本信息
  final String nickname;
  final String avatar;
  final double height;
  final double weight;
  final double targetWeight;
  final double bmi;
  final int age;
  final Gender gender;

  // 体能与难度
  final Difficulty difficulty;
  final FitnessLevel fitnessLevel;
  final int pushupCount;
  final int runDuration;
  final int weeklyFreq;

  // 生活习惯
  final SleepType sleepType;
  final WorkType workType;
  final ExerciseTime exerciseTime;
  final CharacterStyle characterStyle;

  // 目标
  final int targetCal;

  // 偏好设置
  final bool dndMode;
  final String dndStart;
  final String dndEnd;
  final bool notificationEnabled;
  final bool voiceEnabled;
  final String reminderFrequency;

  const UserState({
    this.nickname = '勇士',
    this.avatar = '🧑‍💻',
    this.height = 170,
    this.weight = 70,
    this.targetWeight = 65,
    this.bmi = 0,
    this.age = 25,
    this.gender = Gender.male,
    this.difficulty = Difficulty.normal,
    this.fitnessLevel = FitnessLevel.medium,
    this.pushupCount = 10,
    this.runDuration = 15,
    this.weeklyFreq = 3,
    this.sleepType = SleepType.normal,
    this.workType = WorkType.sedentary,
    this.exerciseTime = ExerciseTime.evening,
    this.characterStyle = CharacterStyle.pet,
    this.targetCal = 1800,
    this.dndMode = false,
    this.dndStart = '22:00',
    this.dndEnd = '08:00',
    this.notificationEnabled = true,
    this.voiceEnabled = true,
    this.reminderFrequency = 'normal',
  });

  UserState copyWith({
    String? nickname,
    String? avatar,
    double? height,
    double? weight,
    double? targetWeight,
    double? bmi,
    int? age,
    Gender? gender,
    Difficulty? difficulty,
    FitnessLevel? fitnessLevel,
    int? pushupCount,
    int? runDuration,
    int? weeklyFreq,
    SleepType? sleepType,
    WorkType? workType,
    ExerciseTime? exerciseTime,
    CharacterStyle? characterStyle,
    int? targetCal,
    bool? dndMode,
    String? dndStart,
    String? dndEnd,
    bool? notificationEnabled,
    bool? voiceEnabled,
    String? reminderFrequency,
  }) {
    return UserState(
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      targetWeight: targetWeight ?? this.targetWeight,
      bmi: bmi ?? this.bmi,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      difficulty: difficulty ?? this.difficulty,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      pushupCount: pushupCount ?? this.pushupCount,
      runDuration: runDuration ?? this.runDuration,
      weeklyFreq: weeklyFreq ?? this.weeklyFreq,
      sleepType: sleepType ?? this.sleepType,
      workType: workType ?? this.workType,
      exerciseTime: exerciseTime ?? this.exerciseTime,
      characterStyle: characterStyle ?? this.characterStyle,
      targetCal: targetCal ?? this.targetCal,
      dndMode: dndMode ?? this.dndMode,
      dndStart: dndStart ?? this.dndStart,
      dndEnd: dndEnd ?? this.dndEnd,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
    );
  }

  /// 计算 BMI
  double calcBmi() {
    if (height <= 0) return 0;
    return weight / (height / 100 * height / 100);
  }
}

/// 用户信息 Notifier
class UserNotifier extends StateNotifier<UserState> {
  UserNotifier() : super(const UserState());

  /// 批量更新用户信息
  void updateUser({
    String? nickname,
    String? avatar,
    double? height,
    double? weight,
    double? targetWeight,
    int? age,
    Gender? gender,
    Difficulty? difficulty,
    FitnessLevel? fitnessLevel,
    int? pushupCount,
    int? runDuration,
    int? weeklyFreq,
    SleepType? sleepType,
    WorkType? workType,
    ExerciseTime? exerciseTime,
    CharacterStyle? characterStyle,
  }) {
    state = state.copyWith(
      nickname: nickname,
      avatar: avatar,
      height: height,
      weight: weight,
      targetWeight: targetWeight,
      age: age,
      gender: gender,
      difficulty: difficulty,
      fitnessLevel: fitnessLevel,
      pushupCount: pushupCount,
      runDuration: runDuration,
      weeklyFreq: weeklyFreq,
      sleepType: sleepType,
      workType: workType,
      exerciseTime: exerciseTime,
      characterStyle: characterStyle,
    );
    // 身高/体重变化时重新计算 BMI
    if (height != null || weight != null) {
      state = state.copyWith(bmi: state.calcBmi());
    }
  }

  /// 更新体重（自动重算 BMI）
  void updateWeight(double weight) {
    state = state.copyWith(weight: weight, bmi: state.calcBmi());
  }

  /// 更新难度
  void updateDifficulty(Difficulty difficulty) {
    state = state.copyWith(difficulty: difficulty);
  }

  /// 更新目标卡路里
  void updateTargetCal(int targetCal) {
    state = state.copyWith(targetCal: targetCal);
  }

  /// 更新活动水平（映射到 [WorkType]）
  void updateActivityLevel(WorkType workType) {
    state = state.copyWith(workType: workType);
  }

  /// 更新勿扰模式
  void updateDndMode(bool enabled, String start, String end) {
    state = state.copyWith(dndMode: enabled, dndStart: start, dndEnd: end);
  }

  /// 更新通知开关
  void updateNotificationEnabled(bool enabled) {
    state = state.copyWith(notificationEnabled: enabled);
  }

  /// 更新语音播报开关
  void updateVoiceEnabled(bool enabled) {
    state = state.copyWith(voiceEnabled: enabled);
  }

  /// 更新提醒频率
  void updateReminderFrequency(String frequency) {
    state = state.copyWith(reminderFrequency: frequency);
  }

  /// 重置为默认状态
  void reset() {
    state = const UserState();
  }
}

/// 用户信息 Provider
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier();
});
