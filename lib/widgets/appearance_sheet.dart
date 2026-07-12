import 'package:flutter/material.dart';

import '../models/app_theme.dart';
import '../models/card.dart';
import 'app_theme_scope.dart';
import 'card_view.dart';

/// Bottom sheet letting the player pick a card-back design and a table
/// background. Selections apply immediately and persist across launches.
void showAppearanceSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1B1F1B),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => const _AppearanceSheet(),
  );
}

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Card Back', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final style in CardBackStyle.values)
                  _CardBackSwatch(
                    style: style,
                    selected: theme.cardBackStyle == style,
                    onTap: () => theme.setCardBackStyle(style),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Table', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final table in TableTheme.values)
                  _TableSwatch(
                    theme: table,
                    selected: theme.tableTheme == table,
                    onTap: () => theme.setTableTheme(table),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBackSwatch extends StatelessWidget {
  final CardBackStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _CardBackSwatch({required this.style, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: selected ? Colors.amberAccent : Colors.transparent, width: 3),
            ),
            child: IgnorePointer(
              child: CardView(
                card: PlayingCard(suit: Suit.spades, rank: 1),
                width: 52,
                height: 52 * 1.4,
                backStyleOverride: style,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              style.label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableSwatch extends StatelessWidget {
  final TableTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _TableSwatch({required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: theme.gradient,
              ),
              border: Border.all(color: selected ? Colors.amberAccent : Colors.white24, width: selected ? 3 : 1),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              theme.label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
