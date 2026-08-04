import 'package:flutter/material.dart';
import '../../theme/forge_theme.dart';
import '../../theme/app_icons.dart';
import '../../constants/app_constants.dart';

/// 商店单项卡片 — 锻造工坊风格
class ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final int ownedQuantity;
  final int coins;
  final VoidCallback? onBuy;

  const ShopItemCard({
    super.key,
    required this.item,
    required this.ownedQuantity,
    required this.coins,
    this.onBuy,
  });

  bool get canAfford => coins >= item.price;

  @override
  Widget build(BuildContext context) {
    final display = AppFonts.display(
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    );
    final body = AppFonts.body(color: AppColors.text);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canAfford
              ? AppColors.copper.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(AppIcons.shop(item.id), size: 36, color: AppColors.gold),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: display.copyWith(fontSize: 16)),
                  Text(
                    item.desc,
                    style: body.copyWith(color: AppColors.text2, fontSize: 12),
                  ),
                  if (ownedQuantity > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '已拥有 ×$ownedQuantity',
                      style: body.copyWith(color: AppColors.green, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on_outlined,
                        color: AppColors.copper, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${item.price}',
                      style: display.copyWith(
                        color: AppColors.copper,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: canAfford ? onBuy : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canAfford ? AppColors.ember : AppColors.bg3,
                    foregroundColor: canAfford
                        ? const Color(0xFFFFF8F5)
                        : AppColors.text2,
                    disabledBackgroundColor: AppColors.bg3,
                    disabledForegroundColor: AppColors.text2,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: canAfford
                            ? AppColors.ember.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                  ),
                  child: Text(canAfford ? '购买' : '金币不足'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
