import 'package:flutter/material.dart';

/// 纸本小圆章：领域符号、序号或图标，统一各处的大小与底色。
///
/// 默认淡色底、彩色字；[filled] 为 true 时反过来用主色铺底、白字，
/// 适合「今日一步」这类需要一眼看到的地方。
class GlyphBadge extends StatelessWidget {
  const GlyphBadge({
    super.key,
    this.glyph,
    this.icon,
    required this.color,
    this.size = 44,
    this.rounded = false,
    this.filled = false,
    this.fontSize,
  }) : assert(glyph != null || icon != null, '文字和图标至少给一个');

  /// 显示的文字符号，例如「字」「日」。
  final String? glyph;

  /// 需要图标时用它，和文字二选一。
  final IconData? icon;

  /// 符号与底色使用的主色。
  final Color color;

  /// 圆章边长。
  final double size;

  /// true 用圆角方形，false 用圆形。
  final bool rounded;

  /// true 用主色铺底、白字；false 用淡色底、彩色字。
  final bool filled;

  /// 符号字号；为空时按边长推算，保证各处大小比例一致。
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : color;
    final background = filled ? color : color.withValues(alpha: 0.12);
    final glyphSize = fontSize ?? size * 0.45;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: rounded ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: rounded ? BorderRadius.circular(size * 0.26) : null,
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, size: glyphSize, color: foreground)
            : Text(
                glyph ?? '',
                style: TextStyle(
                  fontSize: glyphSize,
                  color: foreground,
                  height: 1.1,
                ),
              ),
      ),
    );
  }
}
