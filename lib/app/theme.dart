import 'package:flutter/material.dart';
import '../models/label_definition.dart';

/// 应用主题定义
///
/// 提供明暗两种主题模式的颜色和样式配置。
class AppTheme {
  // ==================== 通用颜色 ====================

  /// 主色调 - 靛蓝色
  static const Color primaryColor = Color(0xFF6366F1);

  /// 次要色 - 紫色
  static const Color secondaryColor = Color(0xFF8B5CF6);

  /// 强调色 - 翡翠绿
  static const Color accentColor = Color(0xFF10B981);

  /// 错误色 - 红色
  static const Color errorColor = Color(0xFFEF4444);

  /// 警告色 - 琥珀色
  static const Color warningColor = Color(0xFFF59E0B);

  // ==================== 暗色主题颜色 ====================

  /// 暗色背景
  static const Color bgDark = Color(0xFF0F0F12);

  /// 暗色卡片背景
  static const Color bgCard = Color(0xFF18181B);

  /// 暗色抬升背景
  static const Color bgElevated = Color(0xFF27272A);

  /// 暗色覆盖层背景
  static const Color bgOverlay = Color(0xFF3F3F46);

  /// 暗色主要文字
  static const Color textPrimary = Color(0xFFF4F4F5);

  /// 暗色次要文字
  static const Color textSecondary = Color(0xFFA1A1AA);

  /// 暗色弱化文字
  static const Color textMuted = Color(0xFF71717A);

  /// 暗色默认边框
  static const Color borderDefault = Color(0xFF3F3F46);

  /// 暗色聚焦边框
  static const Color borderFocus = Color(0xFF6366F1);

  // ==================== 亮色主题颜色 ====================

  /// 亮色背景
  static const Color bgLightBase = Color(0xFFFAFAFA);

  /// 亮色卡片背景
  static const Color bgLightCard = Color(0xFFFFFFFF);

  /// 亮色抬升背景
  static const Color bgLightElevated = Color(0xFFF4F4F5);

  /// 亮色覆盖层背景
  static const Color bgLightOverlay = Color(0xFFE4E4E7);

  /// 亮色主要文字
  static const Color textLightPrimary = Color(0xFF18181B);

  /// 亮色次要文字
  static const Color textLightSecondary = Color(0xFF52525B);

  /// 亮色弱化文字
  static const Color textLightMuted = Color(0xFF71717A);

  /// 亮色默认边框
  static const Color borderLightDefault = Color(0xFFE4E4E7);

  /// 亮色聚焦边框
  static const Color borderLightFocus = Color(0xFF6366F1);

  /// 根据类别ID获取标签颜色
  static Color getLabelColor(int classId) {
    return LabelPalettes
        .defaultPalette[classId % LabelPalettes.defaultPalette.length];
  }

  // ==================== 主题感知颜色获取器 ====================

  /// 获取背景色
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? bgDark
        : bgLightBase;
  }

  /// 获取卡片背景色
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? bgCard
        : bgLightCard;
  }

  /// 获取抬升背景色
  static Color getElevatedColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? bgElevated
        : bgLightElevated;
  }

  /// 获取覆盖层背景色
  static Color getOverlayColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? bgOverlay
        : bgLightOverlay;
  }

  /// 获取主要文字颜色
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimary
        : textLightPrimary;
  }

  /// 获取次要文字颜色
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondary
        : textLightSecondary;
  }

  /// 获取弱化文字颜色
  static Color getTextMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textMuted
        : textLightMuted;
  }

  /// 获取边框颜色
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? borderDefault
        : borderLightDefault;
  }

  // ==================== 亮色主题 ====================

  /// 亮色主题数据
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: bgLightCard,
        error: errorColor,
      ),
      scaffoldBackgroundColor: bgLightBase,
      cardColor: bgLightCard,
      dividerColor: borderLightDefault,
      appBarTheme: _buildAppBarTheme(isLight: true),
      cardTheme: _buildCardTheme(isLight: true),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      iconButtonTheme: _buildIconButtonTheme(isLight: true),
      inputDecorationTheme: _buildInputDecorationTheme(isLight: true),
      listTileTheme: _buildListTileTheme(isLight: true),
      tooltipTheme: _buildTooltipTheme(isLight: true),
      snackBarTheme: _buildSnackBarTheme(isLight: true),
      textTheme: _buildTextTheme(isLight: true),
    );
  }

  // ==================== 暗色主题 ====================

  /// 暗色主题数据
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: bgCard,
        error: errorColor,
      ),
      scaffoldBackgroundColor: bgDark,
      cardColor: bgCard,
      dividerColor: borderDefault,
      appBarTheme: _buildAppBarTheme(isLight: false),
      cardTheme: _buildCardTheme(isLight: false),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      iconButtonTheme: _buildIconButtonTheme(isLight: false),
      inputDecorationTheme: _buildInputDecorationTheme(isLight: false),
      listTileTheme: _buildListTileTheme(isLight: false),
      tooltipTheme: _buildTooltipTheme(isLight: false),
      snackBarTheme: _buildSnackBarTheme(isLight: false),
      textTheme: _buildTextTheme(isLight: false),
    );
  }

  // ==================== 主题组件构建器 ====================

  /// 构建 AppBar 主题样式。
  static AppBarTheme _buildAppBarTheme({required bool isLight}) {
    return AppBarTheme(
      backgroundColor: isLight ? bgLightCard : bgCard,
      foregroundColor: isLight ? textLightPrimary : textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isLight ? textLightPrimary : textPrimary,
      ),
    );
  }

  /// 构建卡片主题样式。
  static CardTheme _buildCardTheme({required bool isLight}) {
    return CardTheme(
      color: isLight ? bgLightCard : bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLight ? borderLightDefault : borderDefault,
          width: 1,
        ),
      ),
    );
  }

  /// 构建主按钮主题样式。
  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 构建图标按钮主题样式。
  static IconButtonThemeData _buildIconButtonTheme({required bool isLight}) {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: isLight ? textLightSecondary : textSecondary,
        hoverColor: isLight ? bgLightOverlay : bgOverlay,
      ),
    );
  }

  /// 构建输入框主题样式。
  static InputDecorationTheme _buildInputDecorationTheme(
      {required bool isLight}) {
    final borderColor = isLight ? borderLightDefault : borderDefault;
    final focusBorderColor = isLight ? borderLightFocus : borderFocus;
    final fillColor = isLight ? bgLightElevated : bgElevated;

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: focusBorderColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  /// 构建列表项主题样式。
  static ListTileThemeData _buildListTileTheme({required bool isLight}) {
    return ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: isLight ? bgLightOverlay : bgOverlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  /// 构建 Tooltip 主题样式。
  static TooltipThemeData _buildTooltipTheme({required bool isLight}) {
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: isLight ? bgLightOverlay : bgOverlay,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(
        color: isLight ? textLightPrimary : textPrimary,
        fontSize: 12,
      ),
    );
  }

  /// 构建 SnackBar 主题样式。
  static SnackBarThemeData _buildSnackBarTheme({required bool isLight}) {
    return SnackBarThemeData(
      backgroundColor: isLight ? bgLightElevated : bgElevated,
      contentTextStyle: TextStyle(
        color: isLight ? textLightPrimary : textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    );
  }

  /// 构建文本主题样式。
  static TextTheme _buildTextTheme({required bool isLight}) {
    final primary = isLight ? textLightPrimary : textPrimary;
    final secondary = isLight ? textLightSecondary : textSecondary;
    final muted = isLight ? textLightMuted : textMuted;

    return TextTheme(
      headlineLarge:
          TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primary),
      headlineMedium:
          TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: primary),
      titleLarge:
          TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primary),
      titleMedium:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: primary),
      bodyLarge: TextStyle(fontSize: 14, color: primary),
      bodyMedium: TextStyle(fontSize: 13, color: secondary),
      bodySmall: TextStyle(fontSize: 12, color: muted),
    );
  }
}
