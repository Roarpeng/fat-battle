import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/game_provider.dart';
import '../../theme/forge_theme.dart';
import '../../theme/tokens.dart';
import '../forge_pressable.dart';

/// 设置页：三枚预览色板，切换工坊纸面。
class VisualThemePicker extends ConsumerWidget {
  const VisualThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      gameStateProvider.select((s) => s.visualTheme),
    );
    final palette = ForgeColors.of(context);

    return ForgeSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ForgeSectionHeader(
            title: '工坊纸面',
            subtitle: '换一套纸面，炉火还在',
          ),
          Row(
            children: [
              for (final theme in AppVisualTheme.values) ...[
                if (theme != AppVisualTheme.values.first)
                  const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: _ThemeChip(
                    theme: theme,
                    selected: current == theme,
                    onTap: () {
                      ref
                          .read(gameStateProvider.notifier)
                          .updateVisualTheme(theme);
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            current.subtitle,
            style: AppFonts.body(fontSize: 12, color: palette.text2),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final AppVisualTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  ForgePalette get _swatch => ForgePalette.forTheme(theme);

  @override
  Widget build(BuildContext context) {
    final live = ForgeColors.of(context);
    return ForgePressable(
      onTap: onTap,
      borderRadius: AppRadii.smAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm,
          AppSpace.sm,
          AppSpace.sm,
          AppSpace.md - 2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? live.copper.withValues(alpha: 0.12)
              : live.surface,
          borderRadius: AppRadii.smAll,
          border: Border.all(
            color: selected ? live.copper : live.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            _MiniSwatch(palette: _swatch),
            const SizedBox(height: AppSpace.sm),
            Text(
              theme.label,
              textAlign: TextAlign.center,
              style: AppFonts.body(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? live.copper : live.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 小色板：纸色底 + 主强调 / 石墨 / 描边三色点。
class _MiniSwatch extends StatelessWidget {
  final ForgePalette palette;

  const _MiniSwatch({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border, width: 1.1),
      ),
      child: Row(
        children: [
          Expanded(child: ColoredBox(color: palette.ember)),
          Expanded(child: ColoredBox(color: palette.copper)),
          Expanded(child: ColoredBox(color: palette.elevated)),
        ],
      ),
    );
  }
}
