import 'package:flutter/material.dart';

class AppBanner {
  final String id;
  final String title;
  final String? subtitle;
  final String? badgeText;
  final String? imageUrl;
  final String actionType;
  final String? actionValue;
  final String actionButtonText;
  final Color gradientStart;
  final Color gradientEnd;
  final bool isActive;
  final int displayOrder;
  final String targetRole;

  const AppBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.badgeText,
    this.imageUrl,
    this.actionType = 'none',
    this.actionValue,
    this.actionButtonText = 'عرض التفاصيل',
    this.gradientStart = const Color(0xFF4F46E5),
    this.gradientEnd = const Color(0xFF7C3AED),
    this.isActive = true,
    this.displayOrder = 1,
    this.targetRole = 'all',
  });

  factory AppBanner.fromMap(Map<String, dynamic> map) {
    return AppBanner(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      subtitle: map['subtitle']?.toString(),
      badgeText: map['badge_text']?.toString(),
      imageUrl: map['image_url']?.toString(),
      actionType: (map['action_type'] ?? 'none').toString().toLowerCase(),
      actionValue: map['action_value']?.toString(),
      actionButtonText: (map['action_button_text'] ?? 'عرض التفاصيل').toString(),
      gradientStart: _parseColor(map['gradient_start'], const Color(0xFF4F46E5)),
      gradientEnd: _parseColor(map['gradient_end'], const Color(0xFF7C3AED)),
      isActive: map['is_active'] == true,
      displayOrder: (map['display_order'] is num) ? (map['display_order'] as num).toInt() : 1,
      targetRole: (map['target_role'] ?? 'all').toString().toLowerCase(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'badge_text': badgeText,
      'image_url': imageUrl,
      'action_type': actionType,
      'action_value': actionValue,
      'action_button_text': actionButtonText,
      'gradient_start': _colorToHex(gradientStart),
      'gradient_end': _colorToHex(gradientEnd),
      'is_active': isActive,
      'display_order': displayOrder,
      'target_role': targetRole,
    };
  }

  static Color _parseColor(dynamic hexOrName, Color defaultColor) {
    if (hexOrName == null) return defaultColor;
    final str = hexOrName.toString().trim();
    if (str.isEmpty) return defaultColor;

    // Presets support
    switch (str.toLowerCase()) {
      case 'purple':
        return const Color(0xFF8B5CF6);
      case 'indigo':
        return const Color(0xFF4F46E5);
      case 'emerald':
      case 'green':
        return const Color(0xFF059669);
      case 'teal':
        return const Color(0xFF0D9488);
      case 'orange':
        return const Color(0xFFEA580C);
      case 'amber':
        return const Color(0xFFD97706);
      case 'blue':
        return const Color(0xFF2563EB);
      case 'rose':
      case 'pink':
        return const Color(0xFFE11D48);
      case 'dark':
      case 'slate':
        return const Color(0xFF1E293B);
    }

    try {
      String hex = str.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}

    return defaultColor;
  }

  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
