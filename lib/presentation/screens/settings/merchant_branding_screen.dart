import 'dart:async' show unawaited;
import 'dart:io';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/pdf_generator.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/presentation/providers/entitlement_providers.dart';
import 'package:daftar/presentation/providers/merchant_profile_providers.dart';
import 'package:daftar/presentation/screens/contact/widgets/export_progress_overlay.dart';
import 'package:daftar/presentation/screens/settings/widgets/logo_source_tile.dart';
import 'package:daftar/presentation/screens/settings/widgets/merchant_branding_upgrade_banner.dart';
import 'package:daftar/presentation/screens/settings/widgets/merchant_logo_crop_screen.dart';
import 'package:daftar/presentation/screens/settings/widgets/store_identity_completion_rail.dart';
import 'package:daftar/presentation/screens/settings/widgets/store_identity_passport.dart';
import 'package:daftar/presentation/screens/settings/widgets/store_logo_seal.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_text_field.dart';
import 'package:daftar/presentation/widgets/premium/premium_limit_upsell_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

/// Premium merchant branding editor — logo, store identity, and PDF preview.
class MerchantBrandingScreen extends ConsumerStatefulWidget {
  const MerchantBrandingScreen({super.key});

  @override
  ConsumerState<MerchantBrandingScreen> createState() =>
      _MerchantBrandingScreenState();
}

class _MerchantBrandingScreenState extends ConsumerState<MerchantBrandingScreen> {
  final _storeNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _storeNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _imagePicker = ImagePicker();

  bool _hydratedFromProfile = false;
  bool _isEditing = true;
  bool _isPreviewingPdf = false;
  String? _storeNameError;

  @override
  void initState() {
    super.initState();
    _storeNameController.addListener(_onDraftChanged);
    _phoneController.addListener(_onDraftChanged);
  }

  @override
  void dispose() {
    _storeNameController
      ..removeListener(_onDraftChanged)
      ..dispose();
    _phoneController
      ..removeListener(_onDraftChanged)
      ..dispose();
    _storeNameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    if (_storeNameError != null && _storeNameController.text.trim().isNotEmpty) {
      setState(() => _storeNameError = null);
    } else {
      setState(() {});
    }
  }

  bool _isPremium(WidgetRef ref) {
    final tier = ref.watch(entitlementProvider).asData?.value.tier;
    return tier != null && tier != AppTier.free;
  }

  void _hydrateFromProfile(MerchantProfile? profile) {
    if (_hydratedFromProfile || profile == null) {
      return;
    }
    _storeNameController.text = profile.storeName;
    _applyPhoneFromProfile(profile.storePhone);
    _hydratedFromProfile = true;
    if (profile.storeName.trim().isNotEmpty && _isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isEditing = false);
        }
      });
    }
  }

  void _applyPhoneFromProfile(String? storePhone) {
    if (storePhone == null || storePhone.trim().isEmpty) {
      return;
    }
    _phoneController.text = storePhone.trim();
  }

  String? _composeStorePhone() {
    final raw = _phoneController.text.trim();
    return raw.isEmpty ? null : raw;
  }

  String _formatPhoneDisplay(String? storePhone) {
    if (storePhone == null || storePhone.trim().isEmpty) {
      return '—';
    }
    return storePhone.trim();
  }

  MerchantProfile _draftProfile({
    required MerchantProfile? persisted,
    String? logoPathOverride,
  }) {
    final now = DateTime.now().toUtc();
    return MerchantProfile(
      id: persisted?.id ?? UuidUtil.generate(),
      storeName: _storeNameController.text.trim(),
      storePhone: _composeStorePhone(),
      logoPath: logoPathOverride ?? persisted?.logoPath,
      createdAt: persisted?.createdAt ?? now,
      updatedAt: now,
    );
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) {
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success
            ? (isDark ? AppColors.surface4 : AppColors.surface2Light)
            : null,
      ),
    );
  }

  void _handleControllerError(Failure failure) {
    if (failure is LimitExceededFailure) {
      unawaited(PremiumLimitUpsellSheet.show(context, failure: failure));
      return;
    }
    unawaited(AppBottomSheet.showError(context, error: failure));
  }

  void _enterEditMode() {
    setState(() => _isEditing = true);
  }

  void _cancelEdit(MerchantProfile? persisted) {
    if (persisted != null) {
      _storeNameController.text = persisted.storeName;
      _applyPhoneFromProfile(persisted.storePhone);
    }
    setState(() {
      _storeNameError = null;
      _isEditing = false;
    });
    context.unfocus();
  }

  Future<void> _onSave() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _storeNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _storeNameError = l10n.merchantBrandingSaveProfileFirst);
      return;
    }

    context.unfocus();
    final saved = await ref
        .read(merchantProfileControllerProvider.notifier)
        .updateProfile(
          storeName: _storeNameController.text,
          storePhone: _composeStorePhone(),
        );

    if (!mounted) {
      return;
    }

    if (saved != null) {
      await HapticService.transactionSaved();
      if (!mounted) {
        return;
      }
      _showSnack(
        l10n.merchantBrandingSaveSuccess,
        success: true,
      );
      ref.read(merchantProfileControllerProvider.notifier).reset();
      setState(() {
        _storeNameError = null;
        _isEditing = false;
      });
    }
  }

  Future<void> _onPickLogo({required bool isLocked}) async {
    if (isLocked) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final source = await AppBottomSheet.show<ImageSource>(
      context,
      title: l10n.merchantBrandingPickSourceTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LogoSourceTile(
            icon: Icons.photo_camera_outlined,
            label: l10n.merchantBrandingPickCamera,
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          const Gap(AppDimensions.spacingSm),
          LogoSourceTile(
            icon: Icons.photo_library_outlined,
            label: l10n.merchantBrandingPickGallery,
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null || !mounted) {
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 100,
    );

    if (picked == null || !mounted) {
      return;
    }

    final croppedPath = await MerchantLogoCropScreen.show(
      context,
      imagePath: picked.path,
    );

    if (croppedPath == null || !mounted) {
      return;
    }

    final profileAsync = ref.read(merchantProfileProvider);
    final persisted = profileAsync.asData?.value;
    if (persisted == null && _storeNameController.text.trim().isEmpty) {
      _showSnack(l10n.merchantBrandingSaveProfileFirst);
      return;
    }

    if (persisted == null) {
      final created = await ref
          .read(merchantProfileControllerProvider.notifier)
          .updateProfile(
            storeName: _storeNameController.text,
            storePhone: _composeStorePhone(),
          );
      if (created == null || !mounted) {
        return;
      }
    }

    final logoPath = await ref
        .read(merchantProfileControllerProvider.notifier)
        .setLogo(sourcePath: croppedPath);

    if (!mounted) {
      return;
    }

    if (logoPath != null) {
      await HapticService.transactionSaved();
      ref.read(merchantProfileControllerProvider.notifier).reset();
    }
  }

  Future<void> _onRemoveLogo({
    required bool isLocked,
    required bool hasLogo,
  }) async {
    if (isLocked || !hasLogo) {
      return;
    }

    final removed = await ref
        .read(merchantProfileControllerProvider.notifier)
        .removeLogo();

    if (!mounted) {
      return;
    }

    if (removed) {
      final l10n = AppLocalizations.of(context)!;
      await HapticService.transactionSaved();
      if (!mounted) {
        return;
      }
      _showSnack(
        l10n.merchantBrandingLogoRemoved,
        success: true,
      );
      ref.read(merchantProfileControllerProvider.notifier).reset();
    }
  }

  Future<void> _onPreviewPdf({
    required bool isLocked,
    required MerchantProfile? persisted,
  }) async {
    if (isLocked || _isPreviewingPdf) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    setState(() => _isPreviewingPdf = true);
    final overlayCtrl = ExportProgressOverlay.show(
      context,
      title: l10n.merchantBrandingPreviewPdf,
    );

    try {
      overlayCtrl.update(0.1, l10n.pdfPreparingData);
      final draft = _draftProfile(persisted: persisted);
      final now = DateTime.now().toUtc();
      const previewContactId = 'preview-contact';
      final contact = Contact(
        id: previewContactId,
        ledgerId: 'preview-ledger',
        name: l10n.merchantBrandingPreviewContactName,
        avatarColor: '#4A5568',
        createdAt: now,
        updatedAt: now,
      );
      final balance = ContactBalance(
        contactId: previewContactId,
        currencyCode: 'YER',
        totalDebt: 150_000,
        totalPayment: 50_000,
        netBalance: 100_000,
        lastUpdatedAt: now,
      );
      final transactions = [
        Transaction(
          id: UuidUtil.generate(),
          contactId: previewContactId,
          type: TransactionType.debt,
          amount: 150_000,
          currency: 'YER',
          description: l10n.debt,
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        Transaction(
          id: UuidUtil.generate(),
          contactId: previewContactId,
          type: TransactionType.payment,
          amount: 50_000,
          currency: 'YER',
          description: l10n.payment,
          transactionDate: now.subtract(const Duration(days: 2)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      overlayCtrl.update(0.45, l10n.pdfBuildingLayout);
      final pdfBytes = await PdfGenerator.generateContactStatement(
        contact: contact,
        contactBalance: balance,
        transactions: transactions,
        isRtl: isRtl,
        applicationName: l10n.appTitle,
        labelStatement: l10n.statement,
        labelContactName: l10n.name,
        labelGeneratedOn: l10n.generatedOn,
        labelTotalDebt: l10n.totalDebt,
        labelTotalPayment: l10n.totalPayment,
        labelNetBalance: l10n.netBalance,
        labelDate: l10n.date,
        labelDetails: l10n.statementDetails,
        labelDebt: l10n.debt,
        labelPayment: l10n.payment,
        labelRunningBalance: l10n.runningBalance,
        labelCurrency: l10n.currency,
        labelPage: l10n.page,
        msgPreparing: l10n.pdfPreparingData,
        msgGrouping: l10n.pdfGroupingTransactions,
        msgBuilding: l10n.pdfBuildingLayout,
        msgRendering: l10n.pdfRendering,
        onProgress: overlayCtrl.update,
        merchantProfile: draft,
      );

      overlayCtrl.complete(l10n.pdfComplete);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      overlayCtrl.dismiss();

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => _BrandingPdfPreviewScreen(
            title: l10n.merchantBrandingPreviewPdf,
            pdfBytes: pdfBytes,
          ),
        ),
      );
    } on Object catch (error) {
      overlayCtrl.dismiss();
      if (!mounted) {
        return;
      }
      unawaited(AppBottomSheet.showError(context, error: error));
    } finally {
      if (mounted) {
        setState(() => _isPreviewingPdf = false);
      }
    }
  }

  Future<Uint8List?> _loadLogoBytes(String path) async {
    try {
      return await File(path).readAsBytes();
    } on Object {
      return null;
    }
  }

  bool _draftHasName() => _storeNameController.text.trim().isNotEmpty;

  bool _draftHasPhone() => _composeStorePhone() != null;

  String _draftPhoneDisplay() =>
      _formatPhoneDisplay(_composeStorePhone());

  Widget _buildReadMode({
    required AppLocalizations l10n,
    required bool isDark,
    required MerchantProfile? profile,
    required bool hasLogo,
    required String? logoPath,
    required bool isLocked,
    required bool isMutating,
  }) {
    final storeName = profile?.storeName.trim().isNotEmpty == true
        ? profile!.storeName.trim()
        : _storeNameController.text.trim();
    final phoneDisplay = _formatPhoneDisplay(
      profile?.storePhone ?? _composeStorePhone(),
    );

    return Center(
      key: const ValueKey<String>('merchant_read_mode'),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.pagePaddingH,
          AppDimensions.spacingLg,
          AppDimensions.pagePaddingH,
          AppDimensions.spacingXxl,
        ),
        child: Column(
          children: [
            StoreIdentityPassport(
              storeName: storeName,
              phoneDisplay: phoneDisplay,
              isDark: isDark,
              hasLogo: hasLogo,
              logoPath: logoPath,
              profile: profile,
              loadLogoBytes: _loadLogoBytes,
              hasName: storeName.isNotEmpty,
              hasPhone: phoneDisplay != '—',
              onTap: isMutating ? null : _enterEditMode,
            ),
            const Gap(AppDimensions.spacing4xl),
            FadeSlideTransition(
              delay: const Duration(milliseconds: 120),
              child: DaftarButton(
                label: l10n.merchantBrandingPreviewPdf,
                variant: DaftarButtonVariant.secondary,
                icon: Icons.picture_as_pdf_outlined,
                isLoading: _isPreviewingPdf,
                isExpanded: true,
                onPressed: isLocked || isMutating
                    ? null
                    : () => unawaited(
                          _onPreviewPdf(
                            isLocked: isLocked,
                            persisted: profile,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditMode({
    required AppLocalizations l10n,
    required bool isDark,
    required MerchantProfile? profile,
    required bool hasLogo,
    required String? logoPath,
    required bool isLocked,
    required bool isMutating,
    required double bottomPadding,
  }) {
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final draftName = _storeNameController.text;
    final draftPhone = _draftPhoneDisplay();

    return ListView(
      key: const ValueKey<String>('merchant_edit_mode'),
      padding: EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        AppDimensions.spacingXl,
        AppDimensions.pagePaddingH,
        AppDimensions.spacingXxl + bottomPadding,
      ),
      children: [
        Text(
          l10n.merchantBrandingLivePreview,
          style: AppTextStyles.labelMedium.copyWith(
            color: inkMuted,
            letterSpacing: 0.4,
          ),
        ).animate().fadeIn(duration: AppDimensions.animationMedium),
        const Gap(AppDimensions.spacingMd),
        StoreIdentityPassport(
          storeName: draftName,
          phoneDisplay: draftPhone,
          isDark: isDark,
          hasLogo: hasLogo,
          logoPath: logoPath,
          profile: profile,
          loadLogoBytes: _loadLogoBytes,
          hasName: _draftHasName(),
          hasPhone: _draftHasPhone(),
          compact: true,
          animate: false,
        ),
        const Gap(AppDimensions.spacingXxl),
        StoreIdentityCompletionRail(
          hasName: _draftHasName(),
          hasPhone: _draftHasPhone(),
          hasLogo: hasLogo,
        )
            .animate()
            .fadeIn(
              delay: const Duration(milliseconds: 60),
              duration: AppDimensions.animationMedium,
            ),
        const Gap(AppDimensions.spacing4xl),
        if (!isLocked)
          DaftarCard(
          variant: DaftarCardVariant.compact,
          padding: const EdgeInsetsDirectional.all(AppDimensions.spacingXl),
          child: Column(
            children: [
              StoreLogoSeal(
                diameter: 96,
                isDark: isDark,
                hasLogo: hasLogo,
                logoPath: logoPath,
                profile: profile,
                loadLogoBytes: _loadLogoBytes,
                tappable: !isMutating,
                showCameraBadge: true,
                onTap: isMutating
                    ? null
                    : () => unawaited(_onPickLogo(isLocked: isLocked)),
              ),
              const Gap(AppDimensions.spacingSm),
              Text(
                l10n.merchantBrandingUploadLogo,
                style: AppTextStyles.labelMedium.copyWith(color: inkMuted),
              ),
              if (hasLogo) ...[
                const Gap(AppDimensions.spacingXs),
                DaftarButton(
                  label: l10n.merchantBrandingRemoveLogo,
                  variant: DaftarButtonVariant.tertiary,
                  size: DaftarButtonSize.small,
                  onPressed: isLocked || isMutating
                      ? null
                      : () => unawaited(
                            _onRemoveLogo(
                              isLocked: isLocked,
                              hasLogo: hasLogo,
                            ),
                          ),
                ),
              ],
            ],
          ),
        )
            .animate()
            .fadeIn(
              delay: const Duration(milliseconds: 100),
              duration: AppDimensions.animationMedium,
            )
            .slideY(begin: 0.04, end: 0),
        const Gap(AppDimensions.spacingXxl),
        DaftarTextField(
          controller: _storeNameController,
          focusNode: _storeNameFocus,
          label: l10n.merchantBrandingStoreName,
          prefixIcon: Icons.storefront_outlined,
          enabled: !isMutating,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          errorText: _storeNameError,
          onSubmitted: (_) =>
              FocusScope.of(context).requestFocus(_phoneFocus),
        )
            .animate()
            .fadeIn(
              delay: const Duration(milliseconds: 140),
              duration: AppDimensions.animationMedium,
            )
            .slideY(begin: 0.04, end: 0),
        const Gap(AppDimensions.spacingXxl),
        DaftarTextField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          label: l10n.phoneNumber,
          prefixIcon: Icons.call_outlined,
          enabled: !isMutating,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          textDirection: TextDirection.ltr,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'[0-9٠-٩+\s\-()]'),
            ),
          ],
        )
            .animate()
            .fadeIn(
              delay: const Duration(milliseconds: 180),
              duration: AppDimensions.animationMedium,
            )
            .slideY(begin: 0.04, end: 0),
        const Gap(AppDimensions.spacingXxl),
        DaftarButton(
          label: l10n.merchantBrandingPreviewPdf,
          variant: DaftarButtonVariant.secondary,
          icon: Icons.picture_as_pdf_outlined,
          isLoading: _isPreviewingPdf,
          isExpanded: true,
          onPressed: isLocked || isMutating
              ? null
              : () => unawaited(
                    _onPreviewPdf(
                      isLocked: isLocked,
                      persisted: profile,
                    ),
                  ),
        )
            .animate()
            .fadeIn(
              delay: const Duration(milliseconds: 220),
              duration: AppDimensions.animationMedium,
            ),
        const Gap(AppDimensions.spacingXxl),
        DaftarButton(
          label: l10n.saveChanges,
          isExpanded: true,
          isLoading: isMutating,
          onPressed: isMutating
              ? null
              : () => unawaited(_onSave()),
        )
            .animate()
            .fadeIn(
              delay: const Duration(milliseconds: 260),
              duration: AppDimensions.animationMedium,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final isLocked = !_isPremium(ref);
    final profileAsync = ref.watch(merchantProfileProvider);
    final mutation = ref.watch(merchantProfileControllerProvider);
    final isMutating = mutation.isLoading;

    ref.listen<AsyncValue<void>>(merchantProfileControllerProvider, (
      previous,
      next,
    ) {
      if (next.hasError && next.error is Failure) {
        _handleControllerError(next.error! as Failure);
        ref.read(merchantProfileControllerProvider.notifier).reset();
      }
    });

    final persisted = profileAsync.asData?.value;
    if (persisted != null) {
      _hydrateFromProfile(persisted);
    }

    final logoPath = persisted?.logoPath;
    final hasLogo = logoPath != null &&
        logoPath.isNotEmpty &&
        File(logoPath).existsSync();
    final hasSavedProfile =
        persisted != null && persisted.storeName.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surface0 : AppColors.surface0Light,
      appBar: AppBar(
        title: Text(l10n.merchantBrandingScreenTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isEditing && hasSavedProfile)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.merchantBrandingEditIdentity,
              onPressed: isMutating ? null : _enterEditMode,
            ),
          if (_isEditing && hasSavedProfile)
            TextButton(
              onPressed: isMutating
                  ? null
                  : () => _cancelEdit(persisted),
              child: Text(l10n.backupRestoreCancel),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLocked)
              const Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppDimensions.pagePaddingH,
                  AppDimensions.spacingMd,
                  AppDimensions.pagePaddingH,
                  0,
                ),
                child: FadeSlideTransition(
                  child: MerchantBrandingUpgradeBanner(),
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                    duration: AppDimensions.animationMedium,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slide,
                          child: child,
                        ),
                      );
                    },
                    child: _isEditing
                        ? _buildEditMode(
                            l10n: l10n,
                            isDark: isDark,
                            profile: persisted,
                            hasLogo: hasLogo,
                            logoPath: logoPath,
                            isLocked: isLocked,
                            isMutating: isMutating,
                            bottomPadding: context.bottomPadding,
                          )
                        : _buildReadMode(
                            l10n: l10n,
                            isDark: isDark,
                            profile: persisted,
                            hasLogo: hasLogo,
                            logoPath: logoPath,
                            isLocked: isLocked,
                            isMutating: isMutating,
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandingPdfPreviewScreen extends StatelessWidget {
  const _BrandingPdfPreviewScreen({
    required this.title,
    required this.pdfBytes,
  });

  final String title;
  final Uint8List pdfBytes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surface0 : AppColors.surface0Light,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfPreviewPageDecoration: BoxDecoration(
          color: isDark ? AppColors.surface2 : AppColors.surface1Light,
          border: Border.all(
            color: isDark
                ? AppColors.borderSubtle
                : AppColors.borderSubtleLight,
            width: AppDimensions.dividerThickness,
          ),
        ),
      ),
    );
  }
}
