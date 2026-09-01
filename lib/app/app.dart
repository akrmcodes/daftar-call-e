import 'package:daftar/app/router/app_router_provider.dart';
import 'package:daftar/app/theme/app_theme.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/providers/app_lock_provider.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/locale_provider.dart' hide Locale;
import 'package:daftar/presentation/providers/theme_provider.dart' hide Theme;
import 'package:daftar/presentation/screens/auth/lock_screen.dart';
import 'package:daftar/presentation/shared/widgets/daftar_architecture_hud.dart';
import 'package:daftar/presentation/shared/widgets/daftar_launch_curtain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget for the Daftar application.
///
/// Configures the generated Flutter localizations, the shared theme, and the
/// app router used by the Stage 0 navigation shell.
class DaftarApp extends ConsumerWidget {
  const DaftarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..watch(appLockManagerProvider)
      ..watch(backupQueueManagerProvider)
      ..watch(driveBackupHydratorProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeProvider),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(goRouterProvider),
      builder: (context, child) {
        return TooltipVisibility(
          visible: false,
          child: AppLockOverlay(
            child: Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                const DaftarArchitectureHud(),
                const DaftarLaunchCurtain(),
              ],
            ),
          ),
        );
      },
    );
  }
}
