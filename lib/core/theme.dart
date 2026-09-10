import 'package:flutter/material.dart';

/// 书径主题 —— 简约 + 毛玻璃
class AppTheme {
  static const Color seed = Color(0xFF34A853); // 草绿

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFF7F8F7),
      onSurface: const Color(0xFF1A1C1A),
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF161816),
      onSurface: const Color(0xFFE2E5E2),
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.onSurface.withOpacity(0.06),
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: null,
      textTheme: Typography.englishLike2021.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
  }
}

/// 玻璃材质参数（深浅模式不同）
class Glass {
  static Color fill(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.62);
  }

  static Color border(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.85);
  }

  static Color text(BuildContext context) => Theme.of(context).colorScheme.onSurface;
}
