import 'package:flutter/material.dart';

/// Плавное открытие модального bottom sheet (как у инструкции Shizuku).
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    enableDrag: enableDrag,
    backgroundColor: Theme.of(context).cardColor,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    transitionAnimationController: null,
    builder: (ctx) {
      return AnimatedPadding(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      );
    },
  );
}

/// Ручка сверху у bottom sheet.
Widget appSheetHandle(BuildContext context) {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// Плавный диалог (fade + scale), уважает [animationsEnabled].
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool animate = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: Duration(milliseconds: animate ? 280 : 0),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return builder(ctx);
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      if (!animate) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Плавный переход на страницу справа налево.
Future<T?> pushAppPage<T>(
  BuildContext context,
  Widget page, {
  bool animate = true,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (!animate) return child;
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          ),
        );
      },
      transitionDuration: Duration(milliseconds: animate ? 320 : 0),
      reverseTransitionDuration: Duration(milliseconds: animate ? 260 : 0),
    ),
  );
}
