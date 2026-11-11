import 'package:flutter/material.dart';

/// 暖白纸面底色。
const paperBackground = Color(0xFFF6F1E7);

/// 卡片与输入区的纸面。
const paperSurface = Color(0xFFFBF7EF);

/// 墨色正文。
const paperInk = Color(0xFF2A2622);

/// 次要文字，像铅笔写的。
const paperInkSoft = Color(0xFF6B6259);

/// 细墨线。
const paperLine = Color(0xFFE3DACB);

/// 低饱和赭石，用于强调与已完成。
const paperOchre = Color(0xFF8C4A2F);

/// 低饱和石青，用于提示与链接。
const paperStone = Color(0xFF3E6F8C);

/// 全应用共用的安静纸本主题：暖白纸面、墨色字、低饱和赭石与石青。
ThemeData buildPaperTheme() {
  final base = ThemeData(useMaterial3: true);
  final scheme = ColorScheme.fromSeed(
    seedColor: paperOchre,
    brightness: Brightness.light,
  ).copyWith(
    primary: paperOchre,
    onPrimary: Colors.white,
    secondary: paperStone,
    onSecondary: Colors.white,
    surface: paperSurface,
    onSurface: paperInk,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paperBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: paperBackground,
      foregroundColor: paperInk,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paperSurface,
      elevation: 0,
      indicatorColor: paperOchre.withValues(alpha: 0.14),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, letterSpacing: 1, color: paperInk),
      ),
      iconTheme: const WidgetStatePropertyAll(
        IconThemeData(color: paperInkSoft, size: 22),
      ),
    ),
    textTheme: base.textTheme
        .apply(bodyColor: paperInk, displayColor: paperInk)
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            height: 1.35,
            letterSpacing: 1.6,
            color: paperInk,
          ),
          headlineSmall: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.4,
            letterSpacing: 1.2,
            color: paperInk,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: paperInk,
          ),
          bodyMedium: const TextStyle(fontSize: 15, height: 1.7, color: paperInk),
          bodySmall: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: paperInkSoft,
          ),
        ),
    dividerTheme: const DividerThemeData(
      color: paperLine,
      thickness: 1,
      space: 1,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: paperInk,
        side: const BorderSide(color: paperLine),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, letterSpacing: 0.6),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: paperOchre),
    ),
    // 主按钮统一成赭石圆角长条，页面里不再各写一份样式。
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: paperOchre,
        foregroundColor: Colors.white,
        disabledBackgroundColor: paperLine,
        disabledForegroundColor: paperInkSoft,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, letterSpacing: 0.8),
      ),
    ),
    // 弹窗与提示条也用纸面，避免跳出白色系统面板。
    dialogTheme: DialogThemeData(
      backgroundColor: paperSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: paperInk,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// 纸本卡片：细墨线描边加极轻阴影，代替高饱和浮起的 Material 卡片。
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? paperSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: paperLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A2A2622),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) {
      return surface;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: surface,
      ),
    );
  }
}

/// 技能档小标签：只在本人和监护人视图出现，不公开比较。
class MasteryPill extends StatelessWidget {
  const MasteryPill({
    super.key,
    required this.label,
    this.color = paperInkSoft,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, letterSpacing: 0.6),
      ),
    );
  }
}
