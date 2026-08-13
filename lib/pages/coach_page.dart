import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../core/coach_safety.dart';
import '../providers/game_provider.dart';
import '../services/coach_service.dart';
import '../theme/forge_theme.dart';
import '../theme/tokens.dart';
import '../widgets/forge_pressable.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/home/mini_monster_header.dart';

/// 塑身工坊营养教练（接地气，不改目标、不偷偷记账）。
class CoachPage extends ConsumerStatefulWidget {
  const CoachPage({super.key});

  @override
  ConsumerState<CoachPage> createState() => _CoachPageState();
}

class _CoachBubble {
  final String text;
  final bool fromUser;
  final List<CoachProposedLog> logs;
  _CoachBubble({
    required this.text,
    required this.fromUser,
    this.logs = const [],
  });
}

class _CoachPageState extends ConsumerState<CoachPage> {
  static const _chips = [
    '今天预算还剩多少',
    '蛋白质够不够',
    '这顿怎么记',
    '剩余预算吃什么',
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _history = <Map<String, String>>[];
  final _bubbles = <_CoachBubble>[];
  bool _sending = false;

  TextStyle get _display => AppFonts.display(color: AppColors.text);
  TextStyle get _muted => AppFonts.body(color: AppColors.text2, fontSize: 13);

  @override
  void initState() {
    super.initState();
    _bubbles.add(_CoachBubble(
      text: '我是工坊教练。只看你今天的饮食账、剩余预算和锤炼，不会改卡路里目标，也不会偷偷记账——要记入得你点头。',
      fromUser: false,
    ));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  CoachTurnContext _ctx() =>
      CoachTurnContext.fromGameState(ref.read(gameStateProvider));

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _bubbles.add(_CoachBubble(text: text, fromUser: true));
      _input.clear();
    });
    _jumpBottom();

    final ctx = _ctx();
    final result = await CoachService().turn(
      message: text,
      context: ctx,
      history: List<Map<String, String>>.from(_history),
    );
    if (!mounted) return;

    _history.add({'role': 'user', 'content': text});
    _history.add({'role': 'assistant', 'content': result.reply});
    if (_history.length > 16) {
      _history.removeRange(0, _history.length - 16);
    }

    setState(() {
      _sending = false;
      _bubbles.add(_CoachBubble(
        text: result.reply,
        fromUser: false,
        logs: result.proposedLogs,
      ));
    });
    _jumpBottom();
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _confirmLog(CoachProposedLog log) async {
    final edited = await showDialog<CoachProposedLog>(
      context: context,
      builder: (ctx) => _GramsConfirmDialog(initial: log),
    );
    if (edited == null || !mounted) return;
    await ref.read(gameStateProvider.notifier).addFood(edited.toFoodItem());
    if (!mounted) return;
    final left = ref.read(gameStateProvider).remainingCal;
    setState(() {
      _bubbles.add(_CoachBubble(
        text: left >= 0
            ? '已记入 ${edited.name} ${edited.grams}g（约 ${edited.estimatedCal} kcal）。今日还可摄入 $left kcal。'
            : '已记入 ${edited.name} ${edited.grams}g（约 ${edited.estimatedCal} kcal）。今日已超出 ${-left} kcal。',
        fromUser: false,
      ));
    });
    _jumpBottom();
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final ctx = CoachTurnContext.fromGameState(gs);

    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('工坊教练', style: _display.copyWith(fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const MiniMonsterHeader(),
            _ContextStrip(ctx: ctx),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: AppSpace.page.copyWith(bottom: AppSpace.lg),
                itemCount: _bubbles.length + (_sending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _bubbles.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: Text('炉火还在想…', style: _muted),
                      ),
                    );
                  }
                  final b = _bubbles[i];
                  return _BubbleTile(
                    bubble: b,
                    onConfirm: _confirmLog,
                  );
                },
              ),
            ),
            _ChipRow(
              chips: _chips,
              enabled: !_sending,
              onTap: _send,
            ),
            _InputBar(
              controller: _input,
              enabled: !_sending,
              onSend: () => _send(_input.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextStrip extends StatelessWidget {
  final CoachTurnContext ctx;
  const _ContextStrip({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final remaining = ctx.budget['remainingCal'] as int;
    final protein = ctx.proteinLogged.round();
    final need = ctx.proteinTarget.round();
    final shield = ctx.monster['shield'] as int;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, 0),
      child: ForgeSurface(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: Row(
          children: [
            _stat(
              remaining >= 0 ? '剩余 $remaining' : '超出 ${-remaining}',
              remaining >= 0 ? AppColors.green : AppColors.ember,
            ),
            _dot(),
            _stat('蛋白 $protein/$need g', AppColors.copper),
            if (shield > 0) ...[
              _dot(),
              _stat('护盾 $shield', AppColors.shield),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        child: Text('·', style: AppFonts.body(color: AppColors.text2)),
      );

  Widget _stat(String t, Color c) => Flexible(
        child: Text(
          t,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.body(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: c,
          ),
        ),
      );
}

class _BubbleTile extends StatelessWidget {
  final _CoachBubble bubble;
  final Future<void> Function(CoachProposedLog) onConfirm;
  const _BubbleTile({required this.bubble, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final align = bubble.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = bubble.fromUser ? AppColors.ember.withValues(alpha: 0.18) : AppColors.elevated;
    final border = bubble.fromUser ? AppColors.ember.withValues(alpha: 0.35) : AppColors.border;
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bubble.text,
              style: AppFonts.body(color: AppColors.text, height: 1.45),
            ),
            if (bubble.logs.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                '建议记账（需你确认，改克数后再写入）',
                style: AppFonts.body(color: AppColors.text2, fontSize: 12),
              ),
              const SizedBox(height: AppSpace.xs),
              ...bubble.logs.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: ForgePressable(
                    onTap: () => onConfirm(log),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                        vertical: AppSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: AppRadii.smAll,
                        border: Border.all(color: AppColors.copper.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${log.name} · ${log.grams}g · 约 ${log.estimatedCal} kcal',
                              style: AppFonts.body(fontSize: 13, color: AppColors.text),
                            ),
                          ),
                          Text(
                            '改克数记入',
                            style: AppFonts.body(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.copper,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> chips;
  final bool enabled;
  final ValueChanged<String> onTap;
  const _ChipRow({
    required this.chips,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, i) {
          final label = chips[i];
          return ForgePressable(
            onTap: enabled ? () => onTap(label) : null,
            child: Container(
              alignment: Alignment.center,
              padding: AppSpace.chip,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: AppColors.copper.withValues(alpha: 0.45)),
              ),
              child: Text(
                label,
                style: AppFonts.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.copper,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.md),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: '问今天怎么吃、怎么记…',
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.ember,
                foregroundColor: AppColors.onEmber,
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _GramsConfirmDialog extends StatefulWidget {
  final CoachProposedLog initial;
  const _GramsConfirmDialog({required this.initial});

  @override
  State<_GramsConfirmDialog> createState() => _GramsConfirmDialogState();
}

class _GramsConfirmDialogState extends State<_GramsConfirmDialog> {
  late final TextEditingController _grams;
  late final TextEditingController _name;
  late MealType _meal;

  @override
  void initState() {
    super.initState();
    _grams = TextEditingController(text: '${widget.initial.grams}');
    _name = TextEditingController(text: widget.initial.name);
    _meal = widget.initial.meal;
  }

  @override
  void dispose() {
    _grams.dispose();
    _name.dispose();
    super.dispose();
  }

  int get _g => int.tryParse(_grams.text.trim()) ?? widget.initial.grams;

  int get _est => (widget.initial.caloriePer100g * _g / 100).round();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(
        '确认记入',
        style: AppFonts.display(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '食物名称'),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _grams,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '克数', suffixText: 'g'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            '估算 $_est kcal（按每 100g ${widget.initial.caloriePer100g} kcal）',
            style: AppFonts.body(color: AppColors.copper, fontSize: 13),
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.xs,
            children: MealType.values.map((m) {
              final on = m == _meal;
              return ChoiceChip(
                label: Text(m.name),
                selected: on,
                onSelected: (_) => setState(() => _meal = m),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            '确认前不会写入饮食账。',
            style: AppFonts.body(color: AppColors.text2, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: AppFonts.body(color: AppColors.text2)),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty || _g <= 0) return;
            Navigator.pop(
              context,
              widget.initial.copyWith(name: name, grams: _g, meal: _meal),
            );
          },
          child: const Text('确认记入'),
        ),
      ],
    );
  }
}
