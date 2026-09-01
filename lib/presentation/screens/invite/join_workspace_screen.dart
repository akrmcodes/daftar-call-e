import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/deep_link_token_parser.dart';
import 'package:daftar/presentation/providers/deep_link_providers.dart';
import 'package:daftar/presentation/screens/invite/deep_link_outcome_message.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings entry for pasting an invite link or token (roadmap Decision 1A).
class JoinWorkspaceScreen extends ConsumerStatefulWidget {
  /// Creates the join screen.
  const JoinWorkspaceScreen({super.key});

  @override
  ConsumerState<JoinWorkspaceScreen> createState() => _JoinWorkspaceScreenState();
}

class _JoinWorkspaceScreenState extends ConsumerState<JoinWorkspaceScreen> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) {
      return;
    }

    final token = DeepLinkTokenParser.extractFromRaw(raw);
    if (token == null) {
      setState(() {
        _error = AppLocalizations.of(context)!.joinWorkspaceInvalidCode;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final outcome =
        await ref.read(deepLinkControllerProvider.notifier).handleToken(token);

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
      _error = deepLinkOutcomeMessage(AppLocalizations.of(context)!, outcome);
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      return;
    }
    _codeController.text = text;
    await _submit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final muted = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final surface = isDark ? AppColors.surface1 : AppColors.surface0Light;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surface2 : AppColors.surface1Light,
        title: Text(
          l10n.joinWorkspaceTitle,
          style: AppTextStyles.headlineLarge.copyWith(color: ink),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Text(
              l10n.joinWorkspaceBody,
              style: AppTextStyles.bodyLarge.copyWith(color: muted),
            ),
            const SizedBox(height: 24),
            DaftarTextField(
              controller: _codeController,
              label: l10n.joinWorkspaceCodeLabel,
              hint: l10n.joinWorkspaceCodeHint,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.debt : AppColors.debtLight,
                ),
              ),
            ],
            const SizedBox(height: 20),
            DaftarButton(
              label: l10n.joinWorkspaceContinue,
              isLoading: _submitting,
              isExpanded: true,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: 12),
            DaftarButton(
              label: l10n.inviteCeremonyPasteClipboard,
              variant: DaftarButtonVariant.secondary,
              isExpanded: true,
              onPressed: _submitting ? null : _pasteFromClipboard,
            ),
          ],
        ),
      ),
    );
  }
}
