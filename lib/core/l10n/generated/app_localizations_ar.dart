// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'دفتر';

  @override
  String get greeting => 'مرحباً';

  @override
  String get home => 'الرئيسية';

  @override
  String get settings => 'الإعدادات';

  @override
  String get netBalance => 'صافي الرصيد';

  @override
  String get totalDebt => 'إجمالي الدين';

  @override
  String get totalCredit => 'إجمالي الائتمان';

  @override
  String get tapToExpand => 'اضغط للتوسيع';

  @override
  String get tapToCollapse => 'اضغط للطي';

  @override
  String get tapToSeeBreakdown => 'اضغط لرؤية التفاصيل';

  @override
  String get hideBreakdown => 'إخفاء التفاصيل';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get changeLanguage => 'تغيير اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'الإنجليزية';

  @override
  String get appearance => 'المظهر';

  @override
  String get homeScreenSubtitle => 'استعرض الشاشات المؤقتة من هنا.';

  @override
  String get openLedgerDetails => 'فتح تفاصيل الدفتر';

  @override
  String get openContactDetails => 'فتح تفاصيل الحساب';

  @override
  String get settingsScreenSubtitle =>
      'خصّص دفتر — اللغة والمظهر ومساحة العمل.';

  @override
  String get settingsGroupPreferences => 'التفضيلات';

  @override
  String get settingsGroupAccountSecurity => 'الحساب والأمان';

  @override
  String get settingsGroupWorkspace => 'مساحة العمل';

  @override
  String get settingsGroupPrivacy => 'الخصوصية';

  @override
  String get settingsGroupSupport => 'الدعم';

  @override
  String get settingsSystemTheme => 'النظام';

  @override
  String get settingsDefaultCurrency => 'العملة الافتراضية';

  @override
  String get settingsMultiCurrency => 'تفعيل ميزة تعدد العملات';

  @override
  String get settingsMultiCurrencySubtitle =>
      'اختر عملة لكل حساب أو معاملة جديدة. عند الإيقاف، تُستخدم العملة الافتراضية فقط.';

  @override
  String get settingsSwipeToDelete => 'السحب للحذف';

  @override
  String get settingsSwipeToDeleteSubtitle =>
      'اسحب عناصر القائمة للحذف بسرعة. عند الإيقاف، استخدم القائمة على كل صف.';

  @override
  String get settingsTtsMuted => 'كتم القراءة الصوتية';

  @override
  String get settingsTtsMutedSubtitle =>
      'أوقف الكلام على الجهاز لبطاقات التأكيد وتقرير الإغلاق. المبالغ تبقى ظاهرة على الشاشة.';

  @override
  String get settingsDemoArchitectureHud => 'عرض هيكل الوكيل';

  @override
  String get settingsDemoArchitectureHudSubtitle =>
      'للتجربة: النموذج والأدوات ومسار التأكيد البشري وزمن الاستجابة. ليس جولة في المنتج.';

  @override
  String get settingsCalleAllowDial => 'السماح بالاتصال عبر CALL-E';

  @override
  String get settingsCalleAllowDialSubtitle =>
      'بوابة على الجهاز لـ Confirm & Call. يجب تفعيل علم البناء في التطبيق والخادم أيضاً.';

  @override
  String architectureHudSemantics(String step) {
    return 'أداة هيكل الوكيل، المرحلة $step';
  }

  @override
  String architectureHudRouting(String model) {
    return 'Cloud Run · $model';
  }

  @override
  String get architectureHudLatencyPending => '…';

  @override
  String get architectureHudScopeCapture => 'تسجيل';

  @override
  String get architectureHudScopeClose => 'إغلاق';

  @override
  String get architectureHudScopeAsk => 'سؤال';

  @override
  String architectureHudToolScope(String scope, String tools) {
    return '$scope · $tools';
  }

  @override
  String get architectureHudHitlPropose => 'اقتراح';

  @override
  String get architectureHudHitlConfirm => 'تأكيد';

  @override
  String get architectureHudHitlCommit => 'حفظ';

  @override
  String get architectureHudHitlRank => 'ترتيب';

  @override
  String architectureHudPendingRecorded(int pending, int recorded) {
    return 'معلّق $pending · مسجّل $recorded';
  }

  @override
  String architectureHudSkipped(int skipped) {
    return 'تخطّى $skipped';
  }

  @override
  String architectureHudModel(String model) {
    return 'النموذج $model';
  }

  @override
  String architectureHudTool(String name) {
    return 'الأداة $name';
  }

  @override
  String architectureHudLatency(int ms) {
    return '$ms مللي ثانية';
  }

  @override
  String architectureHudCorrelation(String id) {
    return 'المرجع $id';
  }

  @override
  String architectureHudEmailSent(String id) {
    return 'أُرسل · $id';
  }

  @override
  String architectureHudCallChip(String id, String status) {
    return 'اتصال · $id · $status';
  }

  @override
  String architectureHudCallId(String id) {
    return 'اتصال · $id';
  }

  @override
  String architectureHudCallStatusOnly(String status) {
    return 'اتصال · $status';
  }

  @override
  String get architectureHudCallPlanned => 'مجدول';

  @override
  String get architectureHudCallRinging => 'يرن';

  @override
  String get architectureHudCallCompleted => 'اكتمل';

  @override
  String get architectureHudCallFailed => 'فشل';

  @override
  String get contactDeleteConfirmTitle => 'هل أنت متأكد؟';

  @override
  String get contactDeleteConfirmBody =>
      'سيؤدي هذا إلى إزالة الحساب وجميع المعاملات المرتبطة به من دفترك.';

  @override
  String get contactDeleteConfirmAction => 'حذف الحساب';

  @override
  String get ledgerDeleteConfirmTitle => 'هل أنت متأكد؟';

  @override
  String get ledgerDeleteConfirmBody =>
      'سيؤدي هذا إلى حذف هذا الدفتر مع جميع الحسابات والمعاملات المرتبطة به.';

  @override
  String get ledgerDeleteConfirmAction => 'حذف الدفتر';

  @override
  String get settingsMerchantBranding => 'هوية المتجر';

  @override
  String get settingsMerchantBrandingSubtitle =>
      'الشعار واسم المتجر وكشوف PDF المخصصة';

  @override
  String get settingsPremium => 'الخطة والتفعيل';

  @override
  String get settingsPremiumSubtitle =>
      'عرض خطتك أو استرداد رمز أو مقارنة الباقات';

  @override
  String get settingsGoogleAccount => 'حساب Google';

  @override
  String get settingsGoogleAccountSignInPrompt =>
      'سجّل الدخول للنسخ الاحتياطي على Drive';

  @override
  String get settingsAnalytics => 'تحليلات الاستخدام';

  @override
  String get settingsAnalyticsSubtitle =>
      'ساعدنا على تحسين دفتر ببيانات استخدام مجهولة';

  @override
  String get settingsAbout => 'عن دفتر';

  @override
  String settingsVersionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settingsRateApp => 'قيّم دفتر';

  @override
  String get settingsContactSupport => 'تواصل مع الدعم';

  @override
  String get settingsSelectLanguage => 'اللغة';

  @override
  String get settingsSelectTheme => 'المظهر';

  @override
  String get settingsSelectCurrency => 'العملة';

  @override
  String get settingsProBadgeLabel => 'Pro';

  @override
  String get settingsSaveFailed => 'تعذّر حفظ الإعدادات';

  @override
  String get settingsStoreLaunchError => 'تعذّر فتح المتجر';

  @override
  String get settingsVaultTrustLabel => 'ثقة الخزنة';

  @override
  String get settingsVaultTrustHigh => 'محمي بالكامل';

  @override
  String get settingsVaultTrustMedium => 'محمي جزئياً';

  @override
  String get settingsVaultTrustLow => 'يحتاج إجراء';

  @override
  String get settingsGroupVault => 'صحة الخزنة';

  @override
  String get settingsSecurityAdvanced => 'أمان متقدّم';

  @override
  String get settingsCommandSecurity => 'الأمان';

  @override
  String get settingsCommandBackup => 'النسخ الاحتياطي';

  @override
  String get settingsCommandImport => 'استيراد';

  @override
  String get settingsCommandAccount => 'الحساب';

  @override
  String get settingsAboutDescription =>
      'دفتر هو سجلّك الرقمي الذي يعمل دون اتصال — صُمّم للتجّار الذين يحتاجون ثقة ووضوحاً وتحكّماً في كل دين ودفعة.';

  @override
  String get settingsAboutOfflineFirst => 'يعمل بالكامل دون اتصال';

  @override
  String get settingsAboutArabicFirst => 'تصميم عربي أولاً';

  @override
  String get settingsAboutFinancialGrade => 'سلامة مالية بمعايير عالية';

  @override
  String get merchantBrandingScreenTitle => 'هوية المتجر';

  @override
  String get merchantBrandingScreenSubtitle => 'خصّص كشوف PDF بهوية متجرك';

  @override
  String get merchantBrandingUpgradeTitle => 'الكشوف المخصصة ميزة Pro';

  @override
  String get merchantBrandingUpgradeSubtitle =>
      'ترقّ للباقة Pro لإضافة شعارك واسم متجرك لكل تصدير PDF.';

  @override
  String get merchantBrandingUpgradeCta => 'عرض الباقات';

  @override
  String get merchantBrandingStoreName => 'اسم المتجر';

  @override
  String get merchantBrandingUploadLogo => 'رفع الشعار';

  @override
  String get merchantBrandingRemoveLogo => 'إزالة الشعار';

  @override
  String get merchantBrandingPreviewPdf => 'معاينة PDF';

  @override
  String get merchantBrandingSaveSuccess => 'تم حفظ الهوية';

  @override
  String get merchantBrandingLogoRemoved => 'تمت إزالة الشعار';

  @override
  String get merchantBrandingPickSourceTitle => 'إضافة شعار المتجر';

  @override
  String get merchantBrandingPickCamera => 'الكاميرا';

  @override
  String get merchantBrandingPickGallery => 'مكتبة الصور';

  @override
  String get merchantBrandingCropTitle => 'ضبط الشعار';

  @override
  String get merchantBrandingCropHint =>
      'قرّب للتكبير واسحب لتحديد موضع الشعار';

  @override
  String get merchantBrandingCropConfirm => 'استخدام الشعار';

  @override
  String get merchantBrandingSaveProfileFirst =>
      'احفظ اسم المتجر قبل إضافة الشعار';

  @override
  String get merchantBrandingPreviewContactName => 'حساب تجريبي';

  @override
  String get merchantBrandingCountryYemen => 'اليمن';

  @override
  String get merchantBrandingCountrySaudi => 'السعودية';

  @override
  String get merchantBrandingTapToEdit => 'اضغط لتعديل هوية متجرك';

  @override
  String get merchantBrandingEditIdentity => 'تعديل الهوية';

  @override
  String get merchantBrandingLivePreview => 'معاينة مباشرة';

  @override
  String get merchantBrandingStatementPreview => 'كيف يظهر على الكشوف';

  @override
  String get merchantBrandingCompletionTitle => 'قائمة الهوية';

  @override
  String get merchantBrandingStepPhone => 'الهاتف';

  @override
  String get merchantBrandingStepLogo => 'الشعار';

  @override
  String get merchantBrandingIdentityComplete => 'الهوية مكتملة';

  @override
  String get merchantBrandingIdentityIncomplete => 'أكمل هويتك للكشوف المخصصة';

  @override
  String get accountManagementTitle => 'حساب Google';

  @override
  String get accountManagementSubtitle =>
      'إدارة الحساب المستخدم للنسخ الاحتياطي على Drive';

  @override
  String get accountManagementSignOut => 'تسجيل الخروج';

  @override
  String get accountManagementSwitchAccount => 'تبديل الحساب';

  @override
  String get accountManagementSignOutConfirmTitle => 'تسجيل الخروج';

  @override
  String get accountManagementSignOutConfirmBody =>
      'لن تتمكن من الوصول إلى نسخ Google Drive الاحتياطية لهذا الحساب من التطبيق. بياناتك المحلية لن تتأثر. يمكنك تسجيل الدخول بنفس الحساب أو بحساب مختلف لاحقًا.';

  @override
  String get accountManagementSignOutConfirmCta => 'تسجيل الخروج';

  @override
  String get accountManagementStatusConnected => 'الحساب مرتبط';

  @override
  String get accountManagementStatusConnectedSubtitle =>
      'النسخ الاحتياطي السحابي متاح لهذا الحساب';

  @override
  String get accountManagementStatusPartialSubtitle =>
      'تم تسجيل الدخول — أنشئ نسخة احتياطية للمزامنة مع Drive';

  @override
  String get accountManagementStatusDisconnected => 'لا يوجد حساب مرتبط';

  @override
  String get accountManagementStatusDisconnectedSubtitle =>
      'سجّل الدخول لتفعيل النسخ الاحتياطي المشفّر على Google Drive';

  @override
  String get accountManagementIdentityRing => 'تسجيل الدخول';

  @override
  String get accountManagementCloudRing => 'السحابة';

  @override
  String get accountManagementTrustLocalData =>
      'دفترك يبقى على هذا الجهاز — تسجيل الخروج لا يحذف بياناتك المحلية';

  @override
  String get accountManagementTrustDriveScope =>
      'وصول Google محصور في مجلد النسخ الاحتياطي الخاص بدفتر';

  @override
  String get accountManagementActionsTitle => 'إجراءات الحساب';

  @override
  String get accountManagementManageBackup => 'إدارة النسخ الاحتياطية';

  @override
  String get accountManagementManageBackupSubtitle =>
      'عرض النسخ المحلية وحالة مزامنة Drive';

  @override
  String get accountManagementConnectedBadge => 'متصل';

  @override
  String get accountManagementMigrationRelinkTitle => 'أعد ربط حساب Google';

  @override
  String get accountManagementMigrationRelinkBody =>
      'تم اكتشاف تسجيل دخول سابق على هذا الجهاز. سجّل الدخول مجددًا لاستعادة النسخ الاحتياطي السحابي المشفّر — دفترك المحلي آمن.';

  @override
  String get accountManagementNeedsReauthTitle => 'انتهت الجلسة';

  @override
  String get accountManagementNeedsReauthBody =>
      'انتهت صلاحية تسجيل الدخول إلى Google أو تم إلغاؤه. استعد الوصول لاستئناف النسخ الاحتياطي السحابي.';

  @override
  String get accountManagementRestoreAccess => 'استعادة الوصول';

  @override
  String get currentLanguage => 'اللغة الحالية';

  @override
  String get currentTheme => 'السمة الحالية';

  @override
  String get ledgerDetailTitle => 'تفاصيل الدفتر';

  @override
  String get contactDetailTitle => 'تفاصيل الحساب';

  @override
  String get contactDetails => 'تفاصيل الحساب';

  @override
  String get ledgerDetailSubtitle => 'هذه شاشة مؤقتة لعرض تفاصيل الدفتر.';

  @override
  String get contactDetailSubtitle => 'هذه شاشة مؤقتة لعرض تفاصيل الحساب.';

  @override
  String get ledgerIdLabel => 'معرّف الدفتر';

  @override
  String get contactIdLabel => 'معرّف الحساب';

  @override
  String get myLedgers => 'دفاتري';

  @override
  String ledgerAccountCount(int count) {
    return '$count حسابات';
  }

  @override
  String get searchHint => 'ابحث بالاسم أو الرقم';

  @override
  String get searchContacts => 'البحث في الحسابات...';

  @override
  String get sort => 'ترتيب';

  @override
  String get sortBy => 'الترتيب حسب';

  @override
  String get sortByName => 'الاسم';

  @override
  String get sortByBalance => 'الرصيد';

  @override
  String get sortByRecent => 'الأحدث';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterDebt => 'عليه';

  @override
  String get filterCredit => 'له';

  @override
  String get filterSettled => 'مُسدّد';

  @override
  String get noSearchResults => 'لا توجد حسابات تطابق بحثك';

  @override
  String get noFilterResults => 'لا توجد حسابات في هذه الفئة';

  @override
  String get editLedger => 'تعديل الدفتر';

  @override
  String get ledgerName => 'اسم الدفتر';

  @override
  String get selectColor => 'اختر اللون';

  @override
  String get selectIcon => 'اختر الأيقونة';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get delete => 'حذف';

  @override
  String get undo => 'تراجع';

  @override
  String get contactDeleted => 'تم حذف الحساب';

  @override
  String get addContact => 'إضافة حساب';

  @override
  String get name => 'الاسم';

  @override
  String get nameRequired => 'الاسم مطلوب';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get contactEmailHint => 'البريد الإلكتروني (اختياري)';

  @override
  String get contactEmailInvalid => 'أدخل بريداً صالحاً أو اتركه فارغاً.';

  @override
  String get importFromContacts => 'استيراد من جهات الاتصال';

  @override
  String get notes => 'ملاحظات';

  @override
  String get creditLimit => 'حد الائتمان';

  @override
  String get selectCurrency => 'اختر العملة';

  @override
  String get save => 'حفظ';

  @override
  String get editContact => 'تعديل الحساب';

  @override
  String get openWhatsApp => 'فتح واتساب';

  @override
  String get call => 'اتصال';

  @override
  String get callLaunchError => 'تعذر فتح تطبيق الاتصال';

  @override
  String get whatsappLaunchError => 'تعذر فتح واتساب';

  @override
  String get invalidAmount => 'القيمة غير صالحة';

  @override
  String transactionsCount(int count) {
    return '$count عمليات';
  }

  @override
  String get emptyStateTitle => 'لا توجد بيانات بعد';

  @override
  String get noTransactionsYet => 'لا توجد عمليات بعد';

  @override
  String get emptyStateSubtitle => 'أضف أول عنصر وسيظهر هنا.';

  @override
  String get emptyStateAction => 'إضافة جديد';

  @override
  String get archiveVaultTitle => 'خزنة الأرشيف';

  @override
  String get archiveVaultSubtitle => 'دفاتر مجمّدة — للقراءة فقط حتى الاستعادة';

  @override
  String get archivedTotalLabel => 'إجمالي المؤرشف';

  @override
  String get archivedLedgerReadOnlyBadge => 'للقراءة فقط';

  @override
  String get unarchiveLedgerAction => 'استعادة';

  @override
  String get unarchiveLedgerSuccess => 'تمت استعادة الدفتر إلى مساحة عملك';

  @override
  String get archiveVaultEmptyTitle => 'الخزنة فارغة';

  @override
  String get archiveVaultEmptySubtitle =>
      'تظهر الدفاتر المؤرشفة هنا، مجمّدة في وقتها مع أرصدتها المحفوظة.';

  @override
  String get contactArchivedReadOnlyTitle => 'هذا الحساب في دفتر مؤرشف';

  @override
  String get contactArchivedReadOnlySubtitle =>
      'البيانات للقراءة فقط. يمكنك عرض العمليات وتصدير الكشوف.';

  @override
  String get ledgerArchivedReadOnlyTitle => 'دفتر مؤرشف — للقراءة فقط';

  @override
  String get ledgerArchivedReadOnlySubtitle =>
      'هذا الدفتر مجمّد في خزنة الأرشيف. الأرصدة محفوظة؛ الإدخالات الجديدة معطّلة.';

  @override
  String get ledgerOptionsTitle => 'خيارات الدفتر';

  @override
  String get archiveLedgerAction => 'أرشفة الدفتر';

  @override
  String get financialCloseTitle => 'أرشفة الدفتر';

  @override
  String get financialCloseSubtitle =>
      'انقل هذا الدفتر إلى الخزنة ليبقى مساحة عملك مرتّبة.';

  @override
  String get financialCloseEducationTitle => 'ماذا يحدث عند الأرشفة؟';

  @override
  String get financialCloseEducationBody =>
      'الأرشفة تُخفِي الدفتر عن مساحة عملك اليومية. تبقى كل الأرصدة والعمليات محفوظة—ويمكنك استعادته في أي وقت من خزنة الأرشيف.';

  @override
  String get financialCloseArchiveOnly => 'أرشفة إلى الخزنة';

  @override
  String get financialCloseArchiveOnlyDescription =>
      'تجميد الدفتر كما هو. لا شيء يُنقل؛ كل شيء يبقى للقراءة في الخزنة.';

  @override
  String get carryForwardToggleLabel => 'نقل الأرصدة أولاً';

  @override
  String get carryForwardToggleDescription =>
      'انقل الديون والأرصدة النشطة إلى دفتر آخر لتتابع تجارتك دون البدء من الصفر.';

  @override
  String get carryForwardTargetPickerLabel => 'تابع في';

  @override
  String get carryForwardTargetPickerHint => 'اختر الدفتر الذي تستقبل أرصدتك';

  @override
  String get carryForwardCreateNewLedger => 'ابدأ دفتراً جديداً';

  @override
  String get carryForwardPreviewTitle => 'معاينة';

  @override
  String carryForwardPreviewContacts(int count) {
    return '$count حسابات بأرصدة';
  }

  @override
  String carryForwardPreviewTransactions(int count) {
    return '$count قيود افتتاحية';
  }

  @override
  String get openingBalanceItemName => 'رصيد افتتاحي';

  @override
  String carryForwardOpeningBalanceNote(String ledgerName) {
    return 'رصيد افتتاحي مرحّل من $ledgerName';
  }

  @override
  String get carryForwardSuccess => 'تم ختم الدفتر في الخزنة';

  @override
  String get carryForwardSuccessBody =>
      'سجلاتك مجمّدة بأمان. استعدها في أي وقت من خزنة الأرشيف.';

  @override
  String get carryForwardConfirmTitle => 'أنت المتحكّم';

  @override
  String get carryForwardConfirmBody =>
      'ينتقل هذا الدفتر إلى الخزنة للقراءة فقط. استعده متى شئت—بياناتك لن تضيع أبداً.';

  @override
  String get confirmArchive => 'ختم وأرشفة';

  @override
  String get archiveCeremonySealing => 'جارٍ ختم الدفتر…';

  @override
  String get archiveCeremonyTransferring => 'جارٍ تأمين الأرصدة…';

  @override
  String get contactSearchArchivedBadge => 'مؤرشف';

  @override
  String get homeArchiveVaultEntry => 'فتح خزنة الأرشيف';

  @override
  String get limitWarningTitle => 'الحد يقترب';

  @override
  String get limitWarningSubtitle => 'أنت تقترب من حد الخطة المجانية.';

  @override
  String get limitReachedTitle => 'تم تجاوز الحد';

  @override
  String get limitReachedSubtitle => 'قم بالترقية لمتابعة الإضافة.';

  @override
  String get maxLedgersReached =>
      'عذراً، لقد وصلت للحد الأقصى (دفتر واحد) في النسخة المجانية';

  @override
  String get premiumUpgradeBannerTitle => 'أنت تقترب من حد الخطة المجانية';

  @override
  String premiumUpgradeBannerUsage(
    Object current,
    Object max,
    Object resource,
  ) {
    return '$current من $max $resource';
  }

  @override
  String get premiumUpgradeResourceLedgers => 'دفاتر';

  @override
  String get premiumUpgradeResourceContacts => 'حسابات';

  @override
  String get premiumUpgradeResourceTransactions => 'معاملات';

  @override
  String get premiumUpgradeLedgers =>
      'أضف دفاتر بلا حدود ونظّم كل حساباتك في مكان واحد.';

  @override
  String get premiumUpgradeContacts =>
      'تابع عدداً غير محدود من العملاء دون حذف السجلات القديمة.';

  @override
  String get premiumUpgradeTransactions =>
      'سجّل كل بيع ودفعة — بلا سقف على سجل معاملاتك.';

  @override
  String get premiumUpgradeSubtitle =>
      'فعّل مساحة عمل غير محدودة وكشوف PDF احترافية.';

  @override
  String get premiumUpgradeCta => 'استكشف Pro';

  @override
  String get premiumUpgradeBannerHide => 'إخفاء';

  @override
  String get premiumUpgradeBannerHiddenToast =>
      'تم الإخفاء. يمكنك الترقية في أي وقت من الإعدادات.';

  @override
  String get addTransaction => 'إضافة عملية';

  @override
  String get editTransaction => 'تعديل المعاملة';

  @override
  String get debt => 'عليه';

  @override
  String get payment => 'له';

  @override
  String get amount => 'المبلغ';

  @override
  String get itemName => 'اسم الصنف';

  @override
  String get descriptionOptional => 'ملاحظة (اختياري)';

  @override
  String get date => 'التاريخ';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String get saveTransaction => 'حفظ العملية';

  @override
  String get amountRequired => 'المبلغ مطلوب';

  @override
  String get transactionSaved => 'تم حفظ العملية بنجاح';

  @override
  String get creditLimitWarning => 'تنبيه: لقد اقترب الحساب من الحد الائتماني';

  @override
  String get creditLimitExceeded =>
      'تحذير: لقد تجاوز الحساب الحد الائتماني المسموح به!';

  @override
  String get creditLimitCallSheetTitle =>
      'اتصال لإبلاغهم بأن البضائع الجديدة معلّقة حتى السداد؟';

  @override
  String creditLimitCallSheetBody(
    String contactName,
    String outstanding,
    String limit,
  ) {
    return '$contactName مدين بـ $outstanding من حد ائتمان $limit.';
  }

  @override
  String get creditLimitCallSheetPrepare => 'إعداد المكالمة';

  @override
  String get creditLimitCallSheetNotNow => 'ليس الآن';

  @override
  String get creditLimitCallSheetOutstanding => 'المستحق';

  @override
  String get creditLimitCallSheetLimit => 'حد الائتمان';

  @override
  String get creditLimitCallSessionTitle => 'مكالمة الحد الائتماني';

  @override
  String get creditLimitCallSessionInProgress => 'المكالمة قيد التنفيذ';

  @override
  String get creditLimitCallSessionPreparing => 'جاري إعداد المكالمة…';

  @override
  String get creditLimitCallSessionSummaryTitle => 'ملخص المكالمة';

  @override
  String get creditLimitCallSessionDone => 'تم';

  @override
  String get creditLimitCallSessionViewCall => 'عرض المكالمة';

  @override
  String get creditLimitCallSessionResumeChip => 'مكالمة قيد التنفيذ';

  @override
  String creditLimitCallSessionRunId(String id) {
    return 'تشغيل · $id';
  }

  @override
  String get collectionsDeskCreditLimitSubtitle =>
      'تجاوز الحد الائتماني — أكّد التواصل لهذا الحساب.';

  @override
  String get errorCreditLimitNoOutreach =>
      'لا يوجد هاتف أو بريد يمكن استخدامه للتواصل مع هذا الحساب.';

  @override
  String get notificationWarningTitle => 'تنبيه ائتماني';

  @override
  String notificationWarningBody(String contactName) {
    return 'لقد تجاوز حساب $contactName نسبة 80% من الحد الائتماني.';
  }

  @override
  String notificationExceededBody(String contactName) {
    return 'تحذير: حساب $contactName تجاوز الحد الائتماني المسموح به!';
  }

  @override
  String get recentTransactions => 'العمليات الأخيرة';

  @override
  String get transactionsError => 'تعذر تحميل العمليات';

  @override
  String get noLedgersYet => 'لا توجد دفاتر بعد';

  @override
  String get noLedgersSubtitle => 'أنشئ أول دفتر لبدء تتبع الديون.';

  @override
  String get addLedger => 'إضافة دفتر';

  @override
  String get noContactsYet => 'لا توجد حسابات بعد';

  @override
  String get noContactsSubtitle => 'أضف أول حساب لهذا الدفتر.';

  @override
  String get loadingError => 'حدث خطأ ما';

  @override
  String get ledgerDeleted => 'تم حذف الدفتر';

  @override
  String get transactionDeleted => 'تم حذف المعاملة';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get statement => 'كشف حساب';

  @override
  String get statementDetails => 'البيان';

  @override
  String get type => 'النوع';

  @override
  String get description => 'الوصف';

  @override
  String get totalPayment => 'إجمالي الدفعات';

  @override
  String get generatedOn => 'تاريخ الإنشاء';

  @override
  String get runningBalance => 'الرصيد التراكمي';

  @override
  String get page => 'صفحة';

  @override
  String get currency => 'العملة';

  @override
  String get exportStatement => 'تصدير كشف الحساب';

  @override
  String get generatingPdf => 'جاري تجهيز الملف...';

  @override
  String get exportFailed => 'فشل التصدير';

  @override
  String get pdfFetchFailed => 'تعذّر تحميل المعاملات';

  @override
  String get pdfRenderFailed => 'تعذّر إنشاء ملف PDF';

  @override
  String get pdfSaveFailed => 'تعذّر حفظ الملف';

  @override
  String get pdfShareFailed => 'تعذّر فتح خيارات المشاركة';

  @override
  String get pdfTimeout => 'استغرق التصدير وقتاً طويلاً. يرجى المحاولة مجدداً.';

  @override
  String get pdfSavedLocally => 'تم حفظ الكشف على الجهاز';

  @override
  String get pdfPreparingData => 'جاري تحضير البيانات...';

  @override
  String get pdfGroupingTransactions => 'جاري تجميع المعاملات...';

  @override
  String get pdfBuildingLayout => 'جاري بناء التخطيط...';

  @override
  String get pdfRendering => 'جاري إنشاء المستند...';

  @override
  String get pdfComplete => 'تم!';

  @override
  String get pdfSaving => 'جاري الحفظ...';

  @override
  String get shareStatement => 'مشاركة الكشف';

  @override
  String statementShareSubject(String contactName) {
    return 'كشف حساب — $contactName';
  }

  @override
  String get exportStatementDateRange => 'تصدير لفترة تاريخية';

  @override
  String get exportLedgerSummary => 'تصدير ملخص الدفتر';

  @override
  String get ledgerSummaryReport => 'تقرير ملخص الدفتر';

  @override
  String get totalLedgerBalance => 'إجمالي رصيد الدفتر';

  @override
  String get rowNumber => '#';

  @override
  String get pdfListingContacts => 'جاري إدراج الحسابات...';

  @override
  String get pdfGroupingAccounts => 'جاري تجميع الحسابات حسب العملة...';

  @override
  String get shareLedgerSummary => 'مشاركة ملخص الدفتر';

  @override
  String ledgerSummaryShareSubject(String ledgerName) {
    return 'ملخص الدفتر — $ledgerName';
  }

  @override
  String get statementPeriodLabel => 'الفترة';

  @override
  String get pdfNoTransactionsInRange => 'لا توجد معاملات في هذه الفترة.';

  @override
  String get csvImportTitle => 'استيراد CSV';

  @override
  String get csvImportSubtitle =>
      'طابق أعمدة الملف مع حقول الدفتر، تحقق من الترميز بالمعاينة، ثم نفّذ الاستيراد.';

  @override
  String get csvImportSelectFile => 'اختيار ملف CSV';

  @override
  String get csvImportEncoding => 'ترميز النص';

  @override
  String get csvEncodingAuto => 'تلقائي (مُستحسن)';

  @override
  String get csvEncodingUtf8 => 'UTF-8';

  @override
  String get csvEncodingWindows1256 => 'عربي ويندوز (1256)';

  @override
  String get csvImportMappingSection => 'ربط الأعمدة';

  @override
  String get csvImportPreviewSection => 'معاينة أول الصفوف';

  @override
  String get csvImportColumnHint => 'اختر عمود CSV';

  @override
  String get csvImportColumnNone => 'بدون';

  @override
  String get csvImportStart => 'بدء الاستيراد';

  @override
  String get csvImportProgressLabel => 'جاري استيراد الصفوف…';

  @override
  String get csvImportSummaryTitle => 'ملخص الاستيراد';

  @override
  String get csvImportTotalRows => 'إجمالي الصفوف';

  @override
  String get csvImportSuccessLabel => 'نجح الاستيراد';

  @override
  String get csvImportFailureLabel => 'صفوف تم تخطّيها';

  @override
  String get csvImportRowErrors => 'مشاكل في الصفوف';

  @override
  String get csvImportAnotherFile => 'استيراد ملف آخر';

  @override
  String get csvImportFinish => 'تم';

  @override
  String get csvImportNoLedgerMessage =>
      'افتح دفتراً من الرئيسية — يُرفق الاستيراد بدفتر واحد فقط.';

  @override
  String get csvImportMappingIncompleteHint =>
      'اختر عمود CSV لكل الحقول المطلوبة.';

  @override
  String get csvImportReadFailed => 'تعذّر قراءة هذا الملف.';

  @override
  String get csvImportEmptyFile => 'ملف CSV فارغ.';

  @override
  String get csvImportParseWorkerFailed => 'تعذّر تحليل ملف CSV.';

  @override
  String get csvImportStructureFatalPrefix => 'مشكلة في بنية CSV';

  @override
  String get csvImportBlockingFailureTitle => 'تعذّر بدء الاستيراد';

  @override
  String get csvImportSelectedFileLabel => 'الملف المختار';

  @override
  String get csvImportDuplicatesSheetTitle => 'تطابق حسابات موجودة في الدفتر';

  @override
  String csvImportDuplicatesSheetBody(int count) {
    return 'وجدنا $count حساباً في دفترك يُطابق صفوفاً في هذا الملف. يمكن دمج المعاملات الجديدة معها أو تخطِّي تلك الصفوف.';
  }

  @override
  String get csvImportDuplicatesMergeRecommended => 'دمج المعاملات (مُستحسَن)';

  @override
  String get csvImportDuplicatesSkipLabel => 'تخطِّ التكرارات';

  @override
  String get csvImportDuplicatesCancelImport => 'إلغاء الاستيراد';

  @override
  String get csvImportPrefabProgressLabel => 'جاري فحص الملف…';

  @override
  String get csvImportSkippedDuplicatesLabel =>
      'صفوف تم تخطّيها لمطابقتها حسابات موجودة';

  @override
  String get csvImportStepFile => 'الملف';

  @override
  String get csvImportStepMapping => 'الربط';

  @override
  String get csvImportStepImport => 'الاستيراد';

  @override
  String get csvImportStepDone => 'النتيجة';

  @override
  String get csvImportRequiredFieldsLabel => 'حقول مطلوبة';

  @override
  String get csvImportOptionalFieldsLabel => 'حقول اختيارية';

  @override
  String get csvImportFileZoneHint => 'اضغط لاختيار ملف .csv من دفترك السابق';

  @override
  String get csvImportReplaceFile => 'ملف آخر';

  @override
  String get csvImportTargetLedgerLabel => 'الاستيراد إلى';

  @override
  String get csvImportTargetLedgerHint =>
      'ستُضاف الحسابات والمعاملات إلى هذا الدفتر';

  @override
  String get csvImportChooseLedgerTitle => 'اختر الدفتر';

  @override
  String get csvImportNoLedgerSelected => 'اختر دفتراً للمتابعة';

  @override
  String get backupTitle => 'النسخ الاحتياطي والاستعادة';

  @override
  String get backupStatusSafe => 'بياناتك في أمان';

  @override
  String get backupStatusNoBackup => 'لا توجد نسخة احتياطية';

  @override
  String get backupStatusNoBackupSubtitle =>
      'أنشئ نسخة احتياطية لحماية بياناتك.';

  @override
  String get backupLastBackup => 'آخر نسخة احتياطية';

  @override
  String get backupCreateNow => 'إنشاء نسخة احتياطية الآن';

  @override
  String get backupCreating => 'جاري إنشاء النسخة الاحتياطية…';

  @override
  String get backupSuccess => 'تم إنشاء النسخة الاحتياطية بنجاح';

  @override
  String get backupFailed => 'فشل إنشاء النسخة الاحتياطية';

  @override
  String get backupHistory => 'سجل النسخ الاحتياطية';

  @override
  String get backupNoHistory => 'لا توجد نسخ احتياطية بعد';

  @override
  String get backupShare => 'مشاركة';

  @override
  String get backupRestore => 'استعادة';

  @override
  String get backupDelete => 'حذف';

  @override
  String get backupDeleteConfirmTitle => 'حذف النسخة الاحتياطية؟';

  @override
  String get backupDeleteConfirmBody =>
      'سيتم حذف ملف النسخة الاحتياطية من جهازك بشكل نهائي.';

  @override
  String get backupDeleteSuccess => 'تم حذف النسخة الاحتياطية';

  @override
  String get backupDeleteFailed => 'فشل حذف النسخة الاحتياطية';

  @override
  String backupSizeBytes(int size) {
    return '$size بايت';
  }

  @override
  String backupSizeKb(String size) {
    return '$size ك.ب';
  }

  @override
  String backupSizeMb(String size) {
    return '$size م.ب';
  }

  @override
  String get backupRestoreWarningTitle => '⚠ تحذير: إجراء خطير';

  @override
  String get backupRestoreWarningBody =>
      'سيؤدي ذلك إلى استبدال قاعدة البيانات الحالية بالكامل. أي بيانات أضفتها بعد هذه النسخة الاحتياطية ستُفقد إلى الأبد. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get backupRestoreConfirm => 'أفهم — قم بالاستعادة';

  @override
  String get backupRestoreCancel => 'إلغاء';

  @override
  String get backupRestoring => 'جاري الاستعادة…';

  @override
  String get backupRestoreSuccess => 'تمت الاستعادة';

  @override
  String get backupRestoreSuccessBody =>
      'تم استعادة بياناتك. يجب إعادة تشغيل التطبيق لتطبيق التغييرات.';

  @override
  String get backupRestoreRestartNow => 'إعادة التشغيل الآن';

  @override
  String get backupRestoreFailed => 'فشلت الاستعادة';

  @override
  String get backupRestoreFromFile => 'الاستعادة من ملف خارجي';

  @override
  String get backupReminderLabel => 'تذكير النسخ الاحتياطي التلقائي';

  @override
  String get backupReminderOff => 'إيقاف';

  @override
  String get backupReminderWeekly => 'أسبوعي';

  @override
  String get backupReminderMonthly => 'شهري';

  @override
  String get backupShareSubject => 'ملف نسخة دفتر الاحتياطية';

  @override
  String get backupTrustEncrypted => 'مشفّر بـ AES-256 على جهازك';

  @override
  String get backupTrustDrivePrivate =>
      'يُحفظ في مجلد دفتر الخاص في Google Drive — لا يطّلع عليه أحد غيرك.';

  @override
  String get backupRelativeJustNow => 'الآن';

  @override
  String backupRelativeMinutes(int count) {
    return 'منذ $count د';
  }

  @override
  String backupRelativeHours(int count) {
    return 'منذ $count س';
  }

  @override
  String get backupRelativeYesterday => 'أمس';

  @override
  String backupRelativeDays(int count) {
    return 'منذ $count أيام';
  }

  @override
  String get backupHealthLocal => 'محلي';

  @override
  String get backupHealthCloud => 'سحابي';

  @override
  String backupTotalSize(int count, String size) {
    return '$count نسخ · $size';
  }

  @override
  String get backupStatusLocalOnly =>
      'نسخة محلية نشطة — المزامنة السحابية معلّقة';

  @override
  String get backupTimelineLatest => 'الأحدث';

  @override
  String get backupTimelineSwipeHint => 'اسحب لتصفّح سجل النسخ الاحتياطية';

  @override
  String get backupCeremonyTitle => 'طقس الخزنة';

  @override
  String get backupCeremonyValidating => 'جاري التحقق من السلامة…';

  @override
  String get backupCeremonyDecrypting => 'جاري فك تشفير الدفتر…';

  @override
  String get backupCeremonyApplying => 'جاري التطبيق على الخزنة…';

  @override
  String get backupCeremonyDownloading => 'جاري التنزيل من السحابة…';

  @override
  String get backupCreateSuccessBody => 'تم ختم دفترك وحفظه بأمان.';

  @override
  String get backupDriveSectionTitle => 'Google Drive';

  @override
  String get backupDriveInviteBody =>
      'انسخ بياناتك احتياطيًا إلى Google Drive الشخصي — مجانًا ومشفّرًا وخاصًا.';

  @override
  String get backupDriveSignInWithGoogle => 'تسجيل الدخول عبر Google';

  @override
  String get backupDriveBackupToDrive => 'نسخ احتياطي إلى Drive';

  @override
  String get backupDriveRestoreFromDrive => 'استعادة من Drive';

  @override
  String get backupDriveCloudBackups => 'النسخ الاحتياطية السحابية';

  @override
  String get backupDriveNoCloudBackups =>
      'لا توجد نسخ احتياطية في Google Drive بعد';

  @override
  String get backupDriveSignOut => 'تسجيل الخروج من Google';

  @override
  String get backupDriveUploading => 'جاري الرفع إلى Google Drive…';

  @override
  String get backupDriveDownloading => 'جاري التنزيل من Google Drive…';

  @override
  String get backupDriveCancel => 'إلغاء';

  @override
  String backupDrivePercent(int percent) {
    return '$percent٪';
  }

  @override
  String get backupDrivePendingRetry =>
      'النسخ الاحتياطي معلّق — سيُعاد تلقائيًا عند عودة الاتصال';

  @override
  String get backupDriveRetryNow => 'إعادة المحاولة الآن';

  @override
  String get backupDriveQuotaExceeded =>
      'مساحة Google Drive ممتلئة. حرّر مساحة أو أدِر النسخ القديمة';

  @override
  String get backupDriveManageBackups => 'إدارة النسخ الاحتياطية';

  @override
  String get backupDriveAuthExpired =>
      'انتهت جلسة Google. سجّل الدخول مجددًا للمتابعة.';

  @override
  String get backupDriveOffline =>
      'لا يوجد اتصال بالإنترنت. سيستأنف النسخ الاحتياطي عند عودة الشبكة.';

  @override
  String get backupDriveSignInAgain => 'تسجيل الدخول مجددًا';

  @override
  String get backupDriveOfflineGrantMissing =>
      'إذن النسخ الاحتياطي الدائم غير مكتمل. امنح صلاحية Drive مرة واحدة ليستمر النسخ التلقائي حتى مع إغلاق التطبيق.';

  @override
  String get backupDriveOfflineGrantAction => 'إكمال الآن';

  @override
  String get backupDriveOfflineGrantFailed =>
      'لم يكتمل تفويض Drive. تحقق من الاتصال وحاول مجددًا.';

  @override
  String get backupDriveNotificationPermissionDenied =>
      'الإشعارات متوقفة. فعّلها من إعدادات النظام ليصلك تنبيه عند تشغيل أو فشل النسخ الاحتياطي التلقائي.';

  @override
  String get backupDriveNotificationPermissionOpenSettings => 'فتح الإعدادات';

  @override
  String get backupDriveBatteryOptTitle => 'السماح بالنسخ في الخلفية';

  @override
  String get backupDriveBatteryOptBody =>
      'على هذا الهاتف قد توقف قيود البطارية النسخ التلقائي إلى Drive أثناء إغلاق التطبيق. اسمح ببطارية غير مقيّدة ليستمر النسخ والجهاز يعمل ومتصل بالإنترنت.';

  @override
  String get backupDriveBatteryOptAllow => 'السماح ببطارية غير مقيّدة';

  @override
  String get backupDriveBatteryOptLater => 'ليس الآن';

  @override
  String get backupDriveTimingHonesty =>
      'يعمل تقريباً كل فترة بينما الهاتف يعمل ومتصل وليس متوقفاً بالقوة — وليس أثناء إطفاء الجهاز.';

  @override
  String get backupDriveDeleteRemoteTitle => 'حذف النسخة السحابية؟';

  @override
  String get backupDriveDeleteRemoteBody =>
      'سيُزال هذا الملف نهائيًا من Google Drive.';

  @override
  String get backupDriveUploadSuccess => 'تم الرفع إلى Google Drive';

  @override
  String get backupDriveUploadFailed => 'فشل الرفع إلى Drive';

  @override
  String get backupDriveDeleteRemoteSuccess => 'تم حذف النسخة السحابية';

  @override
  String get backupDriveDeleteRemoteFailed => 'فشل حذف النسخة السحابية';

  @override
  String get backupDriveSignInSuccess => 'تم تسجيل الدخول عبر Google';

  @override
  String get backupDriveSignInFailed => 'فشل تسجيل الدخول عبر Google';

  @override
  String get syncAuthBridgeFailed =>
      'تعذّر الاتصال بخادوم المزامنة. حاول مرة أخرى لاحقًا.';

  @override
  String get inviteCeremonyTitle => 'الدعوة';

  @override
  String get inviteCeremonyExpiredTitle => 'انتهت صلاحية هذه الدعوة';

  @override
  String get inviteCeremonyExpiredBody =>
      'اطلب من صاحب المحل إرسال رابط دعوة جديد. يمكنك طلب ذلك من الزر أدناه.';

  @override
  String get inviteCeremonyRevokedTitle => 'هذه الدعوة لم تعد صالحة';

  @override
  String get inviteCeremonyRevokedBody =>
      'تم إلغاء الرابط أو أنه غير متاح. اطلب دعوة جديدة من صاحب المحل.';

  @override
  String get inviteCeremonyAlreadyClaimedTitle => 'تم استخدام الدعوة مسبقًا';

  @override
  String get inviteCeremonyAlreadyClaimedBody =>
      'شخص آخر قبل هذه الدعوة. اطلب دعوة جديدة إن كنت ما زلت بحاجة للوصول.';

  @override
  String get inviteCeremonyAlreadyClaimedByYouTitle => 'قبلت هذه الدعوة مسبقًا';

  @override
  String get inviteCeremonyAlreadyClaimedByYouBody =>
      'تم المطالبة بهذا الرابط على حسابك. افتح التطبيق كالمعتاد أو اطلب دعوة جديدة إن تعذّر الوصول.';

  @override
  String get inviteCeremonyRequestCta => 'طلب دعوة جديدة';

  @override
  String get inviteCeremonyPendingBody =>
      'تم حفظ الطلب. اطلب من صاحب المحل فتح «الفريق» وإعادة إرسال الدعوة.';

  @override
  String get inviteCeremonyOpenHome => 'فتح دفتر';

  @override
  String get inviteCeremonyManualCodeLabel => 'لديك رمز دعوة؟';

  @override
  String get inviteCeremonyManualCodeHint => 'الصق رمز الدعوة أو الرابط الكامل';

  @override
  String get inviteCeremonyPasteClipboard => 'لصق';

  @override
  String get inviteCeremonySubmitCode => 'متابعة';

  @override
  String get inviteAcceptTitle => 'دعوة للفريق';

  @override
  String get inviteAcceptPreviewTitle => 'تمت دعوتك';

  @override
  String get inviteAcceptPreviewBody =>
      'سجّل الدخول بحساب Google الذي تلقّى هذه الدعوة للانضمام إلى مساحة العمل.';

  @override
  String get inviteAcceptInvitedEmailLabel => 'البريد المدعو';

  @override
  String get inviteAcceptRoleLabel => 'الدور';

  @override
  String get inviteAcceptCta => 'تسجيل الدخول بـ Google للقبول';

  @override
  String get inviteAcceptInProgress => 'جارٍ الانضمام…';

  @override
  String inviteAcceptEmailMismatch(String email) {
    return 'حساب Google هذا لا يطابق البريد المدعو. سجّل الدخول بـ $email.';
  }

  @override
  String get inviteAcceptErrorGeneric =>
      'تعذّر قبول الدعوة. أعد المحاولة أو اطلب رابطًا جديدًا من صاحب المحل.';

  @override
  String get inviteAcceptSuccessTitle => 'تم بنجاح';

  @override
  String inviteAcceptSuccessBody(String role) {
    return 'انضممت إلى مساحة العمل بدور $role. ستبدأ المزامنة عند الاتصال بالإنترنت.';
  }

  @override
  String get inviteAcceptContinueHome => 'فتح دفتر';

  @override
  String get syncReportConnectionRefused =>
      'تعذّر الوصول إلى خادوم المزامنة. تأكد أن هاتفك والحاسوب على نفس شبكة الواي فاي وأن خادوم Supabase المحلي يعمل.';

  @override
  String get syncReportSyncNow => 'مزامنة الآن';

  @override
  String get syncReportSyncNowInProgress => 'جاري المزامنة…';

  @override
  String get syncReportUpload => 'رفع';

  @override
  String get syncReportUploadInProgress => 'جاري الرفع…';

  @override
  String get syncReportDownload => 'تنزيل';

  @override
  String get syncReportDownloadInProgress => 'جاري التنزيل…';

  @override
  String syncReportPushSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم رفع $count تغيير',
      one: 'تم رفع تغيير واحد',
      zero: 'لا يوجد شيء لرفعه',
    );
    return '$_temp0';
  }

  @override
  String syncReportPullSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تنزيل $count تغيير',
      one: 'تم تنزيل تغيير واحد',
      zero: 'لا توجد تغييرات جديدة',
    );
    return '$_temp0';
  }

  @override
  String get syncReportPushFailed =>
      'فشل الرفع. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get syncReportPullFailed =>
      'فشل التنزيل. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get syncReportDeviceRegistrationFailed =>
      'تعذّر تسجيل هذا الجهاز على خادوم المزامنة.';

  @override
  String get syncReportStatusIdle => 'في انتظار أول مزامنة';

  @override
  String get syncReportTitle => 'تقرير المزامنة';

  @override
  String get syncReportStatusLoadFailed => 'تعذّر تحميل حالة المزامنة';

  @override
  String get syncReportStatusSuccess => 'مزامنة ناجحة';

  @override
  String get syncReportStatusPartial => 'مزامنة جزئية — يوجد تعارضات';

  @override
  String get syncReportStatusFailed => 'فشلت المزامنة';

  @override
  String get syncReportStatusDormant => 'المزامنة غير نشطة';

  @override
  String get syncReportConflictsHeading => 'تعارضات تحتاج مراجعة';

  @override
  String get syncReportStatMerged => 'عمليات مدمجة';

  @override
  String get syncReportStatPending => 'قيد الانتظار';

  @override
  String get syncReportStatConflicts => 'تعارضات';

  @override
  String get syncReportConflictDeleteVsEdit => 'حذف مقابل تعديل';

  @override
  String get syncReportConflictConcurrentCreate => 'إنشاء متزامن';

  @override
  String get syncReportConflictAmbiguous => 'تعارض غير محدد';

  @override
  String get syncReportConflictRejectedPush => 'رفضه الخادم';

  @override
  String get syncReportEntityLedger => 'دفتر';

  @override
  String get syncReportEntityContact => 'جهة اتصال';

  @override
  String get syncReportEntityTransaction => 'معاملة';

  @override
  String get syncReportNoConflicts => 'لا توجد تعارضات — جميع البيانات متزامنة';

  @override
  String get syncReportDormantTitle => 'مزامنة متعددة الأجهزة';

  @override
  String get syncReportDormantBody =>
      'قم بالترقية إلى Pro+ لمزامنة بياناتك عبر أجهزة متعددة';

  @override
  String get backupDriveSignOutSuccess => 'تم تسجيل الخروج من Google';

  @override
  String get backupDriveSignOutFailed => 'فشل تسجيل الخروج';

  @override
  String get backupDriveRestorePickTitle => 'اختر نسخة احتياطية للاستعادة';

  @override
  String get backupDriveRestoreLoading =>
      'جاري تحميل النسخ الاحتياطية من Google Drive…';

  @override
  String backupDriveRestorePickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نسخة احتياطية',
      one: 'نسخة احتياطية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get backupDriveRestorePickDate => 'اختر تاريخاً';

  @override
  String get backupDriveRestoreClearDate => 'كل التواريخ';

  @override
  String get backupDriveRestoreDateEmpty =>
      'لا توجد نسخ احتياطية في هذا التاريخ';

  @override
  String backupDriveCloudBackupsPreviewFootnote(int shown, int total) {
    return 'عرض أحدث $shown من $total. استخدم «استعادة من Drive» لتصفح كل النسخ حسب التاريخ.';
  }

  @override
  String get backupDriveAutoBackupLabel => 'نسخ احتياطي تلقائي إلى Drive';

  @override
  String get backupDriveAutoBackupInterval => 'فترة النسخ الاحتياطي';

  @override
  String get backupDriveAutoBackupDaily => 'يومي';

  @override
  String get backupDriveAutoBackupWeekly => 'أسبوعي';

  @override
  String get backupDriveHiddenFolderHint =>
      'تُخزَّن النسخ الاحتياطية في مجلد مخفي وآمن داخل Google Drive لمنع الحذف العرضي.';

  @override
  String backupDriveAutoBackupLastRun(String when) {
    return 'آخر نسخ احتياطي تلقائي: $when';
  }

  @override
  String get backupDriveAutoBackupNeverRun =>
      'لم يُنفَّذ نسخ احتياطي تلقائي بعد';

  @override
  String get backupDriveAutoBackupIosHint =>
      'على iPhone، يحدّد النظام موعد النسخ الاحتياطي تلقائيًا عندما يكون ذلك مناسبًا للبطارية.';

  @override
  String get backupAutoNotifInProgressTitle => 'نسخ احتياطي تلقائي';

  @override
  String get backupAutoNotifInProgressBody =>
      'جاري رفع نسخة دفتر الاحتياطية إلى Google Drive…';

  @override
  String get backupAutoNotifSuccessTitle => 'اكتمل النسخ الاحتياطي التلقائي';

  @override
  String get backupAutoNotifSuccessBody =>
      'تم حفظ نسختك المشفّرة في Google Drive بنجاح.';

  @override
  String get backupAutoNotifRetryTitle => 'النسخ الاحتياطي معلّق';

  @override
  String get backupAutoNotifRetryBody =>
      'لا يوجد اتصال بالإنترنت. سيُعاد الرفع تلقائيًا عند عودة الشبكة.';

  @override
  String get backupAutoNotifNeedsReauthTitle => 'يلزم تسجيل الدخول مجددًا';

  @override
  String get backupAutoNotifNeedsReauthBody =>
      'انتهت جلسة Google. افتح دفتر وسجّل الدخول لاستئناف النسخ الاحتياطي التلقائي.';

  @override
  String get backupAutoNotifQuotaTitle => 'مساحة Google Drive ممتلئة';

  @override
  String get backupAutoNotifQuotaBody =>
      'حرّر مساحة في Drive أو احذف نسخ دفتر القديمة من الإعدادات.';

  @override
  String get backupAutoNotifStorageFullTitle => 'مساحة الجهاز غير كافية';

  @override
  String get backupAutoNotifStorageFullBody =>
      'لا يمكن إنشاء نسخة احتياطية. حرّر مساحة على جهازك ثم أعد المحاولة.';

  @override
  String get backupAutoNotifFailedTitle => 'فشل النسخ الاحتياطي التلقائي';

  @override
  String get backupAutoNotifFailedBody =>
      'تعذّر رفع النسخة الاحتياطية. افتح دفتر للاطلاع على التفاصيل.';

  @override
  String get smokeTestTitle => 'اختبار السحابة';

  @override
  String get smokeTestButton => 'تشغيل اختبار السحابة';

  @override
  String get smokeTestSubtitle => 'تحقق من تسجيل الدخول بـ Google و Drive';

  @override
  String get smokeTestRunning => 'جاري التشخيص…';

  @override
  String get smokeTestComplete => 'اكتمل التشخيص';

  @override
  String get smokeTestClose => 'إغلاق';

  @override
  String get preflightSignIn => 'تسجيل دخول تفاعلي';

  @override
  String get preflightDriveRoundTrip => 'اختبار Drive الكامل';

  @override
  String get preflightSilentSignIn => 'تسجيل دخول صامت';

  @override
  String get preflightSignOut => 'تسجيل الخروج';

  @override
  String get preflightConsoleTitle => 'سجل التشخيص';

  @override
  String get preflightClearLog => 'مسح السجل';

  @override
  String get premiumTitle => 'الخطط';

  @override
  String get premiumHeroTitle => 'اختر الخطة المناسبة لمتجرك';

  @override
  String get premiumHeroTagline =>
      'حدود واضحة في المجاني. مساحة عمل بلا سقف في Pro. مزامنة وأتمتة في Pro+.';

  @override
  String get premiumHeroTaglineContest =>
      'حدود واضحة في المجاني. مساحة عمل بلا سقف في Pro. تحليلات وأتمتة في Pro+.';

  @override
  String get premiumVaultSealTitle => 'رمز التفعيل';

  @override
  String get premiumVaultSealSubtitle =>
      'أدخل رمز Pro أو Pro+. تظهر الشرطات أثناء الكتابة.';

  @override
  String get premiumTrustEncrypted => 'تشفير AES-256 على جهازك قبل أي رفع';

  @override
  String get premiumTrustOffline =>
      'الخطط تعمل دون إنترنت — يُزامَن التفعيل عند عودة الاتصال';

  @override
  String get activationBrowsePlans => 'تصفّح الخطط';

  @override
  String get activationCodeLabel => 'رمز التفعيل';

  @override
  String get activationCodeHint => 'PROPLUS-XXXX-XXXX-XXXX-XXXX';

  @override
  String get activationHaveCode => 'إضافة رمز تفعيل';

  @override
  String get activationAddCode => 'إضافة رمز تفعيل';

  @override
  String get activateButton => 'تفعيل';

  @override
  String get activating => 'جاري التفعيل…';

  @override
  String get activationSuccessTitle => 'تم تفعيل الخطة';

  @override
  String get activationSuccessSubtitle =>
      'خطتك الجديدة جاهزة. استمتع بقوة دفترك الكاملة.';

  @override
  String get activationSuccessDone => 'متابعة';

  @override
  String get activationErrorInvalid =>
      'رمز غير صالح. تحقق من الرمز وحاول مجدداً.';

  @override
  String get planStatusTitle => 'خطتك';

  @override
  String get planTierFree => 'مجاني';

  @override
  String get planTierPro => 'Pro';

  @override
  String get planTierProPlus => 'Pro+';

  @override
  String get planLegendCurrent => 'الحالية';

  @override
  String planExpiresOn(Object date) {
    return 'ينتهي في $date';
  }

  @override
  String planDaysRemaining(Object count) {
    return 'متبقي $count يوماً';
  }

  @override
  String get planLifetime => 'اشتراك نشط';

  @override
  String get tierCompareFree => 'مجاني';

  @override
  String get tierComparePro => 'Pro';

  @override
  String get tierCompareProPlus => 'Pro+';

  @override
  String get tierPriceFree => '0 \$';

  @override
  String get freeTierPrice => 'مجاني';

  @override
  String get tierPricePro => '24.99\$/سنة';

  @override
  String get tierPriceProPlus => '49.99\$/سنة';

  @override
  String get tierPriceProAmount => '\$24.99';

  @override
  String get tierPriceProPeriod => '/سنة';

  @override
  String get tierPriceProPlusAmount => '\$49.99';

  @override
  String get tierPriceProPlusPeriod => '/سنة';

  @override
  String get tierBadgeSavePro => 'وفّر 20٪';

  @override
  String get tierBadgeSaveProPlus => 'الأقوى';

  @override
  String get tierBadgeRecommended => 'موصى بها';

  @override
  String get tierCardHighlightFree1 => 'دفتر واحد و50 حساباً';

  @override
  String get tierCardHighlightFree2 => '500 معاملة نشطة';

  @override
  String get tierCardHighlightFree3 => 'استيراد CSV مجاناً';

  @override
  String get tierCardHighlightPro1 => 'مساحة عمل غير محدودة';

  @override
  String get tierCardHighlightPro2 => 'كشوف PDF بعلامتك التجارية';

  @override
  String get tierCardHighlightProPlus1 => 'كل مزايا Pro';

  @override
  String get tierCardHighlightProPlus2 => 'مزامنة متعددة الأجهزة';

  @override
  String get tierCardHighlightProPlus2Contest => 'مكتب تحصيل الوكيل الذكي';

  @override
  String get tierCardHighlightProPlus3 => 'وكيل الإغلاق — صوت وطقوس';

  @override
  String get tierCardCtaFree => 'استمر مجاناً';

  @override
  String get tierCardCtaPro => 'فعّل Pro';

  @override
  String get tierCardCtaProPlus => 'فعّل Pro+';

  @override
  String get tierCardCurrentPlan => 'خطتك الحالية';

  @override
  String get tierCardTaglineFree => 'كل ما تحتاجه للبداية';

  @override
  String get tierCardTaglinePro => 'للمتاجر النامية — بلا سقف';

  @override
  String get tierCardTaglineProPlus => 'مزامنة متعددة الأجهزة والأتمتة';

  @override
  String get tierCardTaglineProPlusContest => 'وكيل الإغلاق والتحصيل';

  @override
  String get tierCardBilledAnnually => 'يُدفع سنوياً';

  @override
  String get tierCardOldPricePro => '\$31.99';

  @override
  String get tierCardOldPriceProPlus => '\$62.99';

  @override
  String get tierCompareTitle => 'قارن المزايا';

  @override
  String get tierCompareSubtitle => 'اضغط فئة لعرض ما تتضمنه كل خطة';

  @override
  String get tierMatrixGroupWorkspace => 'مساحة العمل';

  @override
  String get tierMatrixGroupData => 'البيانات والنسخ الاحتياطي';

  @override
  String get tierMatrixGroupCloud => 'السحابة والأتمتة';

  @override
  String get tierMatrixGroupGrowth => 'نموّ الأعمال';

  @override
  String get tierBadgeFree => 'مجاني';

  @override
  String get tierBadgeComingSoon => 'قريباً';

  @override
  String get tierFeatureWorkspaceLimits => 'الدفاتر والحسابات والمعاملات';

  @override
  String get tierFeatureBackupLocalCloud =>
      'نسخ احتياطي محلي وسحابي عبر Google Drive';

  @override
  String get tierFeatureDataExport => 'كشوف PDF';

  @override
  String get tierFeatureAiVoice => 'الإدخال الصوتي بالذكاء الاصطناعي';

  @override
  String get tierFeatureWhatsappStatements => 'كشوف واتساب شهرية آلية';

  @override
  String get tierFeatureAnalyticsDashboard =>
      'لوحة تحليلات ورسوم بيانية متقدمة';

  @override
  String get tierFeatureStoreBranding => 'هوية متجرك على التقارير المصدّرة';

  @override
  String get tierFeatureCustomerPortal => 'بوابة لحظية للعملاء';

  @override
  String get tierValueBasicPdf => 'PDF أساسي';

  @override
  String get tierValueBrandedExport => 'PDF بعلامتك';

  @override
  String get tierFeatureLedgers => 'دفاتر نشطة';

  @override
  String get tierFeatureContacts => 'حسابات نشطة';

  @override
  String get tierFeatureTransactions => 'معاملات نشطة';

  @override
  String get tierFeatureCsvImport => 'استيراد CSV';

  @override
  String get tierFeatureBrandedPdf => 'كشوف PDF بعلامتك';

  @override
  String get tierFeatureLedgerArchiving => 'أرشفة الدفاتر واستعادتها';

  @override
  String get tierFeatureSync => 'مزامنة متعددة الأجهزة';

  @override
  String get tierFeatureWhatsapp => 'أتمتة واتساب';

  @override
  String get tierFeatureAnalytics => 'تحليلات متقدمة';

  @override
  String get tierFeaturePortal => 'بوابة العملاء';

  @override
  String get tierUnlimited => 'غير محدود';

  @override
  String get tierValueStarter => '1 / 50 / 500';

  @override
  String get tierLimitLedgersFree => '1';

  @override
  String get tierLimitContactsFree => '50';

  @override
  String get tierLimitTransactionsFree => '500';

  @override
  String get manageSubscriptionTitle => 'الخطة والتفعيل';

  @override
  String get manageSubscriptionSubtitle =>
      'اعرض خطتك، فعّل رمزاً، أو قارن الباقات.';

  @override
  String get manageSubscriptionCta => 'فتح مركز الخطط';

  @override
  String get limitUpsellTitle => 'تجاوزت حد المجاني';

  @override
  String get limitUpsellSubtitle =>
      'رقِّ إلى Pro لمساحة عمل غير محدودة — الاستيراد يبقى مجانياً دائماً.';

  @override
  String limitUpsellProgress(Object current, Object max) {
    return '$current من $max مستخدم';
  }

  @override
  String get limitUpsellCta => 'فعّل Pro';

  @override
  String get limitUpsellDismiss => 'ليس الآن';

  @override
  String get premiumBadgeFree => 'مجاني';

  @override
  String get premiumBadgePro => 'Pro';

  @override
  String get premiumBadgeProPlus => 'Pro+';

  @override
  String get securityTitle => 'الأمان';

  @override
  String get securitySubtitle => 'احمِ دفترك برمز PIN وفتح القفل بالبصمة.';

  @override
  String get securityAppLockTitle => 'قفل التطبيق (PIN)';

  @override
  String get securityAppLockSubtitle =>
      'يطلب رمز PIN عند العودة إلى دفتر بعد مهلة.';

  @override
  String get securityChangePinTitle => 'تغيير الرمز';

  @override
  String get securityChangePinSubtitle => 'حدّث رمز فتح القفل';

  @override
  String get securityBiometricTitle => 'فتح بالبصمة';

  @override
  String get securityBiometricSubtitle =>
      'استخدم البصمة أو Face ID عند التوفّر';

  @override
  String get securityBiometricEnrollReason =>
      'تحقق من هويتك لتفعيل فتح القفل بالبصمة في دفتر';

  @override
  String get securityBiometricRequiresAppLock =>
      'فعّل قفل التطبيق أولاً لاستخدام فتح القفل بالبصمة.';

  @override
  String get securityTimeoutTitle => 'قفل تلقائي';

  @override
  String get securityTimeoutSubtitle =>
      'مدة بقاء التطبيق في الخلفية قبل إعادة القفل';

  @override
  String get securityTimeoutImmediate => 'فوراً';

  @override
  String get securityTimeoutOneMinute => '1 د';

  @override
  String get securityTimeoutFiveMinutes => '5 د';

  @override
  String get securityTimeoutFifteenMinutes => '15 د';

  @override
  String get securityPinCreateTitle => 'إنشاء رمز PIN';

  @override
  String get securityPinConfirmTitle => 'تأكيد الرمز';

  @override
  String get securityPinChangeTitle => 'تغيير الرمز';

  @override
  String get securityPinCurrentTitle => 'الرمز الحالي';

  @override
  String get securityPinNewTitle => 'رمز جديد';

  @override
  String get securityPinDisableTitle => 'أدخل الرمز للإيقاف';

  @override
  String get securityPinSubtitle => 'اختر رمزاً من 4 أرقام';

  @override
  String get securityPinConfirmSubtitle => 'أعد إدخال نفس الرمز';

  @override
  String get securityPinCurrentSubtitle => 'أدخل رمزك الحالي';

  @override
  String get securityPinDisableSubtitle => 'تحقق من الرمز لإيقاف قفل التطبيق';

  @override
  String get securityPinHint => '4 أرقام';

  @override
  String get securityPinMismatch => 'الرمزان غير متطابقين. حاول مجدداً.';

  @override
  String get securityPinIncorrect => 'رمز غير صحيح';

  @override
  String get securityPinLockedOut => 'محاولات كثيرة. انتظر ثم حاول.';

  @override
  String get securityPinInvalid => 'يجب أن يكون الرمز 4 أرقام';

  @override
  String get securityPinSaveFailed => 'تعذّر حفظ إعدادات الأمان';

  @override
  String get securitySettingsError => 'حدث خطأ. حاول مجدداً.';

  @override
  String get securityStatusProtected => 'محمي بالكامل';

  @override
  String get securityStatusProtectedSubtitle =>
      'رمز PIN وفتح القفل بالبصمة مفعّلان';

  @override
  String get securityStatusPinOnly => 'محمي برمز PIN';

  @override
  String get securityStatusPinOnlySubtitle => 'يُقفل دفترك عند مغادرة التطبيق';

  @override
  String get securityStatusUnprotected => 'لا يوجد قفل';

  @override
  String get securityStatusUnprotectedSubtitle =>
      'أي شخص يملك هاتفك يمكنه فتح دفتر';

  @override
  String get securityGroupAccess => 'التحكم بالوصول';

  @override
  String get securityGroupAutoLock => 'قفل تلقائي';

  @override
  String get securityTrustPinSecure =>
      'يُخزَّن الرمز مشفّراً في الخزنة الآمنة للجهاز — وليس في قاعدة البيانات';

  @override
  String get securityTrustBiometricLocal =>
      'بيانات البصمة لا تغادر جهازك أبداً';

  @override
  String get securityHeroPinRing => 'PIN';

  @override
  String get securityHeroBiometricRing => 'بصمة';

  @override
  String get lockScreenTitle => 'دفتر مقفل';

  @override
  String get lockScreenSubtitle => 'أدخل رمز PIN للمتابعة';

  @override
  String get lockScreenBiometricRetry => 'فتح بالبصمة';

  @override
  String get lockScreenForgotPin => 'نسيت رمز الدخول؟';

  @override
  String get lockScreenForgotPinTitle => 'مسح البيانات المحلية؟';

  @override
  String get lockScreenForgotPinBody =>
      'لحماية معلوماتك، استعادة الوصول بدون الرمز سيمسح نهائياً كل البيانات على هذا الجهاز—الدفاتر والجهات والمعاملات. يجب أن يكون لديك ملف نسخ احتياطي بصيغة .daftar لاستعادة سجلاتك. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get lockScreenForgotPinCta => 'مسح البيانات والمتابعة';

  @override
  String get lockScreenForgotPinTypeCode => 'اكتب هذا الرمز للتأكيد';

  @override
  String get lockScreenForgotPinCodeHint => 'أدخل الرمز المكوّن من 4 أرقام';

  @override
  String get lockScreenForgotPinPreparing => 'جارٍ تجهيز بيئة آمنة…';

  @override
  String get fatalErrorTitle => 'عذراً، حدث خطأ غير متوقع';

  @override
  String get fatalErrorBody => 'لا تقلق، جميع بياناتك ودفاترك في أمان تام.';

  @override
  String get fatalErrorRestart => 'إعادة تشغيل التطبيق';

  @override
  String get errorSheetDismiss => 'حسناً';

  @override
  String get errorGenericTitle => 'حدث خطأ ما';

  @override
  String get errorGenericMessage =>
      'تعذّر إتمام هذا الإجراء. يُرجى المحاولة مرة أخرى.';

  @override
  String get errorValidationTitle => 'تحقق من المدخلات';

  @override
  String get errorValidationMessage => 'يُرجى تصحيح بعض التفاصيل قبل المتابعة.';

  @override
  String get errorDatabaseTitle => 'تعذّر حفظ التغييرات';

  @override
  String get errorDatabaseMessage =>
      'بياناتك في أمان. يُرجى المحاولة بعد قليل.';

  @override
  String get errorNetworkTitle => 'مشكلة في الاتصال';

  @override
  String get errorNetworkMessage => 'تحقق من اتصال الإنترنت وحاول مجدداً.';

  @override
  String get errorRateLimitedTitle => 'طلبات كثيرة جداً';

  @override
  String get errorRateLimitedMessage =>
      'أرسلت عدة دعوات خلال وقت قصير. انتظر قليلاً ثم حاول مجدداً.';

  @override
  String errorRateLimitedMessageWithRetry(int minutes) {
    return 'أرسلت عدة دعوات خلال وقت قصير. حاول مجدداً بعد نحو $minutes دقيقة.';
  }

  @override
  String get errorSeatCapTitle => 'الفريق مكتمل';

  @override
  String errorSeatCapMessage(int maxWorkers) {
    return 'يمكنك دعوة حتى $maxWorkers عاملين في برو+. أزل عاملاً معلقاً أو نشطاً لدعوة شخص آخر.';
  }

  @override
  String get errorForbiddenTitle => 'غير مسموح';

  @override
  String get errorForbiddenMessage =>
      'صلاحيتك في مساحة العمل لا تسمح بهذا الإجراء. اطلب الإذن من مالك مساحة العمل.';

  @override
  String get errorInvalidRequestMessage =>
      'لم يُقبل هذا الطلب. حدّث التطبيق ثم أعد المحاولة.';

  @override
  String get errorInvalidActionMessage =>
      'تعذّرت مزامنة هذا التغيير لأن الخادم لم يتعرّف عليه. حدّث التطبيق ثم أعد المحاولة.';

  @override
  String get errorNotFoundMessage => 'لم نعثر على هذا العنصر. ربما تم حذفه.';

  @override
  String get errorConflictMessage =>
      'قام شخص آخر بتعديل هذا قبلك. حدّث الصفحة ثم أعد المحاولة.';

  @override
  String get errorServerMessage =>
      'واجه خادم المزامنة مشكلة. بياناتك محفوظة على هذا الجهاز — أعد المحاولة لاحقاً.';

  @override
  String get errorServiceUnavailableMessage =>
      'خادم المزامنة غير متاح مؤقتاً. بياناتك محفوظة على هذا الجهاز.';

  @override
  String get errorDeviceCapMessage =>
      'وصلت إلى عدد الأجهزة المسموح به في مساحة العمل. أزل جهازاً لإضافة آخر.';

  @override
  String get errorSyncEventCapMessage =>
      'بلغت مساحة العمل حد المزامنة الشهري. ستُستأنف المزامنة الشهر القادم.';

  @override
  String get errorStorageTitle => 'مشكلة في التخزين';

  @override
  String get errorStorageMessage =>
      'تعذّر الوصول إلى مساحة الجهاز. حرّر مساحة إن لزم، ثم أعد المحاولة.';

  @override
  String get errorAuthTitle => 'يلزم تسجيل الدخول';

  @override
  String get errorAuthMessage => 'يُرجى تسجيل الدخول مجدداً للمتابعة.';

  @override
  String get errorInvalidAmountTitle => 'مبلغ غير صالح';

  @override
  String get errorInvalidAmountMessage => 'أدخل مبلغاً صحيحاً أكبر من صفر.';

  @override
  String get errorQuotaExceededTitle => 'المساحة ممتلئة';

  @override
  String get errorQuotaExceededMessage =>
      'مساحة التخزين السحابي ممتلئة. حرّر مساحة وحاول مجدداً.';

  @override
  String get errorContactNameExists => 'يوجد حساب بهذا الاسم في الدفتر بالفعل.';

  @override
  String get errorExportFailedTitle => 'تعذّر التصدير';

  @override
  String get errorExportFailedMessage =>
      'تعذّر إنشاء الملف أو مشاركته. يُرجى المحاولة مرة أخرى.';

  @override
  String get errorStorageFullTitle => 'مساحة التخزين ممتلئة';

  @override
  String get errorStorageFullMessage =>
      'يرجى تفريغ 50 ميغابايت على الأقل من مساحة الجهاز للمتابعة بأمان.';

  @override
  String get cloudSyncStatusOffline =>
      'غير متصل — بياناتك محفوظة على هذا الجهاز';

  @override
  String get cloudSyncStatusSyncing =>
      'جارٍ مزامنة النسخة الاحتياطية مع السحابة';

  @override
  String get cloudSyncStatusSynced => 'تم النسخ الاحتياطي إلى السحابة';

  @override
  String get cloudSyncStatusNeedsReauth =>
      'سجّل الدخول مجدداً لاستئناف النسخ الاحتياطي';

  @override
  String get cloudSyncStatusQuota => 'مساحة التخزين السحابي ممتلئة';

  @override
  String get recoveryTitle => 'استرداد النظام';

  @override
  String get recoveryBody =>
      'تعرض ملف البيانات المحلي للتلف بسبب انقطاع في التخزين أو الطاقة. لحماية أموالك، تم إيقاف التطبيق مؤقتاً.';

  @override
  String get recoveryRestoreDrive => 'استعادة من Google Drive';

  @override
  String get recoveryStartFresh => 'بدء من جديد (حذف البيانات المحلية)';

  @override
  String get recoveryStartFreshConfirmTitle => 'حذف البيانات المحلية؟';

  @override
  String get recoveryStartFreshConfirmBody =>
      'سيؤدي هذا إلى إزالة قاعدة البيانات التالفة من هذا الجهاز نهائياً. نسخ Google Drive الاحتياطية لن تتأثر. سيعيد التطبيق التشغيل بدفتر فارغ جديد.';

  @override
  String get recoveryNoDriveBackups =>
      'لم يُعثر على نسخ احتياطية في Google Drive لهذا الحساب.';

  @override
  String get recoveryPickBackupTitle => 'اختر نسخة للاستعادة';

  @override
  String get recoveryRestoreFromFile => 'استعادة من ملف نسخة احتياطية';

  @override
  String get settingsCloudBackupLegend => 'السحابة';

  @override
  String get quickAddTitle => 'إضافة سريعة';

  @override
  String get quickAddNewAccountBadge => 'حساب جديد';

  @override
  String get quickAddSelectLedgerHint =>
      'اختر الدفتر الذي ينتمي إليه هذا الحساب';

  @override
  String get quickAddLedgerLockedHint => 'تم تحديد الدفتر تلقائياً';

  @override
  String get quickAddNoLedgerTitle => 'أنشئ دفتراً أولاً';

  @override
  String get quickAddNoLedgerMessage =>
      'كل معاملة تنتمي إلى دفتر. أنشئ دفترك الأول لتسجيل الديون والمدفوعات.';

  @override
  String get onboardingSkip => 'تخطّي';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingGetStarted => 'ابدأ الآن';

  @override
  String get onboardingTrackDebtsTitle => 'نظّم ديونك بسهولة';

  @override
  String get onboardingTrackDebtsBody =>
      'استبدل الكشكول الورقي بدفتر رقمي بسيط يعمل بدون إنترنت.';

  @override
  String get onboardingDriveBackupTitle => 'نسخ احتياطي آمن على Google Drive';

  @override
  String get onboardingDriveBackupBody =>
      'نسختك الاحتياطية المشفّرة في حسابك على Google — مخفية وخاصة.';

  @override
  String get onboardingSharePdfTitle => 'شارك كشوفات PDF بعلامتك';

  @override
  String get onboardingSharePdfBody =>
      'أرسل كشف حساب احترافي لعملائك عبر واتساب بلمسة واحدة.';

  @override
  String get onboardingPremiumTitle => 'فعّل مزايا Pro';

  @override
  String get onboardingPremiumBody =>
      'احصل على التصدير بعلامتك التجارية، أرشفة الدفاتر، والمزيد من الأدوات المتقدمة.';

  @override
  String get onboardingSetupHeroLine => 'حِسابك مضبوط، وحقّك محفوظ.';

  @override
  String get onboardingSetupLanguageTitle => 'لغة التطبيق';

  @override
  String get onboardingSetupLookTitle => 'المظهر';

  @override
  String get onboardingSetupLookDark => 'داكن';

  @override
  String get onboardingSetupLookLight => 'فاتح';

  @override
  String get onboardingSetupLookSystem => 'حسب الجهاز';

  @override
  String get onboardingSetupCurrencyLabel => 'عملة الدفتر';

  @override
  String get onboardingSetupStoreTitle => 'اسم المحل';

  @override
  String get onboardingSetupStoreNameHint => 'مثل: متجر نموذجي';

  @override
  String get onboardingSetupStoreLogoPro =>
      'الشعار ميزة Pro — يمكنك تسميه المحل الآن.';

  @override
  String get onboardingSetupGoogleTitle => 'حفظ نسخة على Google';

  @override
  String get onboardingSetupGooglePrimary => 'المتابعة مع Google';

  @override
  String get onboardingSetupGoogleLater => 'إعداد لاحقاً';

  @override
  String get onboardingSetupGoogleFailed =>
      'تعذّر تسجيل الدخول. دفترك يعمل بدون إنترنت — أعد المحاولة من هنا.';

  @override
  String get onboardingSetupProExpander => 'لديك رمز؟';

  @override
  String get onboardingSetupProHint =>
      'رمز التفعيل اختياري. يمكنك المتابعة بدونه.';

  @override
  String get onboardingSetupLedgerTitle => 'أول دفتر';

  @override
  String get onboardingSetupLanguageBody =>
      'يمكنك تغييرها لاحقاً من الإعدادات.';

  @override
  String get onboardingSetupLookBody => 'يُطبَّق اختيارك على هذا الشاشة فوراً.';

  @override
  String get onboardingSetupStoreBody =>
      'يظهر على كشوف PDF التي ترسلها للعملاء.';

  @override
  String get onboardingTryDemoStore => 'تجربة متجر افتراضي';

  @override
  String get onboardingSetupGoogleBody =>
      'نسخة احتياطية مشفّرة في حساب Google. دفترك يبقى على هذا الجهاز.';

  @override
  String get onboardingSetupGoogleCompleteDrive => 'إكمال صلاحية Drive';

  @override
  String get onboardingSetupGoogleGrantError =>
      'لم يكتمل تفويض Drive. تحقق من الاتصال وحاول مجدداً.';

  @override
  String get onboardingSetupGoogleSignedIn =>
      'تم تسجيل الدخول — خطوة واحدة للنسخ التلقائي.';

  @override
  String get onboardingSetupProTitle => 'علامة المحل Pro';

  @override
  String get onboardingSetupProBrandingSubtitle =>
      'اسم محلك وشعارك على كل PDF تشاركه.';

  @override
  String get onboardingSetupProStoreFallback => 'محلك';

  @override
  String get onboardingSetupLedgerLedgerLine =>
      'الدفتر هو الكشكول — زبائن، موردين، أو شخصي.';

  @override
  String get onboardingSetupLedgerAccountsLine =>
      'الحسابات هي الأشخاص داخل هذا الكشكول.';

  @override
  String get onboardingSetupLedgerCustomChip => 'اسم مخصص';

  @override
  String get onboardingSetupLedgerCustomHint => 'مثل: ديون الورشة';

  @override
  String get onboardingSetupLedgerCreate => 'إنشاء الدفتر';

  @override
  String get demoSeedReportTitle => 'المتجر النموذجي جاهز';

  @override
  String demoSeedReportStoreKept(String name) {
    return 'اسم المحل: $name (محفوظ)';
  }

  @override
  String demoSeedReportStoreGenerated(String name) {
    return 'اسم المحل: $name (تم إنشاؤه)';
  }

  @override
  String demoSeedReportLedger(String name) {
    return 'الدفتر: $name';
  }

  @override
  String demoSeedReportContacts(int count) {
    return '$count حسابات متأخرة مع بريد';
  }

  @override
  String get demoSeedReportTones => 'نطاقات ودية، تذكير، وحازمة';

  @override
  String demoSeedReportSendSplit(int pdfCount, int textCount) {
    return 'أعلى $pdfCount بكشف PDF؛ $textCount بتذكير نصي';
  }

  @override
  String get demoSeedReportDone => 'متابعة';

  @override
  String get demoSeedReportError =>
      'تعذّر تحميل المتجر النموذجي. أعد المحاولة.';

  @override
  String get settingsSampleStoreSection => 'متجر نموذجي';

  @override
  String get settingsSampleStoreBody =>
      'ملء دفتر زبائن نموذجي بسبعة حسابات متأخرة للمقيّمين.';

  @override
  String get settingsSampleStoreReset => 'إعادة بيانات المتجر النموذجي';

  @override
  String get settingsSampleStoreFootnote =>
      'يستبدل الحسابات والدفاتر والحركات. اسم المحل يُحفظ إن كان مضبوطاً.';

  @override
  String get settingsSampleStoreResetConfirmTitle => 'إعادة المتجر النموذجي؟';

  @override
  String get settingsSampleStoreResetConfirmBody =>
      'سيستبدل هذا الحسابات والدفاتر والحركات ببيانات تجريبية. اسم المحل يبقى إن كان مضبوطاً.';

  @override
  String get settingsSampleStoreResetConfirm => 'إعادة';

  @override
  String get settingsSampleStoreResetCancel => 'إلغاء';

  @override
  String get settingsTeam => 'الفريق';

  @override
  String get settingsTeamSubtitle => 'ادعُ العمال إلى مساحة عملك';

  @override
  String get settingsJoinWorkspace => 'لديك رمز دعوة؟';

  @override
  String get settingsJoinWorkspaceSubtitle =>
      'الصق رابط دعوة الفريق للانضمام إلى مساحة العمل';

  @override
  String get joinWorkspaceTitle => 'الانضمام إلى مساحة العمل';

  @override
  String get joinWorkspaceBody =>
      'الصق رابط الدعوة أو الرمز من صاحب المحل. ستسجّل الدخول بحساب Google الذي تلقّى الدعوة.';

  @override
  String get joinWorkspaceCodeLabel => 'رابط الدعوة أو الرمز';

  @override
  String get joinWorkspaceCodeHint => 'https://daftar.app/i/… أو الصق الرمز';

  @override
  String get joinWorkspaceContinue => 'متابعة';

  @override
  String get joinWorkspaceInvalidCode => 'أدخل رابط دعوة أو رمزًا صالحًا.';

  @override
  String get joinWorkspaceAlreadyUsed => 'سبق فتح هذه الدعوة على هذا الجهاز.';

  @override
  String get joinWorkspaceBusy =>
      'ما زال فتح الدعوة السابقة جاريًا. حاول بعد لحظات.';

  @override
  String get inviteAcceptWorkspaceMismatch =>
      'تعذّر الانضمام إلى مساحة عمل التاجر. جرّب تسجيل الخروج والمحاولة مجددًا أو تواصل مع صاحب المحل.';

  @override
  String get settingsSyncReport => 'تقرير المزامنة';

  @override
  String get settingsSyncReportSubtitle =>
      'حالة المزامنة بين الأجهزة والمزامنة اليدوية';

  @override
  String get memberManagementTitle => 'الفريق';

  @override
  String get memberManagementSubtitle => 'ادعُ حتى عاملين للتعاون على دفاترك.';

  @override
  String get memberManagementSeatsHint =>
      'المالك + حتى عاملين (3 مقاعد كحد أقصى).';

  @override
  String get memberManagementUpgradeTitle => 'التعاون الجماعي ميزة Pro+';

  @override
  String get memberManagementUpgradeSubtitle =>
      'قم بالترقية لدعوة عمال يمكنهم عرض أو تعديل دفاترك عبر الأجهزة.';

  @override
  String get memberManagementUpgradeCta => 'عرض الخطط';

  @override
  String get memberManagementPermissionDenied =>
      'مالك مساحة العمل فقط يمكنه إدارة أعضاء الفريق.';

  @override
  String get memberManagementActiveSection => 'الأعضاء النشطون';

  @override
  String get memberManagementPendingSection => 'الدعوات المعلّقة';

  @override
  String get memberManagementEmptySection => 'لا يوجد أعضاء في هذا القسم.';

  @override
  String get memberManagementInviteCta => 'دعوة عامل';

  @override
  String get memberManagementInviteSheetTitle => 'دعوة عامل';

  @override
  String get memberManagementEmailLabel => 'البريد الإلكتروني';

  @override
  String get memberManagementRoleLabel => 'الدور';

  @override
  String get memberManagementRoleOwner => 'مالك';

  @override
  String get memberManagementRoleEditor => 'محرّر';

  @override
  String get memberManagementRoleViewer => 'مشاهد';

  @override
  String get memberManagementStatusPending => 'معلّق';

  @override
  String get memberManagementStatusActive => 'نشط';

  @override
  String get memberManagementSendInvite => 'إرسال الدعوة';

  @override
  String get memberManagementInviteSuccessTitle => 'رابط الدعوة جاهز';

  @override
  String memberManagementInviteRoleGranted(String role) {
    return 'الصلاحية الممنوحة: $role';
  }

  @override
  String get memberManagementInviteDowngradedTitle =>
      'تمت الدعوة كمشاهد وليس كمحرّر';

  @override
  String get memberManagementInviteDowngradedBody =>
      'جميع مقاعد المحرّرين مستخدمة، لذلك أُنشئت هذه الدعوة بصلاحية الاطلاع فقط. أزل محرّرًا أولًا إذا كنت تحتاج مقعدًا آخر.';

  @override
  String get memberManagementCopyLink => 'نسخ الرابط';

  @override
  String get memberManagementShareLink => 'مشاركة الرابط';

  @override
  String get memberManagementLinkCopied => 'تم نسخ رابط الدعوة';

  @override
  String get memberManagementRevokeInvite => 'إلغاء';

  @override
  String get memberManagementRemoveMember => 'إزالة';

  @override
  String get memberManagementRevokeConfirmTitle => 'إلغاء الدعوة؟';

  @override
  String get memberManagementRevokeConfirmBody =>
      'سيُلغى هذا الطلب المعلّق ويُحرّر المقعد.';

  @override
  String get memberManagementRemoveConfirmTitle => 'إزالة العضو؟';

  @override
  String get memberManagementRemoveConfirmBody =>
      'سيفقد هذا العضو الوصول عند المزامنة التالية.';

  @override
  String get memberManagementRenewalSection => 'طلبات تجديد الدعوة';

  @override
  String get memberManagementRenewalEmpty => 'لا توجد طلبات تجديد معلّقة.';

  @override
  String get memberManagementRenewalResend => 'إعادة إرسال الدعوة';

  @override
  String memberManagementRenewalRequestedAt(String date) {
    return 'طُلب في $date';
  }

  @override
  String get closingAgentTitle => 'وكيل الإقفال';

  @override
  String get closingAgentEmptyTitle => 'ما الذي نسجّل؟';

  @override
  String get closingAgentEmptySubtitle => 'اضغط مثالاً أو اكتب الاسم والمبلغ';

  @override
  String get closingAgentComposerHint => 'اكتب في الدفتر';

  @override
  String get closingAgentSpeakWorking => 'جاري مراجعة وتدقيق الدفتر...';

  @override
  String get closingAgentExampleChip1 => 'محمد سدد 500';

  @override
  String get closingAgentExampleChip2 => 'أحمد عليه 200';

  @override
  String get closingAgentCloseToday => 'أقفل اليوم';

  @override
  String get closingAgentCloseTodayGoal => 'اقفل يومي';

  @override
  String get closingAgentCloseTodaySemantics =>
      'أقفل اليوم وابدأ إقفال نهاية اليوم';

  @override
  String get closingAgentSendSemantics => 'إرسال الهدف';

  @override
  String get closingAgentMicSemantics => 'الصوت';

  @override
  String get closingAgentMicBanner => 'اضغط مطولاً للتحدث';

  @override
  String get closingAgentMicRecording => 'جارٍ التسجيل';

  @override
  String get closingAgentMicSlideToCancel => 'اسحب للأعلى للإلغاء';

  @override
  String get closingAgentMicReleaseToCancel => 'ارفع لإلغاء التسجيل';

  @override
  String closingAgentMicRecordingElapsed(int seconds) {
    return 'جارٍ التسجيل، مضى $seconds ثانية';
  }

  @override
  String get closingAgentMicPermissionDenied =>
      'الوصول إلى الميكروفون متوقف. افتح الإعدادات للسماح لدفتر بالتسجيل.';

  @override
  String get closingAgentMicOpenSettings => 'فتح الإعدادات';

  @override
  String get closingAgentContactsPermissionDenied =>
      'الوصول إلى جهات الاتصال متوقف. افتح الإعدادات للسماح لدفتر بملء الاسم والهاتف.';

  @override
  String get closingAgentPermissionBannerSemantics => 'تنبيه صلاحية';

  @override
  String get backupDriveNotSignedIn => 'سجّل الدخول لحفظ نسخة على درايف.';

  @override
  String get closingAgentConfirmDebt => 'سجل الدين';

  @override
  String get closingAgentConfirmPayment => 'سجّل السداد';

  @override
  String get closingAgentConfirmCreateContact => 'أنشئ الحساب';

  @override
  String get closingAgentConfirmCreateLedger => 'أنشئ الدفتر';

  @override
  String get closingAgentConfirmAll => 'سجّل في الدفتر';

  @override
  String get closingAgentConfirmPlan => 'تأكيد الخطة';

  @override
  String get closingAgentIntentDebt => 'دين';

  @override
  String get closingAgentIntentPayment => 'سداد';

  @override
  String get closingAgentIntentNewAccount => 'حساب جديد';

  @override
  String get closingAgentIntentLedger => 'دفتر';

  @override
  String get closingAgentIntentStatement => 'كشف';

  @override
  String get closingAgentSkip => 'تخطي';

  @override
  String get closingAgentConfirmed => 'تم التسجيل';

  @override
  String get closingAgentSkipped => 'تم التخطي';

  @override
  String get closingAgentSelectLedger => 'اختر الدفتر';

  @override
  String get closingAgentSelectCurrency => 'اختر العملة';

  @override
  String get closingAgentContactUnresolvedHelper => 'حدّد الحساب قبل التسجيل.';

  @override
  String get closingAgentWhichContact => 'أي حساب؟';

  @override
  String closingAgentDidYouMean(String name) {
    return 'هل تقصد أحد هؤلاء، أم إنشاء حساب جديد باسم $name؟';
  }

  @override
  String closingAgentCreateNewNamed(String name) {
    return 'أنشئ «$name»';
  }

  @override
  String closingAgentContactAlreadyExists(String name) {
    return 'يوجد حساب باسم $name في الدفتر.';
  }

  @override
  String get closingAgentLedgerTypeCustomers => 'زبائن';

  @override
  String get closingAgentLedgerTypeSuppliers => 'موردون';

  @override
  String get closingAgentLedgerTypePersonal => 'شخصي';

  @override
  String get closingAgentLedgerTypeCustom => 'مخصص';

  @override
  String get closingAgentAskOverdueTitle => 'من عليه باقٍ';

  @override
  String get closingAgentAskLargestTitle => 'أكبر دين';

  @override
  String get closingAgentAskSmallestTitle => 'أقل دين';

  @override
  String get closingAgentAskLastPaymentTitle => 'آخر دفعة';

  @override
  String get closingAgentAskLastDebtTitle => 'آخر دين';

  @override
  String closingAgentAskNoLastPayment(String name) {
    return 'لا توجد دفعة في الدفتر لـ $name.';
  }

  @override
  String closingAgentAskNoLastDebt(String name) {
    return 'لا يوجد دين في الدفتر لـ $name.';
  }

  @override
  String get closingAgentAskNeedName => 'حدّد اسم الحساب.';

  @override
  String get closingAgentAskEmpty => 'لا أحد عليه شيء الآن.';

  @override
  String get closingAgentAskBalanceTitle => 'الرصيد';

  @override
  String get closingAgentAskUnresolved => 'لا يوجد حساب مطابق في الدفتر.';

  @override
  String closingAgentSpeakDebt(String name, String amount) {
    return '$name عليه $amount';
  }

  @override
  String closingAgentSpeakPayment(String name, String amount) {
    return '$name سدد $amount';
  }

  @override
  String closingAgentSpeakDebtWithItem(
    String name,
    String amount,
    String item,
  ) {
    return '$name عليه $amount $item';
  }

  @override
  String closingAgentSpeakPaymentWithItem(
    String name,
    String amount,
    String item,
  ) {
    return '$name سدد $amount $item';
  }

  @override
  String closingAgentSpeakBalance(String name, String amount) {
    return '$name عليه $amount';
  }

  @override
  String closingAgentSpeakCredit(String name, String amount) {
    return '$name له $amount';
  }

  @override
  String closingAgentSpeakSettled(String name) {
    return '$name لا عليه شيء';
  }

  @override
  String get closingAgentSpeakThisAccount => 'هذا الحساب';

  @override
  String get closingAgentSpeakPlanReady =>
      'خطة إقفال اليوم جاهزة. راجعها على الشاشة ثم أكّد.';

  @override
  String closingAgentSpeakRiyals(String amount) {
    return '$amount ريال';
  }

  @override
  String closingAgentSpeakDollars(String amount) {
    return '$amount دولار';
  }

  @override
  String closingAgentSpeakConfirmDebt(String amount, String name, String cta) {
    return 'سأسجل $amount ديناً على $name. اضغط $cta.';
  }

  @override
  String closingAgentSpeakConfirmPayment(
    String amount,
    String name,
    String cta,
  ) {
    return 'سأسجل $amount سداداً من $name. اضغط $cta.';
  }

  @override
  String closingAgentSpeakConfirmDebtCreate(
    String name,
    String amount,
    String cta,
  ) {
    return 'لا يوجد حساب باسم $name. سأنشئ الحساب وأسجل عليه ديناً بمبلغ $amount. اضغط $cta.';
  }

  @override
  String closingAgentSpeakConfirmPaymentCreate(
    String name,
    String amount,
    String cta,
  ) {
    return 'لا يوجد حساب باسم $name. سأنشئ الحساب وأسجل عليه سداداً بمبلغ $amount. اضغط $cta.';
  }

  @override
  String closingAgentSpeakConfirmDebtItem(
    String amount,
    String name,
    String item,
    String cta,
  ) {
    return 'سأسجل $amount ديناً على $name مقابل $item. اضغط $cta.';
  }

  @override
  String closingAgentSpeakConfirmPaymentItem(
    String amount,
    String name,
    String item,
    String cta,
  ) {
    return 'سأسجل $amount سداداً من $name مقابل $item. اضغط $cta.';
  }

  @override
  String closingAgentSpeakConfirmDebtCreateItem(
    String name,
    String amount,
    String item,
    String cta,
  ) {
    return 'لا يوجد حساب باسم $name. سأنشئ الحساب وأسجل عليه ديناً بمبلغ $amount مقابل $item. اضغط $cta.';
  }

  @override
  String closingAgentSpeakConfirmPaymentCreateItem(
    String name,
    String amount,
    String item,
    String cta,
  ) {
    return 'لا يوجد حساب باسم $name. سأنشئ الحساب وأسجل عليه سداداً بمبلغ $amount مقابل $item. اضغط $cta.';
  }

  @override
  String closingAgentSpeakConfirmStatement(String name, String cta) {
    return 'سأجهّز كشف حساب بي دي إف لـ $name. اضغط $cta.';
  }

  @override
  String closingAgentSpeakConfirmCreateContact(String name, String cta) {
    return 'سأنشئ حساباً باسم $name. اضغط $cta.';
  }

  @override
  String closingAgentSpeakConfirmCreateLedger(String name, String cta) {
    return 'سأنشئ دفتراً باسم $name. اضغط $cta.';
  }

  @override
  String closingAgentStatementTitle(String name) {
    return 'كشف حساب $name';
  }

  @override
  String closingAgentSpeakOverdueIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حسابات عليها باقٍ.',
      one: 'حساب واحد عليه باقٍ.',
    );
    return '$_temp0';
  }

  @override
  String closingAgentSpeakWhichCandidates(String names) {
    return 'أي حساب؟ $names.';
  }

  @override
  String get closingAgentLedgerRequiredHelper =>
      'اختر دفتراً قبل إنشاء الحساب.';

  @override
  String closingAgentUnknownContactHelper(String name) {
    return 'لا يوجد حساب باسم $name. إنشاؤه وتسجيل المبلغ؟';
  }

  @override
  String get closingAgentNoLedgerHelper =>
      'لا يوجد دفتر بعد. سمِّ دفتراً لإنشائه.';

  @override
  String get closingAgentLedgerNameHint => 'اسم الدفتر';

  @override
  String get closingAgentConfirmCreateAndRecordDebt =>
      'أنشئ الحساب وسجّل الدين';

  @override
  String get closingAgentConfirmCreateAndRecordPayment =>
      'أنشئ الحساب وسجّل السداد';

  @override
  String get closingAgentCurrencyRequiredHelper =>
      'اختر عملة قبل إنشاء هذا الحساب.';

  @override
  String get closingAgentPlanTitle => 'خطة الإقفال';

  @override
  String get closingAgentPlanSendSplit =>
      'أعلى خمسة حسابات ثقلاً تحصل على كشف حساب مرفق. بقية مجموعة الإرسال تحصل على تذكير بالبريد. الترتيب من التقادم؛ لا يختار جيميناي المعرّفات.';

  @override
  String get closingAgentPlanDeviceRuns =>
      'بعد النسخ الاحتياطي والتقادم يقسم مكتب التحصيل المتصلين المؤهلين عن البريد. اليمن والمناطق غير المدعومة تبقى على البريد. النص ثابت؛ لا يختار جيميناي المعرّفات.';

  @override
  String get closingAgentPlanOutreachConsent =>
      'هذان الزران يبدآن الإقفال. بعد النسخ ومسح التقادم، مكتب التحصيل هو موضع تأكيد الاتصال والبريد.';

  @override
  String get closingAgentTaskmasterTitle => 'خطة إقفال اليوم';

  @override
  String get closingAgentApprovePlan => 'اعتماد الخطة';

  @override
  String get closingAgentStartClose => 'ابدأ الإقفال';

  @override
  String get closingAgentStartCloseWithoutOutreach => 'ابدأ الإقفال دون تواصل';

  @override
  String get closingAgentConfirmAndSend => 'تأكيد وإرسال الكشوفات';

  @override
  String get closingAgentConfirmWithoutSending => 'تأكيد دون إرسال';

  @override
  String closingTaskmasterSealed(int count) {
    return 'أُنجزت $count مهمة';
  }

  @override
  String get closingTaskBindLedger => 'مطابقة القيود';

  @override
  String get closingTaskCollectDebts => 'جمع ديون اليوم';

  @override
  String get closingTaskCollectPayments => 'جمع دفعات اليوم';

  @override
  String get closingTaskTallyTotals => 'جمع المجاميع لكل عملة';

  @override
  String get closingTaskStampSnapshot => 'ختم لقطة اليوم';

  @override
  String get closingTaskPrepareVault => 'تحضير حمولة الخزنة';

  @override
  String get closingTaskSealDrive => 'ختم النسخة على درايف';

  @override
  String get closingTaskScanAging => 'مسح أرصدة التقادم';

  @override
  String get closingTaskRankUrgency => 'ترتيب حسب الإلحاح';

  @override
  String get closingTaskBuildSendSet => 'تجهيز قائمة المدينين المستهدفين';

  @override
  String get closingTaskOpenDesk => 'فتح مكتب التحصيل';

  @override
  String get closingTaskComposeReport => 'تأليف تقرير اليوم';

  @override
  String get closingTaskPresentSeal => 'عرض ختم اليوم';

  @override
  String closingTaskCaptionDebts(int count) {
    return '$count ديون اليوم';
  }

  @override
  String closingTaskCaptionPayments(int count) {
    return '$count دفعات اليوم';
  }

  @override
  String closingTaskCaptionCurrencies(int count) {
    return '$count عملات';
  }

  @override
  String closingTaskCaptionSendSet(int count) {
    return 'حتى $count حساباً';
  }

  @override
  String closingTaskCaptionOverdue(int count) {
    return '$count متأخرون';
  }

  @override
  String get closingTaskCaptionSendAuth => 'يلزم إذن Google قبل الإرسال';

  @override
  String get closingAgentCurrencyLabel => 'العملة';

  @override
  String get closingAgentNoteLabel => 'ملاحظة';

  @override
  String get closingAgentReadOnlyTool => 'هذه الخطوة للعرض فقط في هذه النسخة.';

  @override
  String get closingAgentFabTipTitle => 'الوكيل والإدخال اليدوي';

  @override
  String get closingAgentFabTipBody =>
      'اضغط للوكيل · اضغط مطولاً للإدخال اليدوي';

  @override
  String get closingAgentFabTipTapRow => 'اضغط → الوكيل';

  @override
  String get closingAgentFabTipHoldRow => 'اضغط مطولاً → إدخال يدوي';

  @override
  String get closingAgentFabTipSkip => 'تخطي';

  @override
  String get closingAgentFabTipDismiss => 'حسناً';

  @override
  String get closingAgentFabTipSemantics =>
      'تلميح زر الإضافة: اضغط للوكيل، اضغط مطولاً للإدخال اليدوي';

  @override
  String get closingAgentConfirmCoachTitle => 'أكد المبلغ';

  @override
  String get closingAgentConfirmCoachBody => 'لا يُسجَّل شيء حتى تؤكد.';

  @override
  String get closingAgentConfirmCoachSemantics => 'تلميح تأكيد المبلغ';

  @override
  String get collectionsDeskApproveCoachTitle => 'تأكيد وإرسال الكشوفات';

  @override
  String get collectionsDeskApproveCoachBody =>
      'تُرسل التذكيرات دفعة واحدة. أثقل خمسة حسابات تحصل على كشف.';

  @override
  String get collectionsDeskApproveCoachSemantics =>
      'تلميح تأكيد وإرسال الكشوفات';

  @override
  String get closingRitualBackupUnsigned =>
      'سجّل الدخول لحفظ نسخة الليلة على درايف.';

  @override
  String get closingRitualBackupGrantMissing =>
      'لم تُمنح صلاحية Drive. وافق عليها مرة واحدة لحفظ نسخة الليلة.';

  @override
  String get closingRitualRunning => 'جاري إقفال اليوم…';

  @override
  String get closingRitualProgressSummary => 'جاري عدّ قيود اليوم';

  @override
  String get closingRitualProgressBackup => 'جاري حفظ نسخة على درايف';

  @override
  String get closingRitualProgressShortlist => 'جاري إيجاد الحسابات المتأخرة';

  @override
  String get closingRitualRemindersTitle => 'تحضير تذكيرات التحصيل؟';

  @override
  String get closingRitualRemindersYes => 'نعم';

  @override
  String get closingRitualRemindersTop5 => 'أعلى 5';

  @override
  String get closingRitualRemindersNo => 'لا';

  @override
  String get closingRitualPdfsTitle => 'إرفاق كشوف الحساب؟';

  @override
  String get closingRitualPdfsNone => 'بدون';

  @override
  String get closingRitualPdfsSelective => 'انتقائي';

  @override
  String get closingRitualPdfsSelected => 'المحددون';

  @override
  String get closingRitualReportTitle => 'أُقفل اليوم';

  @override
  String closingRitualSpeakBooks(int debtCount, int paymentCount) {
    return 'اليوم سجّلت $debtCount ديون و$paymentCount دفعات';
  }

  @override
  String get closingRitualSpeakBackupSafe =>
      'نسخة الليلة على درايف. دفترك بأمان';

  @override
  String get closingRitualSpeakBackupQueued =>
      'ستكتمل نسخة الليلة عند عودة الاتصال';

  @override
  String get closingRitualSpeakBackupUnsigned =>
      'سجّل الدخول لحفظ نسخة الليلة على درايف';

  @override
  String get closingRitualSpeakBackupGrant =>
      'وافق على صلاحية درايف مرة واحدة لحفظ نسخة الليلة';

  @override
  String get closingRitualSpeakBackupFailed => 'نسخة درايف تحتاج محاولة أخرى';

  @override
  String closingRitualSpeakQueue(int prepared, int sent, int failed) {
    return '$prepared جاهزة، $sent أُرسلت، $failed فشلت';
  }

  @override
  String closingRitualSpeakOverdueRemain(int count) {
    return '$count حسابات ما زالت متأخرة';
  }

  @override
  String get closingRitualSpeakClose => 'هذا إقفال اليوم';

  @override
  String closingRitualReportDebtCount(int count) {
    return '$count ديون';
  }

  @override
  String get closingRitualReportDebtsUnit => 'ديون اليوم';

  @override
  String closingRitualReportPaymentCount(int count) {
    return '$count دفعات';
  }

  @override
  String get closingRitualReportPaymentsUnit => 'دفعات اليوم';

  @override
  String closingRitualReportTotals(
    String currencyCode,
    String debt,
    String payment,
  ) {
    return '$currencyCode: $debt دين · $payment سداد';
  }

  @override
  String get closingRitualBackupUploaded => 'حُفظت النسخة على درايف';

  @override
  String get closingRitualEmptyOverdue => 'لا شيء للتحصيل';

  @override
  String get closingRitualSkipAll => 'تم تخطي التذكيرات';

  @override
  String get closingRitualReminderAll => 'التذكيرات: مجموعة الإرسال (حتى 20)';

  @override
  String get closingRitualReminderTop5 => 'التذكيرات: أعلى 5';

  @override
  String get closingRitualReminderNone => 'التذكيرات: لا شيء';

  @override
  String get closingRitualPdfNone => 'الكشوف: بدون';

  @override
  String get closingRitualPdfSelective => 'الكشوف: انتقائي';

  @override
  String get closingRitualPdfAll => 'الكشوف: المحددون';

  @override
  String get closingRitualPdfRankedTop5 => 'الكشوف: أعلى 5 مرتبة';

  @override
  String get closingRitualNeedsHuman => 'يحتاج انتباهك';

  @override
  String closingRitualOverdueCount(int count) {
    return '$count متأخرون';
  }

  @override
  String get closingRitualCallReportTitle => 'تقرير المكالمات';

  @override
  String closingRitualCallPromiseLine(String amount, String date) {
    return 'وعد بـ $amount في $date';
  }

  @override
  String closingRitualCallRowSemantics(String name, String status) {
    return 'مكالمة $name، $status';
  }

  @override
  String get closingRitualRetry => 'متابعة إقفال اليوم';

  @override
  String get collectionsDeskTitle => 'التحصيل';

  @override
  String collectionsDeskCount(int count) {
    return '$count تذكيرات';
  }

  @override
  String get collectionsDeskOpenWhatsApp => 'فتح واتساب';

  @override
  String get collectionsDeskCopy => 'نسخ';

  @override
  String get collectionsDeskSkip => 'تخطي';

  @override
  String get collectionsDeskAttachStatement => 'إرفاق كشف الحساب';

  @override
  String get collectionsDeskStartSending => 'بدء الإرسال';

  @override
  String get collectionsDeskApproveSend => 'تأكيد وإرسال الكشوفات';

  @override
  String get collectionsDeskSkipOutreach => 'تخطي التواصل';

  @override
  String get collectionsDeskRetrySend => 'إعادة الإرسال';

  @override
  String get collectionsDeskSending => 'جاري الإرسال…';

  @override
  String get collectionsDeskPdfAttached => 'PDF مرفق';

  @override
  String get collectionsDeskReminderOnly => 'تذكير فقط';

  @override
  String get collectionsDeskDone => 'تم';

  @override
  String get collectionsDeskCopied => 'تم نسخ التذكير';

  @override
  String get collectionsDeskWhatsAppFailed =>
      'لم يُفتح واتساب. انسخ التذكير وأرسله بنفسك.';

  @override
  String get collectionsDeskToneFriendly => 'ودي';

  @override
  String get collectionsDeskToneReminder => 'تذكير';

  @override
  String get collectionsDeskToneFirm => 'حازم';

  @override
  String collectionsDeskAgeDays(int days) {
    return '$days يوماً';
  }

  @override
  String collectionsDeskLastPaymentDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'آخر سداد قبل $days يوماً',
      one: 'آخر سداد قبل يوم',
      zero: 'آخر سداد اليوم',
    );
    return '$_temp0';
  }

  @override
  String get collectionsDeskOpened => 'فُتح';

  @override
  String get collectionsDeskSkippedStatus => 'مُتخطى';

  @override
  String get collectionsDeskSentStatus => 'أُرسل';

  @override
  String get collectionsDeskFailedStatus => 'فشل';

  @override
  String get collectionsDeskConfirmAndCall => 'تأكيد والاتصال';

  @override
  String get collectionsDeskConfirmWithoutCalling => 'تأكيد دون اتصال';

  @override
  String get collectionsDeskWithoutCalling => 'دون اتصال';

  @override
  String get collectionsDeskWithoutSending => 'دون إرسال';

  @override
  String get collectionsDeskRailTitleVoiceCalls => 'مكالمات صوتية';

  @override
  String get collectionsDeskRailTitleEmailStatements => 'كشوفات البريد';

  @override
  String collectionsDeskRailCallOnSingle(int count, String name) {
    return '$count مكالمة مجدولة ($name)';
  }

  @override
  String collectionsDeskRailCallOnMultiple(
    int count,
    String name,
    int othersCount,
  ) {
    return '$count مكالمات مجدولة · $name و$othersCount آخرين';
  }

  @override
  String get collectionsDeskRailCallOff =>
      'تم التخطي — لن تُجرى أي مكالمات صادرة';

  @override
  String collectionsDeskRailEmailOnMixed(
    int count,
    int pdfCount,
    int textCount,
  ) {
    return '$count كشوف ($pdfCount مع مرفق PDF + $textCount تذكيرات نصية)';
  }

  @override
  String collectionsDeskRailEmailOnAllPdf(int count) {
    return '$count كشوف مع مرفق PDF';
  }

  @override
  String collectionsDeskRailEmailOnAllText(int count) {
    return '$count تذكيرات نصية';
  }

  @override
  String get collectionsDeskRailEmailOff => 'تم التخطي — لن يُرسل أي بريد';

  @override
  String collectionsDeskCommitCallPhrase(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكالمة',
      many: '$count مكالمة',
      few: '$count مكالمات',
      two: 'مكالمتان',
      one: 'مكالمة واحدة',
    );
    return '$_temp0';
  }

  @override
  String collectionsDeskCommitStatementPhrase(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count كشف',
      many: '$count كشفاً',
      few: '$count كشوف',
      two: 'كشفان',
      one: 'كشف واحد',
    );
    return '$_temp0';
  }

  @override
  String collectionsDeskCommitOutreachBoth(
    String callPhrase,
    String emailPhrase,
  ) {
    return 'تأكيد ($callPhrase + $emailPhrase)';
  }

  @override
  String collectionsDeskCommitCallsOnly(String callPhrase) {
    return 'تأكيد ($callPhrase)';
  }

  @override
  String collectionsDeskCommitEmailOnly(String emailPhrase) {
    return 'إرسال الكشوفات فقط ($emailPhrase)';
  }

  @override
  String get collectionsDeskCommitSeal => 'إغلاق اليوم دون تواصل';

  @override
  String collectionsDeskRetryUnanswered(int count) {
    return 'إعادة الاتصال بمن لم يرد — $count';
  }

  @override
  String get collectionsDeskPromiseNotPayment => 'الوعد ليس دفعة';

  @override
  String get collectionsDeskPromiseNotPaymentSubtitle =>
      'يسجّل CALL-E ما قاله العميل أنه سيدفع. لا يُدخل المال إلى دفترك.';

  @override
  String contactPendingPromiseBody(String amount, String date) {
    return 'وعد بـ $amount في $date';
  }

  @override
  String contactPendingPromiseSemantics(String amount, String date) {
    return 'وعد معلّق: $amount في $date';
  }

  @override
  String get contactPromiseStatusPending => 'معلّق';

  @override
  String get contactPromiseUpdateStatus => 'تحديث الحالة';

  @override
  String get contactPromiseStatusActionSheetTitle => 'حالة الوعد';

  @override
  String get contactPromiseStatusKept => 'تم الوفاء';

  @override
  String get contactPromiseStatusBroken => 'لم يُوفَ';

  @override
  String get contactPromiseStatusCancelled => 'ملغى';

  @override
  String get contactPromiseMarkBrokenConfirmTitle =>
      'تعليم الوعد بأنه لم يُوفَ؟';

  @override
  String get contactPromiseMarkBrokenConfirmBody =>
      'يُحدّث بطاقة الوعد فقط. لا يُدخل مالاً إلى دفترك.';

  @override
  String get contactPromiseMarkCancelledConfirmTitle => 'إلغاء هذا الوعد؟';

  @override
  String get contactPromiseMarkCancelledConfirmBody =>
      'يُحدّث بطاقة الوعد فقط. لا يُدخل مالاً إلى دفترك.';

  @override
  String get collectionsDeskCallPreviewTitle => 'ما سيقوله CALL-E';

  @override
  String collectionsDeskCallingProgress(int index, int total) {
    return 'جاري الاتصال $index من $total';
  }

  @override
  String collectionsDeskCallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكالمة',
      many: '$count مكالمة',
      few: '$count مكالمات',
      two: 'مكالمتان',
      one: 'مكالمة واحدة',
    );
    return '$_temp0';
  }

  @override
  String collectionsDeskEmailCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      many: '$count رسالة',
      few: '$count رسائل',
      two: 'بريدان',
      one: 'بريد واحد',
    );
    return '$_temp0';
  }

  @override
  String get collectionsDeskRailCall => 'اتصال';

  @override
  String get collectionsDeskRailEmail => 'بريد';

  @override
  String get collectionsDeskRailBoth => 'الاثنان';

  @override
  String get collectionsDeskRailCallUnavailable => 'لا يمكن الاتصال';

  @override
  String get collectionsDeskRailSkipped => 'متخطى';

  @override
  String collectionsQueueSending(int index, int total) {
    return 'إرسال $index من $total';
  }

  @override
  String collectionsQueuePaused(int index, int total) {
    return 'متوقف · $index من $total';
  }

  @override
  String get collectionsQueuePause => 'إيقاف';

  @override
  String get collectionsQueueResume => 'متابعة';

  @override
  String closingRitualQueuePrepared(int count) {
    return '$count جاهزة';
  }

  @override
  String closingRitualQueueOpened(int count) {
    return '$count فُتحت';
  }

  @override
  String closingRitualQueueSkipped(int count) {
    return '$count مُتخطاة';
  }

  @override
  String closingRitualQueueSent(int count) {
    return '$count أُرسلت';
  }

  @override
  String closingRitualQueueFailed(int count) {
    return '$count فشلت';
  }

  @override
  String get errorGoalTextRequired => 'اكتب الهدف أولاً.';

  @override
  String get errorAgentIdTokenMissing =>
      'يلزم تسجيل الدخول إلى Google لاستخدام الوكيل.';

  @override
  String get errorAgentOpenIdGrantRequired =>
      'يلزم تحديث صلاحية Google مرة واحدة ليبقى الوكيل متصلاً. وافق مرة واحدة — النسخ الاحتياطي على Drive دون تغيير.';

  @override
  String get errorClosingAgentForbidden =>
      'هذا الحساب لا يملك صلاحية استخدام الوكيل. سجّل الدخول بحساب Google المصرّح.';

  @override
  String get errorClosingAgentRequestFailed =>
      'تعذّر الوصول إلى الوكيل. دفترك آمن على هذا الجهاز — اضغط مطولاً على + لإضافة قيد.';

  @override
  String get errorProposalInFlight => 'التأكيد جارٍ لهذه العملية.';

  @override
  String get errorContactUnresolved =>
      'لم يُعثر على حساب واحد مطابق. وضّح الاسم أو أنشئ الحساب.';

  @override
  String get errorLedgerRequired => 'اختر دفتراً قبل إنشاء هذا الحساب.';

  @override
  String get errorCurrencyRequired => 'اختر عملة قبل إنشاء هذا الحساب.';

  @override
  String get errorProposalAlreadyCommitted => 'تم تسجيل هذا القيد مسبقاً.';

  @override
  String get errorClosingAgentParseFailed =>
      'تعذّر قراءة رد الوكيل. حاول مرة أخرى.';

  @override
  String get errorSmtpTitle => 'لم يُرسل البريد';

  @override
  String get errorSmtpNeedsHuman =>
      'رفضت Gmail على Cloud Run كلمة مرور التطبيق. تسجيل الدخول إلى التطبيق مجدداً لن يفيد. دفترك لم يتغيّر.';

  @override
  String get errorSmtpSenderMisconfigured =>
      'مرسل البريد غير مُعدّ على Cloud Run. تسجيل الدخول إلى Drive غير مرتبط. دفترك لم يتغيّر.';

  @override
  String get errorCalleKillSwitchTitle => 'المكالمات متوقفة';

  @override
  String get errorCalleKillSwitch =>
      'المكالمات الهاتفية مغلقة. البريد ما زال يعمل. دفترك لم يتغيّر.';

  @override
  String get errorCalleNeedsHumanTitle => 'المكالمة تحتاج نظرة';

  @override
  String get errorCalleNeedsHuman =>
      'تحتاج المكالمة مراجعة شخص. دفترك لم يتغيّر.';

  @override
  String get errorCallePollTimeoutTitle => 'انتهى وقت المكالمة';

  @override
  String get errorCallePollTimeout =>
      'لم تكتمل المكالمة في الوقت المحدد. دفترك لم يتغيّر. لا تضغط تأكيد والاتصال مرة أخرى.';

  @override
  String get errorCollectionsEmailCap =>
      'يمكنك إرسال 20 تذكيراً كحد أقصى في المرة الواحدة.';
}
