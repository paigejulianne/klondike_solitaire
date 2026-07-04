import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klondike_solitaire/models/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to classic blue cards on classic green felt', () {
    final theme = AppTheme();
    expect(theme.cardBackStyle, CardBackStyle.classicBlue);
    expect(theme.tableTheme, TableTheme.classicGreen);
  });

  test('setCardBackStyle updates the value, notifies, and persists', () async {
    final theme = AppTheme();
    var notified = false;
    theme.addListener(() => notified = true);

    await theme.setCardBackStyle(CardBackStyle.crimson);

    expect(theme.cardBackStyle, CardBackStyle.crimson);
    expect(notified, isTrue);

    final reloaded = AppTheme();
    await reloaded.load();
    expect(reloaded.cardBackStyle, CardBackStyle.crimson);
  });

  test('setTableTheme updates the value, notifies, and persists', () async {
    final theme = AppTheme();
    var notified = false;
    theme.addListener(() => notified = true);

    await theme.setTableTheme(TableTheme.walnut);

    expect(theme.tableTheme, TableTheme.walnut);
    expect(notified, isTrue);

    final reloaded = AppTheme();
    await reloaded.load();
    expect(reloaded.tableTheme, TableTheme.walnut);
  });

  test('setting the same value again does not notify', () async {
    final theme = AppTheme();
    var notifyCount = 0;
    theme.addListener(() => notifyCount++);

    await theme.setCardBackStyle(CardBackStyle.classicBlue);

    expect(notifyCount, 0);
  });
}
