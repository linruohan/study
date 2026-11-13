import 'package:flutter/material.dart';

/// 应用图标：篆书「教」的方章图案。
///
/// 图案是预先生成好的 PNG 资源，运行时不依赖任何字体。
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 34});

  /// 图标边长。
  final double size;

  /// 图标资源路径。
  static const asset = 'assets/brand/app_mark.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        semanticLabel: '文明重启图标',
      ),
    );
  }
}
