import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A card-back design, drawn entirely from colors/shapes (no image assets).
enum CardBackStyle {
  classicBlue('Classic Blue', [Color(0xFF2C6BD6), Color(0xFF1B49A0)], Icons.style),
  crimson('Crimson', [Color(0xFFD6402C), Color(0xFF8E1F13)], Icons.favorite),
  emerald('Emerald', [Color(0xFF1FAE6B), Color(0xFF0B6B3F)], Icons.eco),
  royalPurple('Royal Purple', [Color(0xFF7C4FD6), Color(0xFF4A2A94)], Icons.auto_awesome),
  teal('Teal', [Color(0xFF13B0C4), Color(0xFF0A6B78)], Icons.water_drop),
  sunset('Sunset', [Color(0xFFF08A24), Color(0xFFB5560F)], Icons.wb_sunny),
  rose('Rose', [Color(0xFFE85C9A), Color(0xFF9B2E63)], Icons.spa),
  gold('Gold', [Color(0xFFE0A400), Color(0xFF9A6E00)], Icons.star),
  charcoal('Charcoal', [Color(0xFF5A6472), Color(0xFF2B313B)], Icons.grid_view),
  magenta('Magenta', [Color(0xFFC13FB0), Color(0xFF7A1E6E)], Icons.diamond);

  final String label;
  final List<Color> gradient;
  final IconData icon;
  const CardBackStyle(this.label, this.gradient, this.icon);
}

/// A table (background) theme.
enum TableTheme {
  classicGreen('Classic Green', [Color(0xFF15803D), Color(0xFF063D15)]),
  midnightBlue('Midnight Blue', [Color(0xFF1E3A6E), Color(0xFF0A1530)]),
  casinoRed('Casino Red', [Color(0xFF7A1F2B), Color(0xFF2E0A10)]),
  walnut('Walnut', [Color(0xFF6B4A2E), Color(0xFF2E1D10)]),
  teal('Teal', [Color(0xFF0F6E6E), Color(0xFF04302E)]),
  slateGray('Slate Gray', [Color(0xFF4A5568), Color(0xFF1A202C)]),
  plum('Plum', [Color(0xFF4A2A5E), Color(0xFF1E0F2E)]),
  charcoal('Charcoal', [Color(0xFF2D2D2D), Color(0xFF0A0A0A)]),
  ocean('Ocean', [Color(0xFF0E7490), Color(0xFF082F49)]),
  burgundy('Burgundy', [Color(0xFF5B1A34), Color(0xFF260713)]);

  final String label;
  final List<Color> gradient;
  const TableTheme(this.label, this.gradient);
}

const _prefsCardBackKey = 'appearance.cardBackStyle';
const _prefsTableThemeKey = 'appearance.tableTheme';

/// Holds the user's chosen appearance and persists it across app launches.
class AppTheme extends ChangeNotifier {
  CardBackStyle cardBackStyle = CardBackStyle.classicBlue;
  TableTheme tableTheme = TableTheme.classicGreen;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final backName = prefs.getString(_prefsCardBackKey);
    final tableName = prefs.getString(_prefsTableThemeKey);
    cardBackStyle = CardBackStyle.values.firstWhere(
      (s) => s.name == backName,
      orElse: () => CardBackStyle.classicBlue,
    );
    tableTheme = TableTheme.values.firstWhere(
      (t) => t.name == tableName,
      orElse: () => TableTheme.classicGreen,
    );
    notifyListeners();
  }

  Future<void> setCardBackStyle(CardBackStyle style) async {
    if (style == cardBackStyle) return;
    cardBackStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCardBackKey, style.name);
  }

  Future<void> setTableTheme(TableTheme theme) async {
    if (theme == tableTheme) return;
    tableTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTableThemeKey, theme.name);
  }
}
