import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../core/safety.dart';
import '../theme/forge_theme.dart';
import '../theme/tokens.dart';

/// 首次使用医疗免责声明。同意后写入 [kMedicalDisclaimerPrefKey]。
class MedicalDisclaimer {
  MedicalDisclaimer._();

  static Future<bool> isAccepted(SharedPreferences? prefs) async {
    if (prefs != null) {
      return prefs.getBool(kMedicalDisclaimerPrefKey) ?? false;
    }
    final instance = await SharedPreferences.getInstance();
    return instance.getBool(kMedicalDisclaimerPrefKey) ?? false;
  }

  static Future<void> markAccepted(SharedPreferences? prefs) async {
    final instance = prefs ?? await SharedPreferences.getInstance();
    await instance.setBool(kMedicalDisclaimerPrefKey, true);
  }

  /// 若尚未同意，弹出不可关闭的声明；同意后返回 true。
  static Future<bool> ensureAccepted(
    BuildContext context, {
    SharedPreferences? prefs,
  }) async {
    if (await isAccepted(prefs)) return true;
    if (!context.mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const MedicalDisclaimerDialog(),
    );
    if (accepted == true) {
      await markAccepted(prefs);
      return true;
    }
    return false;
  }
}

class MedicalDisclaimerDialog extends StatelessWidget {
  const MedicalDisclaimerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: AppColors.border),
      ),
      title: Text(
        '使用前请了解',
        style: AppFonts.display(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Text(
          '塑身工坊是游戏化记录工具，不是医疗器械，不能替代医生的诊断、治疗或营养指导。\n\n'
          '开始减脂或运动前，请咨询医生或注册营养师，尤其是有基础疾病、进食困扰或正在服药时。\n\n'
          '请把目标放在打中热量预算带，而不是吃得越少越好。',
          style: AppFonts.body(fontSize: 14, height: 1.45, color: AppColors.text),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('我已了解，开始使用'),
        ),
      ],
    );
  }
}

/// 连续极端赤字危机提示（含北京危机热线）。
class SafetyCrisisBanner extends StatelessWidget {
  const SafetyCrisisBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.shield.withValues(alpha: 0.12),
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: AppColors.shield.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '先照顾好自己',
            style: AppFonts.body(
              fontWeight: FontWeight.w800,
              color: AppColors.shield,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            extremeDeficitHelpCopy(),
            style: AppFonts.body(fontSize: 12, height: 1.4, color: AppColors.text2),
          ),
        ],
      ),
    );
  }
}

/// 超出预算时的中性文案：护盾是机制，不用红色「失败」。
String calorieBudgetStatusCopy(int remaining) {
  if (remaining >= 0) return '预算带内还剩 $remaining kcal';
  return '超出预算 ${-remaining} kcal，怪物获得护盾';
}
