import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/presentation/screens/onboarding/onboarding_beat.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_text_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Beat 7 — one-tap first ledger when the workspace is empty.
class OnboardingLedgerBeat extends StatefulWidget {
  const OnboardingLedgerBeat({
    required this.onSelected,
    required this.isBusy,
    this.onTryDemoStore,
    super.key,
  });

  final void Function(LedgerType type, {String? customName}) onSelected;
  final bool isBusy;
  final VoidCallback? onTryDemoStore;

  @override
  State<OnboardingLedgerBeat> createState() => _OnboardingLedgerBeatState();
}

class _OnboardingLedgerBeatState extends State<OnboardingLedgerBeat> {
  bool _showCustomField = false;
  late final TextEditingController _customNameController;

  @override
  void initState() {
    super.initState();
    _customNameController = TextEditingController();
    _customNameController.addListener(_onCustomNameChanged);
  }

  @override
  void dispose() {
    _customNameController
      ..removeListener(_onCustomNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onCustomNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _selectTemplate(LedgerType type) {
    if (widget.isBusy) {
      return;
    }
    setState(() => _showCustomField = false);
    widget.onSelected(type);
  }

  void _onTryDemoStore() {
    if (widget.isBusy || widget.onTryDemoStore == null) {
      return;
    }
    setState(() => _showCustomField = false);
    widget.onTryDemoStore!();
  }

  void _toggleCustom() {
    if (widget.isBusy) {
      return;
    }
    setState(() => _showCustomField = true);
  }

  void _createCustom() {
    if (widget.isBusy) {
      return;
    }
    final name = _customNameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    widget.onSelected(LedgerType.custom, customName: name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    return OnboardingBeatMotion(
      child: OnboardingBeatFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnboardingBeatHeader(
              icon: Icons.menu_book_outlined,
              title: l10n.onboardingSetupLedgerTitle,
            ),
            const Gap(AppDimensions.spacingMd),
            Text(
              l10n.onboardingSetupLedgerLedgerLine,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: inkMuted,
                height: 1.45,
              ),
            ),
            const Gap(AppDimensions.spacingSm),
            Text(
              l10n.onboardingSetupLedgerAccountsLine,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: inkMuted,
                height: 1.45,
              ),
            ),
            const Gap(AppDimensions.spacing4xl),
            _LedgerChip(
              key: const ValueKey<String>('onboarding-ledger-customers'),
              icon: Icons.people_alt_rounded,
              label: l10n.closingAgentLedgerTypeCustomers,
              enabled: !widget.isBusy,
              onTap: () => _selectTemplate(LedgerType.customers),
            ),
            const Gap(AppDimensions.spacingLg),
            _LedgerChip(
              key: const ValueKey<String>('onboarding-try-demo-store'),
              icon: Icons.auto_stories_outlined,
              label: l10n.onboardingTryDemoStore,
              enabled: !widget.isBusy && widget.onTryDemoStore != null,
              onTap: _onTryDemoStore,
            ),
            const Gap(AppDimensions.spacingLg),
            _LedgerChip(
              key: const ValueKey<String>('onboarding-ledger-personal'),
              icon: Icons.person_rounded,
              label: l10n.closingAgentLedgerTypePersonal,
              enabled: !widget.isBusy,
              onTap: () => _selectTemplate(LedgerType.personal),
            ),
            const Gap(AppDimensions.spacingLg),
            _LedgerChip(
              key: const ValueKey<String>('onboarding-ledger-custom'),
              icon: Icons.folder_special_rounded,
              label: l10n.onboardingSetupLedgerCustomChip,
              enabled: !widget.isBusy,
              isSelected: _showCustomField,
              onTap: _toggleCustom,
            ),
            if (_showCustomField) ...[
              const Gap(AppDimensions.spacingLg),
              DaftarTextField(
                key: const ValueKey<String>('onboarding-ledger-custom-name'),
                controller: _customNameController,
                label: l10n.onboardingSetupLedgerCustomChip,
                hint: l10n.onboardingSetupLedgerCustomHint,
                prefixIcon: Icons.folder_special_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _createCustom(),
              ),
              const Gap(AppDimensions.spacingLg),
              DaftarButton(
                key: const ValueKey<String>('onboarding-ledger-create'),
                label: l10n.onboardingSetupLedgerCreate,
                isExpanded: true,
                isLoading: widget.isBusy,
                onPressed: widget.isBusy || _customNameController.text.trim().isEmpty
                    ? null
                    : _createCustom,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LedgerChip extends StatelessWidget {
  const _LedgerChip({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.isSelected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return DaftarCard(
      variant: DaftarCardVariant.selectable,
      isSelected: isSelected,
      onTap: enabled ? onTap : null,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppDimensions.spacingXl,
        vertical: AppDimensions.spacingXl,
      ),
      child: Row(
        children: [
          Icon(icon, color: inkPrimary),
          const Gap(AppDimensions.spacingLg),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.titleMedium.copyWith(color: inkPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
