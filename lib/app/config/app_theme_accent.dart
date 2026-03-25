import 'package:flutter/material.dart';

enum AppThemeAccent {
  forest('forest', '森绿', Color(0xFF166534), Color(0xFF34D399)),
  ocean('ocean', '海蓝', Color(0xFF0F766E), Color(0xFF2DD4BF)),
  cobalt('cobalt', '钴蓝', Color(0xFF1D4ED8), Color(0xFF60A5FA)),
  sunset('sunset', '日落', Color(0xFFEA580C), Color(0xFFFB923C)),
  rose('rose', '玫红', Color(0xFFE11D48), Color(0xFFFB7185)),
  violet('violet', '靛紫', Color(0xFF7C3AED), Color(0xFFA78BFA)),
  amber('amber', '琥珀', Color(0xFFD97706), Color(0xFFFBBF24));

  const AppThemeAccent(this.value, this.label, this.lightSeed, this.darkSeed);

  final String value;
  final String label;
  final Color lightSeed;
  final Color darkSeed;

  static AppThemeAccent fromValue(String? value) {
    for (final item in values) {
      if (item.value == value) {
        return item;
      }
    }
    return AppThemeAccent.forest;
  }
}
