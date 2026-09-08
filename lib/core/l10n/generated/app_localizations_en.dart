// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Daftar';

  @override
  String get greeting => 'Welcome';

  @override
  String get home => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get netBalance => 'Net balance';

  @override
  String get totalDebt => 'Total debt';

  @override
  String get totalCredit => 'Total credit';

  @override
  String get tapToExpand => 'Tap to expand';

  @override
  String get tapToCollapse => 'Tap to collapse';

  @override
  String get tapToSeeBreakdown => 'Tap to see breakdown';

  @override
  String get hideBreakdown => 'Hide breakdown';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get appearance => 'Appearance';

  @override
  String get homeScreenSubtitle =>
      'Use the buttons below to open the placeholder detail screens.';

  @override
  String get openLedgerDetails => 'Open Ledger Details';

  @override
  String get openContactDetails => 'Open Contact Details';

  @override
  String get settingsScreenSubtitle =>
      'Personalize Daftar — language, appearance, and workspace.';

  @override
  String get settingsGroupPreferences => 'Preferences';

  @override
  String get settingsGroupAccountSecurity => 'Account & Security';

  @override
  String get settingsGroupWorkspace => 'Workspace';

  @override
  String get settingsGroupPrivacy => 'Privacy';

  @override
  String get settingsGroupSupport => 'Support';

  @override
  String get settingsSystemTheme => 'System';

  @override
  String get settingsDefaultCurrency => 'Default currency';

  @override
  String get settingsMultiCurrency => 'Enable Multi-Currency';

  @override
  String get settingsMultiCurrencySubtitle =>
      'Choose a currency for each new contact or transaction. When off, everything uses your default currency.';

  @override
  String get settingsSwipeToDelete => 'Swipe to delete';

  @override
  String get settingsSwipeToDeleteSubtitle =>
      'Swipe list items to delete quickly. When off, use the menu on each row instead.';

  @override
  String get settingsTtsMuted => 'Mute spoken read-back';

  @override
  String get settingsTtsMutedSubtitle =>
      'Turn off on-device speech for confirm cards and the closing report. Amounts on screen stay visible.';

  @override
  String get settingsDemoArchitectureHud => 'Show agent architecture';

  @override
  String get settingsDemoArchitectureHudSubtitle =>
      'For demos: model, tools, HITL path, and round-trip time. Not a product tour.';

  @override
  String get settingsCalleAllowDial => 'Allow CALL-E outbound';

  @override
  String get settingsCalleAllowDialSubtitle =>
      'On-device gate for Confirm & Call. The APK build flag and Cloud Run must also be on.';

  @override
  String architectureHudSemantics(String step) {
    return 'Agent architecture instrument, step $step';
  }

  @override
  String architectureHudRouting(String model) {
    return 'Cloud Run · $model';
  }

  @override
  String get architectureHudLatencyPending => '…';

  @override
  String get architectureHudScopeCapture => 'Capture';

  @override
  String get architectureHudScopeClose => 'Close';

  @override
  String get architectureHudScopeAsk => 'Ask';

  @override
  String architectureHudToolScope(String scope, String tools) {
    return '$scope · $tools';
  }

  @override
  String get architectureHudHitlPropose => 'Propose';

  @override
  String get architectureHudHitlConfirm => 'Confirm';

  @override
  String get architectureHudHitlCommit => 'Commit';

  @override
  String get architectureHudHitlRank => 'Rank';

  @override
  String architectureHudPendingRecorded(int pending, int recorded) {
    return 'Pending $pending · Recorded $recorded';
  }

  @override
  String architectureHudSkipped(int skipped) {
    return 'Skipped $skipped';
  }

  @override
  String architectureHudModel(String model) {
    return 'Model $model';
  }

  @override
  String architectureHudTool(String name) {
    return 'Tool $name';
  }

  @override
  String architectureHudLatency(int ms) {
    return '$ms ms';
  }

  @override
  String architectureHudCorrelation(String id) {
    return 'Ref $id';
  }

  @override
  String architectureHudEmailSent(String id) {
    return 'Sent · $id';
  }

  @override
  String architectureHudCallChip(String id, String status) {
    return 'Call · $id · $status';
  }

  @override
  String architectureHudCallId(String id) {
    return 'Call · $id';
  }

  @override
  String architectureHudCallStatusOnly(String status) {
    return 'Call · $status';
  }

  @override
  String get architectureHudCallPlanned => 'planned';

  @override
  String get architectureHudCallRinging => 'ringing';

  @override
  String get architectureHudCallCompleted => 'completed';

  @override
  String get architectureHudCallFailed => 'failed';

  @override
  String get contactDeleteConfirmTitle => 'Are you sure?';

  @override
  String get contactDeleteConfirmBody =>
      'This will permanently remove this contact and all associated transactions from your ledger.';

  @override
  String get contactDeleteConfirmAction => 'Delete contact';

  @override
  String get ledgerDeleteConfirmTitle => 'Are you sure?';

  @override
  String get ledgerDeleteConfirmBody =>
      'This will remove this ledger along with all accounts and transactions inside it.';

  @override
  String get ledgerDeleteConfirmAction => 'Delete ledger';

  @override
  String get settingsMerchantBranding => 'Merchant branding';

  @override
  String get settingsMerchantBrandingSubtitle =>
      'Logo, store name, and branded PDF statements';

  @override
  String get settingsPremium => 'Plan & activation';

  @override
  String get settingsPremiumSubtitle => 'View plan, redeem code, compare tiers';

  @override
  String get settingsGoogleAccount => 'Google account';

  @override
  String get settingsGoogleAccountSignInPrompt => 'Sign in for Drive backup';

  @override
  String get settingsAnalytics => 'Usage analytics';

  @override
  String get settingsAnalyticsSubtitle =>
      'Help improve Daftar with anonymous usage data';

  @override
  String get settingsAbout => 'About Daftar';

  @override
  String settingsVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get settingsRateApp => 'Rate Daftar';

  @override
  String get settingsContactSupport => 'Contact support';

  @override
  String get settingsSelectLanguage => 'Language';

  @override
  String get settingsSelectTheme => 'Theme';

  @override
  String get settingsSelectCurrency => 'Currency';

  @override
  String get settingsProBadgeLabel => 'Pro';

  @override
  String get settingsSaveFailed => 'Could not save settings';

  @override
  String get settingsStoreLaunchError => 'Could not open the store';

  @override
  String get settingsVaultTrustLabel => 'Vault trust';

  @override
  String get settingsVaultTrustHigh => 'Fully protected';

  @override
  String get settingsVaultTrustMedium => 'Partially protected';

  @override
  String get settingsVaultTrustLow => 'Needs attention';

  @override
  String get settingsGroupVault => 'Vault health';

  @override
  String get settingsSecurityAdvanced => 'Advanced security';

  @override
  String get settingsCommandSecurity => 'Security';

  @override
  String get settingsCommandBackup => 'Backup';

  @override
  String get settingsCommandImport => 'Import';

  @override
  String get settingsCommandAccount => 'Account';

  @override
  String get settingsAboutDescription =>
      'Daftar is your offline-first digital ledger — built for merchants who need trust, clarity, and control over every debt and payment.';

  @override
  String get settingsAboutOfflineFirst => 'Works fully offline';

  @override
  String get settingsAboutArabicFirst => 'Arabic-first design';

  @override
  String get settingsAboutFinancialGrade => 'Financial-grade integrity';

  @override
  String get merchantBrandingScreenTitle => 'Merchant branding';

  @override
  String get merchantBrandingScreenSubtitle =>
      'Customize PDF statements with your store identity';

  @override
  String get merchantBrandingUpgradeTitle =>
      'Branded statements are a Pro feature';

  @override
  String get merchantBrandingUpgradeSubtitle =>
      'Upgrade to add your logo and store name to every PDF export.';

  @override
  String get merchantBrandingUpgradeCta => 'View plans';

  @override
  String get merchantBrandingStoreName => 'Store name';

  @override
  String get merchantBrandingUploadLogo => 'Upload logo';

  @override
  String get merchantBrandingRemoveLogo => 'Remove logo';

  @override
  String get merchantBrandingPreviewPdf => 'Preview PDF';

  @override
  String get merchantBrandingSaveSuccess => 'Branding saved';

  @override
  String get merchantBrandingLogoRemoved => 'Logo removed';

  @override
  String get merchantBrandingPickSourceTitle => 'Add store logo';

  @override
  String get merchantBrandingPickCamera => 'Camera';

  @override
  String get merchantBrandingPickGallery => 'Photo library';

  @override
  String get merchantBrandingCropTitle => 'Adjust logo';

  @override
  String get merchantBrandingCropHint =>
      'Pinch to zoom and drag to position your logo';

  @override
  String get merchantBrandingCropConfirm => 'Use logo';

  @override
  String get merchantBrandingSaveProfileFirst =>
      'Save your store name before adding a logo';

  @override
  String get merchantBrandingPreviewContactName => 'Sample customer';

  @override
  String get merchantBrandingCountryYemen => 'Yemen';

  @override
  String get merchantBrandingCountrySaudi => 'Saudi Arabia';

  @override
  String get merchantBrandingTapToEdit => 'Tap to edit your store identity';

  @override
  String get merchantBrandingEditIdentity => 'Edit identity';

  @override
  String get merchantBrandingLivePreview => 'Live preview';

  @override
  String get merchantBrandingStatementPreview => 'How it appears on statements';

  @override
  String get merchantBrandingCompletionTitle => 'Identity checklist';

  @override
  String get merchantBrandingStepPhone => 'Phone';

  @override
  String get merchantBrandingStepLogo => 'Logo';

  @override
  String get merchantBrandingIdentityComplete => 'Identity complete';

  @override
  String get merchantBrandingIdentityIncomplete =>
      'Complete your identity for branded PDFs';

  @override
  String get accountManagementTitle => 'Google account';

  @override
  String get accountManagementSubtitle =>
      'Manage the account used for Google Drive backup';

  @override
  String get accountManagementSignOut => 'Sign out';

  @override
  String get accountManagementSwitchAccount => 'Switch account';

  @override
  String get accountManagementSignOutConfirmTitle => 'Sign out';

  @override
  String get accountManagementSignOutConfirmBody =>
      'Google Drive backups from this account will no longer be accessible from this app. Your local data will not be affected. You can sign in with the same or different account later.';

  @override
  String get accountManagementSignOutConfirmCta => 'Sign out';

  @override
  String get accountManagementStatusConnected => 'Account linked';

  @override
  String get accountManagementStatusConnectedSubtitle =>
      'Cloud backup is available for this Google account';

  @override
  String get accountManagementStatusPartialSubtitle =>
      'Signed in — create a backup to sync with Google Drive';

  @override
  String get accountManagementStatusDisconnected => 'No account linked';

  @override
  String get accountManagementStatusDisconnectedSubtitle =>
      'Sign in to enable encrypted cloud backup on Google Drive';

  @override
  String get accountManagementIdentityRing => 'Sign-in';

  @override
  String get accountManagementCloudRing => 'Cloud';

  @override
  String get accountManagementTrustLocalData =>
      'Your ledger stays on this device — signing out never deletes local data';

  @override
  String get accountManagementTrustDriveScope =>
      'Google access is limited to your private Daftar backup folder';

  @override
  String get accountManagementActionsTitle => 'Account actions';

  @override
  String get accountManagementManageBackup => 'Manage backups';

  @override
  String get accountManagementManageBackupSubtitle =>
      'View local copies and Drive sync status';

  @override
  String get accountManagementConnectedBadge => 'Connected';

  @override
  String get accountManagementMigrationRelinkTitle =>
      'Re-link your Google account';

  @override
  String get accountManagementMigrationRelinkBody =>
      'A previous sign-in was detected on this device. Sign in again to restore encrypted cloud backup — your local ledger is safe.';

  @override
  String get accountManagementNeedsReauthTitle => 'Session expired';

  @override
  String get accountManagementNeedsReauthBody =>
      'Your Google sign-in has expired or was revoked. Restore access to resume cloud backup.';

  @override
  String get accountManagementRestoreAccess => 'Restore access';

  @override
  String get currentLanguage => 'Current Language';

  @override
  String get currentTheme => 'Current Theme';

  @override
  String get ledgerDetailTitle => 'Ledger Details';

  @override
  String get contactDetailTitle => 'Contact Details';

  @override
  String get contactDetails => 'Contact Details';

  @override
  String get ledgerDetailSubtitle =>
      'This placeholder screen will show ledger data later.';

  @override
  String get contactDetailSubtitle =>
      'This placeholder screen will show contact data later.';

  @override
  String get ledgerIdLabel => 'Ledger ID';

  @override
  String get contactIdLabel => 'Contact ID';

  @override
  String get myLedgers => 'My Ledgers';

  @override
  String ledgerAccountCount(int count) {
    return '$count accounts';
  }

  @override
  String get searchHint => 'Search by name or phone';

  @override
  String get searchContacts => 'Search contacts...';

  @override
  String get sort => 'Sort';

  @override
  String get sortBy => 'Sort By';

  @override
  String get sortByName => 'Name';

  @override
  String get sortByBalance => 'Balance';

  @override
  String get sortByRecent => 'Most Recent';

  @override
  String get filterAll => 'All';

  @override
  String get filterDebt => 'Debt';

  @override
  String get filterCredit => 'Credit';

  @override
  String get filterSettled => 'Settled';

  @override
  String get noSearchResults => 'No contacts match your search';

  @override
  String get noFilterResults => 'No contacts in this category';

  @override
  String get editLedger => 'Edit Ledger';

  @override
  String get ledgerName => 'Ledger Name';

  @override
  String get selectColor => 'Select Color';

  @override
  String get selectIcon => 'Select Icon';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get delete => 'Delete';

  @override
  String get undo => 'Undo';

  @override
  String get contactDeleted => 'Contact deleted';

  @override
  String get addContact => 'Add Account';

  @override
  String get name => 'Name';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get contactEmailHint => 'Email (optional)';

  @override
  String get contactEmailInvalid => 'Enter a valid email or leave it empty.';

  @override
  String get importFromContacts => 'Import from Contacts';

  @override
  String get notes => 'Notes';

  @override
  String get creditLimit => 'Credit Limit';

  @override
  String get selectCurrency => 'Select Currency';

  @override
  String get save => 'Save';

  @override
  String get editContact => 'Edit Contact';

  @override
  String get openWhatsApp => 'Open WhatsApp';

  @override
  String get call => 'Call';

  @override
  String get callLaunchError => 'Could not open the Phone app';

  @override
  String get whatsappLaunchError => 'Could not open WhatsApp';

  @override
  String get invalidAmount => 'Invalid amount';

  @override
  String transactionsCount(int count) {
    return '$count Transactions';
  }

  @override
  String get emptyStateTitle => 'Nothing here yet';

  @override
  String get noTransactionsYet => 'No Transactions Yet';

  @override
  String get emptyStateSubtitle =>
      'Add your first item and it will appear here.';

  @override
  String get emptyStateAction => 'Add New';

  @override
  String get archiveVaultTitle => 'Archive Vault';

  @override
  String get archiveVaultSubtitle =>
      'Frozen ledgers — read-only until restored';

  @override
  String get archivedTotalLabel => 'Archived Total';

  @override
  String get archivedLedgerReadOnlyBadge => 'Read-only';

  @override
  String get unarchiveLedgerAction => 'Restore';

  @override
  String get unarchiveLedgerSuccess => 'Ledger restored to your workspace';

  @override
  String get archiveVaultEmptyTitle => 'Vault is empty';

  @override
  String get archiveVaultEmptySubtitle =>
      'Archived ledgers appear here, frozen in time with their balances preserved.';

  @override
  String get contactArchivedReadOnlyTitle =>
      'This contact is in an archived ledger';

  @override
  String get contactArchivedReadOnlySubtitle =>
      'Data is read-only. You can view transactions and export statements.';

  @override
  String get ledgerArchivedReadOnlyTitle => 'Vaulted ledger — read-only';

  @override
  String get ledgerArchivedReadOnlySubtitle =>
      'This ledger is frozen in the Archive Vault. Balances are preserved; new entries are disabled.';

  @override
  String get ledgerOptionsTitle => 'Ledger options';

  @override
  String get archiveLedgerAction => 'Archive ledger';

  @override
  String get financialCloseTitle => 'Archive ledger';

  @override
  String get financialCloseSubtitle =>
      'Tuck this ledger into your Vault to keep your workspace focused.';

  @override
  String get financialCloseEducationTitle => 'What happens when you archive?';

  @override
  String get financialCloseEducationBody =>
      'Archiving hides this ledger from your daily workspace. Every balance and transaction stays safe—and you can restore it anytime from Archive Vault.';

  @override
  String get financialCloseArchiveOnly => 'Archive to Vault';

  @override
  String get financialCloseArchiveOnlyDescription =>
      'Freeze this ledger as-is. Nothing moves; everything stays readable in the Vault.';

  @override
  String get carryForwardToggleLabel => 'Move balances first';

  @override
  String get carryForwardToggleDescription =>
      'Copy active debts and credits into another ledger so you can keep trading without starting over.';

  @override
  String get carryForwardTargetPickerLabel => 'Continue in';

  @override
  String get carryForwardTargetPickerHint =>
      'Select the ledger that receives your balances';

  @override
  String get carryForwardCreateNewLedger => 'Start a fresh ledger';

  @override
  String get carryForwardPreviewTitle => 'Preview';

  @override
  String carryForwardPreviewContacts(int count) {
    return '$count contacts with balances';
  }

  @override
  String carryForwardPreviewTransactions(int count) {
    return '$count opening-balance entries';
  }

  @override
  String get openingBalanceItemName => 'Opening Balance';

  @override
  String carryForwardOpeningBalanceNote(String ledgerName) {
    return 'Opening balance rolled over from $ledgerName';
  }

  @override
  String get carryForwardSuccess => 'Ledger sealed in Vault';

  @override
  String get carryForwardSuccessBody =>
      'Your records are frozen safely. Restore anytime from Archive Vault.';

  @override
  String get carryForwardConfirmTitle => 'You\'re in control';

  @override
  String get carryForwardConfirmBody =>
      'This ledger moves to the Vault as read-only. Restore it whenever you\'re ready—your data is never lost.';

  @override
  String get confirmArchive => 'Seal & archive';

  @override
  String get archiveCeremonySealing => 'Sealing your ledger…';

  @override
  String get archiveCeremonyTransferring => 'Securing your balances…';

  @override
  String get contactSearchArchivedBadge => 'Archived';

  @override
  String get homeArchiveVaultEntry => 'Open Archive Vault';

  @override
  String get limitWarningTitle => 'Limit approaching';

  @override
  String get limitWarningSubtitle =>
      'You\'re getting close to the free-tier limit.';

  @override
  String get limitReachedTitle => 'Limit reached';

  @override
  String get limitReachedSubtitle => 'Upgrade to continue adding more items.';

  @override
  String get maxLedgersReached =>
      'Sorry, you\'ve reached the maximum limit (one ledger) in the free version.';

  @override
  String get premiumUpgradeBannerTitle =>
      'You\'re nearing your Free plan limit';

  @override
  String premiumUpgradeBannerUsage(
    Object current,
    Object max,
    Object resource,
  ) {
    return '$current of $max $resource';
  }

  @override
  String get premiumUpgradeResourceLedgers => 'ledgers';

  @override
  String get premiumUpgradeResourceContacts => 'contacts';

  @override
  String get premiumUpgradeResourceTransactions => 'transactions';

  @override
  String get premiumUpgradeLedgers =>
      'Add unlimited ledgers and keep every account organized in one place.';

  @override
  String get premiumUpgradeContacts =>
      'Track unlimited customers without deleting older records.';

  @override
  String get premiumUpgradeTransactions =>
      'Record every sale and payment — no ceiling on your ledger history.';

  @override
  String get premiumUpgradeSubtitle =>
      'Unlock unlimited workspace and professional PDF branding.';

  @override
  String get premiumUpgradeCta => 'Explore Pro';

  @override
  String get premiumUpgradeBannerHide => 'Hide';

  @override
  String get premiumUpgradeBannerHiddenToast =>
      'Hidden. You can upgrade anytime from Settings.';

  @override
  String get addTransaction => 'Add Transaction';

  @override
  String get editTransaction => 'Edit Transaction';

  @override
  String get debt => 'Debt';

  @override
  String get payment => 'Payment';

  @override
  String get amount => 'Amount';

  @override
  String get itemName => 'Item Name';

  @override
  String get descriptionOptional => 'Note (optional)';

  @override
  String get date => 'Date';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisWeek => 'This Week';

  @override
  String get saveTransaction => 'Save Transaction';

  @override
  String get amountRequired => 'Amount is required';

  @override
  String get transactionSaved => 'Transaction saved successfully';

  @override
  String get creditLimitWarning =>
      'Warning: Account is approaching its credit limit.';

  @override
  String get creditLimitExceeded =>
      'Alert: Account has exceeded its credit limit!';

  @override
  String get creditLimitCallSheetTitle =>
      'Call to say no new goods until a payment?';

  @override
  String creditLimitCallSheetBody(
    String contactName,
    String outstanding,
    String limit,
  ) {
    return '$contactName owes $outstanding against a $limit credit limit.';
  }

  @override
  String get creditLimitCallSheetPrepare => 'Prepare the call';

  @override
  String get creditLimitCallSheetNotNow => 'Not now';

  @override
  String get creditLimitCallSheetOutstanding => 'Outstanding';

  @override
  String get creditLimitCallSheetLimit => 'Credit limit';

  @override
  String get creditLimitCallSessionTitle => 'Credit-limit call';

  @override
  String get creditLimitCallSessionInProgress => 'Call in progress';

  @override
  String get creditLimitCallSessionPreparing => 'Preparing call…';

  @override
  String get creditLimitCallSessionSummaryTitle => 'Call summary';

  @override
  String get creditLimitCallSessionDone => 'Done';

  @override
  String get creditLimitCallSessionViewCall => 'View call';

  @override
  String get creditLimitCallSessionResumeChip => 'Call in progress';

  @override
  String creditLimitCallSessionRunId(String id) {
    return 'Run · $id';
  }

  @override
  String get collectionsDeskCreditLimitSubtitle =>
      'Credit limit reached — confirm outreach for this account.';

  @override
  String get errorCreditLimitNoOutreach =>
      'This account has no phone or email we can use for outreach.';

  @override
  String get notificationWarningTitle => 'Credit Alert';

  @override
  String notificationWarningBody(String contactName) {
    return 'Account $contactName has exceeded 80% of its credit limit.';
  }

  @override
  String notificationExceededBody(String contactName) {
    return 'Warning: Account $contactName has exceeded its credit limit!';
  }

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get transactionsError => 'Failed to load transactions';

  @override
  String get noLedgersYet => 'No Ledgers Yet';

  @override
  String get noLedgersSubtitle =>
      'Create your first ledger to start tracking debts.';

  @override
  String get addLedger => 'Add Ledger';

  @override
  String get noContactsYet => 'No Contacts Yet';

  @override
  String get noContactsSubtitle => 'Add your first contact to this ledger.';

  @override
  String get loadingError => 'Something went wrong';

  @override
  String get ledgerDeleted => 'Ledger deleted';

  @override
  String get transactionDeleted => 'Transaction deleted';

  @override
  String get retry => 'Retry';

  @override
  String get statement => 'Statement';

  @override
  String get statementDetails => 'Details';

  @override
  String get type => 'Type';

  @override
  String get description => 'Description';

  @override
  String get totalPayment => 'Total payment';

  @override
  String get generatedOn => 'Generated on';

  @override
  String get runningBalance => 'Running balance';

  @override
  String get page => 'Page';

  @override
  String get currency => 'Currency';

  @override
  String get exportStatement => 'Export Statement';

  @override
  String get generatingPdf => 'Generating PDF...';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get pdfFetchFailed => 'Couldn\'t load transactions';

  @override
  String get pdfRenderFailed => 'Couldn\'t generate the PDF';

  @override
  String get pdfSaveFailed => 'Couldn\'t save the file';

  @override
  String get pdfShareFailed => 'Couldn\'t open the share sheet';

  @override
  String get pdfTimeout => 'Export is taking too long. Please try again.';

  @override
  String get pdfSavedLocally => 'Statement saved to device';

  @override
  String get pdfPreparingData => 'Preparing data...';

  @override
  String get pdfGroupingTransactions => 'Grouping transactions...';

  @override
  String get pdfBuildingLayout => 'Building layout...';

  @override
  String get pdfRendering => 'Rendering document...';

  @override
  String get pdfComplete => 'Complete!';

  @override
  String get pdfSaving => 'Saving to device...';

  @override
  String get shareStatement => 'Share Statement';

  @override
  String statementShareSubject(String contactName) {
    return 'Statement for $contactName';
  }

  @override
  String get exportStatementDateRange => 'Export a date range';

  @override
  String get exportLedgerSummary => 'Export Ledger Summary';

  @override
  String get ledgerSummaryReport => 'Ledger Summary Report';

  @override
  String get totalLedgerBalance => 'Total ledger balance';

  @override
  String get rowNumber => '#';

  @override
  String get pdfListingContacts => 'Listing accounts...';

  @override
  String get pdfGroupingAccounts => 'Grouping accounts by currency...';

  @override
  String get shareLedgerSummary => 'Share Ledger Summary';

  @override
  String ledgerSummaryShareSubject(String ledgerName) {
    return 'Ledger summary — $ledgerName';
  }

  @override
  String get statementPeriodLabel => 'Period';

  @override
  String get pdfNoTransactionsInRange => 'No transactions in that period.';

  @override
  String get csvImportTitle => 'Import CSV';

  @override
  String get csvImportSubtitle =>
      'Match CSV columns to دفتر fields, verify encoding with the preview, then import into this ledger.';

  @override
  String get csvImportSelectFile => 'Select CSV file';

  @override
  String get csvImportEncoding => 'Text encoding';

  @override
  String get csvEncodingAuto => 'Auto (recommended)';

  @override
  String get csvEncodingUtf8 => 'UTF-8';

  @override
  String get csvEncodingWindows1256 => 'Windows Arabic (1256)';

  @override
  String get csvImportMappingSection => 'Column mapping';

  @override
  String get csvImportPreviewSection => 'First rows preview';

  @override
  String get csvImportColumnHint => 'Choose CSV column';

  @override
  String get csvImportColumnNone => 'None';

  @override
  String get csvImportStart => 'Start import';

  @override
  String get csvImportProgressLabel => 'Importing rows…';

  @override
  String get csvImportSummaryTitle => 'Import summary';

  @override
  String get csvImportTotalRows => 'Total rows';

  @override
  String get csvImportSuccessLabel => 'Imported successfully';

  @override
  String get csvImportFailureLabel => 'Skipped rows';

  @override
  String get csvImportRowErrors => 'Row issues';

  @override
  String get csvImportAnotherFile => 'Import another file';

  @override
  String get csvImportFinish => 'Done';

  @override
  String get csvImportNoLedgerMessage =>
      'Open a ledger from Home or select one when only one exists — imports always attach to a ledger.';

  @override
  String get csvImportMappingIncompleteHint =>
      'Pick a CSV column for every required field.';

  @override
  String get csvImportReadFailed => 'Could not read that file.';

  @override
  String get csvImportEmptyFile => 'That CSV file is empty.';

  @override
  String get csvImportParseWorkerFailed => 'Could not parse the CSV file.';

  @override
  String get csvImportStructureFatalPrefix => 'CSV structure problem';

  @override
  String get csvImportBlockingFailureTitle => 'Import could not start';

  @override
  String get csvImportSelectedFileLabel => 'Selected file';

  @override
  String get csvImportDuplicatesSheetTitle => 'Existing contacts matched';

  @override
  String csvImportDuplicatesSheetBody(int count) {
    return 'We found $count contacts in your ledger that match rows in this file. Choose whether to merge new transactions into them or skip those rows.';
  }

  @override
  String get csvImportDuplicatesMergeRecommended =>
      'Merge transactions (recommended)';

  @override
  String get csvImportDuplicatesSkipLabel => 'Skip duplicates';

  @override
  String get csvImportDuplicatesCancelImport => 'Cancel import';

  @override
  String get csvImportPrefabProgressLabel => 'Checking file…';

  @override
  String get csvImportSkippedDuplicatesLabel => 'Duplicate rows skipped';

  @override
  String get csvImportStepFile => 'File';

  @override
  String get csvImportStepMapping => 'Mapping';

  @override
  String get csvImportStepImport => 'Import';

  @override
  String get csvImportStepDone => 'Done';

  @override
  String get csvImportRequiredFieldsLabel => 'Required fields';

  @override
  String get csvImportOptionalFieldsLabel => 'Optional fields';

  @override
  String get csvImportFileZoneHint =>
      'Tap to browse for a .csv export from your old ledger';

  @override
  String get csvImportReplaceFile => 'Choose a different file';

  @override
  String get csvImportTargetLedgerLabel => 'Import into';

  @override
  String get csvImportTargetLedgerHint =>
      'Accounts and transactions will be added to this ledger';

  @override
  String get csvImportChooseLedgerTitle => 'Choose ledger';

  @override
  String get csvImportNoLedgerSelected => 'Select a ledger to continue';

  @override
  String get backupTitle => 'Backup & Restore';

  @override
  String get backupStatusSafe => 'Your data is safe';

  @override
  String get backupStatusNoBackup => 'No backup found';

  @override
  String get backupStatusNoBackupSubtitle =>
      'Create a backup to protect your data.';

  @override
  String get backupLastBackup => 'Last backup';

  @override
  String get backupCreateNow => 'Create Backup Now';

  @override
  String get backupCreating => 'Creating backup…';

  @override
  String get backupSuccess => 'Backup created successfully';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get backupHistory => 'Backup History';

  @override
  String get backupNoHistory => 'No backups yet';

  @override
  String get backupShare => 'Share';

  @override
  String get backupRestore => 'Restore';

  @override
  String get backupDelete => 'Delete';

  @override
  String get backupDeleteConfirmTitle => 'Delete Backup?';

  @override
  String get backupDeleteConfirmBody =>
      'This will permanently remove the backup file from your device.';

  @override
  String get backupDeleteSuccess => 'Backup deleted';

  @override
  String get backupDeleteFailed => 'Failed to delete backup';

  @override
  String backupSizeBytes(int size) {
    return '$size bytes';
  }

  @override
  String backupSizeKb(String size) {
    return '$size KB';
  }

  @override
  String backupSizeMb(String size) {
    return '$size MB';
  }

  @override
  String get backupRestoreWarningTitle => '⚠ WARNING: DESTRUCTIVE ACTION';

  @override
  String get backupRestoreWarningBody =>
      'This will completely overwrite your current database. Any data added after this backup will be lost FOREVER. This action cannot be undone.';

  @override
  String get backupRestoreConfirm => 'I Understand — Restore';

  @override
  String get backupRestoreCancel => 'Cancel';

  @override
  String get backupRestoring => 'Restoring backup…';

  @override
  String get backupRestoreSuccess => 'Restore complete';

  @override
  String get backupRestoreSuccessBody =>
      'Your data has been restored. The app must restart to apply the changes.';

  @override
  String get backupRestoreRestartNow => 'Restart Now';

  @override
  String get backupRestoreFailed => 'Restore failed';

  @override
  String get backupRestoreFromFile => 'Restore from External File';

  @override
  String get backupReminderLabel => 'Auto-Backup Reminder';

  @override
  String get backupReminderOff => 'Off';

  @override
  String get backupReminderWeekly => 'Weekly';

  @override
  String get backupReminderMonthly => 'Monthly';

  @override
  String get backupShareSubject => 'Daftar Backup File';

  @override
  String get backupTrustEncrypted => 'Encrypted with AES-256 on your device';

  @override
  String get backupTrustDrivePrivate =>
      'Stored in your private Daftar folder on Google Drive — only you can access it.';

  @override
  String get backupRelativeJustNow => 'just now';

  @override
  String backupRelativeMinutes(int count) {
    return '${count}m ago';
  }

  @override
  String backupRelativeHours(int count) {
    return '${count}h ago';
  }

  @override
  String get backupRelativeYesterday => 'Yesterday';

  @override
  String backupRelativeDays(int count) {
    return '$count days ago';
  }

  @override
  String get backupHealthLocal => 'Local';

  @override
  String get backupHealthCloud => 'Cloud';

  @override
  String backupTotalSize(int count, String size) {
    return '$count backups · $size';
  }

  @override
  String get backupStatusLocalOnly =>
      'Local backup active — cloud sync pending';

  @override
  String get backupTimelineLatest => 'Latest';

  @override
  String get backupTimelineSwipeHint => 'Swipe to browse your backup history';

  @override
  String get backupCeremonyTitle => 'Vault Ceremony';

  @override
  String get backupCeremonyValidating => 'Validating integrity…';

  @override
  String get backupCeremonyDecrypting => 'Decrypting your ledger…';

  @override
  String get backupCeremonyApplying => 'Applying to your vault…';

  @override
  String get backupCeremonyDownloading => 'Downloading from cloud…';

  @override
  String get backupCreateSuccessBody =>
      'Your ledger has been sealed and saved securely.';

  @override
  String get backupDriveSectionTitle => 'Google Drive';

  @override
  String get backupDriveInviteBody =>
      'Back up to your personal Google Drive — free, encrypted, and private.';

  @override
  String get backupDriveSignInWithGoogle => 'Sign in with Google';

  @override
  String get backupDriveBackupToDrive => 'Backup to Drive';

  @override
  String get backupDriveRestoreFromDrive => 'Restore from Drive';

  @override
  String get backupDriveCloudBackups => 'Cloud backups';

  @override
  String get backupDriveNoCloudBackups => 'No backups in Google Drive yet';

  @override
  String get backupDriveSignOut => 'Sign out of Google';

  @override
  String get backupDriveUploading => 'Uploading to Google Drive…';

  @override
  String get backupDriveDownloading => 'Downloading from Google Drive…';

  @override
  String get backupDriveCancel => 'Cancel';

  @override
  String backupDrivePercent(int percent) {
    return '$percent%';
  }

  @override
  String get backupDrivePendingRetry =>
      'Backup pending — will retry automatically when online';

  @override
  String get backupDriveRetryNow => 'Retry Now';

  @override
  String get backupDriveQuotaExceeded =>
      'Your Google Drive is full. Free up space or manage old backups';

  @override
  String get backupDriveManageBackups => 'Manage backups';

  @override
  String get backupDriveAuthExpired =>
      'Google sign-in expired. Sign in again to continue.';

  @override
  String get backupDriveOffline =>
      'No internet connection. Drive backup will resume when you\'re back online.';

  @override
  String get backupDriveSignInAgain => 'Sign in again';

  @override
  String get backupDriveOfflineGrantMissing =>
      'Permanent backup access is incomplete. Approve Drive access once so automatic backup keeps working even when the app is closed.';

  @override
  String get backupDriveOfflineGrantAction => 'Complete now';

  @override
  String get backupDriveOfflineGrantFailed =>
      'Drive authorization didn\'t complete. Check your connection and try again.';

  @override
  String get backupDriveNotificationPermissionDenied =>
      'Notifications are off. Enable them in system settings so you are alerted when automatic backup runs or fails.';

  @override
  String get backupDriveNotificationPermissionOpenSettings => 'Open settings';

  @override
  String get backupDriveBatteryOptTitle => 'Allow background backup';

  @override
  String get backupDriveBatteryOptBody =>
      'On this phone, battery restrictions can stop automatic Drive backup while the app is closed. Allow unrestricted battery so backups keep running when the phone is on and online.';

  @override
  String get backupDriveBatteryOptAllow => 'Allow unrestricted battery';

  @override
  String get backupDriveBatteryOptLater => 'Not now';

  @override
  String get backupDriveTimingHonesty =>
      'Runs about every interval while the phone is on, online, and not force-stopped — not while powered off.';

  @override
  String get backupDriveDeleteRemoteTitle => 'Delete cloud backup?';

  @override
  String get backupDriveDeleteRemoteBody =>
      'This permanently removes the backup from your Google Drive.';

  @override
  String get backupDriveUploadSuccess => 'Uploaded to Google Drive';

  @override
  String get backupDriveUploadFailed => 'Drive upload failed';

  @override
  String get backupDriveDeleteRemoteSuccess => 'Cloud backup deleted';

  @override
  String get backupDriveDeleteRemoteFailed => 'Failed to delete cloud backup';

  @override
  String get backupDriveSignInSuccess => 'Signed in with Google';

  @override
  String get backupDriveSignInFailed => 'Google sign-in failed';

  @override
  String get syncAuthBridgeFailed =>
      'Could not connect to the sync server. Try again later.';

  @override
  String get inviteCeremonyTitle => 'Invitation';

  @override
  String get inviteCeremonyExpiredTitle => 'This invitation has expired';

  @override
  String get inviteCeremonyExpiredBody =>
      'Ask the shop owner to send a new invite link. You can request one below.';

  @override
  String get inviteCeremonyRevokedTitle => 'This invitation is no longer valid';

  @override
  String get inviteCeremonyRevokedBody =>
      'The link was revoked or is unavailable. Request a new invitation from the owner.';

  @override
  String get inviteCeremonyAlreadyClaimedTitle => 'Invitation already used';

  @override
  String get inviteCeremonyAlreadyClaimedBody =>
      'Someone else already accepted this invite. Request a new one if you still need access.';

  @override
  String get inviteCeremonyAlreadyClaimedByYouTitle =>
      'You already accepted this invite';

  @override
  String get inviteCeremonyAlreadyClaimedByYouBody =>
      'This link was already claimed on your account. Open the app normally or request a fresh invite if access is missing.';

  @override
  String get inviteCeremonyRequestCta => 'Request a new invitation';

  @override
  String get inviteCeremonyPendingBody =>
      'Request saved. Ask the shop owner to open Team and resend your invite.';

  @override
  String get inviteCeremonyOpenHome => 'Open Daftar';

  @override
  String get inviteCeremonyManualCodeLabel => 'Have an invite code?';

  @override
  String get inviteCeremonyManualCodeHint =>
      'Paste the invite token or full link';

  @override
  String get inviteCeremonyPasteClipboard => 'Paste';

  @override
  String get inviteCeremonySubmitCode => 'Continue';

  @override
  String get inviteAcceptTitle => 'Team invitation';

  @override
  String get inviteAcceptPreviewTitle => 'You\'ve been invited';

  @override
  String get inviteAcceptPreviewBody =>
      'Sign in with the Google account that received this invite to join the workspace.';

  @override
  String get inviteAcceptInvitedEmailLabel => 'Invited email';

  @override
  String get inviteAcceptRoleLabel => 'Role';

  @override
  String get inviteAcceptCta => 'Sign in with Google to accept';

  @override
  String get inviteAcceptInProgress => 'Joining workspace…';

  @override
  String inviteAcceptEmailMismatch(String email) {
    return 'This Google account does not match the invited email. Sign in with $email instead.';
  }

  @override
  String get inviteAcceptErrorGeneric =>
      'Could not accept the invite. Try again or ask the owner for a new link.';

  @override
  String get inviteAcceptSuccessTitle => 'You\'re in';

  @override
  String inviteAcceptSuccessBody(String role) {
    return 'You joined the workspace as $role. Sync will start when you\'re online.';
  }

  @override
  String get inviteAcceptContinueHome => 'Open Daftar';

  @override
  String get syncReportConnectionRefused =>
      'Cannot reach the sync server. Make sure your phone and computer are on the same Wi‑Fi and the local Supabase stack is running.';

  @override
  String get syncReportSyncNow => 'Sync now';

  @override
  String get syncReportSyncNowInProgress => 'Syncing…';

  @override
  String get syncReportUpload => 'Upload';

  @override
  String get syncReportUploadInProgress => 'Uploading…';

  @override
  String get syncReportDownload => 'Download';

  @override
  String get syncReportDownloadInProgress => 'Downloading…';

  @override
  String syncReportPushSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uploaded $count changes',
      one: 'Uploaded 1 change',
      zero: 'Nothing to upload',
    );
    return '$_temp0';
  }

  @override
  String syncReportPullSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloaded $count changes',
      one: 'Downloaded 1 change',
      zero: 'No new changes',
    );
    return '$_temp0';
  }

  @override
  String get syncReportPushFailed =>
      'Upload failed. Check your connection and try again.';

  @override
  String get syncReportPullFailed =>
      'Download failed. Check your connection and try again.';

  @override
  String get syncReportDeviceRegistrationFailed =>
      'Could not register this device with the sync server.';

  @override
  String get syncReportStatusIdle => 'Awaiting first sync';

  @override
  String get syncReportTitle => 'Sync report';

  @override
  String get syncReportStatusLoadFailed => 'Could not load sync status';

  @override
  String get syncReportStatusSuccess => 'Sync complete';

  @override
  String get syncReportStatusPartial => 'Partly synced — conflicts need review';

  @override
  String get syncReportStatusFailed => 'Sync failed';

  @override
  String get syncReportStatusDormant => 'Sync is inactive';

  @override
  String get syncReportConflictsHeading => 'Conflicts needing review';

  @override
  String get syncReportStatMerged => 'Merged ops';

  @override
  String get syncReportStatPending => 'Pending';

  @override
  String get syncReportStatConflicts => 'Conflicts';

  @override
  String get syncReportConflictDeleteVsEdit => 'Delete vs edit';

  @override
  String get syncReportConflictConcurrentCreate => 'Concurrent create';

  @override
  String get syncReportConflictAmbiguous => 'Unclassified conflict';

  @override
  String get syncReportConflictRejectedPush => 'Rejected by the server';

  @override
  String get syncReportEntityLedger => 'Ledger';

  @override
  String get syncReportEntityContact => 'Contact';

  @override
  String get syncReportEntityTransaction => 'Transaction';

  @override
  String get syncReportNoConflicts => 'No conflicts — everything is in sync';

  @override
  String get syncReportDormantTitle => 'Multi-device sync';

  @override
  String get syncReportDormantBody =>
      'Upgrade to Pro+ to sync your data across multiple devices';

  @override
  String get backupDriveSignOutSuccess => 'Signed out of Google';

  @override
  String get backupDriveSignOutFailed => 'Sign out failed';

  @override
  String get backupDriveRestorePickTitle => 'Choose a backup to restore';

  @override
  String get backupDriveRestoreLoading => 'Loading backups from Google Drive…';

  @override
  String backupDriveRestorePickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count backups',
      one: '1 backup',
    );
    return '$_temp0';
  }

  @override
  String get backupDriveRestorePickDate => 'Pick a date';

  @override
  String get backupDriveRestoreClearDate => 'All dates';

  @override
  String get backupDriveRestoreDateEmpty => 'No backups on this date';

  @override
  String backupDriveCloudBackupsPreviewFootnote(int shown, int total) {
    return 'Showing latest $shown of $total. Use Restore from Drive to browse all backups by date.';
  }

  @override
  String get backupDriveAutoBackupLabel => 'Auto-Backup to Drive';

  @override
  String get backupDriveAutoBackupInterval => 'Backup interval';

  @override
  String get backupDriveAutoBackupDaily => 'Daily';

  @override
  String get backupDriveAutoBackupWeekly => 'Weekly';

  @override
  String get backupDriveHiddenFolderHint =>
      'Backups are stored in a secure, hidden folder inside your Google Drive to prevent accidental deletion.';

  @override
  String backupDriveAutoBackupLastRun(String when) {
    return 'Last automatic backup: $when';
  }

  @override
  String get backupDriveAutoBackupNeverRun => 'No automatic backup has run yet';

  @override
  String get backupDriveAutoBackupIosHint =>
      'On iPhone, the system schedules automatic backup when battery and usage allow.';

  @override
  String get backupAutoNotifInProgressTitle => 'Automatic backup';

  @override
  String get backupAutoNotifInProgressBody =>
      'Uploading your encrypted Daftar backup to Google Drive…';

  @override
  String get backupAutoNotifSuccessTitle => 'Automatic backup complete';

  @override
  String get backupAutoNotifSuccessBody =>
      'Your encrypted backup was saved to Google Drive.';

  @override
  String get backupAutoNotifRetryTitle => 'Backup pending';

  @override
  String get backupAutoNotifRetryBody =>
      'No internet connection. Upload will resume when you are back online.';

  @override
  String get backupAutoNotifNeedsReauthTitle => 'Sign in again';

  @override
  String get backupAutoNotifNeedsReauthBody =>
      'Your Google session expired. Open Daftar and sign in to resume automatic backup.';

  @override
  String get backupAutoNotifQuotaTitle => 'Google Drive is full';

  @override
  String get backupAutoNotifQuotaBody =>
      'Free up Drive space or delete old Daftar backups in Settings.';

  @override
  String get backupAutoNotifStorageFullTitle => 'Not enough device storage';

  @override
  String get backupAutoNotifStorageFullBody =>
      'Cannot create a backup. Free up space on your device and try again.';

  @override
  String get backupAutoNotifFailedTitle => 'Automatic backup failed';

  @override
  String get backupAutoNotifFailedBody =>
      'Could not upload your backup. Open Daftar for details.';

  @override
  String get smokeTestTitle => 'Cloud Smoke Test';

  @override
  String get smokeTestButton => 'Run Cloud Smoke Test';

  @override
  String get smokeTestSubtitle => 'Verify Google Sign-In & Drive integration';

  @override
  String get smokeTestRunning => 'Running diagnostics…';

  @override
  String get smokeTestComplete => 'Diagnostic complete';

  @override
  String get smokeTestClose => 'Close';

  @override
  String get preflightSignIn => 'Interactive Sign-In';

  @override
  String get preflightDriveRoundTrip => 'Drive Round-Trip';

  @override
  String get preflightSilentSignIn => 'Silent Sign-In';

  @override
  String get preflightSignOut => 'Sign Out';

  @override
  String get preflightConsoleTitle => 'Diagnostic Log';

  @override
  String get preflightClearLog => 'Clear Log';

  @override
  String get premiumTitle => 'Plans';

  @override
  String get premiumHeroTitle => 'Choose the plan that fits your store';

  @override
  String get premiumHeroTagline =>
      'Clear limits on Free. Unlimited workspace on Pro. Sync and automation on Pro+.';

  @override
  String get premiumHeroTaglineContest =>
      'Clear limits on Free. Unlimited workspace on Pro. Analytics and automation on Pro+.';

  @override
  String get premiumVaultSealTitle => 'Activation code';

  @override
  String get premiumVaultSealSubtitle =>
      'Enter your Pro or Pro+ code. Dashes appear as you type.';

  @override
  String get premiumTrustEncrypted =>
      'AES-256 on your device before anything leaves it';

  @override
  String get premiumTrustOffline =>
      'Plans work offline — activation syncs when you reconnect';

  @override
  String get activationBrowsePlans => 'Browse plans';

  @override
  String get activationCodeLabel => 'Activation code';

  @override
  String get activationCodeHint => 'PROPLUS-XXXX-XXXX-XXXX-XXXX';

  @override
  String get activationHaveCode => 'Add activation code';

  @override
  String get activationAddCode => 'Add activation code';

  @override
  String get activateButton => 'Activate';

  @override
  String get activating => 'Activating…';

  @override
  String get activationSuccessTitle => 'Plan activated';

  @override
  String get activationSuccessSubtitle =>
      'Your new plan is ready. Enjoy the full power of your ledger.';

  @override
  String get activationSuccessDone => 'Continue';

  @override
  String get activationErrorInvalid =>
      'Invalid code. Check the code and try again.';

  @override
  String get planStatusTitle => 'Your plan';

  @override
  String get planTierFree => 'Free';

  @override
  String get planTierPro => 'Pro';

  @override
  String get planTierProPlus => 'Pro+';

  @override
  String get planLegendCurrent => 'Current';

  @override
  String planExpiresOn(Object date) {
    return 'Expires $date';
  }

  @override
  String planDaysRemaining(Object count) {
    return '$count days remaining';
  }

  @override
  String get planLifetime => 'Active subscription';

  @override
  String get tierCompareFree => 'Free';

  @override
  String get tierComparePro => 'Pro';

  @override
  String get tierCompareProPlus => 'Pro+';

  @override
  String get tierPriceFree => '\$0';

  @override
  String get freeTierPrice => 'Free';

  @override
  String get tierPricePro => '\$24.99/yr';

  @override
  String get tierPriceProPlus => '\$49.99/yr';

  @override
  String get tierPriceProAmount => '\$24.99';

  @override
  String get tierPriceProPeriod => '/yr';

  @override
  String get tierPriceProPlusAmount => '\$49.99';

  @override
  String get tierPriceProPlusPeriod => '/yr';

  @override
  String get tierBadgeSavePro => 'Save 20%';

  @override
  String get tierBadgeSaveProPlus => 'Best value';

  @override
  String get tierBadgeRecommended => 'Recommended';

  @override
  String get tierCardHighlightFree1 => '1 ledger & 50 contacts';

  @override
  String get tierCardHighlightFree2 => '500 live transactions';

  @override
  String get tierCardHighlightFree3 => 'Free CSV import';

  @override
  String get tierCardHighlightPro1 => 'Unlimited live workspace';

  @override
  String get tierCardHighlightPro2 => 'Branded PDF statements';

  @override
  String get tierCardHighlightProPlus1 => 'Everything in Pro';

  @override
  String get tierCardHighlightProPlus2 => 'Multi-device sync';

  @override
  String get tierCardHighlightProPlus2Contest =>
      'Closing Agent collections desk';

  @override
  String get tierCardHighlightProPlus3 => 'Closing Agent voice & rituals';

  @override
  String get tierCardCtaFree => 'Continue free';

  @override
  String get tierCardCtaPro => 'Activate Pro';

  @override
  String get tierCardCtaProPlus => 'Activate Pro+';

  @override
  String get tierCardCurrentPlan => 'Your current plan';

  @override
  String get tierCardTaglineFree => 'Everything you need to start';

  @override
  String get tierCardTaglinePro => 'For growing stores — no ceilings';

  @override
  String get tierCardTaglineProPlus => 'Multi-device sync and automation';

  @override
  String get tierCardTaglineProPlusContest => 'Closing Agent & collections';

  @override
  String get tierCardBilledAnnually => 'Billed annually';

  @override
  String get tierCardOldPricePro => '\$31.99';

  @override
  String get tierCardOldPriceProPlus => '\$62.99';

  @override
  String get tierCompareTitle => 'Compare features';

  @override
  String get tierCompareSubtitle =>
      'Tap a category to see what each plan includes';

  @override
  String get tierMatrixGroupWorkspace => 'Workspace';

  @override
  String get tierMatrixGroupData => 'Data & backup';

  @override
  String get tierMatrixGroupCloud => 'Cloud & automation';

  @override
  String get tierMatrixGroupGrowth => 'Business growth';

  @override
  String get tierBadgeFree => 'FREE';

  @override
  String get tierBadgeComingSoon => 'Coming soon';

  @override
  String get tierFeatureWorkspaceLimits => 'Ledgers, contacts & transactions';

  @override
  String get tierFeatureBackupLocalCloud => 'Local & Google Drive backup';

  @override
  String get tierFeatureDataExport => 'PDF statements';

  @override
  String get tierFeatureAiVoice => 'AI voice input';

  @override
  String get tierFeatureWhatsappStatements =>
      'Automated monthly WhatsApp statements';

  @override
  String get tierFeatureAnalyticsDashboard => 'Advanced analytics & charts';

  @override
  String get tierFeatureStoreBranding => 'Store branding on exports';

  @override
  String get tierFeatureCustomerPortal => 'Real-time customer portal';

  @override
  String get tierValueBasicPdf => 'Basic PDF';

  @override
  String get tierValueBrandedExport => 'Branded PDF';

  @override
  String get tierFeatureLedgers => 'Live ledgers';

  @override
  String get tierFeatureContacts => 'Live contacts';

  @override
  String get tierFeatureTransactions => 'Live transactions';

  @override
  String get tierFeatureCsvImport => 'CSV import';

  @override
  String get tierFeatureBrandedPdf => 'Branded PDF statements';

  @override
  String get tierFeatureLedgerArchiving => 'Ledger archiving & restore';

  @override
  String get tierFeatureSync => 'Multi-device sync';

  @override
  String get tierFeatureWhatsapp => 'WhatsApp automation';

  @override
  String get tierFeatureAnalytics => 'Advanced analytics';

  @override
  String get tierFeaturePortal => 'Customer portal';

  @override
  String get tierUnlimited => 'Unlimited';

  @override
  String get tierValueStarter => '1 / 50 / 500';

  @override
  String get tierLimitLedgersFree => '1';

  @override
  String get tierLimitContactsFree => '50';

  @override
  String get tierLimitTransactionsFree => '500';

  @override
  String get manageSubscriptionTitle => 'Plan & activation';

  @override
  String get manageSubscriptionSubtitle =>
      'View your plan, redeem a code, or compare tiers.';

  @override
  String get manageSubscriptionCta => 'Open plan center';

  @override
  String get limitUpsellTitle => 'You\'ve outgrown Free';

  @override
  String get limitUpsellSubtitle =>
      'Upgrade to Pro for unlimited live workspace — imports stay free forever.';

  @override
  String limitUpsellProgress(Object current, Object max) {
    return '$current of $max used';
  }

  @override
  String get limitUpsellCta => 'Unlock Pro';

  @override
  String get limitUpsellDismiss => 'Not now';

  @override
  String get premiumBadgeFree => 'Free plan';

  @override
  String get premiumBadgePro => 'Pro';

  @override
  String get premiumBadgeProPlus => 'Pro+';

  @override
  String get securityTitle => 'Security';

  @override
  String get securitySubtitle =>
      'Protect your ledger with a PIN and biometric unlock.';

  @override
  String get securityAppLockTitle => 'App lock (PIN)';

  @override
  String get securityAppLockSubtitle =>
      'Require a PIN when returning to Daftar after a timeout.';

  @override
  String get securityChangePinTitle => 'Change PIN';

  @override
  String get securityChangePinSubtitle => 'Update your unlock code';

  @override
  String get securityBiometricTitle => 'Biometric unlock';

  @override
  String get securityBiometricSubtitle =>
      'Use fingerprint or Face ID when available';

  @override
  String get securityBiometricEnrollReason =>
      'Authenticate to enable biometric unlock for Daftar';

  @override
  String get securityBiometricRequiresAppLock =>
      'Turn on app lock first to use biometric unlock.';

  @override
  String get securityTimeoutTitle => 'Auto-lock';

  @override
  String get securityTimeoutSubtitle =>
      'How long Daftar can stay in the background before locking';

  @override
  String get securityTimeoutImmediate => 'Now';

  @override
  String get securityTimeoutOneMinute => '1 min';

  @override
  String get securityTimeoutFiveMinutes => '5 min';

  @override
  String get securityTimeoutFifteenMinutes => '15 min';

  @override
  String get securityPinCreateTitle => 'Create PIN';

  @override
  String get securityPinConfirmTitle => 'Confirm PIN';

  @override
  String get securityPinChangeTitle => 'Change PIN';

  @override
  String get securityPinCurrentTitle => 'Current PIN';

  @override
  String get securityPinNewTitle => 'New PIN';

  @override
  String get securityPinDisableTitle => 'Enter PIN to turn off';

  @override
  String get securityPinSubtitle => 'Choose a 4-digit PIN';

  @override
  String get securityPinConfirmSubtitle => 'Enter the same PIN again';

  @override
  String get securityPinCurrentSubtitle => 'Enter your current PIN';

  @override
  String get securityPinDisableSubtitle =>
      'Verify your PIN to disable app lock';

  @override
  String get securityPinHint => '4 digits';

  @override
  String get securityPinMismatch => 'PINs do not match. Try again.';

  @override
  String get securityPinIncorrect => 'Incorrect PIN';

  @override
  String get securityPinLockedOut => 'Too many attempts. Wait and try again.';

  @override
  String get securityPinInvalid => 'PIN must be 4 digits';

  @override
  String get securityPinSaveFailed => 'Could not save security settings';

  @override
  String get securitySettingsError => 'Something went wrong. Please try again.';

  @override
  String get securityStatusProtected => 'Fully secured';

  @override
  String get securityStatusProtectedSubtitle =>
      'PIN and biometric unlock are active';

  @override
  String get securityStatusPinOnly => 'PIN protected';

  @override
  String get securityStatusPinOnlySubtitle =>
      'Your ledger locks when you leave Daftar';

  @override
  String get securityStatusUnprotected => 'No lock active';

  @override
  String get securityStatusUnprotectedSubtitle =>
      'Anyone with your phone can open Daftar';

  @override
  String get securityGroupAccess => 'Access control';

  @override
  String get securityGroupAutoLock => 'Auto-lock';

  @override
  String get securityTrustPinSecure =>
      'PIN is hashed and stored in your device\'s secure enclave — never in the database';

  @override
  String get securityTrustBiometricLocal =>
      'Biometric data never leaves your device';

  @override
  String get securityHeroPinRing => 'PIN';

  @override
  String get securityHeroBiometricRing => 'Biometric';

  @override
  String get lockScreenTitle => 'Daftar is locked';

  @override
  String get lockScreenSubtitle => 'Enter your PIN to continue';

  @override
  String get lockScreenBiometricRetry => 'Unlock with biometrics';

  @override
  String get lockScreenForgotPin => 'Forgot PIN?';

  @override
  String get lockScreenForgotPinTitle => 'Erase local data?';

  @override
  String get lockScreenForgotPinBody =>
      'To protect your information, recovering without your PIN will permanently erase all data on this device—ledgers, contacts, and transactions. You must have a .daftar backup file ready to restore your records. This cannot be undone.';

  @override
  String get lockScreenForgotPinCta => 'Erase data and continue';

  @override
  String get lockScreenForgotPinTypeCode => 'Type this code to confirm';

  @override
  String get lockScreenForgotPinCodeHint => 'Enter the 4-digit code';

  @override
  String get lockScreenForgotPinPreparing => 'Preparing a safe environment…';

  @override
  String get fatalErrorTitle => 'Oops, a glitch occurred';

  @override
  String get fatalErrorBody =>
      'Don\'t worry — all your ledgers and data are completely safe.';

  @override
  String get fatalErrorRestart => 'Restart app';

  @override
  String get errorSheetDismiss => 'OK';

  @override
  String get errorGenericTitle => 'Something went wrong';

  @override
  String get errorGenericMessage =>
      'We couldn\'t complete this action. Please try again.';

  @override
  String get errorValidationTitle => 'Check your input';

  @override
  String get errorValidationMessage =>
      'Some details need to be corrected before continuing.';

  @override
  String get errorDatabaseTitle => 'Couldn\'t save changes';

  @override
  String get errorDatabaseMessage =>
      'Your data is safe. Please try again in a moment.';

  @override
  String get errorNetworkTitle => 'Connection problem';

  @override
  String get errorNetworkMessage =>
      'Check your internet connection and try again.';

  @override
  String get errorRateLimitedTitle => 'Too many requests';

  @override
  String get errorRateLimitedMessage =>
      'You\'ve sent several invites in a short time. Please wait a bit and try again.';

  @override
  String errorRateLimitedMessageWithRetry(int minutes) {
    return 'You\'ve sent several invites in a short time. Please try again in about $minutes minutes.';
  }

  @override
  String get errorSeatCapTitle => 'Team is full';

  @override
  String errorSeatCapMessage(int maxWorkers) {
    return 'You can invite up to $maxWorkers workers on Pro+. Remove a pending or active worker to invite someone else.';
  }

  @override
  String get errorForbiddenTitle => 'Not allowed';

  @override
  String get errorForbiddenMessage =>
      'Your role in this workspace doesn\'t allow this action. Ask the workspace owner for access.';

  @override
  String get errorInvalidRequestMessage =>
      'This request wasn\'t accepted. Update the app and try again.';

  @override
  String get errorInvalidActionMessage =>
      'This change couldn\'t be synced because the server didn\'t recognize it. Update the app and try again.';

  @override
  String get errorNotFoundMessage =>
      'We couldn\'t find that item. It may have been removed.';

  @override
  String get errorConflictMessage =>
      'Someone else changed this first. Refresh and try again.';

  @override
  String get errorServerMessage =>
      'The sync server hit a problem. Your data is safe on this device — please try again later.';

  @override
  String get errorServiceUnavailableMessage =>
      'The sync server is temporarily unavailable. Your data is safe on this device.';

  @override
  String get errorDeviceCapMessage =>
      'You\'ve reached the number of devices this workspace allows. Remove a device to add another.';

  @override
  String get errorSyncEventCapMessage =>
      'This workspace reached its monthly sync limit. Syncing resumes next month.';

  @override
  String get errorStorageTitle => 'Storage issue';

  @override
  String get errorStorageMessage =>
      'We couldn\'t access device storage. Free up space if needed, then try again.';

  @override
  String get errorAuthTitle => 'Sign-in required';

  @override
  String get errorAuthMessage => 'Please sign in again to continue.';

  @override
  String get errorInvalidAmountTitle => 'Invalid amount';

  @override
  String get errorInvalidAmountMessage =>
      'Enter a valid amount greater than zero.';

  @override
  String get errorQuotaExceededTitle => 'Storage full';

  @override
  String get errorQuotaExceededMessage =>
      'Your cloud storage is full. Free up space and try again.';

  @override
  String get errorContactNameExists =>
      'A contact with this name already exists in this ledger.';

  @override
  String get errorExportFailedTitle => 'Export failed';

  @override
  String get errorExportFailedMessage =>
      'We couldn\'t create or share the file. Please try again.';

  @override
  String get errorStorageFullTitle => 'Storage full';

  @override
  String get errorStorageFullMessage =>
      'Please free up at least 50MB of space on your device to proceed safely.';

  @override
  String get cloudSyncStatusOffline =>
      'Offline — your data is saved on this device';

  @override
  String get cloudSyncStatusSyncing => 'Syncing backup to the cloud';

  @override
  String get cloudSyncStatusSynced => 'Backed up to the cloud';

  @override
  String get cloudSyncStatusNeedsReauth =>
      'Sign in again to resume cloud backup';

  @override
  String get cloudSyncStatusQuota => 'Cloud storage is full';

  @override
  String get recoveryTitle => 'System recovery';

  @override
  String get recoveryBody =>
      'Your local database file was corrupted due to a storage or power interruption. To protect your data, the app has been halted.';

  @override
  String get recoveryRestoreDrive => 'Restore from Google Drive';

  @override
  String get recoveryStartFresh => 'Start fresh (delete local data)';

  @override
  String get recoveryStartFreshConfirmTitle => 'Delete local data?';

  @override
  String get recoveryStartFreshConfirmBody =>
      'This permanently removes the corrupted database on this device. Your Google Drive backups are not affected. The app will restart with a new empty ledger.';

  @override
  String get recoveryNoDriveBackups =>
      'No Google Drive backups were found for this account.';

  @override
  String get recoveryPickBackupTitle => 'Choose a backup to restore';

  @override
  String get recoveryRestoreFromFile => 'Restore from backup file';

  @override
  String get settingsCloudBackupLegend => 'Cloud';

  @override
  String get quickAddTitle => 'Quick add';

  @override
  String get quickAddNewAccountBadge => 'New account';

  @override
  String get quickAddSelectLedgerHint =>
      'Choose which ledger this account belongs to';

  @override
  String get quickAddLedgerLockedHint => 'Ledger detected automatically';

  @override
  String get quickAddNoLedgerTitle => 'Create a ledger first';

  @override
  String get quickAddNoLedgerMessage =>
      'Every transaction belongs to a ledger. Create your first ledger to start recording debts and payments.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingTrackDebtsTitle => 'Track debts with ease';

  @override
  String get onboardingTrackDebtsBody =>
      'Replace your paper ledger with a simple digital notebook that works offline.';

  @override
  String get onboardingDriveBackupTitle => 'Secure Google Drive backups';

  @override
  String get onboardingDriveBackupBody =>
      'Your encrypted backup lives in your own Google account — hidden and private.';

  @override
  String get onboardingSharePdfTitle => 'Share branded PDF statements';

  @override
  String get onboardingSharePdfBody =>
      'Send professional account statements to customers via WhatsApp in one tap.';

  @override
  String get onboardingPremiumTitle => 'Unlock Pro features';

  @override
  String get onboardingPremiumBody =>
      'Activate Pro for branded exports, ledger archiving, and more premium tools.';

  @override
  String get onboardingSetupHeroLine => 'Debts tracked. Trust intact.';

  @override
  String get onboardingSetupLanguageTitle => 'App language';

  @override
  String get onboardingSetupLookTitle => 'Look';

  @override
  String get onboardingSetupLookDark => 'Dark';

  @override
  String get onboardingSetupLookLight => 'Light';

  @override
  String get onboardingSetupLookSystem => 'Match device';

  @override
  String get onboardingSetupCurrencyLabel => 'Ledger currency';

  @override
  String get onboardingSetupStoreTitle => 'Store name';

  @override
  String get onboardingSetupStoreNameHint => 'e.g. Sample Store';

  @override
  String get onboardingSetupStoreLogoPro =>
      'Logo is a Pro extra — you can name the store now.';

  @override
  String get onboardingSetupGoogleTitle => 'Save a copy on Google';

  @override
  String get onboardingSetupGooglePrimary => 'Continue with Google';

  @override
  String get onboardingSetupGoogleLater => 'Set up later';

  @override
  String get onboardingSetupGoogleFailed =>
      'Sign-in didn’t finish. Your ledger still works offline — try again here.';

  @override
  String get onboardingSetupProExpander => 'Have a code?';

  @override
  String get onboardingSetupProHint =>
      'An activation code is optional. You can continue without one.';

  @override
  String get onboardingSetupLedgerTitle => 'First ledger';

  @override
  String get onboardingSetupLanguageBody =>
      'You can change this anytime in Settings.';

  @override
  String get onboardingSetupLookBody =>
      'Your choice applies to this screen right away.';

  @override
  String get onboardingSetupStoreBody =>
      'Shows on PDF statements you send to customers.';

  @override
  String get onboardingTryDemoStore => 'Try with Demo Store';

  @override
  String get onboardingSetupGoogleBody =>
      'Encrypted backup in your Google account. Your ledger stays on this device.';

  @override
  String get onboardingSetupGoogleCompleteDrive => 'Complete Drive access';

  @override
  String get onboardingSetupGoogleGrantError =>
      'Drive authorization didn\'t complete. Check your connection and try again.';

  @override
  String get onboardingSetupGoogleSignedIn =>
      'Signed in — one more step for automatic backup.';

  @override
  String get onboardingSetupProTitle => 'Pro branding';

  @override
  String get onboardingSetupProBrandingSubtitle =>
      'Your store name and logo on every PDF you share.';

  @override
  String get onboardingSetupProStoreFallback => 'Your store';

  @override
  String get onboardingSetupLedgerLedgerLine =>
      'A ledger is the notebook — customers, suppliers, or personal.';

  @override
  String get onboardingSetupLedgerAccountsLine =>
      'Accounts are the people inside that notebook.';

  @override
  String get onboardingSetupLedgerCustomChip => 'Custom name';

  @override
  String get onboardingSetupLedgerCustomHint => 'e.g. Workshop debts';

  @override
  String get onboardingSetupLedgerCreate => 'Create ledger';

  @override
  String get demoSeedReportTitle => 'Sample store ready';

  @override
  String demoSeedReportStoreKept(String name) {
    return 'Store name: $name (kept)';
  }

  @override
  String demoSeedReportStoreGenerated(String name) {
    return 'Store name: $name (generated)';
  }

  @override
  String demoSeedReportLedger(String name) {
    return 'Ledger: $name';
  }

  @override
  String demoSeedReportContacts(int count) {
    return '$count overdue accounts with email';
  }

  @override
  String get demoSeedReportTones =>
      'Friendly, Reminder, and Firm tone bands included';

  @override
  String demoSeedReportSendSplit(int pdfCount, int textCount) {
    return 'Top $pdfCount get statement PDFs; $textCount get text-only reminders';
  }

  @override
  String get demoSeedReportDone => 'Continue';

  @override
  String get demoSeedReportError =>
      'Could not load the sample store. Try again.';

  @override
  String get settingsSampleStoreSection => 'Sample store';

  @override
  String get settingsSampleStoreBody =>
      'Populate a demo customers ledger with seven overdue accounts for contest evaluators.';

  @override
  String get settingsSampleStoreReset => 'Reset sample store data';

  @override
  String get settingsSampleStoreFootnote =>
      'Replaces contacts, ledgers, and transactions. Your store name is kept when set.';

  @override
  String get settingsSampleStoreResetConfirmTitle => 'Reset sample store?';

  @override
  String get settingsSampleStoreResetConfirmBody =>
      'This replaces your contacts, ledgers, and transactions with the demo dataset. Your store name stays if you already set one.';

  @override
  String get settingsSampleStoreResetConfirm => 'Reset';

  @override
  String get settingsSampleStoreResetCancel => 'Cancel';

  @override
  String get settingsTeam => 'Team';

  @override
  String get settingsTeamSubtitle => 'Invite workers to your workspace';

  @override
  String get settingsJoinWorkspace => 'Have an invite code?';

  @override
  String get settingsJoinWorkspaceSubtitle =>
      'Paste a team invite link to join a workspace';

  @override
  String get joinWorkspaceTitle => 'Join workspace';

  @override
  String get joinWorkspaceBody =>
      'Paste the invite link or code from your shop owner. You will sign in with the Google account that received the invite.';

  @override
  String get joinWorkspaceCodeLabel => 'Invite link or code';

  @override
  String get joinWorkspaceCodeHint =>
      'https://daftar.app/i/… or paste the token';

  @override
  String get joinWorkspaceContinue => 'Continue';

  @override
  String get joinWorkspaceInvalidCode => 'Enter a valid invite link or code.';

  @override
  String get joinWorkspaceAlreadyUsed =>
      'This invite has already been opened on this device.';

  @override
  String get joinWorkspaceBusy =>
      'Still opening the previous invite. Try again in a moment.';

  @override
  String get inviteAcceptWorkspaceMismatch =>
      'Could not join the merchant workspace. Sign out, try again, or contact the shop owner.';

  @override
  String get settingsSyncReport => 'Sync report';

  @override
  String get settingsSyncReportSubtitle =>
      'Multi-device sync status and manual sync';

  @override
  String get memberManagementTitle => 'Team';

  @override
  String get memberManagementSubtitle =>
      'Invite up to two workers to collaborate on your ledgers.';

  @override
  String get memberManagementSeatsHint =>
      'Owner plus up to 2 workers (3 seats max).';

  @override
  String get memberManagementUpgradeTitle =>
      'Team collaboration is a Pro+ feature';

  @override
  String get memberManagementUpgradeSubtitle =>
      'Upgrade to invite workers who can view or edit your ledgers across devices.';

  @override
  String get memberManagementUpgradeCta => 'View plans';

  @override
  String get memberManagementPermissionDenied =>
      'Only the workspace owner can manage team members.';

  @override
  String get memberManagementActiveSection => 'Active members';

  @override
  String get memberManagementPendingSection => 'Pending invites';

  @override
  String get memberManagementEmptySection => 'No members in this section.';

  @override
  String get memberManagementInviteCta => 'Invite worker';

  @override
  String get memberManagementInviteSheetTitle => 'Invite a worker';

  @override
  String get memberManagementEmailLabel => 'Email address';

  @override
  String get memberManagementRoleLabel => 'Role';

  @override
  String get memberManagementRoleOwner => 'Owner';

  @override
  String get memberManagementRoleEditor => 'Editor';

  @override
  String get memberManagementRoleViewer => 'Viewer';

  @override
  String get memberManagementStatusPending => 'Pending';

  @override
  String get memberManagementStatusActive => 'Active';

  @override
  String get memberManagementSendInvite => 'Send invite';

  @override
  String get memberManagementInviteSuccessTitle => 'Invite link ready';

  @override
  String memberManagementInviteRoleGranted(String role) {
    return 'Access granted: $role';
  }

  @override
  String get memberManagementInviteDowngradedTitle =>
      'Invited as viewer, not editor';

  @override
  String get memberManagementInviteDowngradedBody =>
      'Every editor seat is already in use, so this invite was created with view-only access. Remove an editor first if you need another one.';

  @override
  String get memberManagementCopyLink => 'Copy link';

  @override
  String get memberManagementShareLink => 'Share link';

  @override
  String get memberManagementLinkCopied => 'Invite link copied';

  @override
  String get memberManagementRevokeInvite => 'Revoke';

  @override
  String get memberManagementRemoveMember => 'Remove';

  @override
  String get memberManagementRevokeConfirmTitle => 'Revoke invite?';

  @override
  String get memberManagementRevokeConfirmBody =>
      'This cancels the pending invite and frees the seat.';

  @override
  String get memberManagementRemoveConfirmTitle => 'Remove member?';

  @override
  String get memberManagementRemoveConfirmBody =>
      'This member will lose access on their next sync.';

  @override
  String get memberManagementRenewalSection => 'Renewal requests';

  @override
  String get memberManagementRenewalEmpty => 'No pending renewal requests.';

  @override
  String get memberManagementRenewalResend => 'Resend invite';

  @override
  String memberManagementRenewalRequestedAt(String date) {
    return 'Requested $date';
  }

  @override
  String get closingAgentTitle => 'Closing Agent';

  @override
  String get closingAgentEmptyTitle => 'What should we record?';

  @override
  String get closingAgentEmptySubtitle =>
      'Tap an example, or type the name and amount';

  @override
  String get closingAgentComposerHint => 'Write in the ledger';

  @override
  String get closingAgentSpeakWorking => 'Reconciling ledger entries...';

  @override
  String get closingAgentExampleChip1 => 'Mohamed paid 500';

  @override
  String get closingAgentExampleChip2 => 'Ahmed owes 200';

  @override
  String get closingAgentCloseToday => 'Close today';

  @override
  String get closingAgentCloseTodayGoal => 'Close my day';

  @override
  String get closingAgentCloseTodaySemantics =>
      'Close today and start end-of-day closing';

  @override
  String get closingAgentSendSemantics => 'Send goal';

  @override
  String get closingAgentMicSemantics => 'Voice';

  @override
  String get closingAgentMicBanner => 'Hold to speak';

  @override
  String get closingAgentMicRecording => 'Recording';

  @override
  String get closingAgentMicSlideToCancel => 'Slide up to cancel';

  @override
  String get closingAgentMicReleaseToCancel => 'Release to cancel';

  @override
  String closingAgentMicRecordingElapsed(int seconds) {
    return 'Recording, $seconds seconds elapsed';
  }

  @override
  String get closingAgentMicPermissionDenied =>
      'Microphone access is off. Open Settings to allow Daftar to record.';

  @override
  String get closingAgentMicOpenSettings => 'Open Settings';

  @override
  String get closingAgentContactsPermissionDenied =>
      'Contacts access is off. Open Settings to let Daftar fill in name and phone.';

  @override
  String get closingAgentPermissionBannerSemantics => 'Permission notice';

  @override
  String get backupDriveNotSignedIn => 'Sign in to save your Drive backup.';

  @override
  String get closingAgentConfirmDebt => 'Record debt';

  @override
  String get closingAgentConfirmPayment => 'Record payment';

  @override
  String get closingAgentConfirmCreateContact => 'Create account';

  @override
  String get closingAgentConfirmCreateLedger => 'Create ledger';

  @override
  String get closingAgentConfirmAll => 'Record in the books';

  @override
  String get closingAgentConfirmPlan => 'Confirm plan';

  @override
  String get closingAgentIntentDebt => 'Debt';

  @override
  String get closingAgentIntentPayment => 'Payment';

  @override
  String get closingAgentIntentNewAccount => 'New account';

  @override
  String get closingAgentIntentLedger => 'Ledger';

  @override
  String get closingAgentIntentStatement => 'Statement';

  @override
  String get closingAgentSkip => 'Skip';

  @override
  String get closingAgentConfirmed => 'Recorded';

  @override
  String get closingAgentSkipped => 'Skipped';

  @override
  String get closingAgentSelectLedger => 'Choose a ledger';

  @override
  String get closingAgentSelectCurrency => 'Choose a currency';

  @override
  String get closingAgentContactUnresolvedHelper =>
      'Resolve the account before recording.';

  @override
  String get closingAgentWhichContact => 'Which account?';

  @override
  String closingAgentDidYouMean(String name) {
    return 'Did you mean one of these, or create a new account named $name?';
  }

  @override
  String closingAgentCreateNewNamed(String name) {
    return 'Create “$name”';
  }

  @override
  String closingAgentContactAlreadyExists(String name) {
    return '$name already has an account in the books.';
  }

  @override
  String get closingAgentLedgerTypeCustomers => 'Customers';

  @override
  String get closingAgentLedgerTypeSuppliers => 'Suppliers';

  @override
  String get closingAgentLedgerTypePersonal => 'Personal';

  @override
  String get closingAgentLedgerTypeCustom => 'Custom';

  @override
  String get closingAgentAskOverdueTitle => 'Who still owes';

  @override
  String get closingAgentAskLargestTitle => 'Largest outstanding';

  @override
  String get closingAgentAskSmallestTitle => 'Smallest outstanding';

  @override
  String get closingAgentAskLastPaymentTitle => 'Last payment';

  @override
  String get closingAgentAskLastDebtTitle => 'Last debt';

  @override
  String closingAgentAskNoLastPayment(String name) {
    return 'No payment on the books for $name.';
  }

  @override
  String closingAgentAskNoLastDebt(String name) {
    return 'No debt on the books for $name.';
  }

  @override
  String get closingAgentAskNeedName => 'Say which account you mean.';

  @override
  String get closingAgentAskEmpty => 'Nobody owes anything right now.';

  @override
  String get closingAgentAskBalanceTitle => 'Balance';

  @override
  String get closingAgentAskUnresolved => 'No matching account in the books.';

  @override
  String closingAgentSpeakDebt(String name, String amount) {
    return '$name owes $amount';
  }

  @override
  String closingAgentSpeakPayment(String name, String amount) {
    return '$name paid $amount';
  }

  @override
  String closingAgentSpeakDebtWithItem(
    String name,
    String amount,
    String item,
  ) {
    return '$name owes $amount $item';
  }

  @override
  String closingAgentSpeakPaymentWithItem(
    String name,
    String amount,
    String item,
  ) {
    return '$name paid $amount $item';
  }

  @override
  String closingAgentSpeakBalance(String name, String amount) {
    return '$name owes $amount';
  }

  @override
  String closingAgentSpeakCredit(String name, String amount) {
    return '$name is owed $amount';
  }

  @override
  String closingAgentSpeakSettled(String name) {
    return '$name is settled';
  }

  @override
  String get closingAgentSpeakThisAccount => 'this account';

  @override
  String get closingAgentSpeakPlanReady =>
      'Today\'s closing plan is ready. Review it on screen, then confirm.';

  @override
  String closingAgentSpeakRiyals(String amount) {
    return '$amount riyals';
  }

  @override
  String closingAgentSpeakDollars(String amount) {
    return '$amount dollars';
  }

  @override
  String closingAgentSpeakConfirmDebt(String amount, String name, String cta) {
    return 'I\'ll record $amount as a debt on $name. Press $cta.';
  }

  @override
  String closingAgentSpeakConfirmPayment(
    String amount,
    String name,
    String cta,
  ) {
    return 'I\'ll record $amount as a payment from $name. Press $cta.';
  }

  @override
  String closingAgentSpeakConfirmDebtCreate(
    String name,
    String amount,
    String cta,
  ) {
    return 'There\'s no account named $name. I\'ll create one and record a $amount debt. Press $cta.';
  }

  @override
  String closingAgentSpeakConfirmPaymentCreate(
    String name,
    String amount,
    String cta,
  ) {
    return 'There\'s no account named $name. I\'ll create one and record a $amount payment. Press $cta.';
  }

  @override
  String closingAgentSpeakConfirmDebtItem(
    String amount,
    String name,
    String item,
    String cta,
  ) {
    return 'I\'ll record $amount as a debt on $name for $item. Press $cta.';
  }

  @override
  String closingAgentSpeakConfirmPaymentItem(
    String amount,
    String name,
    String item,
    String cta,
  ) {
    return 'I\'ll record $amount as a payment from $name for $item. Press $cta.';
  }

  @override
  String closingAgentSpeakConfirmDebtCreateItem(
    String name,
    String amount,
    String item,
    String cta,
  ) {
    return 'There\'s no account named $name. I\'ll create one and record a $amount debt for $item. Press $cta.';
  }

  @override
  String closingAgentSpeakConfirmPaymentCreateItem(
    String name,
    String amount,
    String item,
    String cta,
  ) {
    return 'There\'s no account named $name. I\'ll create one and record a $amount payment for $item. Press $cta.';
  }

  @override
  String closingAgentSpeakConfirmStatement(String name, String cta) {
    return 'I\'ll prepare a customer statement PDF for $name. Press $cta.';
  }

  @override
  String closingAgentSpeakConfirmCreateContact(String name, String cta) {
    return 'I\'ll create an account named $name. Press $cta.';
  }

  @override
  String closingAgentSpeakConfirmCreateLedger(String name, String cta) {
    return 'I\'ll create a ledger named $name. Press $cta.';
  }

  @override
  String closingAgentStatementTitle(String name) {
    return 'Statement for $name';
  }

  @override
  String closingAgentSpeakOverdueIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts are overdue.',
      one: 'One account is overdue.',
    );
    return '$_temp0';
  }

  @override
  String closingAgentSpeakWhichCandidates(String names) {
    return 'Which account? $names.';
  }

  @override
  String get closingAgentLedgerRequiredHelper =>
      'Choose a ledger before creating this account.';

  @override
  String closingAgentUnknownContactHelper(String name) {
    return 'No account named $name. Create it and record this amount?';
  }

  @override
  String get closingAgentNoLedgerHelper =>
      'There is no ledger yet. Name one to create it.';

  @override
  String get closingAgentLedgerNameHint => 'Ledger name';

  @override
  String get closingAgentConfirmCreateAndRecordDebt => 'Create & record debt';

  @override
  String get closingAgentConfirmCreateAndRecordPayment =>
      'Create & record payment';

  @override
  String get closingAgentCurrencyRequiredHelper =>
      'Choose a currency before creating this account.';

  @override
  String get closingAgentPlanTitle => 'Closing plan';

  @override
  String get closingAgentPlanSendSplit =>
      'The five heaviest overdue accounts get a statement PDF. The rest of the send set get a reminder email. Aging ranks; Gemini does not pick who.';

  @override
  String get closingAgentPlanDeviceRuns =>
      'After backup and aging, the Collections Desk splits call-eligible contacts from email. Yemen and other unsupported regions stay on email. Copy is fixed; Gemini does not pick who.';

  @override
  String get closingAgentPlanOutreachConsent =>
      'These buttons start the close. After backup and aging, the Collections Desk is where you confirm calls and emails.';

  @override
  String get closingAgentTaskmasterTitle => 'Today\'s closing plan';

  @override
  String get closingAgentApprovePlan => 'Approve plan';

  @override
  String get closingAgentStartClose => 'Start close';

  @override
  String get closingAgentStartCloseWithoutOutreach =>
      'Start close without outreach';

  @override
  String get closingAgentConfirmAndSend => 'Confirm & Send Statements';

  @override
  String get closingAgentConfirmWithoutSending => 'Confirm without sending';

  @override
  String closingTaskmasterSealed(int count) {
    return '$count tasks sealed';
  }

  @override
  String get closingTaskBindLedger => 'Reconcile ledger';

  @override
  String get closingTaskCollectDebts => 'Collect today\'s debts';

  @override
  String get closingTaskCollectPayments => 'Collect today\'s payments';

  @override
  String get closingTaskTallyTotals => 'Tally per-currency totals';

  @override
  String get closingTaskStampSnapshot => 'Stamp the day snapshot';

  @override
  String get closingTaskPrepareVault => 'Prepare vault payload';

  @override
  String get closingTaskSealDrive => 'Seal backup to Drive';

  @override
  String get closingTaskScanAging => 'Scan aging balances';

  @override
  String get closingTaskRankUrgency => 'Rank by urgency';

  @override
  String get closingTaskBuildSendSet => 'Compile outreach list';

  @override
  String get closingTaskOpenDesk => 'Open collections desk';

  @override
  String get closingTaskComposeReport => 'Compose day report';

  @override
  String get closingTaskPresentSeal => 'Present the day seal';

  @override
  String closingTaskCaptionDebts(int count) {
    return '$count debts today';
  }

  @override
  String closingTaskCaptionPayments(int count) {
    return '$count payments today';
  }

  @override
  String closingTaskCaptionCurrencies(int count) {
    return '$count currencies';
  }

  @override
  String closingTaskCaptionSendSet(int count) {
    return 'Up to $count accounts';
  }

  @override
  String closingTaskCaptionOverdue(int count) {
    return '$count overdue';
  }

  @override
  String get closingTaskCaptionSendAuth =>
      'Google permission required before sending';

  @override
  String get closingAgentCurrencyLabel => 'Currency';

  @override
  String get closingAgentNoteLabel => 'Note';

  @override
  String get closingAgentReadOnlyTool =>
      'This step is view-only in this version.';

  @override
  String get closingAgentFabTipTitle => 'Agent and manual entry';

  @override
  String get closingAgentFabTipBody =>
      'Tap for the agent · press and hold for manual entry';

  @override
  String get closingAgentFabTipTapRow => 'Tap → agent';

  @override
  String get closingAgentFabTipHoldRow => 'Hold → manual entry';

  @override
  String get closingAgentFabTipSkip => 'Skip';

  @override
  String get closingAgentFabTipDismiss => 'Got it';

  @override
  String get closingAgentFabTipSemantics =>
      'Add-button tip: tap for the agent, hold for manual entry';

  @override
  String get closingAgentConfirmCoachTitle => 'Confirm the amount';

  @override
  String get closingAgentConfirmCoachBody =>
      'Nothing is recorded until you confirm.';

  @override
  String get closingAgentConfirmCoachSemantics => 'Amount confirm tip';

  @override
  String get collectionsDeskApproveCoachTitle => 'Confirm & Send Statements';

  @override
  String get collectionsDeskApproveCoachBody =>
      'Reminders go out in one send. The five heaviest accounts get a statement.';

  @override
  String get collectionsDeskApproveCoachSemantics =>
      'Confirm & Send Statements tip';

  @override
  String get closingRitualBackupUnsigned =>
      'Sign in to save tonight’s Drive backup.';

  @override
  String get closingRitualBackupGrantMissing =>
      'Drive permission was not granted. Approve access once to save tonight\'s backup.';

  @override
  String get closingRitualRunning => 'Closing the day…';

  @override
  String get closingRitualProgressSummary => 'Counting today\'s books';

  @override
  String get closingRitualProgressBackup => 'Saving a Drive backup';

  @override
  String get closingRitualProgressShortlist => 'Finding overdue accounts';

  @override
  String get closingRitualRemindersTitle => 'Prepare collection reminders?';

  @override
  String get closingRitualRemindersYes => 'Yes';

  @override
  String get closingRitualRemindersTop5 => 'Top 5';

  @override
  String get closingRitualRemindersNo => 'No';

  @override
  String get closingRitualPdfsTitle => 'Attach statements?';

  @override
  String get closingRitualPdfsNone => 'None';

  @override
  String get closingRitualPdfsSelective => 'Selective';

  @override
  String get closingRitualPdfsSelected => 'Selected';

  @override
  String get closingRitualReportTitle => 'Day closed';

  @override
  String closingRitualSpeakBooks(int debtCount, int paymentCount) {
    return 'Today you recorded $debtCount debts and $paymentCount payments';
  }

  @override
  String get closingRitualSpeakBackupSafe =>
      'Tonight\'s backup is on Google Drive. Your books are safe';

  @override
  String get closingRitualSpeakBackupQueued =>
      'Tonight\'s backup will finish when you\'re back online';

  @override
  String get closingRitualSpeakBackupUnsigned =>
      'Sign in to save tonight\'s Google Drive backup';

  @override
  String get closingRitualSpeakBackupGrant =>
      'Approve Google Drive access once to save tonight\'s backup';

  @override
  String get closingRitualSpeakBackupFailed =>
      'Google Drive backup needs another try';

  @override
  String closingRitualSpeakQueue(int prepared, int sent, int failed) {
    return '$prepared prepared, $sent sent, $failed failed';
  }

  @override
  String closingRitualSpeakOverdueRemain(int count) {
    return '$count overdue accounts remain';
  }

  @override
  String get closingRitualSpeakClose => 'That\'s the close for today';

  @override
  String closingRitualReportDebtCount(int count) {
    return '$count debts';
  }

  @override
  String get closingRitualReportDebtsUnit => 'today\'s debts';

  @override
  String closingRitualReportPaymentCount(int count) {
    return '$count payments';
  }

  @override
  String get closingRitualReportPaymentsUnit => 'today\'s payments';

  @override
  String closingRitualReportTotals(
    String currencyCode,
    String debt,
    String payment,
  ) {
    return '$currencyCode: $debt debt · $payment paid';
  }

  @override
  String get closingRitualBackupUploaded => 'Backup saved to Drive';

  @override
  String get closingRitualEmptyOverdue => 'Nothing to collect';

  @override
  String get closingRitualSkipAll => 'Reminders skipped';

  @override
  String get closingRitualReminderAll => 'Reminders: send set (up to 20)';

  @override
  String get closingRitualReminderTop5 => 'Reminders: top 5';

  @override
  String get closingRitualReminderNone => 'Reminders: none';

  @override
  String get closingRitualPdfNone => 'Statements: none';

  @override
  String get closingRitualPdfSelective => 'Statements: selective';

  @override
  String get closingRitualPdfAll => 'Statements: selected';

  @override
  String get closingRitualPdfRankedTop5 => 'Statements: ranked Top 5';

  @override
  String get closingRitualNeedsHuman => 'Needs your attention';

  @override
  String closingRitualOverdueCount(int count) {
    return '$count overdue';
  }

  @override
  String get closingRitualRetry => 'Continue closing the day';

  @override
  String get collectionsDeskTitle => 'Collections';

  @override
  String collectionsDeskCount(int count) {
    return '$count reminders';
  }

  @override
  String get collectionsDeskOpenWhatsApp => 'Open WhatsApp';

  @override
  String get collectionsDeskCopy => 'Copy';

  @override
  String get collectionsDeskSkip => 'Skip';

  @override
  String get collectionsDeskAttachStatement => 'Attach statement';

  @override
  String get collectionsDeskStartSending => 'Start sending';

  @override
  String get collectionsDeskApproveSend => 'Confirm & Send Statements';

  @override
  String get collectionsDeskSkipOutreach => 'Skip outreach';

  @override
  String get collectionsDeskRetrySend => 'Retry sending';

  @override
  String get collectionsDeskSending => 'Sending…';

  @override
  String get collectionsDeskPdfAttached => 'PDF attached';

  @override
  String get collectionsDeskReminderOnly => 'Reminder only';

  @override
  String get collectionsDeskDone => 'Done';

  @override
  String get collectionsDeskCopied => 'Reminder copied';

  @override
  String get collectionsDeskWhatsAppFailed =>
      'WhatsApp didn’t open. Copy the reminder and send it yourself.';

  @override
  String get collectionsDeskToneFriendly => 'Friendly';

  @override
  String get collectionsDeskToneReminder => 'Reminder';

  @override
  String get collectionsDeskToneFirm => 'Firm';

  @override
  String collectionsDeskAgeDays(int days) {
    return '$days days';
  }

  @override
  String collectionsDeskLastPaymentDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Last payment $days days ago',
      one: 'Last payment 1 day ago',
      zero: 'Last payment today',
    );
    return '$_temp0';
  }

  @override
  String get collectionsDeskOpened => 'Opened';

  @override
  String get collectionsDeskSkippedStatus => 'Skipped';

  @override
  String get collectionsDeskSentStatus => 'Sent';

  @override
  String get collectionsDeskFailedStatus => 'Failed';

  @override
  String get collectionsDeskConfirmAndCall => 'Confirm & Call';

  @override
  String get collectionsDeskConfirmWithoutCalling => 'Confirm without calling';

  @override
  String get collectionsDeskWithoutCalling => 'Without calling';

  @override
  String get collectionsDeskWithoutSending => 'Without sending';

  @override
  String collectionsDeskRailChipVoiceCalls(int count) {
    return 'Voice calls · $count';
  }

  @override
  String collectionsDeskRailChipEmail(int count) {
    return 'Email · $count';
  }

  @override
  String collectionsDeskCommitOutreachBoth(int callCount, int emailCount) {
    return 'Confirm outreach — $callCount calls + $emailCount emails';
  }

  @override
  String collectionsDeskCommitCallsOnly(int count) {
    return 'Start calls only — $count';
  }

  @override
  String collectionsDeskCommitEmailOnly(int count) {
    return 'Send email only — $count';
  }

  @override
  String get collectionsDeskCommitSeal => 'Skip outreach and seal the day';

  @override
  String collectionsDeskRetryUnanswered(int count) {
    return 'Retry unanswered — $count';
  }

  @override
  String get collectionsDeskPromiseNotPayment => 'A promise is not a payment';

  @override
  String get collectionsDeskPromiseNotPaymentSubtitle =>
      'CALL-E records what the customer said they will pay. It does not write money to your ledger.';

  @override
  String contactPendingPromiseBody(String amount, String date) {
    return 'Promised $amount on $date';
  }

  @override
  String contactPendingPromiseSemantics(String amount, String date) {
    return 'Pending promise: $amount on $date';
  }

  @override
  String get contactPromiseStatusPending => 'Pending';

  @override
  String get contactPromiseUpdateStatus => 'Update status';

  @override
  String get contactPromiseStatusActionSheetTitle => 'Promise status';

  @override
  String get contactPromiseStatusKept => 'Kept';

  @override
  String get contactPromiseStatusBroken => 'Broken';

  @override
  String get contactPromiseStatusCancelled => 'Cancelled';

  @override
  String get contactPromiseMarkBrokenConfirmTitle => 'Mark promise broken?';

  @override
  String get contactPromiseMarkBrokenConfirmBody =>
      'This updates the promise card only. It does not write money to your ledger.';

  @override
  String get contactPromiseMarkCancelledConfirmTitle => 'Cancel this promise?';

  @override
  String get contactPromiseMarkCancelledConfirmBody =>
      'This updates the promise card only. It does not write money to your ledger.';

  @override
  String get collectionsDeskCallPreviewTitle => 'What CALL-E will say';

  @override
  String collectionsDeskCallingProgress(int index, int total) {
    return 'Calling $index of $total';
  }

  @override
  String collectionsDeskCallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calls',
      one: '1 call',
    );
    return '$_temp0';
  }

  @override
  String collectionsDeskEmailCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count emails',
      one: '1 email',
    );
    return '$_temp0';
  }

  @override
  String get collectionsDeskRailCall => 'Call';

  @override
  String get collectionsDeskRailEmail => 'Email';

  @override
  String get collectionsDeskRailBoth => 'Both';

  @override
  String get collectionsDeskRailCallUnavailable => 'Can\'t call';

  @override
  String get collectionsDeskRailSkipped => 'Skipped';

  @override
  String collectionsQueueSending(int index, int total) {
    return 'Sending $index of $total';
  }

  @override
  String collectionsQueuePaused(int index, int total) {
    return 'Paused · $index of $total';
  }

  @override
  String get collectionsQueuePause => 'Pause';

  @override
  String get collectionsQueueResume => 'Resume';

  @override
  String closingRitualQueuePrepared(int count) {
    return '$count prepared';
  }

  @override
  String closingRitualQueueOpened(int count) {
    return '$count opened';
  }

  @override
  String closingRitualQueueSkipped(int count) {
    return '$count skipped';
  }

  @override
  String closingRitualQueueSent(int count) {
    return '$count sent';
  }

  @override
  String closingRitualQueueFailed(int count) {
    return '$count failed';
  }

  @override
  String get errorGoalTextRequired => 'Type a goal first.';

  @override
  String get errorAgentIdTokenMissing =>
      'Sign in with Google to use the agent.';

  @override
  String get errorAgentOpenIdGrantRequired =>
      'A one-time Google permission update is required to keep the agent signed in. Approve it once — Drive backup is unchanged.';

  @override
  String get errorClosingAgentForbidden =>
      'This Google account cannot use the agent. Sign in with the authorized account.';

  @override
  String get errorClosingAgentRequestFailed =>
      'Couldn’t reach the agent. Your books are safe on this device — hold + to add an entry.';

  @override
  String get errorProposalInFlight =>
      'This confirmation is already in progress.';

  @override
  String get errorContactUnresolved =>
      'Couldn’t match a single account. Clarify the name or create it.';

  @override
  String get errorLedgerRequired =>
      'Choose a ledger before creating this account.';

  @override
  String get errorCurrencyRequired =>
      'Choose a currency before creating this account.';

  @override
  String get errorProposalAlreadyCommitted =>
      'This entry was already recorded.';

  @override
  String get errorClosingAgentParseFailed =>
      'The agent reply couldn’t be read. Try again.';

  @override
  String get errorSmtpTitle => 'Email was not sent';

  @override
  String get errorSmtpNeedsHuman =>
      'Gmail on Cloud Run rejected the App Password. Signing into the app again will not help. Your books are unchanged.';

  @override
  String get errorSmtpSenderMisconfigured =>
      'Email sender is not configured on Cloud Run. Google Drive sign-in is unrelated. Your books are unchanged.';

  @override
  String get errorCalleKillSwitchTitle => 'Calls are paused';

  @override
  String get errorCalleKillSwitch =>
      'Phone calls are turned off. Email still works. Your books are unchanged.';

  @override
  String get errorCalleNeedsHumanTitle => 'Call needs a look';

  @override
  String get errorCalleNeedsHuman =>
      'The call needs a person to review. Your books are unchanged.';

  @override
  String get errorCallePollTimeoutTitle => 'Call timed out';

  @override
  String get errorCallePollTimeout =>
      'The call did not finish in time. Your books are unchanged. Do not tap Confirm & Call again.';

  @override
  String get errorCollectionsEmailCap =>
      'You can send at most 20 reminders at once.';
}
