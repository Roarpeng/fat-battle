import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'motion.dart';
import 'tokens.dart';

/// 统一页面 push：enter easeOut ≤300ms，exit 更快；scale 从 0.95
Route<T> forgePageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: AppMotion.pageEnter,
    reverseTransitionDuration: AppMotion.pageExit,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppMotion.reduceMotion(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: AppMotion.enterScale, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<T?> showForgeSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: AppColors.elevated,
    barrierColor: AppColors.overlay,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: builder,
  );
}
