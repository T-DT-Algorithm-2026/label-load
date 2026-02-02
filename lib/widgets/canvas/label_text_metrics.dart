import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 标签文本排版与命中辅助。
///
/// 提供文本矩形、悬停检测和段落构建的统一逻辑。
class LabelTextMetrics {
  static const double _fontSize = 12;
  static const double _paddingHorizontal = 8;
  static const double _height = 18;
  static const double _offsetTop = 20;
  static const double _textOffsetX = 4;
  static const double _textOffsetY = 18;

  /// 基于标签矩形构建文本背景矩形。
  static Rect buildTextRect({
    required Rect labelRect,
    required String text,
    required double maxWidth,
  }) {
    final paragraph = _buildParagraph(
      text,
      ui.TextStyle(
        fontSize: _fontSize,
        fontWeight: FontWeight.w500,
      ),
      maxWidth,
    );

    return Rect.fromLTWH(
      labelRect.left,
      labelRect.top - _offsetTop,
      paragraph.maxIntrinsicWidth + _paddingHorizontal,
      _height,
    );
  }

  /// 判断鼠标是否悬停在文本矩形内。
  static bool isHovered({
    required Rect textRect,
    required Offset? mousePosition,
    required Size canvasSize,
  }) {
    if (mousePosition == null) return false;
    final mousePixel = Offset(
      mousePosition.dx * canvasSize.width,
      mousePosition.dy * canvasSize.height,
    );
    return textRect.contains(mousePixel);
  }

  /// 构建用于绘制的段落对象。
  static ui.Paragraph buildParagraph({
    required String text,
    required Color color,
    required bool isHovered,
    required double maxWidth,
  }) {
    final textStyle = ui.TextStyle(
      color: color.withValues(alpha: isHovered ? 0.3 : 1.0),
      fontSize: _fontSize,
      fontWeight: FontWeight.w500,
    );

    return _buildParagraph(text, textStyle, maxWidth);
  }

  /// 文本绘制偏移（相对标签矩形）。
  static Offset textOffset(Rect labelRect) {
    return Offset(labelRect.left + _textOffsetX, labelRect.top - _textOffsetY);
  }

  static ui.Paragraph _buildParagraph(
    String text,
    ui.TextStyle style,
    double maxWidth,
  ) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: _fontSize,
        fontWeight: FontWeight.w500,
      ),
    )
      ..pushStyle(style)
      ..addText(text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
    return paragraph;
  }
}
