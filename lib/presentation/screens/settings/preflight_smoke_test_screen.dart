import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_ambient_mesh.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_scroll_screen_title.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';

/// Temporary Phase 0.5 diagnostic — debug builds only.
class PreflightSmokeTestScreen extends StatefulWidget {
  const PreflightSmokeTestScreen({super.key});

  @override
  State<PreflightSmokeTestScreen> createState() =>
      _PreflightSmokeTestScreenState();
}

class _PreflightSmokeTestScreenState extends State<PreflightSmokeTestScreen> {
  static const _testPayload = 'DAFTAR_SMOKE_TEST_OK';
  static const _testFileName = 'smoke_test.txt';
  static const List<String> _driveScopes = [
    drive.DriveApi.driveAppdataScope,
  ];

  final _logLines = <String>[];
  final _logController = ScrollController();

  bool _busy = false;
  bool _initialized = false;
  GoogleSignInAccount? _account;

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  void _appendLog(String message) {
    final stamp = DateFormat('HH:mm:ss').format(DateTime.now());
    setState(() {
      _logLines.add('[$stamp] $message');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logController.hasClients) {
        unawaited(
          _logController.animateTo(
            _logController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  void _logError(Object error, [StackTrace? stackTrace]) {
    if (error is PlatformException) {
      _appendLog(
        'PlatformException code=${error.code} '
        'message=${error.message ?? '(none)'} '
        'details=${error.details ?? '(none)'}',
      );
      return;
    }
    _appendLog('ERROR: $error');
    if (stackTrace != null) {
      _appendLog(stackTrace.toString());
    }
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e, st) {
      _logError(e, st);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final serverClientId = Env.googleServerClientId;
    if (serverClientId.isEmpty) {
      throw StateError(
        'GOOGLE_SERVER_CLIENT_ID is empty. Check .env and rebuild env.g.dart.',
      );
    }

    _appendLog('Initializing GoogleSignIn (serverClientId configured)…');
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );
    _initialized = true;
    _appendLog('GoogleSignIn initialized.');
  }

  Future<drive.DriveApi> _createDriveApi(GoogleSignInAccount account) async {
    final authorization = await account.authorizationClient
        .authorizationForScopes(_driveScopes);
    if (authorization == null) {
      throw StateError(
        'No authorization for drive.appdata. Run Interactive Sign-In first.',
      );
    }
    final authClient = authorization.authClient(scopes: _driveScopes);
    return drive.DriveApi(authClient);
  }

  Future<void> _interactiveSignIn() async {
    await _runGuarded(() async {
      await HapticService.buttonPress();
      _appendLog('── Interactive Sign-In ──');
      await _ensureInitialized();

      _account = await GoogleSignIn.instance.authenticate();
      _appendLog('Authenticated: ${_account!.email}');

      await _account!.authorizationClient.authorizeScopes(_driveScopes);
      _appendLog('drive.appdata scope authorized.');

      final driveApi = await _createDriveApi(_account!);
      _appendLog('DriveApi client ready (${driveApi.runtimeType}).');
      _appendLog('Interactive Sign-In PASSED.');
    });
  }

  Future<void> _driveRoundTrip() async {
    await _runGuarded(() async {
      await HapticService.buttonPress();
      _appendLog('── Drive v3 Round-Trip (appDataFolder) ──');
      await _ensureInitialized();

      final account = _account;
      if (account == null) {
        throw StateError('Not signed in. Run Interactive Sign-In first.');
      }

      final driveApi = await _createDriveApi(account);

      _appendLog('Uploading $_testFileName…');
      final contentBytes = utf8.encode(_testPayload);
      final created = await driveApi.files.create(
        drive.File()
          ..name = _testFileName
          ..parents = ['appDataFolder'],
        uploadMedia: drive.Media(
          Stream.value(contentBytes),
          contentBytes.length,
        ),
      );
      final uploadedId = created.id;
      if (uploadedId == null || uploadedId.isEmpty) {
        throw StateError('Upload returned empty file id.');
      }
      _appendLog('Upload OK id=$uploadedId');

      _appendLog('Listing appDataFolder for $_testFileName…');
      final listed = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_testFileName'",
        $fields: 'files(id,name)',
      );
      final files = listed.files ?? [];
      if (files.isEmpty) {
        throw StateError('List: file not found in appDataFolder.');
      }
      final listedId = files.first.id;
      _appendLog('List OK found ${files.length} file(s) id=$listedId');

      _appendLog('Downloading…');
      final media = await driveApi.files.get(
        listedId!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final data = <int>[];
      await media.stream.forEach(data.addAll);
      final content = utf8.decode(data);
      if (content != _testPayload) {
        throw StateError(
          'Content mismatch: expected "$_testPayload", got "$content".',
        );
      }
      _appendLog('Download OK content verified.');

      _appendLog('Deleting…');
      await driveApi.files.delete(listedId);
      _appendLog('Delete OK.');
      _appendLog('Drive Round-Trip PASSED.');
    });
  }

  Future<void> _silentSignIn() async {
    await _runGuarded(() async {
      await HapticService.buttonPress();
      _appendLog('── Silent Sign-In (attemptLightweightAuthentication) ──');
      await _ensureInitialized();

      final future = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (future == null) {
        _appendLog(
          'attemptLightweightAuthentication not supported on this platform.',
        );
        return;
      }

      final silentAccount = await future;
      if (silentAccount == null) {
        _appendLog(
          'Silent auth returned null (expected after sign-out or first launch).',
        );
      } else {
        _account = silentAccount;
        _appendLog('Silent auth OK: ${silentAccount.email}');
      }
      _appendLog('Silent Sign-In step completed without exception.');
    });
  }

  Future<void> _signOut() async {
    await _runGuarded(() async {
      await HapticService.buttonPress();
      _appendLog('── Sign Out ──');
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
      _account = null;
      _appendLog('Signed out. Auth state cleared.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final surfaceColor =
        isDark ? AppColors.surface0 : AppColors.surface0Light;

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BackupAmbientMesh(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              DaftarScrollScreenTitleSliver(
                title: Text(
                  l10n.smokeTestTitle,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: inkPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.smokeTestSubtitle,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: inkSecondary,
                          height: 1.45,
                        ),
                      ),
                      const Gap(AppDimensions.spacingLg),
                      DaftarButton(
                        label: l10n.preflightSignIn,
                        isExpanded: true,
                        isLoading: _busy,
                        onPressed: _busy ? null : _interactiveSignIn,
                      ),
                      const Gap(AppDimensions.spacingSm),
                      DaftarButton(
                        label: l10n.preflightDriveRoundTrip,
                        variant: DaftarButtonVariant.secondary,
                        isExpanded: true,
                        isLoading: _busy,
                        onPressed: _busy ? null : _driveRoundTrip,
                      ),
                      const Gap(AppDimensions.spacingSm),
                      DaftarButton(
                        label: l10n.preflightSilentSignIn,
                        variant: DaftarButtonVariant.secondary,
                        isExpanded: true,
                        isLoading: _busy,
                        onPressed: _busy ? null : _silentSignIn,
                      ),
                      const Gap(AppDimensions.spacingSm),
                      DaftarButton(
                        label: l10n.preflightSignOut,
                        variant: DaftarButtonVariant.tertiary,
                        isExpanded: true,
                        isLoading: _busy,
                        onPressed: _busy ? null : _signOut,
                      ),
                      const Gap(AppDimensions.spacingXl),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.preflightConsoleTitle,
                              style: AppTextStyles.titleSmall.copyWith(
                                color: inkPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(_logLines.clear);
                                  },
                            child: Text(
                              l10n.preflightClearLog,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: inkSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppDimensions.spacingSm),
                      DaftarCard(
                        padding: const EdgeInsetsDirectional.all(
                          AppDimensions.spacingMd,
                        ),
                        child: SizedBox(
                          height: 280,
                          child: _logLines.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.smokeTestRunning,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: inkSecondary,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _logController,
                                  itemCount: _logLines.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsetsDirectional.only(
                                        bottom: AppDimensions.spacingXs,
                                      ),
                                      child: SelectableText(
                                          _logLines[index],
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                            color: inkPrimary,
                                            fontFamily: 'monospace',
                                            height: 1.35,
                                          ),
                                        ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 48,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
