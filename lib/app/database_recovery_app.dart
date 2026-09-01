import 'package:daftar/app/theme/app_theme.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/recovery/database_recovery_screen.dart';
import 'package:flutter/material.dart';

/// Standalone app shell when the SQLite database cannot pass integrity check.
///
/// Does not mount go_router or Riverpod providers that require Drift.
class DatabaseRecoveryApp extends StatelessWidget {
  const DatabaseRecoveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final isRtl = locale.languageCode == 'ar';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: const DatabaseRecoveryScreen(),
      ),
    );
  }
}
