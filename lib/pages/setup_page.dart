import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/game_algorithm.dart';
import '../widgets/home/forge_background.dart';
import '../main.dart';

/// 角色创建页面（5步流程）
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  int _currentStep = 1;

  // 表单数据
  double _height = 170;
  double _weight = 70;
  double _targetWeight = 65;
  SleepType _sleepType = SleepType.normal;
  WorkType _workType = WorkType.sedentary;
  ExerciseTime _exerciseTime = ExerciseTime.evening;
  CharacterStyle _characterStyle = CharacterStyle.pet;
  int _pushupCount = 10;
  int _runDuration = 15;
  int _weeklyFreq = 3;
  Difficulty _difficulty = Difficulty.normal;

  TextStyle get _displayStyle => GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );

  TextStyle get _bodyStyle => GoogleFonts.figtree(color: AppColors.text);

  TextStyle get _mutedStyle =>
      GoogleFonts.figtree(color: AppColors.text2, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            '角色创建',
            style: GoogleFonts.fraunces(fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepContent(),
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.copper, size: 20),
        const SizedBox(width: 8),
        Text(title, style: _displayStyle.copyWith(fontSize: 17)),
      ],
    );
  }

  /// 步骤指示器
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final step = index + 1;
        final isActive = step == _currentStep;
        final isDone = step < _currentStep;

        Color fill;
        Color ring;
        if (isDone) {
          fill = AppColors.green;
          ring = AppColors.green.withValues(alpha: 0.45);
        } else if (isActive) {
          fill = AppColors.ember;
          ring = AppColors.copper.withValues(alpha: 0.55);
        } else {
          fill = AppColors.bg2;
          ring = AppColors.border;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: isActive ? 28 : 24,
          height: isActive ? 28 : 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: ring, width: isActive ? 2 : 1),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.ember.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Text(
            '$step',
            style: GoogleFonts.figtree(
              fontSize: isActive ? 12 : 11,
              fontWeight: FontWeight.w700,
              color: isActive || isDone ? AppColors.text : AppColors.text2,
            ),
          ),
        );
      }),
    );
  }

  /// 步骤内容
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      case 5:
        return _buildStep5();
      default:
        return Container();
    }
  }

  /// 步骤1：基础数据
  Widget _buildStep1() {
    final bmi = GameAlgorithm.calcBMI(_weight, _height);
    final bodyType = GameAlgorithm.getBodyType(bmi);

    return SingleChildScrollView(
      key: const ValueKey(1),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(Icons.straighten, '基础数据'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: '身高',
                      value: _height,
                      suffix: 'cm',
                      onChanged: (v) => setState(() => _height = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField(
                      label: '体重',
                      value: _weight,
                      suffix: 'kg',
                      onChanged: (v) => setState(() => _weight = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInputField(
                label: '目标体重',
                value: _targetWeight,
                suffix: 'kg',
                onChanged: (v) => setState(() => _targetWeight = v),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.copper.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('BMI: ', style: _mutedStyle),
                    Text(
                      bmi.toStringAsFixed(1),
                      style: _bodyStyle.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      ' - $bodyType',
                      style: _bodyStyle.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 步骤2：生活习惯
  Widget _buildStep2() {
    return SingleChildScrollView(
      key: const ValueKey(2),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(Icons.bedtime_outlined, '作息类型'),
                  const SizedBox(height: 12),
                  _buildOptionGrid(
                    options: SleepType.values,
                    selected: _sleepType,
                    onSelect: (v) => setState(() => _sleepType = v),
                    icons: [
                      Icons.wb_sunny_outlined,
                      Icons.schedule_outlined,
                      Icons.nightlight_outlined,
                    ],
                    labels: ['早睡早起', '标准作息', '夜猫子'],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(Icons.work_outline, '办公方式'),
                  const SizedBox(height: 12),
                  _buildOptionGrid(
                    options: WorkType.values,
                    selected: _workType,
                    onSelect: (v) => setState(() => _workType = v),
                    icons: [
                      Icons.event_seat_outlined,
                      Icons.directions_walk_outlined,
                      Icons.directions_run_outlined,
                    ],
                    labels: ['久坐不动', '偶尔走动', '经常外出'],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(Icons.schedule_outlined, '锻炼时间段'),
                  const SizedBox(height: 12),
                  _buildOptionGrid(
                    options: ExerciseTime.values,
                    selected: _exerciseTime,
                    onSelect: (v) => setState(() => _exerciseTime = v),
                    icons: [
                      Icons.wb_twilight,
                      Icons.wb_sunny_outlined,
                      Icons.nights_stay_outlined,
                    ],
                    labels: ['早晨', '下午', '晚上'],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(Icons.palette_outlined, '角色风格'),
                  const SizedBox(height: 12),
                  _buildOptionGrid(
                    options: CharacterStyle.values,
                    selected: _characterStyle,
                    onSelect: (v) => setState(() => _characterStyle = v),
                    icons: [
                      Icons.pets_outlined,
                      Icons.shield_outlined,
                      Icons.auto_fix_high_outlined,
                      Icons.flash_on_outlined,
                    ],
                    labels: ['可爱萌宠', '战斗勇士', '魔法师', '刺客'],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 步骤3：体能评估
  Widget _buildStep3() {
    return SingleChildScrollView(
      key: const ValueKey(3),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(Icons.fitness_center_outlined, '体能评估'),
              const SizedBox(height: 16),
              _buildInputField(
                label: '你能做多少个俯卧撑？',
                value: _pushupCount.toDouble(),
                suffix: '个',
                onChanged: (v) => setState(() => _pushupCount = v.toInt()),
              ),
              const SizedBox(height: 12),
              _buildInputField(
                label: '你能连续跑步多久（分钟）？',
                value: _runDuration.toDouble(),
                suffix: '分钟',
                onChanged: (v) => setState(() => _runDuration = v.toInt()),
              ),
              const SizedBox(height: 16),
              Text('每周锻炼频率', style: _mutedStyle),
              const SizedBox(height: 8),
              _buildOptionGrid(
                options: [1, 3, 5],
                selected: _weeklyFreq,
                onSelect: (v) => setState(() => _weeklyFreq = v),
                icons: [
                  Icons.sentiment_neutral_outlined,
                  Icons.trending_up_outlined,
                  Icons.local_fire_department_outlined,
                ],
                labels: ['1-2次', '3-4次', '5+次'],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 步骤4：选择难度
  Widget _buildStep4() {
    return SingleChildScrollView(
      key: const ValueKey(4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(Icons.tune, '选择难度'),
              const SizedBox(height: 16),
              _buildDifficultyCard(
                icon: Icons.shield_outlined,
                iconColor: AppColors.green,
                name: '简单模式',
                desc: '怪物较弱，每日卡路里目标+200',
                value: Difficulty.easy,
              ),
              const SizedBox(height: 12),
              _buildDifficultyCard(
                icon: Icons.balance,
                iconColor: AppColors.copper,
                name: '普通模式',
                desc: '标准挑战，平衡体验',
                value: Difficulty.normal,
              ),
              const SizedBox(height: 12),
              _buildDifficultyCard(
                icon: Icons.local_fire_department_outlined,
                iconColor: AppColors.ember,
                name: '困难模式',
                desc: '怪物凶猛，每日卡路里目标-400',
                value: Difficulty.hard,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 步骤5：角色确认
  Widget _buildStep5() {
    final bmi = GameAlgorithm.calcBMI(_weight, _height);
    final bodyType = GameAlgorithm.getBodyType(bmi);

    return SingleChildScrollView(
      key: const ValueKey(5),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(Icons.fact_check_outlined, '角色确认'),
              const SizedBox(height: 16),
              _buildSummaryItem('身高', '${_height.toInt()} cm'),
              _buildSummaryItem('体重', '${_weight.toInt()} kg'),
              _buildSummaryItem('目标体重', '${_targetWeight.toInt()} kg'),
              _buildSummaryItem('BMI', '${bmi.toStringAsFixed(1)} ($bodyType)'),
              _buildSummaryItem('作息', _sleepType.name),
              _buildSummaryItem('办公', _workType.name),
              _buildSummaryItem('锻炼时间', _exerciseTime.name),
              _buildSummaryItem('角色风格', _characterStyle.name),
              _buildSummaryItem('俯卧撑', '${_pushupCount}个'),
              _buildSummaryItem('跑步时长', '${_runDuration}分钟'),
              _buildSummaryItem('每周频率', '${_weeklyFreq}次/周'),
              _buildSummaryItem('难度', _difficulty.name),
            ],
          ),
        ),
      ),
    );
  }

  /// 输入字段
  Widget _buildInputField({
    required String label,
    required double value,
    required String suffix,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _mutedStyle),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value.toStringAsFixed(0),
          keyboardType: TextInputType.number,
          style: _bodyStyle,
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: _mutedStyle,
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null) onChanged(parsed);
          },
        ),
      ],
    );
  }

  /// 选项网格
  Widget _buildOptionGrid<T>({
    required List<T> options,
    required T selected,
    required Function(T) onSelect,
    required List<IconData> icons,
    List<String>? labels,
  }) {
    assert(icons.length >= options.length, 'icons 数量不能少于 options 数量');
    assert(labels == null || labels.length >= options.length, 'labels 数量不能少于 options 数量');

    return Row(
      children: List.generate(options.length, (index) {
        final option = options[index];
        final isSelected = option == selected;
        final icon = index < icons.length ? icons[index] : Icons.help_outline;
        final label = labels != null
            ? (index < labels.length ? labels[index] : '未知')
            : (option as dynamic).name;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(option),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.ember.withValues(alpha: 0.12)
                    : AppColors.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.ember : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 26,
                    color: isSelected ? AppColors.copper : AppColors.text2,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.text : AppColors.text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 难度卡片
  Widget _buildDifficultyCard({
    required IconData icon,
    required Color iconColor,
    required String name,
    required String desc,
    required Difficulty value,
  }) {
    final isSelected = _difficulty == value;

    return GestureDetector(
      onTap: () => setState(() => _difficulty = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.ember.withValues(alpha: 0.12)
              : AppColors.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.ember : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.4),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: _displayStyle.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 2),
                  Text(desc, style: _mutedStyle.copyWith(fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.copper, size: 22),
          ],
        ),
      ),
    );
  }

  /// 汇总项
  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _mutedStyle),
          Text(
            value,
            style: _bodyStyle.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// 导航按钮
  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          if (_currentStep > 1)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                child: Text(
                  '上一步',
                  style: GoogleFonts.figtree(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (_currentStep > 1) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _currentStep == 5 ? '生成关卡' : '下一步',
                style: GoogleFonts.figtree(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 下一步
  void _nextStep() {
    // 验证
    if (_currentStep == 1) {
      if (_height < 100 || _height > 250) {
        _showToast('请输入有效身高(100-250cm)');
        return;
      }
      if (_weight < 30 || _weight > 300) {
        _showToast('请输入有效体重(30-300kg)');
        return;
      }
      if (_targetWeight < 30 || _targetWeight > 200) {
        _showToast('请输入有效目标体重');
        return;
      }
      if (_targetWeight >= _weight) {
        _showToast('目标体重应小于当前体重');
        return;
      }
    }

    if (_currentStep == 5) {
      // 创建游戏
      final user = User(
        height: _height,
        weight: _weight,
        targetWeight: _targetWeight,
        sleepType: _sleepType,
        workType: _workType,
        exerciseTime: _exerciseTime,
        characterStyle: _characterStyle,
        pushupCount: _pushupCount,
        runDuration: _runDuration,
        weeklyFreq: _weeklyFreq,
        difficulty: _difficulty,
      );

      ref.read(gameStateProvider.notifier).createGame(user);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainPage()),
      );

      _showToast('冒险开始！击败今天的怪物吧！');
      return;
    }

    setState(() => _currentStep++);
  }

  /// 显示提示
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: _bodyStyle),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
