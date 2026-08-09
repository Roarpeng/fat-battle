import 'package:flutter/material.dart';
import '../../theme/forge_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/tokens.dart';
import '../../constants/app_constants.dart';

/// 商店单项卡片 — 锻造工坊 2.0
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: ForgeSurface(
        borderColor: canAfford
            ? AppColors.copper.withValues(alpha: 0.35)
            : AppColors.border,
        child: Row(
          children: [
            Icon(AppIcons.shop(item.id), size: 36, color: AppColors.gold),
            const SizedBox(width: AppSpace.lg),
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
                    const SizedBox(height: AppSpace.xs),
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
                    const Icon(
                      Icons.monetization_on_outlined,
                      color: AppColors.copper,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      '${item.price}',
                      style: display.copyWith(
                        color: AppColors.copper,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                ElevatedButton(
                  onPressed: canAfford ? onBuy : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canAfford ? AppColors.ember : AppColors.bg3,
                    foregroundColor:
                        canAfford ? AppColors.onEmber : AppColors.text2,
                    disabledBackgroundColor: AppColors.bg3,
                    disabledForegroundColor: AppColors.text2,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.smAll,
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
