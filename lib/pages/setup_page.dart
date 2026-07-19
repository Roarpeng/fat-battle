import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/game_algorithm.dart';
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('角色创建'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 步骤指示器
            _buildStepIndicator(),
            const SizedBox(height: 24),
            
            // 当前步骤内容
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStepContent(),
              ),
            ),
            
            // 导航按钮
            _buildNavigationButtons(),
          ],
        ),
      ),
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
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? AppColors.green : isActive ? AppColors.red : AppColors.border,
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
              const Text(
                '📊 基础数据',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
              
              // BMI预览
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'BMI: ',
                      style: TextStyle(color: AppColors.text2),
                    ),
                    Text(
                      bmi.toStringAsFixed(1),
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' - $bodyType',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
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
          // 作息类型
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🌙 作息类型',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionGrid(
                    options: SleepType.values,
                    selected: _sleepType,
                    onSelect: (v) => setState(() => _sleepType = v),
                    emojis: ['🌅', '☀️', '🦉'],
                    labels: ['早睡早起', '标准作息', '夜猫子'],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // 办公方式
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💼 办公方式',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionGrid(
                    options: WorkType.values,
                    selected: _workType,
                    onSelect: (v) => setState(() => _workType = v),
                    emojis: ['🪑', '🚶', '🏃'],
                    labels: ['久坐不动', '偶尔走动', '经常外出'],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // 锻炼时间段
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⏰ 锻炼时间段',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionGrid(
                    options: ExerciseTime.values,
                    selected: _exerciseTime,
                    onSelect: (v) => setState(() => _exerciseTime = v),
                    emojis: ['🌅', '☀️', '🌙'],
                    labels: ['早晨', '下午', '晚上'],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // 角色风格
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎨 角色风格',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionGrid(
                    options: CharacterStyle.values,
                    selected: _characterStyle,
                    onSelect: (v) => setState(() => _characterStyle = v),
                    emojis: ['🐾', '⚔️', '🧙', '🗡️'],
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
              const Text(
                '💪 体能评估',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
              
              const Text(
                '每周锻炼频率',
                style: TextStyle(color: AppColors.text2),
              ),
              const SizedBox(height: 8),
              _buildOptionGrid(
                options: [1, 3, 5],
                selected: _weeklyFreq,
                onSelect: (v) => setState(() => _weeklyFreq = v),
                emojis: ['😅', '💪', '🔥'],
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
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎮 选择难度',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDifficultyCard(
                    emoji: '😊',
                    name: '简单模式',
                    desc: '怪物较弱，每日卡路里目标+200',
                    value: Difficulty.easy,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildDifficultyCard(
                    emoji: '😐',
                    name: '普通模式',
                    desc: '标准挑战，平衡体验',
                    value: Difficulty.normal,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildDifficultyCard(
                    emoji: '😈',
                    name: '困难模式',
                    desc: '怪物凶猛，每日卡路里目标-400',
                    value: Difficulty.hard,
                  ),
                ],
              ),
            ),
          ),
        ],
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
              const Text(
                '📋 角色确认',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
        Text(label, style: TextStyle(color: AppColors.text2, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value.toStringAsFixed(0),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: suffix,
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
    required List<String> emojis,
    List<String>? labels,
  }) {
    assert(emojis.length >= options.length, 'emojis 数量不能少于 options 数量');
    assert(labels == null || labels.length >= options.length, 'labels 数量不能少于 options 数量');
    
    return Row(
      children: List.generate(options.length, (index) {
        final option = options[index];
        final isSelected = option == selected;
        final emoji = index < emojis.length ? emojis[index] : '❓';
        final label = labels != null
            ? (index < labels.length ? labels[index] : '未知')
            : (option as dynamic).name;
        
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(option),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.red.withOpacity(0.1) : AppColors.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.red : AppColors.border,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(emojis[index], style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.text2,
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
    required String emoji,
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
          color: isSelected ? AppColors.red.withOpacity(0.1) : AppColors.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.red : AppColors.border,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.text2,
                    ),
                  ),
                ],
              ),
            ),
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
          Text(label, style: TextStyle(color: AppColors.text2)),
          Text(value, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: BorderSide(color: AppColors.border),
                ),
                child: const Text('⬅️ 上一步'),
              ),
            ),
          if (_currentStep > 1) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep == 5 ? AppColors.gold : AppColors.red,
              ),
              child: Text(
                _currentStep == 5 ? '⚔️ 生成关卡' : '下一步 ➡️',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
        content: Text(message),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}