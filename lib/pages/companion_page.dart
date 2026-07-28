import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../providers/companion_provider.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/meta/stat_bar.dart';

/// 伙伴图鉴（展示用）
const _companionCatalog = [
  (defId: 'cat', name: '小猫崽', emoji: '🐱', desc: '敏捷的小猎手，擅长连击'),
  (defId: 'dog', name: '忠诚犬', emoji: '🐶', desc: '可靠的守护者，提升护盾效果'),
  (defId: 'dragon', name: '幼龙', emoji: '🐲', desc: '潜力无限的战斗龙，后期爆发'),
  (defId: 'owl', name: '智慧猫头鹰', emoji: '🦉', desc: '洞察弱点，战斗经验加成'),
];

/// 战斗伙伴页面
///
/// 数据来自 [companionProvider]，经 SharedPreferences（`fat_battle_companion`）持久化。
class CompanionPage extends ConsumerStatefulWidget {
  const CompanionPage({super.key});

  @override
  ConsumerState<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends ConsumerState<CompanionPage> {
  TextStyle get _displayStyle => GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );

  TextStyle get _bodyStyle => GoogleFonts.figtree(color: AppColors.text);

  TextStyle get _mutedStyle =>
      GoogleFonts.figtree(color: AppColors.text2, fontSize: 12);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companionProvider.notifier).updateMood();
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionProvider);
    final notifier = ref.read(companionProvider.notifier);
    final active = state.activePet;

    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('战斗伙伴', style: _displayStyle.copyWith(fontSize: 20)),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (active != null) _ActiveCompanionCard(pet: active, state: state),
            const SizedBox(height: 16),
            _ActionRow(
              onPet: () {
                notifier.pet();
                _toast('${active?.name ?? '伙伴'} 很开心！');
              },
              onFeed: () {
                notifier.feed();
                _toast('喂食成功，饥饿度下降');
              },
              onExercise: () {
                notifier.exerciseWithCompanion(10);
                _toast('一起锻炼 10 分钟，获得经验');
              },
              onCollect: state.pendingDrops > 0
                  ? () {
                      final drops = state.pendingDrops;
                      notifier.collectDrops();
                      _toast('领取 $drops 个掉落，皮肤/对话升级');
                    }
                  : null,
              pendingDrops: state.pendingDrops,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.pets_outlined, color: AppColors.copper, size: 20),
                const SizedBox(width: 8),
                Text('切换伙伴', style: _displayStyle.copyWith(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildPetList(state, notifier),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '提示：伙伴进度已写入本地存档（fat_battle_companion），'
                '与主存档独立保存，重装应用会清空。',
                style: _mutedStyle.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPetList(CompanionState state, CompanionNotifier notifier) {
    final widgets = <Widget>[];
    for (var i = 0; i < state.pets.length; i++) {
      final pet = state.pets[i];
      final isActive = i == state.activeIndex;
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.copper.withValues(alpha: 0.1)
                : AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? AppColors.copper.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: ListTile(
            leading: Text(pet.emoji, style: const TextStyle(fontSize: 28)),
            title: Text(pet.name, style: _bodyStyle.copyWith(fontWeight: FontWeight.w600)),
            subtitle: pet.owned
                ? Text('Lv.${pet.level} · ${pet.mood.label}', style: _mutedStyle)
                : Text('未解锁', style: _mutedStyle),
            trailing: pet.owned
                ? (isActive
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.ember.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.ember.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '出战',
                          style: _bodyStyle.copyWith(
                            fontSize: 11,
                            color: AppColors.ember,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: () => notifier.switchPet(i),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.copper,
                        ),
                        child: const Text('切换'),
                      ))
                : null,
            onTap: pet.owned && !isActive ? () => notifier.switchPet(i) : null,
          ),
        ),
      );
    }
    return widgets;
  }
}

class _ActiveCompanionCard extends StatelessWidget {
  final CompanionPet pet;
  final CompanionState state;

  const _ActiveCompanionCard({required this.pet, required this.state});

  @override
  Widget build(BuildContext context) {
    final display = GoogleFonts.fraunces(
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    );
    final body = GoogleFonts.figtree(color: AppColors.text);
    final catalog = _companionCatalog.firstWhere(
      (c) => c.defId == pet.defId,
      orElse: () => (defId: pet.defId, name: pet.name, emoji: pet.emoji, desc: ''),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.copper.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(pet.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(pet.name, style: display.copyWith(fontSize: 20)),
            Text(
              catalog.desc,
              style: body.copyWith(color: AppColors.text2, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${pet.mood.emoji} ${pet.mood.label}',
              style: body.copyWith(color: AppColors.copper, fontSize: 13),
            ),
            const SizedBox(height: 16),
            StatBar(
              label: '经验',
              valueText: '${pet.xp}/${pet.xpToNext}',
              progress: pet.xpToNext > 0 ? pet.xp / pet.xpToNext : 0,
              color: AppColors.copper,
            ),
            const SizedBox(height: 10),
            StatBar(
              label: '饥饿度',
              valueText: '${pet.hunger}/100',
              progress: pet.hunger / 100,
              color: pet.hunger > 80 ? AppColors.ember : AppColors.green,
            ),
            const SizedBox(height: 10),
            StatBar(
              label: '体力',
              valueText: '${pet.energy}/100',
              progress: pet.energy / 100,
              color: pet.energy < 20 ? AppColors.ember : AppColors.green,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MiniStat(icon: Icons.auto_awesome_outlined, label: '皮肤 Lv.${pet.skinLevel}'),
                _MiniStat(icon: Icons.chat_bubble_outline, label: '对话 Lv.${pet.dialogueLevel}'),
                _MiniStat(icon: Icons.card_giftcard_outlined, label: '掉落 ${state.monsterDrops}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.copper, size: 18),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.figtree(color: AppColors.text2, fontSize: 11),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onPet;
  final VoidCallback onFeed;
  final VoidCallback onExercise;
  final VoidCallback? onCollect;
  final int pendingDrops;

  const _ActionRow({
    required this.onPet,
    required this.onFeed,
    required this.onExercise,
    this.onCollect,
    required this.pendingDrops,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _ActionChip(label: '抚摸', icon: Icons.favorite_outline, onTap: onPet),
        _ActionChip(label: '喂食', icon: Icons.restaurant_outlined, onTap: onFeed),
        _ActionChip(label: '锻炼', icon: Icons.directions_run_outlined, onTap: onExercise),
        if (pendingDrops > 0)
          _ActionChip(
            label: '领取掉落 ($pendingDrops)',
            icon: Icons.redeem_outlined,
            onTap: onCollect!,
            highlight: true,
          ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight ? AppColors.ember : AppColors.copper.withValues(alpha: 0.4);
    final bgColor = highlight
        ? AppColors.ember.withValues(alpha: 0.12)
        : AppColors.card;
    final fgColor = highlight ? AppColors.ember : AppColors.copper;

    return Material(
      color: bgColor,
      shape: StadiumBorder(side: BorderSide(color: borderColor)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.figtree(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
