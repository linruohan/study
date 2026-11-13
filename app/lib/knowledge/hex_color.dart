import 'package:flutter/material.dart';

/// 把接口里的 #RRGGBB 转成 Flutter 颜色；格式不对时退回中性色。
Color colorFromHex(String? hex, {Color fallback = const Color(0xFF8C4A2F)}) {
  if (hex == null) {
    return fallback;
  }
  final value = hex.replaceFirst('#', '');
  if (value.length != 6) {
    return fallback;
  }
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) {
    return fallback;
  }
  return Color(0xFF000000 | parsed);
}
