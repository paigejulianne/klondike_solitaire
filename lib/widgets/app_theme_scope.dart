import 'package:flutter/material.dart';

import '../models/app_theme.dart';

/// Makes the current [AppTheme] available to any descendant via
/// [AppThemeScope.of], rebuilding them automatically when it changes.
class AppThemeScope extends InheritedNotifier<AppTheme> {
  const AppThemeScope({super.key, required AppTheme theme, required super.child}) : super(notifier: theme);

  static final AppTheme _fallback = AppTheme();

  /// Falls back to default appearance settings when built outside of a
  /// [AppThemeScope] (e.g. in isolated widget tests), rather than throwing.
  static AppTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    return scope?.notifier ?? _fallback;
  }
}
