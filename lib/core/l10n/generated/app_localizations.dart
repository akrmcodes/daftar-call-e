import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'دفتر'**
  String get appTitle;

  /// No description provided for @greeting.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً'**
  String get greeting;

  /// No description provided for @home.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get home;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @netBalance.
  ///
  /// In ar, this message translates to:
  /// **'صافي الرصيد'**
  String get netBalance;

  /// No description provided for @totalDebt.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الدين'**
  String get totalDebt;

  /// No description provided for @totalCredit.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الائتمان'**
  String get totalCredit;

  /// No description provided for @tapToExpand.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للتوسيع'**
  String get tapToExpand;

  /// No description provided for @tapToCollapse.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للطي'**
  String get tapToCollapse;

  /// No description provided for @tapToSeeBreakdown.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لرؤية التفاصيل'**
  String get tapToSeeBreakdown;

  /// No description provided for @hideBreakdown.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء التفاصيل'**
  String get hideBreakdown;

  /// No description provided for @darkMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الداكن'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الفاتح'**
  String get lightMode;

  /// No description provided for @changeLanguage.
  ///
  /// In ar, this message translates to:
  /// **'تغيير اللغة'**
  String get changeLanguage;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'الإنجليزية'**
  String get english;

  /// No description provided for @appearance.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get appearance;

  /// No description provided for @homeScreenSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'استعرض الشاشات المؤقتة من هنا.'**
  String get homeScreenSubtitle;

  /// No description provided for @openLedgerDetails.
  ///
  /// In ar, this message translates to:
  /// **'فتح تفاصيل الدفتر'**
  String get openLedgerDetails;

  /// No description provided for @openContactDetails.
  ///
  /// In ar, this message translates to:
  /// **'فتح تفاصيل الحساب'**
  String get openContactDetails;

  /// No description provided for @settingsScreenSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'خصّص دفتر — اللغة والمظهر ومساحة العمل.'**
  String get settingsScreenSubtitle;

  /// No description provided for @settingsGroupPreferences.
  ///
  /// In ar, this message translates to:
  /// **'التفضيلات'**
  String get settingsGroupPreferences;

  /// No description provided for @settingsGroupAccountSecurity.
  ///
  /// In ar, this message translates to:
  /// **'الحساب والأمان'**
  String get settingsGroupAccountSecurity;

  /// No description provided for @settingsGroupWorkspace.
  ///
  /// In ar, this message translates to:
  /// **'مساحة العمل'**
  String get settingsGroupWorkspace;

  /// No description provided for @settingsGroupPrivacy.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get settingsGroupPrivacy;

  /// No description provided for @settingsGroupSupport.
  ///
  /// In ar, this message translates to:
  /// **'الدعم'**
  String get settingsGroupSupport;

  /// No description provided for @settingsSystemTheme.
  ///
  /// In ar, this message translates to:
  /// **'النظام'**
  String get settingsSystemTheme;

  /// No description provided for @settingsDefaultCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة الافتراضية'**
  String get settingsDefaultCurrency;

  /// No description provided for @settingsMultiCurrency.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل ميزة تعدد العملات'**
  String get settingsMultiCurrency;

  /// No description provided for @settingsMultiCurrencySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر عملة لكل حساب أو معاملة جديدة. عند الإيقاف، تُستخدم العملة الافتراضية فقط.'**
  String get settingsMultiCurrencySubtitle;

  /// No description provided for @settingsSwipeToDelete.
  ///
  /// In ar, this message translates to:
  /// **'السحب للحذف'**
  String get settingsSwipeToDelete;

  /// No description provided for @settingsSwipeToDeleteSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اسحب عناصر القائمة للحذف بسرعة. عند الإيقاف، استخدم القائمة على كل صف.'**
  String get settingsSwipeToDeleteSubtitle;

  /// No description provided for @settingsTtsMuted.
  ///
  /// In ar, this message translates to:
  /// **'كتم القراءة الصوتية'**
  String get settingsTtsMuted;

  /// No description provided for @settingsTtsMutedSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أوقف الكلام على الجهاز لبطاقات التأكيد وتقرير الإغلاق. المبالغ تبقى ظاهرة على الشاشة.'**
  String get settingsTtsMutedSubtitle;

  /// No description provided for @settingsDemoArchitectureHud.
  ///
  /// In ar, this message translates to:
  /// **'عرض هيكل الوكيل'**
  String get settingsDemoArchitectureHud;

  /// No description provided for @settingsDemoArchitectureHudSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'للتجربة: النموذج والأدوات ومسار التأكيد البشري وزمن الاستجابة. ليس جولة في المنتج.'**
  String get settingsDemoArchitectureHudSubtitle;

  /// No description provided for @settingsCalleAllowDial.
  ///
  /// In ar, this message translates to:
  /// **'السماح بالاتصال عبر CALL-E'**
  String get settingsCalleAllowDial;

  /// No description provided for @settingsCalleAllowDialSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'مفتاح الإيقاف المُجمَّع لـ Confirm & Call. الخادم يفرض نفس الإعداد.'**
  String get settingsCalleAllowDialSubtitle;

  /// No description provided for @settingsCalleAllowDialStubHint.
  ///
  /// In ar, this message translates to:
  /// **'المكالمات الصادرة تُضبط عند البناء حتى المرحلة 5. أعد البناء بـ dart-define للتغيير.'**
  String get settingsCalleAllowDialStubHint;

  /// No description provided for @architectureHudSemantics.
  ///
  /// In ar, this message translates to:
  /// **'أداة هيكل الوكيل، المرحلة {step}'**
  String architectureHudSemantics(String step);

  /// No description provided for @architectureHudRouting.
  ///
  /// In ar, this message translates to:
  /// **'Cloud Run · {model}'**
  String architectureHudRouting(String model);

  /// No description provided for @architectureHudLatencyPending.
  ///
  /// In ar, this message translates to:
  /// **'…'**
  String get architectureHudLatencyPending;

  /// No description provided for @architectureHudScopeCapture.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل'**
  String get architectureHudScopeCapture;

  /// No description provided for @architectureHudScopeClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get architectureHudScopeClose;

  /// No description provided for @architectureHudScopeAsk.
  ///
  /// In ar, this message translates to:
  /// **'سؤال'**
  String get architectureHudScopeAsk;

  /// No description provided for @architectureHudToolScope.
  ///
  /// In ar, this message translates to:
  /// **'{scope} · {tools}'**
  String architectureHudToolScope(String scope, String tools);

  /// No description provided for @architectureHudHitlPropose.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح'**
  String get architectureHudHitlPropose;

  /// No description provided for @architectureHudHitlConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get architectureHudHitlConfirm;

  /// No description provided for @architectureHudHitlCommit.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get architectureHudHitlCommit;

  /// No description provided for @architectureHudHitlRank.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب'**
  String get architectureHudHitlRank;

  /// No description provided for @architectureHudPendingRecorded.
  ///
  /// In ar, this message translates to:
  /// **'معلّق {pending} · مسجّل {recorded}'**
  String architectureHudPendingRecorded(int pending, int recorded);

  /// No description provided for @architectureHudSkipped.
  ///
  /// In ar, this message translates to:
  /// **'تخطّى {skipped}'**
  String architectureHudSkipped(int skipped);

  /// No description provided for @architectureHudModel.
  ///
  /// In ar, this message translates to:
  /// **'النموذج {model}'**
  String architectureHudModel(String model);

  /// No description provided for @architectureHudTool.
  ///
  /// In ar, this message translates to:
  /// **'الأداة {name}'**
  String architectureHudTool(String name);

  /// No description provided for @architectureHudLatency.
  ///
  /// In ar, this message translates to:
  /// **'{ms} مللي ثانية'**
  String architectureHudLatency(int ms);

  /// No description provided for @architectureHudCorrelation.
  ///
  /// In ar, this message translates to:
  /// **'المرجع {id}'**
  String architectureHudCorrelation(String id);

  /// No description provided for @architectureHudEmailSent.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل · {id}'**
  String architectureHudEmailSent(String id);

  /// No description provided for @architectureHudCallChip.
  ///
  /// In ar, this message translates to:
  /// **'اتصال · {id} · {status}'**
  String architectureHudCallChip(String id, String status);

  /// No description provided for @architectureHudCallId.
  ///
  /// In ar, this message translates to:
  /// **'اتصال · {id}'**
  String architectureHudCallId(String id);

  /// No description provided for @architectureHudCallStatusOnly.
  ///
  /// In ar, this message translates to:
  /// **'اتصال · {status}'**
  String architectureHudCallStatusOnly(String status);

  /// No description provided for @architectureHudCallPlanned.
  ///
  /// In ar, this message translates to:
  /// **'مجدول'**
  String get architectureHudCallPlanned;

  /// No description provided for @architectureHudCallRinging.
  ///
  /// In ar, this message translates to:
  /// **'يرن'**
  String get architectureHudCallRinging;

  /// No description provided for @architectureHudCallCompleted.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل'**
  String get architectureHudCallCompleted;

  /// No description provided for @architectureHudCallFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل'**
  String get architectureHudCallFailed;

  /// No description provided for @contactDeleteConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد؟'**
  String get contactDeleteConfirmTitle;

  /// No description provided for @contactDeleteConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيؤدي هذا إلى إزالة الحساب وجميع المعاملات المرتبطة به من دفترك.'**
  String get contactDeleteConfirmBody;

  /// No description provided for @contactDeleteConfirmAction.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get contactDeleteConfirmAction;

  /// No description provided for @ledgerDeleteConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد؟'**
  String get ledgerDeleteConfirmTitle;

  /// No description provided for @ledgerDeleteConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيؤدي هذا إلى حذف هذا الدفتر مع جميع الحسابات والمعاملات المرتبطة به.'**
  String get ledgerDeleteConfirmBody;

  /// No description provided for @ledgerDeleteConfirmAction.
  ///
  /// In ar, this message translates to:
  /// **'حذف الدفتر'**
  String get ledgerDeleteConfirmAction;

  /// No description provided for @settingsMerchantBranding.
  ///
  /// In ar, this message translates to:
  /// **'هوية المتجر'**
  String get settingsMerchantBranding;

  /// No description provided for @settingsMerchantBrandingSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الشعار واسم المتجر وكشوف PDF المخصصة'**
  String get settingsMerchantBrandingSubtitle;

  /// No description provided for @settingsPremium.
  ///
  /// In ar, this message translates to:
  /// **'الخطة والتفعيل'**
  String get settingsPremium;

  /// No description provided for @settingsPremiumSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'عرض خطتك أو استرداد رمز أو مقارنة الباقات'**
  String get settingsPremiumSubtitle;

  /// No description provided for @settingsGoogleAccount.
  ///
  /// In ar, this message translates to:
  /// **'حساب Google'**
  String get settingsGoogleAccount;

  /// No description provided for @settingsGoogleAccountSignInPrompt.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول للنسخ الاحتياطي على Drive'**
  String get settingsGoogleAccountSignInPrompt;

  /// No description provided for @settingsAnalytics.
  ///
  /// In ar, this message translates to:
  /// **'تحليلات الاستخدام'**
  String get settingsAnalytics;

  /// No description provided for @settingsAnalyticsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ساعدنا على تحسين دفتر ببيانات استخدام مجهولة'**
  String get settingsAnalyticsSubtitle;

  /// No description provided for @settingsAbout.
  ///
  /// In ar, this message translates to:
  /// **'عن دفتر'**
  String get settingsAbout;

  /// No description provided for @settingsVersionLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String settingsVersionLabel(String version);

  /// No description provided for @settingsRateApp.
  ///
  /// In ar, this message translates to:
  /// **'قيّم دفتر'**
  String get settingsRateApp;

  /// No description provided for @settingsContactSupport.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع الدعم'**
  String get settingsContactSupport;

  /// No description provided for @settingsSelectLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsSelectLanguage;

  /// No description provided for @settingsSelectTheme.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get settingsSelectTheme;

  /// No description provided for @settingsSelectCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get settingsSelectCurrency;

  /// No description provided for @settingsProBadgeLabel.
  ///
  /// In ar, this message translates to:
  /// **'Pro'**
  String get settingsProBadgeLabel;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ الإعدادات'**
  String get settingsSaveFailed;

  /// No description provided for @settingsStoreLaunchError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح المتجر'**
  String get settingsStoreLaunchError;

  /// No description provided for @settingsVaultTrustLabel.
  ///
  /// In ar, this message translates to:
  /// **'ثقة الخزنة'**
  String get settingsVaultTrustLabel;

  /// No description provided for @settingsVaultTrustHigh.
  ///
  /// In ar, this message translates to:
  /// **'محمي بالكامل'**
  String get settingsVaultTrustHigh;

  /// No description provided for @settingsVaultTrustMedium.
  ///
  /// In ar, this message translates to:
  /// **'محمي جزئياً'**
  String get settingsVaultTrustMedium;

  /// No description provided for @settingsVaultTrustLow.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج إجراء'**
  String get settingsVaultTrustLow;

  /// No description provided for @settingsGroupVault.
  ///
  /// In ar, this message translates to:
  /// **'صحة الخزنة'**
  String get settingsGroupVault;

  /// No description provided for @settingsSecurityAdvanced.
  ///
  /// In ar, this message translates to:
  /// **'أمان متقدّم'**
  String get settingsSecurityAdvanced;

  /// No description provided for @settingsCommandSecurity.
  ///
  /// In ar, this message translates to:
  /// **'الأمان'**
  String get settingsCommandSecurity;

  /// No description provided for @settingsCommandBackup.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي'**
  String get settingsCommandBackup;

  /// No description provided for @settingsCommandImport.
  ///
  /// In ar, this message translates to:
  /// **'استيراد'**
  String get settingsCommandImport;

  /// No description provided for @settingsCommandAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get settingsCommandAccount;

  /// No description provided for @settingsAboutDescription.
  ///
  /// In ar, this message translates to:
  /// **'دفتر هو سجلّك الرقمي الذي يعمل دون اتصال — صُمّم للتجّار الذين يحتاجون ثقة ووضوحاً وتحكّماً في كل دين ودفعة.'**
  String get settingsAboutDescription;

  /// No description provided for @settingsAboutOfflineFirst.
  ///
  /// In ar, this message translates to:
  /// **'يعمل بالكامل دون اتصال'**
  String get settingsAboutOfflineFirst;

  /// No description provided for @settingsAboutArabicFirst.
  ///
  /// In ar, this message translates to:
  /// **'تصميم عربي أولاً'**
  String get settingsAboutArabicFirst;

  /// No description provided for @settingsAboutFinancialGrade.
  ///
  /// In ar, this message translates to:
  /// **'سلامة مالية بمعايير عالية'**
  String get settingsAboutFinancialGrade;

  /// No description provided for @merchantBrandingScreenTitle.
  ///
  /// In ar, this message translates to:
  /// **'هوية المتجر'**
  String get merchantBrandingScreenTitle;

  /// No description provided for @merchantBrandingScreenSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'خصّص كشوف PDF بهوية متجرك'**
  String get merchantBrandingScreenSubtitle;

  /// No description provided for @merchantBrandingUpgradeTitle.
  ///
  /// In ar, this message translates to:
  /// **'الكشوف المخصصة ميزة Pro'**
  String get merchantBrandingUpgradeTitle;

  /// No description provided for @merchantBrandingUpgradeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ترقّ للباقة Pro لإضافة شعارك واسم متجرك لكل تصدير PDF.'**
  String get merchantBrandingUpgradeSubtitle;

  /// No description provided for @merchantBrandingUpgradeCta.
  ///
  /// In ar, this message translates to:
  /// **'عرض الباقات'**
  String get merchantBrandingUpgradeCta;

  /// No description provided for @merchantBrandingStoreName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المتجر'**
  String get merchantBrandingStoreName;

  /// No description provided for @merchantBrandingUploadLogo.
  ///
  /// In ar, this message translates to:
  /// **'رفع الشعار'**
  String get merchantBrandingUploadLogo;

  /// No description provided for @merchantBrandingRemoveLogo.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الشعار'**
  String get merchantBrandingRemoveLogo;

  /// No description provided for @merchantBrandingPreviewPdf.
  ///
  /// In ar, this message translates to:
  /// **'معاينة PDF'**
  String get merchantBrandingPreviewPdf;

  /// No description provided for @merchantBrandingSaveSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الهوية'**
  String get merchantBrandingSaveSuccess;

  /// No description provided for @merchantBrandingLogoRemoved.
  ///
  /// In ar, this message translates to:
  /// **'تمت إزالة الشعار'**
  String get merchantBrandingLogoRemoved;

  /// No description provided for @merchantBrandingPickSourceTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة شعار المتجر'**
  String get merchantBrandingPickSourceTitle;

  /// No description provided for @merchantBrandingPickCamera.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get merchantBrandingPickCamera;

  /// No description provided for @merchantBrandingPickGallery.
  ///
  /// In ar, this message translates to:
  /// **'مكتبة الصور'**
  String get merchantBrandingPickGallery;

  /// No description provided for @merchantBrandingCropTitle.
  ///
  /// In ar, this message translates to:
  /// **'ضبط الشعار'**
  String get merchantBrandingCropTitle;

  /// No description provided for @merchantBrandingCropHint.
  ///
  /// In ar, this message translates to:
  /// **'قرّب للتكبير واسحب لتحديد موضع الشعار'**
  String get merchantBrandingCropHint;

  /// No description provided for @merchantBrandingCropConfirm.
  ///
  /// In ar, this message translates to:
  /// **'استخدام الشعار'**
  String get merchantBrandingCropConfirm;

  /// No description provided for @merchantBrandingSaveProfileFirst.
  ///
  /// In ar, this message translates to:
  /// **'احفظ اسم المتجر قبل إضافة الشعار'**
  String get merchantBrandingSaveProfileFirst;

  /// No description provided for @merchantBrandingPreviewContactName.
  ///
  /// In ar, this message translates to:
  /// **'حساب تجريبي'**
  String get merchantBrandingPreviewContactName;

  /// No description provided for @merchantBrandingCountryYemen.
  ///
  /// In ar, this message translates to:
  /// **'اليمن'**
  String get merchantBrandingCountryYemen;

  /// No description provided for @merchantBrandingCountrySaudi.
  ///
  /// In ar, this message translates to:
  /// **'السعودية'**
  String get merchantBrandingCountrySaudi;

  /// No description provided for @merchantBrandingTapToEdit.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لتعديل هوية متجرك'**
  String get merchantBrandingTapToEdit;

  /// No description provided for @merchantBrandingEditIdentity.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الهوية'**
  String get merchantBrandingEditIdentity;

  /// No description provided for @merchantBrandingLivePreview.
  ///
  /// In ar, this message translates to:
  /// **'معاينة مباشرة'**
  String get merchantBrandingLivePreview;

  /// No description provided for @merchantBrandingStatementPreview.
  ///
  /// In ar, this message translates to:
  /// **'كيف يظهر على الكشوف'**
  String get merchantBrandingStatementPreview;

  /// No description provided for @merchantBrandingCompletionTitle.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الهوية'**
  String get merchantBrandingCompletionTitle;

  /// No description provided for @merchantBrandingStepPhone.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف'**
  String get merchantBrandingStepPhone;

  /// No description provided for @merchantBrandingStepLogo.
  ///
  /// In ar, this message translates to:
  /// **'الشعار'**
  String get merchantBrandingStepLogo;

  /// No description provided for @merchantBrandingIdentityComplete.
  ///
  /// In ar, this message translates to:
  /// **'الهوية مكتملة'**
  String get merchantBrandingIdentityComplete;

  /// No description provided for @merchantBrandingIdentityIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'أكمل هويتك للكشوف المخصصة'**
  String get merchantBrandingIdentityIncomplete;

  /// No description provided for @accountManagementTitle.
  ///
  /// In ar, this message translates to:
  /// **'حساب Google'**
  String get accountManagementTitle;

  /// No description provided for @accountManagementSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الحساب المستخدم للنسخ الاحتياطي على Drive'**
  String get accountManagementSubtitle;

  /// No description provided for @accountManagementSignOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get accountManagementSignOut;

  /// No description provided for @accountManagementSwitchAccount.
  ///
  /// In ar, this message translates to:
  /// **'تبديل الحساب'**
  String get accountManagementSwitchAccount;

  /// No description provided for @accountManagementSignOutConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get accountManagementSignOutConfirmTitle;

  /// No description provided for @accountManagementSignOutConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'لن تتمكن من الوصول إلى نسخ Google Drive الاحتياطية لهذا الحساب من التطبيق. بياناتك المحلية لن تتأثر. يمكنك تسجيل الدخول بنفس الحساب أو بحساب مختلف لاحقًا.'**
  String get accountManagementSignOutConfirmBody;

  /// No description provided for @accountManagementSignOutConfirmCta.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get accountManagementSignOutConfirmCta;

  /// No description provided for @accountManagementStatusConnected.
  ///
  /// In ar, this message translates to:
  /// **'الحساب مرتبط'**
  String get accountManagementStatusConnected;

  /// No description provided for @accountManagementStatusConnectedSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي السحابي متاح لهذا الحساب'**
  String get accountManagementStatusConnectedSubtitle;

  /// No description provided for @accountManagementStatusPartialSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الدخول — أنشئ نسخة احتياطية للمزامنة مع Drive'**
  String get accountManagementStatusPartialSubtitle;

  /// No description provided for @accountManagementStatusDisconnected.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب مرتبط'**
  String get accountManagementStatusDisconnected;

  /// No description provided for @accountManagementStatusDisconnectedSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لتفعيل النسخ الاحتياطي المشفّر على Google Drive'**
  String get accountManagementStatusDisconnectedSubtitle;

  /// No description provided for @accountManagementIdentityRing.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get accountManagementIdentityRing;

  /// No description provided for @accountManagementCloudRing.
  ///
  /// In ar, this message translates to:
  /// **'السحابة'**
  String get accountManagementCloudRing;

  /// No description provided for @accountManagementTrustLocalData.
  ///
  /// In ar, this message translates to:
  /// **'دفترك يبقى على هذا الجهاز — تسجيل الخروج لا يحذف بياناتك المحلية'**
  String get accountManagementTrustLocalData;

  /// No description provided for @accountManagementTrustDriveScope.
  ///
  /// In ar, this message translates to:
  /// **'وصول Google محصور في مجلد النسخ الاحتياطي الخاص بدفتر'**
  String get accountManagementTrustDriveScope;

  /// No description provided for @accountManagementActionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات الحساب'**
  String get accountManagementActionsTitle;

  /// No description provided for @accountManagementManageBackup.
  ///
  /// In ar, this message translates to:
  /// **'إدارة النسخ الاحتياطية'**
  String get accountManagementManageBackup;

  /// No description provided for @accountManagementManageBackupSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'عرض النسخ المحلية وحالة مزامنة Drive'**
  String get accountManagementManageBackupSubtitle;

  /// No description provided for @accountManagementConnectedBadge.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get accountManagementConnectedBadge;

  /// No description provided for @accountManagementMigrationRelinkTitle.
  ///
  /// In ar, this message translates to:
  /// **'أعد ربط حساب Google'**
  String get accountManagementMigrationRelinkTitle;

  /// No description provided for @accountManagementMigrationRelinkBody.
  ///
  /// In ar, this message translates to:
  /// **'تم اكتشاف تسجيل دخول سابق على هذا الجهاز. سجّل الدخول مجددًا لاستعادة النسخ الاحتياطي السحابي المشفّر — دفترك المحلي آمن.'**
  String get accountManagementMigrationRelinkBody;

  /// No description provided for @accountManagementNeedsReauthTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة'**
  String get accountManagementNeedsReauthTitle;

  /// No description provided for @accountManagementNeedsReauthBody.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية تسجيل الدخول إلى Google أو تم إلغاؤه. استعد الوصول لاستئناف النسخ الاحتياطي السحابي.'**
  String get accountManagementNeedsReauthBody;

  /// No description provided for @accountManagementRestoreAccess.
  ///
  /// In ar, this message translates to:
  /// **'استعادة الوصول'**
  String get accountManagementRestoreAccess;

  /// No description provided for @currentLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة الحالية'**
  String get currentLanguage;

  /// No description provided for @currentTheme.
  ///
  /// In ar, this message translates to:
  /// **'السمة الحالية'**
  String get currentTheme;

  /// No description provided for @ledgerDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الدفتر'**
  String get ledgerDetailTitle;

  /// No description provided for @contactDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الحساب'**
  String get contactDetailTitle;

  /// No description provided for @contactDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الحساب'**
  String get contactDetails;

  /// No description provided for @ledgerDetailSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'هذه شاشة مؤقتة لعرض تفاصيل الدفتر.'**
  String get ledgerDetailSubtitle;

  /// No description provided for @contactDetailSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'هذه شاشة مؤقتة لعرض تفاصيل الحساب.'**
  String get contactDetailSubtitle;

  /// No description provided for @ledgerIdLabel.
  ///
  /// In ar, this message translates to:
  /// **'معرّف الدفتر'**
  String get ledgerIdLabel;

  /// No description provided for @contactIdLabel.
  ///
  /// In ar, this message translates to:
  /// **'معرّف الحساب'**
  String get contactIdLabel;

  /// No description provided for @myLedgers.
  ///
  /// In ar, this message translates to:
  /// **'دفاتري'**
  String get myLedgers;

  /// Number of accounts shown on a ledger tile.
  ///
  /// In ar, this message translates to:
  /// **'{count} حسابات'**
  String ledgerAccountCount(int count);

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو الرقم'**
  String get searchHint;

  /// No description provided for @searchContacts.
  ///
  /// In ar, this message translates to:
  /// **'البحث في الحسابات...'**
  String get searchContacts;

  /// No description provided for @sort.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب'**
  String get sort;

  /// No description provided for @sortBy.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب حسب'**
  String get sortBy;

  /// No description provided for @sortByName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get sortByName;

  /// No description provided for @sortByBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get sortByBalance;

  /// No description provided for @sortByRecent.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get sortByRecent;

  /// No description provided for @filterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get filterAll;

  /// No description provided for @filterDebt.
  ///
  /// In ar, this message translates to:
  /// **'عليه'**
  String get filterDebt;

  /// No description provided for @filterCredit.
  ///
  /// In ar, this message translates to:
  /// **'له'**
  String get filterCredit;

  /// No description provided for @filterSettled.
  ///
  /// In ar, this message translates to:
  /// **'مُسدّد'**
  String get filterSettled;

  /// No description provided for @noSearchResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حسابات تطابق بحثك'**
  String get noSearchResults;

  /// No description provided for @noFilterResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حسابات في هذه الفئة'**
  String get noFilterResults;

  /// No description provided for @editLedger.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الدفتر'**
  String get editLedger;

  /// No description provided for @ledgerName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الدفتر'**
  String get ledgerName;

  /// No description provided for @selectColor.
  ///
  /// In ar, this message translates to:
  /// **'اختر اللون'**
  String get selectColor;

  /// No description provided for @selectIcon.
  ///
  /// In ar, this message translates to:
  /// **'اختر الأيقونة'**
  String get selectIcon;

  /// No description provided for @saveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التغييرات'**
  String get saveChanges;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @undo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get undo;

  /// No description provided for @contactDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الحساب'**
  String get contactDeleted;

  /// No description provided for @addContact.
  ///
  /// In ar, this message translates to:
  /// **'إضافة حساب'**
  String get addContact;

  /// No description provided for @name.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get name;

  /// No description provided for @nameRequired.
  ///
  /// In ar, this message translates to:
  /// **'الاسم مطلوب'**
  String get nameRequired;

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneNumber;

  /// No description provided for @contactEmailHint.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني (اختياري)'**
  String get contactEmailHint;

  /// No description provided for @contactEmailInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريداً صالحاً أو اتركه فارغاً.'**
  String get contactEmailInvalid;

  /// No description provided for @importFromContacts.
  ///
  /// In ar, this message translates to:
  /// **'استيراد من جهات الاتصال'**
  String get importFromContacts;

  /// No description provided for @notes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get notes;

  /// No description provided for @creditLimit.
  ///
  /// In ar, this message translates to:
  /// **'حد الائتمان'**
  String get creditLimit;

  /// No description provided for @selectCurrency.
  ///
  /// In ar, this message translates to:
  /// **'اختر العملة'**
  String get selectCurrency;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @editContact.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الحساب'**
  String get editContact;

  /// No description provided for @openWhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'فتح واتساب'**
  String get openWhatsApp;

  /// No description provided for @call.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get call;

  /// No description provided for @callLaunchError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح تطبيق الاتصال'**
  String get callLaunchError;

  /// No description provided for @whatsappLaunchError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح واتساب'**
  String get whatsappLaunchError;

  /// No description provided for @invalidAmount.
  ///
  /// In ar, this message translates to:
  /// **'القيمة غير صالحة'**
  String get invalidAmount;

  /// Number of transactions shown on a contact tile.
  ///
  /// In ar, this message translates to:
  /// **'{count} عمليات'**
  String transactionsCount(int count);

  /// No description provided for @emptyStateTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات بعد'**
  String get emptyStateTitle;

  /// No description provided for @noTransactionsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عمليات بعد'**
  String get noTransactionsYet;

  /// No description provided for @emptyStateSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أضف أول عنصر وسيظهر هنا.'**
  String get emptyStateSubtitle;

  /// No description provided for @emptyStateAction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة جديد'**
  String get emptyStateAction;

  /// No description provided for @archiveVaultTitle.
  ///
  /// In ar, this message translates to:
  /// **'خزنة الأرشيف'**
  String get archiveVaultTitle;

  /// No description provided for @archiveVaultSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'دفاتر مجمّدة — للقراءة فقط حتى الاستعادة'**
  String get archiveVaultSubtitle;

  /// No description provided for @archivedTotalLabel.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المؤرشف'**
  String get archivedTotalLabel;

  /// No description provided for @archivedLedgerReadOnlyBadge.
  ///
  /// In ar, this message translates to:
  /// **'للقراءة فقط'**
  String get archivedLedgerReadOnlyBadge;

  /// No description provided for @unarchiveLedgerAction.
  ///
  /// In ar, this message translates to:
  /// **'استعادة'**
  String get unarchiveLedgerAction;

  /// No description provided for @unarchiveLedgerSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تمت استعادة الدفتر إلى مساحة عملك'**
  String get unarchiveLedgerSuccess;

  /// No description provided for @archiveVaultEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'الخزنة فارغة'**
  String get archiveVaultEmptyTitle;

  /// No description provided for @archiveVaultEmptySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تظهر الدفاتر المؤرشفة هنا، مجمّدة في وقتها مع أرصدتها المحفوظة.'**
  String get archiveVaultEmptySubtitle;

  /// No description provided for @contactArchivedReadOnlyTitle.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب في دفتر مؤرشف'**
  String get contactArchivedReadOnlyTitle;

  /// No description provided for @contactArchivedReadOnlySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'البيانات للقراءة فقط. يمكنك عرض العمليات وتصدير الكشوف.'**
  String get contactArchivedReadOnlySubtitle;

  /// No description provided for @ledgerArchivedReadOnlyTitle.
  ///
  /// In ar, this message translates to:
  /// **'دفتر مؤرشف — للقراءة فقط'**
  String get ledgerArchivedReadOnlyTitle;

  /// No description provided for @ledgerArchivedReadOnlySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'هذا الدفتر مجمّد في خزنة الأرشيف. الأرصدة محفوظة؛ الإدخالات الجديدة معطّلة.'**
  String get ledgerArchivedReadOnlySubtitle;

  /// No description provided for @ledgerOptionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'خيارات الدفتر'**
  String get ledgerOptionsTitle;

  /// No description provided for @archiveLedgerAction.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة الدفتر'**
  String get archiveLedgerAction;

  /// No description provided for @financialCloseTitle.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة الدفتر'**
  String get financialCloseTitle;

  /// No description provided for @financialCloseSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'انقل هذا الدفتر إلى الخزنة ليبقى مساحة عملك مرتّبة.'**
  String get financialCloseSubtitle;

  /// No description provided for @financialCloseEducationTitle.
  ///
  /// In ar, this message translates to:
  /// **'ماذا يحدث عند الأرشفة؟'**
  String get financialCloseEducationTitle;

  /// No description provided for @financialCloseEducationBody.
  ///
  /// In ar, this message translates to:
  /// **'الأرشفة تُخفِي الدفتر عن مساحة عملك اليومية. تبقى كل الأرصدة والعمليات محفوظة—ويمكنك استعادته في أي وقت من خزنة الأرشيف.'**
  String get financialCloseEducationBody;

  /// No description provided for @financialCloseArchiveOnly.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة إلى الخزنة'**
  String get financialCloseArchiveOnly;

  /// No description provided for @financialCloseArchiveOnlyDescription.
  ///
  /// In ar, this message translates to:
  /// **'تجميد الدفتر كما هو. لا شيء يُنقل؛ كل شيء يبقى للقراءة في الخزنة.'**
  String get financialCloseArchiveOnlyDescription;

  /// No description provided for @carryForwardToggleLabel.
  ///
  /// In ar, this message translates to:
  /// **'نقل الأرصدة أولاً'**
  String get carryForwardToggleLabel;

  /// No description provided for @carryForwardToggleDescription.
  ///
  /// In ar, this message translates to:
  /// **'انقل الديون والأرصدة النشطة إلى دفتر آخر لتتابع تجارتك دون البدء من الصفر.'**
  String get carryForwardToggleDescription;

  /// No description provided for @carryForwardTargetPickerLabel.
  ///
  /// In ar, this message translates to:
  /// **'تابع في'**
  String get carryForwardTargetPickerLabel;

  /// No description provided for @carryForwardTargetPickerHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر الدفتر الذي تستقبل أرصدتك'**
  String get carryForwardTargetPickerHint;

  /// No description provided for @carryForwardCreateNewLedger.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ دفتراً جديداً'**
  String get carryForwardCreateNewLedger;

  /// No description provided for @carryForwardPreviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'معاينة'**
  String get carryForwardPreviewTitle;

  /// No description provided for @carryForwardPreviewContacts.
  ///
  /// In ar, this message translates to:
  /// **'{count} حسابات بأرصدة'**
  String carryForwardPreviewContacts(int count);

  /// No description provided for @carryForwardPreviewTransactions.
  ///
  /// In ar, this message translates to:
  /// **'{count} قيود افتتاحية'**
  String carryForwardPreviewTransactions(int count);

  /// No description provided for @openingBalanceItemName.
  ///
  /// In ar, this message translates to:
  /// **'رصيد افتتاحي'**
  String get openingBalanceItemName;

  /// No description provided for @carryForwardOpeningBalanceNote.
  ///
  /// In ar, this message translates to:
  /// **'رصيد افتتاحي مرحّل من {ledgerName}'**
  String carryForwardOpeningBalanceNote(String ledgerName);

  /// No description provided for @carryForwardSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم ختم الدفتر في الخزنة'**
  String get carryForwardSuccess;

  /// No description provided for @carryForwardSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'سجلاتك مجمّدة بأمان. استعدها في أي وقت من خزنة الأرشيف.'**
  String get carryForwardSuccessBody;

  /// No description provided for @carryForwardConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'أنت المتحكّم'**
  String get carryForwardConfirmTitle;

  /// No description provided for @carryForwardConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'ينتقل هذا الدفتر إلى الخزنة للقراءة فقط. استعده متى شئت—بياناتك لن تضيع أبداً.'**
  String get carryForwardConfirmBody;

  /// No description provided for @confirmArchive.
  ///
  /// In ar, this message translates to:
  /// **'ختم وأرشفة'**
  String get confirmArchive;

  /// No description provided for @archiveCeremonySealing.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ ختم الدفتر…'**
  String get archiveCeremonySealing;

  /// No description provided for @archiveCeremonyTransferring.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تأمين الأرصدة…'**
  String get archiveCeremonyTransferring;

  /// No description provided for @contactSearchArchivedBadge.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشف'**
  String get contactSearchArchivedBadge;

  /// No description provided for @homeArchiveVaultEntry.
  ///
  /// In ar, this message translates to:
  /// **'فتح خزنة الأرشيف'**
  String get homeArchiveVaultEntry;

  /// No description provided for @limitWarningTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحد يقترب'**
  String get limitWarningTitle;

  /// No description provided for @limitWarningSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أنت تقترب من حد الخطة المجانية.'**
  String get limitWarningSubtitle;

  /// No description provided for @limitReachedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز الحد'**
  String get limitReachedTitle;

  /// No description provided for @limitReachedSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'قم بالترقية لمتابعة الإضافة.'**
  String get limitReachedSubtitle;

  /// No description provided for @maxLedgersReached.
  ///
  /// In ar, this message translates to:
  /// **'عذراً، لقد وصلت للحد الأقصى (دفتر واحد) في النسخة المجانية'**
  String get maxLedgersReached;

  /// No description provided for @premiumUpgradeBannerTitle.
  ///
  /// In ar, this message translates to:
  /// **'أنت تقترب من حد الخطة المجانية'**
  String get premiumUpgradeBannerTitle;

  /// No description provided for @premiumUpgradeBannerUsage.
  ///
  /// In ar, this message translates to:
  /// **'{current} من {max} {resource}'**
  String premiumUpgradeBannerUsage(Object current, Object max, Object resource);

  /// No description provided for @premiumUpgradeResourceLedgers.
  ///
  /// In ar, this message translates to:
  /// **'دفاتر'**
  String get premiumUpgradeResourceLedgers;

  /// No description provided for @premiumUpgradeResourceContacts.
  ///
  /// In ar, this message translates to:
  /// **'حسابات'**
  String get premiumUpgradeResourceContacts;

  /// No description provided for @premiumUpgradeResourceTransactions.
  ///
  /// In ar, this message translates to:
  /// **'معاملات'**
  String get premiumUpgradeResourceTransactions;

  /// No description provided for @premiumUpgradeLedgers.
  ///
  /// In ar, this message translates to:
  /// **'أضف دفاتر بلا حدود ونظّم كل حساباتك في مكان واحد.'**
  String get premiumUpgradeLedgers;

  /// No description provided for @premiumUpgradeContacts.
  ///
  /// In ar, this message translates to:
  /// **'تابع عدداً غير محدود من العملاء دون حذف السجلات القديمة.'**
  String get premiumUpgradeContacts;

  /// No description provided for @premiumUpgradeTransactions.
  ///
  /// In ar, this message translates to:
  /// **'سجّل كل بيع ودفعة — بلا سقف على سجل معاملاتك.'**
  String get premiumUpgradeTransactions;

  /// No description provided for @premiumUpgradeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'فعّل مساحة عمل غير محدودة وكشوف PDF احترافية.'**
  String get premiumUpgradeSubtitle;

  /// No description provided for @premiumUpgradeCta.
  ///
  /// In ar, this message translates to:
  /// **'استكشف Pro'**
  String get premiumUpgradeCta;

  /// No description provided for @premiumUpgradeBannerHide.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء'**
  String get premiumUpgradeBannerHide;

  /// No description provided for @premiumUpgradeBannerHiddenToast.
  ///
  /// In ar, this message translates to:
  /// **'تم الإخفاء. يمكنك الترقية في أي وقت من الإعدادات.'**
  String get premiumUpgradeBannerHiddenToast;

  /// No description provided for @addTransaction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة عملية'**
  String get addTransaction;

  /// No description provided for @editTransaction.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المعاملة'**
  String get editTransaction;

  /// No description provided for @debt.
  ///
  /// In ar, this message translates to:
  /// **'عليه'**
  String get debt;

  /// No description provided for @payment.
  ///
  /// In ar, this message translates to:
  /// **'له'**
  String get payment;

  /// No description provided for @amount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get amount;

  /// No description provided for @itemName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الصنف'**
  String get itemName;

  /// No description provided for @descriptionOptional.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة (اختياري)'**
  String get descriptionOptional;

  /// No description provided for @date.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get date;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get yesterday;

  /// No description provided for @thisWeek.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get thisWeek;

  /// No description provided for @saveTransaction.
  ///
  /// In ar, this message translates to:
  /// **'حفظ العملية'**
  String get saveTransaction;

  /// No description provided for @amountRequired.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ مطلوب'**
  String get amountRequired;

  /// No description provided for @transactionSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ العملية بنجاح'**
  String get transactionSaved;

  /// No description provided for @creditLimitWarning.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه: لقد اقترب الحساب من الحد الائتماني'**
  String get creditLimitWarning;

  /// No description provided for @creditLimitExceeded.
  ///
  /// In ar, this message translates to:
  /// **'تحذير: لقد تجاوز الحساب الحد الائتماني المسموح به!'**
  String get creditLimitExceeded;

  /// No description provided for @creditLimitCallSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'اتصال لإبلاغهم بأن البضائع الجديدة معلّقة حتى السداد؟'**
  String get creditLimitCallSheetTitle;

  /// No description provided for @creditLimitCallSheetBody.
  ///
  /// In ar, this message translates to:
  /// **'{contactName} مدين بـ {outstanding} من حد ائتمان {limit}.'**
  String creditLimitCallSheetBody(
    String contactName,
    String outstanding,
    String limit,
  );

  /// No description provided for @creditLimitCallSheetPrepare.
  ///
  /// In ar, this message translates to:
  /// **'إعداد المكالمة'**
  String get creditLimitCallSheetPrepare;

  /// No description provided for @creditLimitCallSheetNotNow.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get creditLimitCallSheetNotNow;

  /// No description provided for @creditLimitCallSheetOutstanding.
  ///
  /// In ar, this message translates to:
  /// **'المستحق'**
  String get creditLimitCallSheetOutstanding;

  /// No description provided for @creditLimitCallSheetLimit.
  ///
  /// In ar, this message translates to:
  /// **'حد الائتمان'**
  String get creditLimitCallSheetLimit;

  /// No description provided for @collectionsDeskCreditLimitSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تجاوز الحد الائتماني — أكّد التواصل لهذا الحساب.'**
  String get collectionsDeskCreditLimitSubtitle;

  /// No description provided for @errorCreditLimitNoOutreach.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد هاتف أو بريد يمكن استخدامه للتواصل مع هذا الحساب.'**
  String get errorCreditLimitNoOutreach;

  /// No description provided for @notificationWarningTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه ائتماني'**
  String get notificationWarningTitle;

  /// Local notification body shown when a contact reaches the 80 percent credit warning threshold.
  ///
  /// In ar, this message translates to:
  /// **'لقد تجاوز حساب {contactName} نسبة 80% من الحد الائتماني.'**
  String notificationWarningBody(String contactName);

  /// Local notification body shown when a contact exceeds their credit limit.
  ///
  /// In ar, this message translates to:
  /// **'تحذير: حساب {contactName} تجاوز الحد الائتماني المسموح به!'**
  String notificationExceededBody(String contactName);

  /// No description provided for @recentTransactions.
  ///
  /// In ar, this message translates to:
  /// **'العمليات الأخيرة'**
  String get recentTransactions;

  /// No description provided for @transactionsError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل العمليات'**
  String get transactionsError;

  /// No description provided for @noLedgersYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد دفاتر بعد'**
  String get noLedgersYet;

  /// No description provided for @noLedgersSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ أول دفتر لبدء تتبع الديون.'**
  String get noLedgersSubtitle;

  /// No description provided for @addLedger.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دفتر'**
  String get addLedger;

  /// No description provided for @noContactsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حسابات بعد'**
  String get noContactsYet;

  /// No description provided for @noContactsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أضف أول حساب لهذا الدفتر.'**
  String get noContactsSubtitle;

  /// No description provided for @loadingError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ ما'**
  String get loadingError;

  /// No description provided for @ledgerDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الدفتر'**
  String get ledgerDeleted;

  /// No description provided for @transactionDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف المعاملة'**
  String get transactionDeleted;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @statement.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب'**
  String get statement;

  /// No description provided for @statementDetails.
  ///
  /// In ar, this message translates to:
  /// **'البيان'**
  String get statementDetails;

  /// No description provided for @type.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get type;

  /// No description provided for @description.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get description;

  /// No description provided for @totalPayment.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الدفعات'**
  String get totalPayment;

  /// No description provided for @generatedOn.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإنشاء'**
  String get generatedOn;

  /// No description provided for @runningBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد التراكمي'**
  String get runningBalance;

  /// No description provided for @page.
  ///
  /// In ar, this message translates to:
  /// **'صفحة'**
  String get page;

  /// No description provided for @currency.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get currency;

  /// No description provided for @exportStatement.
  ///
  /// In ar, this message translates to:
  /// **'تصدير كشف الحساب'**
  String get exportStatement;

  /// No description provided for @generatingPdf.
  ///
  /// In ar, this message translates to:
  /// **'جاري تجهيز الملف...'**
  String get generatingPdf;

  /// No description provided for @exportFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التصدير'**
  String get exportFailed;

  /// No description provided for @pdfFetchFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المعاملات'**
  String get pdfFetchFailed;

  /// No description provided for @pdfRenderFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء ملف PDF'**
  String get pdfRenderFailed;

  /// No description provided for @pdfSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ الملف'**
  String get pdfSaveFailed;

  /// No description provided for @pdfShareFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح خيارات المشاركة'**
  String get pdfShareFailed;

  /// No description provided for @pdfTimeout.
  ///
  /// In ar, this message translates to:
  /// **'استغرق التصدير وقتاً طويلاً. يرجى المحاولة مجدداً.'**
  String get pdfTimeout;

  /// No description provided for @pdfSavedLocally.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الكشف على الجهاز'**
  String get pdfSavedLocally;

  /// No description provided for @pdfPreparingData.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحضير البيانات...'**
  String get pdfPreparingData;

  /// No description provided for @pdfGroupingTransactions.
  ///
  /// In ar, this message translates to:
  /// **'جاري تجميع المعاملات...'**
  String get pdfGroupingTransactions;

  /// No description provided for @pdfBuildingLayout.
  ///
  /// In ar, this message translates to:
  /// **'جاري بناء التخطيط...'**
  String get pdfBuildingLayout;

  /// No description provided for @pdfRendering.
  ///
  /// In ar, this message translates to:
  /// **'جاري إنشاء المستند...'**
  String get pdfRendering;

  /// No description provided for @pdfComplete.
  ///
  /// In ar, this message translates to:
  /// **'تم!'**
  String get pdfComplete;

  /// No description provided for @pdfSaving.
  ///
  /// In ar, this message translates to:
  /// **'جاري الحفظ...'**
  String get pdfSaving;

  /// No description provided for @shareStatement.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الكشف'**
  String get shareStatement;

  /// موضوع مشاركة/بريد لملف PDF للكشف.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب — {contactName}'**
  String statementShareSubject(String contactName);

  /// No description provided for @exportStatementDateRange.
  ///
  /// In ar, this message translates to:
  /// **'تصدير لفترة تاريخية'**
  String get exportStatementDateRange;

  /// No description provided for @exportLedgerSummary.
  ///
  /// In ar, this message translates to:
  /// **'تصدير ملخص الدفتر'**
  String get exportLedgerSummary;

  /// No description provided for @ledgerSummaryReport.
  ///
  /// In ar, this message translates to:
  /// **'تقرير ملخص الدفتر'**
  String get ledgerSummaryReport;

  /// No description provided for @totalLedgerBalance.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي رصيد الدفتر'**
  String get totalLedgerBalance;

  /// No description provided for @rowNumber.
  ///
  /// In ar, this message translates to:
  /// **'#'**
  String get rowNumber;

  /// No description provided for @pdfListingContacts.
  ///
  /// In ar, this message translates to:
  /// **'جاري إدراج الحسابات...'**
  String get pdfListingContacts;

  /// No description provided for @pdfGroupingAccounts.
  ///
  /// In ar, this message translates to:
  /// **'جاري تجميع الحسابات حسب العملة...'**
  String get pdfGroupingAccounts;

  /// No description provided for @shareLedgerSummary.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة ملخص الدفتر'**
  String get shareLedgerSummary;

  /// موضوع مشاركة ملف PDF لملخص الدفتر.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الدفتر — {ledgerName}'**
  String ledgerSummaryShareSubject(String ledgerName);

  /// No description provided for @statementPeriodLabel.
  ///
  /// In ar, this message translates to:
  /// **'الفترة'**
  String get statementPeriodLabel;

  /// No description provided for @pdfNoTransactionsInRange.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد معاملات في هذه الفترة.'**
  String get pdfNoTransactionsInRange;

  /// No description provided for @csvImportTitle.
  ///
  /// In ar, this message translates to:
  /// **'استيراد CSV'**
  String get csvImportTitle;

  /// No description provided for @csvImportSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'طابق أعمدة الملف مع حقول الدفتر، تحقق من الترميز بالمعاينة، ثم نفّذ الاستيراد.'**
  String get csvImportSubtitle;

  /// No description provided for @csvImportSelectFile.
  ///
  /// In ar, this message translates to:
  /// **'اختيار ملف CSV'**
  String get csvImportSelectFile;

  /// No description provided for @csvImportEncoding.
  ///
  /// In ar, this message translates to:
  /// **'ترميز النص'**
  String get csvImportEncoding;

  /// No description provided for @csvEncodingAuto.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي (مُستحسن)'**
  String get csvEncodingAuto;

  /// No description provided for @csvEncodingUtf8.
  ///
  /// In ar, this message translates to:
  /// **'UTF-8'**
  String get csvEncodingUtf8;

  /// No description provided for @csvEncodingWindows1256.
  ///
  /// In ar, this message translates to:
  /// **'عربي ويندوز (1256)'**
  String get csvEncodingWindows1256;

  /// No description provided for @csvImportMappingSection.
  ///
  /// In ar, this message translates to:
  /// **'ربط الأعمدة'**
  String get csvImportMappingSection;

  /// No description provided for @csvImportPreviewSection.
  ///
  /// In ar, this message translates to:
  /// **'معاينة أول الصفوف'**
  String get csvImportPreviewSection;

  /// No description provided for @csvImportColumnHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر عمود CSV'**
  String get csvImportColumnHint;

  /// No description provided for @csvImportColumnNone.
  ///
  /// In ar, this message translates to:
  /// **'بدون'**
  String get csvImportColumnNone;

  /// No description provided for @csvImportStart.
  ///
  /// In ar, this message translates to:
  /// **'بدء الاستيراد'**
  String get csvImportStart;

  /// No description provided for @csvImportProgressLabel.
  ///
  /// In ar, this message translates to:
  /// **'جاري استيراد الصفوف…'**
  String get csvImportProgressLabel;

  /// No description provided for @csvImportSummaryTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الاستيراد'**
  String get csvImportSummaryTitle;

  /// No description provided for @csvImportTotalRows.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الصفوف'**
  String get csvImportTotalRows;

  /// No description provided for @csvImportSuccessLabel.
  ///
  /// In ar, this message translates to:
  /// **'نجح الاستيراد'**
  String get csvImportSuccessLabel;

  /// No description provided for @csvImportFailureLabel.
  ///
  /// In ar, this message translates to:
  /// **'صفوف تم تخطّيها'**
  String get csvImportFailureLabel;

  /// No description provided for @csvImportRowErrors.
  ///
  /// In ar, this message translates to:
  /// **'مشاكل في الصفوف'**
  String get csvImportRowErrors;

  /// No description provided for @csvImportAnotherFile.
  ///
  /// In ar, this message translates to:
  /// **'استيراد ملف آخر'**
  String get csvImportAnotherFile;

  /// No description provided for @csvImportFinish.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get csvImportFinish;

  /// No description provided for @csvImportNoLedgerMessage.
  ///
  /// In ar, this message translates to:
  /// **'افتح دفتراً من الرئيسية — يُرفق الاستيراد بدفتر واحد فقط.'**
  String get csvImportNoLedgerMessage;

  /// No description provided for @csvImportMappingIncompleteHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر عمود CSV لكل الحقول المطلوبة.'**
  String get csvImportMappingIncompleteHint;

  /// No description provided for @csvImportReadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر قراءة هذا الملف.'**
  String get csvImportReadFailed;

  /// No description provided for @csvImportEmptyFile.
  ///
  /// In ar, this message translates to:
  /// **'ملف CSV فارغ.'**
  String get csvImportEmptyFile;

  /// No description provided for @csvImportParseWorkerFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحليل ملف CSV.'**
  String get csvImportParseWorkerFailed;

  /// No description provided for @csvImportStructureFatalPrefix.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة في بنية CSV'**
  String get csvImportStructureFatalPrefix;

  /// No description provided for @csvImportBlockingFailureTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر بدء الاستيراد'**
  String get csvImportBlockingFailureTitle;

  /// No description provided for @csvImportSelectedFileLabel.
  ///
  /// In ar, this message translates to:
  /// **'الملف المختار'**
  String get csvImportSelectedFileLabel;

  /// No description provided for @csvImportDuplicatesSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'تطابق حسابات موجودة في الدفتر'**
  String get csvImportDuplicatesSheetTitle;

  /// رسالة قبل الاستيراد عند وجود حسابات متطابقة.
  ///
  /// In ar, this message translates to:
  /// **'وجدنا {count} حساباً في دفترك يُطابق صفوفاً في هذا الملف. يمكن دمج المعاملات الجديدة معها أو تخطِّي تلك الصفوف.'**
  String csvImportDuplicatesSheetBody(int count);

  /// No description provided for @csvImportDuplicatesMergeRecommended.
  ///
  /// In ar, this message translates to:
  /// **'دمج المعاملات (مُستحسَن)'**
  String get csvImportDuplicatesMergeRecommended;

  /// No description provided for @csvImportDuplicatesSkipLabel.
  ///
  /// In ar, this message translates to:
  /// **'تخطِّ التكرارات'**
  String get csvImportDuplicatesSkipLabel;

  /// No description provided for @csvImportDuplicatesCancelImport.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الاستيراد'**
  String get csvImportDuplicatesCancelImport;

  /// No description provided for @csvImportPrefabProgressLabel.
  ///
  /// In ar, this message translates to:
  /// **'جاري فحص الملف…'**
  String get csvImportPrefabProgressLabel;

  /// No description provided for @csvImportSkippedDuplicatesLabel.
  ///
  /// In ar, this message translates to:
  /// **'صفوف تم تخطّيها لمطابقتها حسابات موجودة'**
  String get csvImportSkippedDuplicatesLabel;

  /// No description provided for @csvImportStepFile.
  ///
  /// In ar, this message translates to:
  /// **'الملف'**
  String get csvImportStepFile;

  /// No description provided for @csvImportStepMapping.
  ///
  /// In ar, this message translates to:
  /// **'الربط'**
  String get csvImportStepMapping;

  /// No description provided for @csvImportStepImport.
  ///
  /// In ar, this message translates to:
  /// **'الاستيراد'**
  String get csvImportStepImport;

  /// No description provided for @csvImportStepDone.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة'**
  String get csvImportStepDone;

  /// No description provided for @csvImportRequiredFieldsLabel.
  ///
  /// In ar, this message translates to:
  /// **'حقول مطلوبة'**
  String get csvImportRequiredFieldsLabel;

  /// No description provided for @csvImportOptionalFieldsLabel.
  ///
  /// In ar, this message translates to:
  /// **'حقول اختيارية'**
  String get csvImportOptionalFieldsLabel;

  /// No description provided for @csvImportFileZoneHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لاختيار ملف .csv من دفترك السابق'**
  String get csvImportFileZoneHint;

  /// No description provided for @csvImportReplaceFile.
  ///
  /// In ar, this message translates to:
  /// **'ملف آخر'**
  String get csvImportReplaceFile;

  /// No description provided for @csvImportTargetLedgerLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاستيراد إلى'**
  String get csvImportTargetLedgerLabel;

  /// No description provided for @csvImportTargetLedgerHint.
  ///
  /// In ar, this message translates to:
  /// **'ستُضاف الحسابات والمعاملات إلى هذا الدفتر'**
  String get csvImportTargetLedgerHint;

  /// No description provided for @csvImportChooseLedgerTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر الدفتر'**
  String get csvImportChooseLedgerTitle;

  /// No description provided for @csvImportNoLedgerSelected.
  ///
  /// In ar, this message translates to:
  /// **'اختر دفتراً للمتابعة'**
  String get csvImportNoLedgerSelected;

  /// No description provided for @backupTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي والاستعادة'**
  String get backupTitle;

  /// No description provided for @backupStatusSafe.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك في أمان'**
  String get backupStatusSafe;

  /// No description provided for @backupStatusNoBackup.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نسخة احتياطية'**
  String get backupStatusNoBackup;

  /// No description provided for @backupStatusNoBackupSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ نسخة احتياطية لحماية بياناتك.'**
  String get backupStatusNoBackupSubtitle;

  /// No description provided for @backupLastBackup.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة احتياطية'**
  String get backupLastBackup;

  /// No description provided for @backupCreateNow.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء نسخة احتياطية الآن'**
  String get backupCreateNow;

  /// No description provided for @backupCreating.
  ///
  /// In ar, this message translates to:
  /// **'جاري إنشاء النسخة الاحتياطية…'**
  String get backupCreating;

  /// No description provided for @backupSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء النسخة الاحتياطية بنجاح'**
  String get backupSuccess;

  /// No description provided for @backupFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إنشاء النسخة الاحتياطية'**
  String get backupFailed;

  /// No description provided for @backupHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل النسخ الاحتياطية'**
  String get backupHistory;

  /// No description provided for @backupNoHistory.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نسخ احتياطية بعد'**
  String get backupNoHistory;

  /// No description provided for @backupShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get backupShare;

  /// No description provided for @backupRestore.
  ///
  /// In ar, this message translates to:
  /// **'استعادة'**
  String get backupRestore;

  /// No description provided for @backupDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get backupDelete;

  /// No description provided for @backupDeleteConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف النسخة الاحتياطية؟'**
  String get backupDeleteConfirmTitle;

  /// No description provided for @backupDeleteConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم حذف ملف النسخة الاحتياطية من جهازك بشكل نهائي.'**
  String get backupDeleteConfirmBody;

  /// No description provided for @backupDeleteSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف النسخة الاحتياطية'**
  String get backupDeleteSuccess;

  /// No description provided for @backupDeleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل حذف النسخة الاحتياطية'**
  String get backupDeleteFailed;

  /// حجم الملف بالبايت
  ///
  /// In ar, this message translates to:
  /// **'{size} بايت'**
  String backupSizeBytes(int size);

  /// حجم الملف بالكيلوبايت
  ///
  /// In ar, this message translates to:
  /// **'{size} ك.ب'**
  String backupSizeKb(String size);

  /// حجم الملف بالميغابايت
  ///
  /// In ar, this message translates to:
  /// **'{size} م.ب'**
  String backupSizeMb(String size);

  /// No description provided for @backupRestoreWarningTitle.
  ///
  /// In ar, this message translates to:
  /// **'⚠ تحذير: إجراء خطير'**
  String get backupRestoreWarningTitle;

  /// No description provided for @backupRestoreWarningBody.
  ///
  /// In ar, this message translates to:
  /// **'سيؤدي ذلك إلى استبدال قاعدة البيانات الحالية بالكامل. أي بيانات أضفتها بعد هذه النسخة الاحتياطية ستُفقد إلى الأبد. لا يمكن التراجع عن هذا الإجراء.'**
  String get backupRestoreWarningBody;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In ar, this message translates to:
  /// **'أفهم — قم بالاستعادة'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestoreCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get backupRestoreCancel;

  /// No description provided for @backupRestoring.
  ///
  /// In ar, this message translates to:
  /// **'جاري الاستعادة…'**
  String get backupRestoring;

  /// No description provided for @backupRestoreSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تمت الاستعادة'**
  String get backupRestoreSuccess;

  /// No description provided for @backupRestoreSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'تم استعادة بياناتك. يجب إعادة تشغيل التطبيق لتطبيق التغييرات.'**
  String get backupRestoreSuccessBody;

  /// No description provided for @backupRestoreRestartNow.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التشغيل الآن'**
  String get backupRestoreRestartNow;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشلت الاستعادة'**
  String get backupRestoreFailed;

  /// No description provided for @backupRestoreFromFile.
  ///
  /// In ar, this message translates to:
  /// **'الاستعادة من ملف خارجي'**
  String get backupRestoreFromFile;

  /// No description provided for @backupReminderLabel.
  ///
  /// In ar, this message translates to:
  /// **'تذكير النسخ الاحتياطي التلقائي'**
  String get backupReminderLabel;

  /// No description provided for @backupReminderOff.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get backupReminderOff;

  /// No description provided for @backupReminderWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعي'**
  String get backupReminderWeekly;

  /// No description provided for @backupReminderMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهري'**
  String get backupReminderMonthly;

  /// No description provided for @backupShareSubject.
  ///
  /// In ar, this message translates to:
  /// **'ملف نسخة دفتر الاحتياطية'**
  String get backupShareSubject;

  /// No description provided for @backupTrustEncrypted.
  ///
  /// In ar, this message translates to:
  /// **'مشفّر بـ AES-256 على جهازك'**
  String get backupTrustEncrypted;

  /// No description provided for @backupTrustDrivePrivate.
  ///
  /// In ar, this message translates to:
  /// **'يُحفظ في مجلد دفتر الخاص في Google Drive — لا يطّلع عليه أحد غيرك.'**
  String get backupTrustDrivePrivate;

  /// No description provided for @backupRelativeJustNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get backupRelativeJustNow;

  /// No description provided for @backupRelativeMinutes.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} د'**
  String backupRelativeMinutes(int count);

  /// No description provided for @backupRelativeHours.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} س'**
  String backupRelativeHours(int count);

  /// No description provided for @backupRelativeYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get backupRelativeYesterday;

  /// No description provided for @backupRelativeDays.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} أيام'**
  String backupRelativeDays(int count);

  /// No description provided for @backupHealthLocal.
  ///
  /// In ar, this message translates to:
  /// **'محلي'**
  String get backupHealthLocal;

  /// No description provided for @backupHealthCloud.
  ///
  /// In ar, this message translates to:
  /// **'سحابي'**
  String get backupHealthCloud;

  /// No description provided for @backupTotalSize.
  ///
  /// In ar, this message translates to:
  /// **'{count} نسخ · {size}'**
  String backupTotalSize(int count, String size);

  /// No description provided for @backupStatusLocalOnly.
  ///
  /// In ar, this message translates to:
  /// **'نسخة محلية نشطة — المزامنة السحابية معلّقة'**
  String get backupStatusLocalOnly;

  /// No description provided for @backupTimelineLatest.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get backupTimelineLatest;

  /// No description provided for @backupTimelineSwipeHint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب لتصفّح سجل النسخ الاحتياطية'**
  String get backupTimelineSwipeHint;

  /// No description provided for @backupCeremonyTitle.
  ///
  /// In ar, this message translates to:
  /// **'طقس الخزنة'**
  String get backupCeremonyTitle;

  /// No description provided for @backupCeremonyValidating.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحقق من السلامة…'**
  String get backupCeremonyValidating;

  /// No description provided for @backupCeremonyDecrypting.
  ///
  /// In ar, this message translates to:
  /// **'جاري فك تشفير الدفتر…'**
  String get backupCeremonyDecrypting;

  /// No description provided for @backupCeremonyApplying.
  ///
  /// In ar, this message translates to:
  /// **'جاري التطبيق على الخزنة…'**
  String get backupCeremonyApplying;

  /// No description provided for @backupCeremonyDownloading.
  ///
  /// In ar, this message translates to:
  /// **'جاري التنزيل من السحابة…'**
  String get backupCeremonyDownloading;

  /// No description provided for @backupCreateSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'تم ختم دفترك وحفظه بأمان.'**
  String get backupCreateSuccessBody;

  /// No description provided for @backupDriveSectionTitle.
  ///
  /// In ar, this message translates to:
  /// **'Google Drive'**
  String get backupDriveSectionTitle;

  /// No description provided for @backupDriveInviteBody.
  ///
  /// In ar, this message translates to:
  /// **'انسخ بياناتك احتياطيًا إلى Google Drive الشخصي — مجانًا ومشفّرًا وخاصًا.'**
  String get backupDriveInviteBody;

  /// No description provided for @backupDriveSignInWithGoogle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول عبر Google'**
  String get backupDriveSignInWithGoogle;

  /// No description provided for @backupDriveBackupToDrive.
  ///
  /// In ar, this message translates to:
  /// **'نسخ احتياطي إلى Drive'**
  String get backupDriveBackupToDrive;

  /// No description provided for @backupDriveRestoreFromDrive.
  ///
  /// In ar, this message translates to:
  /// **'استعادة من Drive'**
  String get backupDriveRestoreFromDrive;

  /// No description provided for @backupDriveCloudBackups.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطية السحابية'**
  String get backupDriveCloudBackups;

  /// No description provided for @backupDriveNoCloudBackups.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نسخ احتياطية في Google Drive بعد'**
  String get backupDriveNoCloudBackups;

  /// No description provided for @backupDriveSignOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج من Google'**
  String get backupDriveSignOut;

  /// No description provided for @backupDriveUploading.
  ///
  /// In ar, this message translates to:
  /// **'جاري الرفع إلى Google Drive…'**
  String get backupDriveUploading;

  /// No description provided for @backupDriveDownloading.
  ///
  /// In ar, this message translates to:
  /// **'جاري التنزيل من Google Drive…'**
  String get backupDriveDownloading;

  /// No description provided for @backupDriveCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get backupDriveCancel;

  /// نسبة تقدم النقل
  ///
  /// In ar, this message translates to:
  /// **'{percent}٪'**
  String backupDrivePercent(int percent);

  /// No description provided for @backupDrivePendingRetry.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي معلّق — سيُعاد تلقائيًا عند عودة الاتصال'**
  String get backupDrivePendingRetry;

  /// No description provided for @backupDriveRetryNow.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة الآن'**
  String get backupDriveRetryNow;

  /// No description provided for @backupDriveQuotaExceeded.
  ///
  /// In ar, this message translates to:
  /// **'مساحة Google Drive ممتلئة. حرّر مساحة أو أدِر النسخ القديمة'**
  String get backupDriveQuotaExceeded;

  /// No description provided for @backupDriveManageBackups.
  ///
  /// In ar, this message translates to:
  /// **'إدارة النسخ الاحتياطية'**
  String get backupDriveManageBackups;

  /// No description provided for @backupDriveAuthExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلسة Google. سجّل الدخول مجددًا للمتابعة.'**
  String get backupDriveAuthExpired;

  /// No description provided for @backupDriveOffline.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت. سيستأنف النسخ الاحتياطي عند عودة الشبكة.'**
  String get backupDriveOffline;

  /// No description provided for @backupDriveSignInAgain.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول مجددًا'**
  String get backupDriveSignInAgain;

  /// No description provided for @backupDriveOfflineGrantMissing.
  ///
  /// In ar, this message translates to:
  /// **'إذن النسخ الاحتياطي الدائم غير مكتمل. امنح صلاحية Drive مرة واحدة ليستمر النسخ التلقائي حتى مع إغلاق التطبيق.'**
  String get backupDriveOfflineGrantMissing;

  /// No description provided for @backupDriveOfflineGrantAction.
  ///
  /// In ar, this message translates to:
  /// **'إكمال الآن'**
  String get backupDriveOfflineGrantAction;

  /// No description provided for @backupDriveOfflineGrantFailed.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل تفويض Drive. تحقق من الاتصال وحاول مجددًا.'**
  String get backupDriveOfflineGrantFailed;

  /// No description provided for @backupDriveNotificationPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات متوقفة. فعّلها من إعدادات النظام ليصلك تنبيه عند تشغيل أو فشل النسخ الاحتياطي التلقائي.'**
  String get backupDriveNotificationPermissionDenied;

  /// No description provided for @backupDriveNotificationPermissionOpenSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get backupDriveNotificationPermissionOpenSettings;

  /// No description provided for @backupDriveBatteryOptTitle.
  ///
  /// In ar, this message translates to:
  /// **'السماح بالنسخ في الخلفية'**
  String get backupDriveBatteryOptTitle;

  /// No description provided for @backupDriveBatteryOptBody.
  ///
  /// In ar, this message translates to:
  /// **'على هذا الهاتف قد توقف قيود البطارية النسخ التلقائي إلى Drive أثناء إغلاق التطبيق. اسمح ببطارية غير مقيّدة ليستمر النسخ والجهاز يعمل ومتصل بالإنترنت.'**
  String get backupDriveBatteryOptBody;

  /// No description provided for @backupDriveBatteryOptAllow.
  ///
  /// In ar, this message translates to:
  /// **'السماح ببطارية غير مقيّدة'**
  String get backupDriveBatteryOptAllow;

  /// No description provided for @backupDriveBatteryOptLater.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get backupDriveBatteryOptLater;

  /// No description provided for @backupDriveTimingHonesty.
  ///
  /// In ar, this message translates to:
  /// **'يعمل تقريباً كل فترة بينما الهاتف يعمل ومتصل وليس متوقفاً بالقوة — وليس أثناء إطفاء الجهاز.'**
  String get backupDriveTimingHonesty;

  /// No description provided for @backupDriveDeleteRemoteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف النسخة السحابية؟'**
  String get backupDriveDeleteRemoteTitle;

  /// No description provided for @backupDriveDeleteRemoteBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُزال هذا الملف نهائيًا من Google Drive.'**
  String get backupDriveDeleteRemoteBody;

  /// No description provided for @backupDriveUploadSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم الرفع إلى Google Drive'**
  String get backupDriveUploadSuccess;

  /// No description provided for @backupDriveUploadFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل الرفع إلى Drive'**
  String get backupDriveUploadFailed;

  /// No description provided for @backupDriveDeleteRemoteSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف النسخة السحابية'**
  String get backupDriveDeleteRemoteSuccess;

  /// No description provided for @backupDriveDeleteRemoteFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل حذف النسخة السحابية'**
  String get backupDriveDeleteRemoteFailed;

  /// No description provided for @backupDriveSignInSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الدخول عبر Google'**
  String get backupDriveSignInSuccess;

  /// No description provided for @backupDriveSignInFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل الدخول عبر Google'**
  String get backupDriveSignInFailed;

  /// No description provided for @syncAuthBridgeFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بخادوم المزامنة. حاول مرة أخرى لاحقًا.'**
  String get syncAuthBridgeFailed;

  /// No description provided for @inviteCeremonyTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدعوة'**
  String get inviteCeremonyTitle;

  /// No description provided for @inviteCeremonyExpiredTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية هذه الدعوة'**
  String get inviteCeremonyExpiredTitle;

  /// No description provided for @inviteCeremonyExpiredBody.
  ///
  /// In ar, this message translates to:
  /// **'اطلب من صاحب المحل إرسال رابط دعوة جديد. يمكنك طلب ذلك من الزر أدناه.'**
  String get inviteCeremonyExpiredBody;

  /// No description provided for @inviteCeremonyRevokedTitle.
  ///
  /// In ar, this message translates to:
  /// **'هذه الدعوة لم تعد صالحة'**
  String get inviteCeremonyRevokedTitle;

  /// No description provided for @inviteCeremonyRevokedBody.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الرابط أو أنه غير متاح. اطلب دعوة جديدة من صاحب المحل.'**
  String get inviteCeremonyRevokedBody;

  /// No description provided for @inviteCeremonyAlreadyClaimedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم استخدام الدعوة مسبقًا'**
  String get inviteCeremonyAlreadyClaimedTitle;

  /// No description provided for @inviteCeremonyAlreadyClaimedBody.
  ///
  /// In ar, this message translates to:
  /// **'شخص آخر قبل هذه الدعوة. اطلب دعوة جديدة إن كنت ما زلت بحاجة للوصول.'**
  String get inviteCeremonyAlreadyClaimedBody;

  /// No description provided for @inviteCeremonyAlreadyClaimedByYouTitle.
  ///
  /// In ar, this message translates to:
  /// **'قبلت هذه الدعوة مسبقًا'**
  String get inviteCeremonyAlreadyClaimedByYouTitle;

  /// No description provided for @inviteCeremonyAlreadyClaimedByYouBody.
  ///
  /// In ar, this message translates to:
  /// **'تم المطالبة بهذا الرابط على حسابك. افتح التطبيق كالمعتاد أو اطلب دعوة جديدة إن تعذّر الوصول.'**
  String get inviteCeremonyAlreadyClaimedByYouBody;

  /// No description provided for @inviteCeremonyRequestCta.
  ///
  /// In ar, this message translates to:
  /// **'طلب دعوة جديدة'**
  String get inviteCeremonyRequestCta;

  /// No description provided for @inviteCeremonyPendingBody.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الطلب. اطلب من صاحب المحل فتح «الفريق» وإعادة إرسال الدعوة.'**
  String get inviteCeremonyPendingBody;

  /// No description provided for @inviteCeremonyOpenHome.
  ///
  /// In ar, this message translates to:
  /// **'فتح دفتر'**
  String get inviteCeremonyOpenHome;

  /// No description provided for @inviteCeremonyManualCodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'لديك رمز دعوة؟'**
  String get inviteCeremonyManualCodeLabel;

  /// No description provided for @inviteCeremonyManualCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'الصق رمز الدعوة أو الرابط الكامل'**
  String get inviteCeremonyManualCodeHint;

  /// No description provided for @inviteCeremonyPasteClipboard.
  ///
  /// In ar, this message translates to:
  /// **'لصق'**
  String get inviteCeremonyPasteClipboard;

  /// No description provided for @inviteCeremonySubmitCode.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get inviteCeremonySubmitCode;

  /// No description provided for @inviteAcceptTitle.
  ///
  /// In ar, this message translates to:
  /// **'دعوة للفريق'**
  String get inviteAcceptTitle;

  /// No description provided for @inviteAcceptPreviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'تمت دعوتك'**
  String get inviteAcceptPreviewTitle;

  /// No description provided for @inviteAcceptPreviewBody.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول بحساب Google الذي تلقّى هذه الدعوة للانضمام إلى مساحة العمل.'**
  String get inviteAcceptPreviewBody;

  /// No description provided for @inviteAcceptInvitedEmailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد المدعو'**
  String get inviteAcceptInvitedEmailLabel;

  /// No description provided for @inviteAcceptRoleLabel.
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get inviteAcceptRoleLabel;

  /// No description provided for @inviteAcceptCta.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول بـ Google للقبول'**
  String get inviteAcceptCta;

  /// No description provided for @inviteAcceptInProgress.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الانضمام…'**
  String get inviteAcceptInProgress;

  /// No description provided for @inviteAcceptEmailMismatch.
  ///
  /// In ar, this message translates to:
  /// **'حساب Google هذا لا يطابق البريد المدعو. سجّل الدخول بـ {email}.'**
  String inviteAcceptEmailMismatch(String email);

  /// No description provided for @inviteAcceptErrorGeneric.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر قبول الدعوة. أعد المحاولة أو اطلب رابطًا جديدًا من صاحب المحل.'**
  String get inviteAcceptErrorGeneric;

  /// No description provided for @inviteAcceptSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم بنجاح'**
  String get inviteAcceptSuccessTitle;

  /// No description provided for @inviteAcceptSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'انضممت إلى مساحة العمل بدور {role}. ستبدأ المزامنة عند الاتصال بالإنترنت.'**
  String inviteAcceptSuccessBody(String role);

  /// No description provided for @inviteAcceptContinueHome.
  ///
  /// In ar, this message translates to:
  /// **'فتح دفتر'**
  String get inviteAcceptContinueHome;

  /// No description provided for @syncReportConnectionRefused.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى خادوم المزامنة. تأكد أن هاتفك والحاسوب على نفس شبكة الواي فاي وأن خادوم Supabase المحلي يعمل.'**
  String get syncReportConnectionRefused;

  /// No description provided for @syncReportSyncNow.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة الآن'**
  String get syncReportSyncNow;

  /// No description provided for @syncReportSyncNowInProgress.
  ///
  /// In ar, this message translates to:
  /// **'جاري المزامنة…'**
  String get syncReportSyncNowInProgress;

  /// No description provided for @syncReportUpload.
  ///
  /// In ar, this message translates to:
  /// **'رفع'**
  String get syncReportUpload;

  /// No description provided for @syncReportUploadInProgress.
  ///
  /// In ar, this message translates to:
  /// **'جاري الرفع…'**
  String get syncReportUploadInProgress;

  /// No description provided for @syncReportDownload.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل'**
  String get syncReportDownload;

  /// No description provided for @syncReportDownloadInProgress.
  ///
  /// In ar, this message translates to:
  /// **'جاري التنزيل…'**
  String get syncReportDownloadInProgress;

  /// No description provided for @syncReportPushSuccess.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا يوجد شيء لرفعه} =1{تم رفع تغيير واحد} other{تم رفع {count} تغيير}}'**
  String syncReportPushSuccess(int count);

  /// No description provided for @syncReportPullSuccess.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا توجد تغييرات جديدة} =1{تم تنزيل تغيير واحد} other{تم تنزيل {count} تغيير}}'**
  String syncReportPullSuccess(int count);

  /// No description provided for @syncReportPushFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل الرفع. تحقق من الاتصال وحاول مرة أخرى.'**
  String get syncReportPushFailed;

  /// No description provided for @syncReportPullFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التنزيل. تحقق من الاتصال وحاول مرة أخرى.'**
  String get syncReportPullFailed;

  /// No description provided for @syncReportDeviceRegistrationFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل هذا الجهاز على خادوم المزامنة.'**
  String get syncReportDeviceRegistrationFailed;

  /// No description provided for @syncReportStatusIdle.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار أول مزامنة'**
  String get syncReportStatusIdle;

  /// No description provided for @syncReportTitle.
  ///
  /// In ar, this message translates to:
  /// **'تقرير المزامنة'**
  String get syncReportTitle;

  /// No description provided for @syncReportStatusLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل حالة المزامنة'**
  String get syncReportStatusLoadFailed;

  /// No description provided for @syncReportStatusSuccess.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة ناجحة'**
  String get syncReportStatusSuccess;

  /// No description provided for @syncReportStatusPartial.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة جزئية — يوجد تعارضات'**
  String get syncReportStatusPartial;

  /// No description provided for @syncReportStatusFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشلت المزامنة'**
  String get syncReportStatusFailed;

  /// No description provided for @syncReportStatusDormant.
  ///
  /// In ar, this message translates to:
  /// **'المزامنة غير نشطة'**
  String get syncReportStatusDormant;

  /// No description provided for @syncReportConflictsHeading.
  ///
  /// In ar, this message translates to:
  /// **'تعارضات تحتاج مراجعة'**
  String get syncReportConflictsHeading;

  /// No description provided for @syncReportStatMerged.
  ///
  /// In ar, this message translates to:
  /// **'عمليات مدمجة'**
  String get syncReportStatMerged;

  /// No description provided for @syncReportStatPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد الانتظار'**
  String get syncReportStatPending;

  /// No description provided for @syncReportStatConflicts.
  ///
  /// In ar, this message translates to:
  /// **'تعارضات'**
  String get syncReportStatConflicts;

  /// No description provided for @syncReportConflictDeleteVsEdit.
  ///
  /// In ar, this message translates to:
  /// **'حذف مقابل تعديل'**
  String get syncReportConflictDeleteVsEdit;

  /// No description provided for @syncReportConflictConcurrentCreate.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء متزامن'**
  String get syncReportConflictConcurrentCreate;

  /// No description provided for @syncReportConflictAmbiguous.
  ///
  /// In ar, this message translates to:
  /// **'تعارض غير محدد'**
  String get syncReportConflictAmbiguous;

  /// No description provided for @syncReportConflictRejectedPush.
  ///
  /// In ar, this message translates to:
  /// **'رفضه الخادم'**
  String get syncReportConflictRejectedPush;

  /// No description provided for @syncReportEntityLedger.
  ///
  /// In ar, this message translates to:
  /// **'دفتر'**
  String get syncReportEntityLedger;

  /// No description provided for @syncReportEntityContact.
  ///
  /// In ar, this message translates to:
  /// **'جهة اتصال'**
  String get syncReportEntityContact;

  /// No description provided for @syncReportEntityTransaction.
  ///
  /// In ar, this message translates to:
  /// **'معاملة'**
  String get syncReportEntityTransaction;

  /// No description provided for @syncReportNoConflicts.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تعارضات — جميع البيانات متزامنة'**
  String get syncReportNoConflicts;

  /// No description provided for @syncReportDormantTitle.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة متعددة الأجهزة'**
  String get syncReportDormantTitle;

  /// No description provided for @syncReportDormantBody.
  ///
  /// In ar, this message translates to:
  /// **'قم بالترقية إلى Pro+ لمزامنة بياناتك عبر أجهزة متعددة'**
  String get syncReportDormantBody;

  /// No description provided for @backupDriveSignOutSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الخروج من Google'**
  String get backupDriveSignOutSuccess;

  /// No description provided for @backupDriveSignOutFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل الخروج'**
  String get backupDriveSignOutFailed;

  /// No description provided for @backupDriveRestorePickTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر نسخة احتياطية للاستعادة'**
  String get backupDriveRestorePickTitle;

  /// No description provided for @backupDriveRestoreLoading.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل النسخ الاحتياطية من Google Drive…'**
  String get backupDriveRestoreLoading;

  /// No description provided for @backupDriveRestorePickerCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{نسخة احتياطية واحدة} other{{count} نسخة احتياطية}}'**
  String backupDriveRestorePickerCount(int count);

  /// No description provided for @backupDriveRestorePickDate.
  ///
  /// In ar, this message translates to:
  /// **'اختر تاريخاً'**
  String get backupDriveRestorePickDate;

  /// No description provided for @backupDriveRestoreClearDate.
  ///
  /// In ar, this message translates to:
  /// **'كل التواريخ'**
  String get backupDriveRestoreClearDate;

  /// No description provided for @backupDriveRestoreDateEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نسخ احتياطية في هذا التاريخ'**
  String get backupDriveRestoreDateEmpty;

  /// No description provided for @backupDriveCloudBackupsPreviewFootnote.
  ///
  /// In ar, this message translates to:
  /// **'عرض أحدث {shown} من {total}. استخدم «استعادة من Drive» لتصفح كل النسخ حسب التاريخ.'**
  String backupDriveCloudBackupsPreviewFootnote(int shown, int total);

  /// No description provided for @backupDriveAutoBackupLabel.
  ///
  /// In ar, this message translates to:
  /// **'نسخ احتياطي تلقائي إلى Drive'**
  String get backupDriveAutoBackupLabel;

  /// No description provided for @backupDriveAutoBackupInterval.
  ///
  /// In ar, this message translates to:
  /// **'فترة النسخ الاحتياطي'**
  String get backupDriveAutoBackupInterval;

  /// No description provided for @backupDriveAutoBackupDaily.
  ///
  /// In ar, this message translates to:
  /// **'يومي'**
  String get backupDriveAutoBackupDaily;

  /// No description provided for @backupDriveAutoBackupWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعي'**
  String get backupDriveAutoBackupWeekly;

  /// No description provided for @backupDriveHiddenFolderHint.
  ///
  /// In ar, this message translates to:
  /// **'تُخزَّن النسخ الاحتياطية في مجلد مخفي وآمن داخل Google Drive لمنع الحذف العرضي.'**
  String get backupDriveHiddenFolderHint;

  /// No description provided for @backupDriveAutoBackupLastRun.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخ احتياطي تلقائي: {when}'**
  String backupDriveAutoBackupLastRun(String when);

  /// No description provided for @backupDriveAutoBackupNeverRun.
  ///
  /// In ar, this message translates to:
  /// **'لم يُنفَّذ نسخ احتياطي تلقائي بعد'**
  String get backupDriveAutoBackupNeverRun;

  /// No description provided for @backupDriveAutoBackupIosHint.
  ///
  /// In ar, this message translates to:
  /// **'على iPhone، يحدّد النظام موعد النسخ الاحتياطي تلقائيًا عندما يكون ذلك مناسبًا للبطارية.'**
  String get backupDriveAutoBackupIosHint;

  /// No description provided for @backupAutoNotifInProgressTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسخ احتياطي تلقائي'**
  String get backupAutoNotifInProgressTitle;

  /// No description provided for @backupAutoNotifInProgressBody.
  ///
  /// In ar, this message translates to:
  /// **'جاري رفع نسخة دفتر الاحتياطية إلى Google Drive…'**
  String get backupAutoNotifInProgressBody;

  /// No description provided for @backupAutoNotifSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل النسخ الاحتياطي التلقائي'**
  String get backupAutoNotifSuccessTitle;

  /// No description provided for @backupAutoNotifSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ نسختك المشفّرة في Google Drive بنجاح.'**
  String get backupAutoNotifSuccessBody;

  /// No description provided for @backupAutoNotifRetryTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي معلّق'**
  String get backupAutoNotifRetryTitle;

  /// No description provided for @backupAutoNotifRetryBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت. سيُعاد الرفع تلقائيًا عند عودة الشبكة.'**
  String get backupAutoNotifRetryBody;

  /// No description provided for @backupAutoNotifNeedsReauthTitle.
  ///
  /// In ar, this message translates to:
  /// **'يلزم تسجيل الدخول مجددًا'**
  String get backupAutoNotifNeedsReauthTitle;

  /// No description provided for @backupAutoNotifNeedsReauthBody.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلسة Google. افتح دفتر وسجّل الدخول لاستئناف النسخ الاحتياطي التلقائي.'**
  String get backupAutoNotifNeedsReauthBody;

  /// No description provided for @backupAutoNotifQuotaTitle.
  ///
  /// In ar, this message translates to:
  /// **'مساحة Google Drive ممتلئة'**
  String get backupAutoNotifQuotaTitle;

  /// No description provided for @backupAutoNotifQuotaBody.
  ///
  /// In ar, this message translates to:
  /// **'حرّر مساحة في Drive أو احذف نسخ دفتر القديمة من الإعدادات.'**
  String get backupAutoNotifQuotaBody;

  /// No description provided for @backupAutoNotifStorageFullTitle.
  ///
  /// In ar, this message translates to:
  /// **'مساحة الجهاز غير كافية'**
  String get backupAutoNotifStorageFullTitle;

  /// No description provided for @backupAutoNotifStorageFullBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إنشاء نسخة احتياطية. حرّر مساحة على جهازك ثم أعد المحاولة.'**
  String get backupAutoNotifStorageFullBody;

  /// No description provided for @backupAutoNotifFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'فشل النسخ الاحتياطي التلقائي'**
  String get backupAutoNotifFailedTitle;

  /// No description provided for @backupAutoNotifFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر رفع النسخة الاحتياطية. افتح دفتر للاطلاع على التفاصيل.'**
  String get backupAutoNotifFailedBody;

  /// No description provided for @smokeTestTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختبار السحابة'**
  String get smokeTestTitle;

  /// No description provided for @smokeTestButton.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل اختبار السحابة'**
  String get smokeTestButton;

  /// No description provided for @smokeTestSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من تسجيل الدخول بـ Google و Drive'**
  String get smokeTestSubtitle;

  /// No description provided for @smokeTestRunning.
  ///
  /// In ar, this message translates to:
  /// **'جاري التشخيص…'**
  String get smokeTestRunning;

  /// No description provided for @smokeTestComplete.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل التشخيص'**
  String get smokeTestComplete;

  /// No description provided for @smokeTestClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get smokeTestClose;

  /// No description provided for @preflightSignIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دخول تفاعلي'**
  String get preflightSignIn;

  /// No description provided for @preflightDriveRoundTrip.
  ///
  /// In ar, this message translates to:
  /// **'اختبار Drive الكامل'**
  String get preflightDriveRoundTrip;

  /// No description provided for @preflightSilentSignIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دخول صامت'**
  String get preflightSilentSignIn;

  /// No description provided for @preflightSignOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get preflightSignOut;

  /// No description provided for @preflightConsoleTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل التشخيص'**
  String get preflightConsoleTitle;

  /// No description provided for @preflightClearLog.
  ///
  /// In ar, this message translates to:
  /// **'مسح السجل'**
  String get preflightClearLog;

  /// No description provided for @premiumTitle.
  ///
  /// In ar, this message translates to:
  /// **'الخطط'**
  String get premiumTitle;

  /// No description provided for @premiumHeroTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر الخطة المناسبة لمتجرك'**
  String get premiumHeroTitle;

  /// No description provided for @premiumHeroTagline.
  ///
  /// In ar, this message translates to:
  /// **'حدود واضحة في المجاني. مساحة عمل بلا سقف في Pro. مزامنة وأتمتة في Pro+.'**
  String get premiumHeroTagline;

  /// No description provided for @premiumHeroTaglineContest.
  ///
  /// In ar, this message translates to:
  /// **'حدود واضحة في المجاني. مساحة عمل بلا سقف في Pro. تحليلات وأتمتة في Pro+.'**
  String get premiumHeroTaglineContest;

  /// No description provided for @premiumVaultSealTitle.
  ///
  /// In ar, this message translates to:
  /// **'رمز التفعيل'**
  String get premiumVaultSealTitle;

  /// No description provided for @premiumVaultSealSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز Pro أو Pro+. تظهر الشرطات أثناء الكتابة.'**
  String get premiumVaultSealSubtitle;

  /// No description provided for @premiumTrustEncrypted.
  ///
  /// In ar, this message translates to:
  /// **'تشفير AES-256 على جهازك قبل أي رفع'**
  String get premiumTrustEncrypted;

  /// No description provided for @premiumTrustOffline.
  ///
  /// In ar, this message translates to:
  /// **'الخطط تعمل دون إنترنت — يُزامَن التفعيل عند عودة الاتصال'**
  String get premiumTrustOffline;

  /// No description provided for @activationBrowsePlans.
  ///
  /// In ar, this message translates to:
  /// **'تصفّح الخطط'**
  String get activationBrowsePlans;

  /// No description provided for @activationCodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'رمز التفعيل'**
  String get activationCodeLabel;

  /// No description provided for @activationCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'PROPLUS-XXXX-XXXX-XXXX-XXXX'**
  String get activationCodeHint;

  /// No description provided for @activationHaveCode.
  ///
  /// In ar, this message translates to:
  /// **'إضافة رمز تفعيل'**
  String get activationHaveCode;

  /// No description provided for @activationAddCode.
  ///
  /// In ar, this message translates to:
  /// **'إضافة رمز تفعيل'**
  String get activationAddCode;

  /// No description provided for @activateButton.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get activateButton;

  /// No description provided for @activating.
  ///
  /// In ar, this message translates to:
  /// **'جاري التفعيل…'**
  String get activating;

  /// No description provided for @activationSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل الخطة'**
  String get activationSuccessTitle;

  /// No description provided for @activationSuccessSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'خطتك الجديدة جاهزة. استمتع بقوة دفترك الكاملة.'**
  String get activationSuccessSubtitle;

  /// No description provided for @activationSuccessDone.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get activationSuccessDone;

  /// No description provided for @activationErrorInvalid.
  ///
  /// In ar, this message translates to:
  /// **'رمز غير صالح. تحقق من الرمز وحاول مجدداً.'**
  String get activationErrorInvalid;

  /// No description provided for @planStatusTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطتك'**
  String get planStatusTitle;

  /// No description provided for @planTierFree.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get planTierFree;

  /// No description provided for @planTierPro.
  ///
  /// In ar, this message translates to:
  /// **'Pro'**
  String get planTierPro;

  /// No description provided for @planTierProPlus.
  ///
  /// In ar, this message translates to:
  /// **'Pro+'**
  String get planTierProPlus;

  /// No description provided for @planLegendCurrent.
  ///
  /// In ar, this message translates to:
  /// **'الحالية'**
  String get planLegendCurrent;

  /// No description provided for @planExpiresOn.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي في {date}'**
  String planExpiresOn(Object date);

  /// No description provided for @planDaysRemaining.
  ///
  /// In ar, this message translates to:
  /// **'متبقي {count} يوماً'**
  String planDaysRemaining(Object count);

  /// No description provided for @planLifetime.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك نشط'**
  String get planLifetime;

  /// No description provided for @tierCompareFree.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get tierCompareFree;

  /// No description provided for @tierComparePro.
  ///
  /// In ar, this message translates to:
  /// **'Pro'**
  String get tierComparePro;

  /// No description provided for @tierCompareProPlus.
  ///
  /// In ar, this message translates to:
  /// **'Pro+'**
  String get tierCompareProPlus;

  /// No description provided for @tierPriceFree.
  ///
  /// In ar, this message translates to:
  /// **'0 \$'**
  String get tierPriceFree;

  /// No description provided for @freeTierPrice.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get freeTierPrice;

  /// No description provided for @tierPricePro.
  ///
  /// In ar, this message translates to:
  /// **'24.99\$/سنة'**
  String get tierPricePro;

  /// No description provided for @tierPriceProPlus.
  ///
  /// In ar, this message translates to:
  /// **'49.99\$/سنة'**
  String get tierPriceProPlus;

  /// No description provided for @tierPriceProAmount.
  ///
  /// In ar, this message translates to:
  /// **'\$24.99'**
  String get tierPriceProAmount;

  /// No description provided for @tierPriceProPeriod.
  ///
  /// In ar, this message translates to:
  /// **'/سنة'**
  String get tierPriceProPeriod;

  /// No description provided for @tierPriceProPlusAmount.
  ///
  /// In ar, this message translates to:
  /// **'\$49.99'**
  String get tierPriceProPlusAmount;

  /// No description provided for @tierPriceProPlusPeriod.
  ///
  /// In ar, this message translates to:
  /// **'/سنة'**
  String get tierPriceProPlusPeriod;

  /// No description provided for @tierBadgeSavePro.
  ///
  /// In ar, this message translates to:
  /// **'وفّر 20٪'**
  String get tierBadgeSavePro;

  /// No description provided for @tierBadgeSaveProPlus.
  ///
  /// In ar, this message translates to:
  /// **'الأقوى'**
  String get tierBadgeSaveProPlus;

  /// No description provided for @tierBadgeRecommended.
  ///
  /// In ar, this message translates to:
  /// **'موصى بها'**
  String get tierBadgeRecommended;

  /// No description provided for @tierCardHighlightFree1.
  ///
  /// In ar, this message translates to:
  /// **'دفتر واحد و50 حساباً'**
  String get tierCardHighlightFree1;

  /// No description provided for @tierCardHighlightFree2.
  ///
  /// In ar, this message translates to:
  /// **'500 معاملة نشطة'**
  String get tierCardHighlightFree2;

  /// No description provided for @tierCardHighlightFree3.
  ///
  /// In ar, this message translates to:
  /// **'استيراد CSV مجاناً'**
  String get tierCardHighlightFree3;

  /// No description provided for @tierCardHighlightPro1.
  ///
  /// In ar, this message translates to:
  /// **'مساحة عمل غير محدودة'**
  String get tierCardHighlightPro1;

  /// No description provided for @tierCardHighlightPro2.
  ///
  /// In ar, this message translates to:
  /// **'كشوف PDF بعلامتك التجارية'**
  String get tierCardHighlightPro2;

  /// No description provided for @tierCardHighlightProPlus1.
  ///
  /// In ar, this message translates to:
  /// **'كل مزايا Pro'**
  String get tierCardHighlightProPlus1;

  /// No description provided for @tierCardHighlightProPlus2.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة متعددة الأجهزة'**
  String get tierCardHighlightProPlus2;

  /// No description provided for @tierCardHighlightProPlus2Contest.
  ///
  /// In ar, this message translates to:
  /// **'مكتب تحصيل الوكيل الذكي'**
  String get tierCardHighlightProPlus2Contest;

  /// No description provided for @tierCardHighlightProPlus3.
  ///
  /// In ar, this message translates to:
  /// **'وكيل الإغلاق — صوت وطقوس'**
  String get tierCardHighlightProPlus3;

  /// No description provided for @tierCardCtaFree.
  ///
  /// In ar, this message translates to:
  /// **'استمر مجاناً'**
  String get tierCardCtaFree;

  /// No description provided for @tierCardCtaPro.
  ///
  /// In ar, this message translates to:
  /// **'فعّل Pro'**
  String get tierCardCtaPro;

  /// No description provided for @tierCardCtaProPlus.
  ///
  /// In ar, this message translates to:
  /// **'فعّل Pro+'**
  String get tierCardCtaProPlus;

  /// No description provided for @tierCardCurrentPlan.
  ///
  /// In ar, this message translates to:
  /// **'خطتك الحالية'**
  String get tierCardCurrentPlan;

  /// No description provided for @tierCardTaglineFree.
  ///
  /// In ar, this message translates to:
  /// **'كل ما تحتاجه للبداية'**
  String get tierCardTaglineFree;

  /// No description provided for @tierCardTaglinePro.
  ///
  /// In ar, this message translates to:
  /// **'للمتاجر النامية — بلا سقف'**
  String get tierCardTaglinePro;

  /// No description provided for @tierCardTaglineProPlus.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة متعددة الأجهزة والأتمتة'**
  String get tierCardTaglineProPlus;

  /// No description provided for @tierCardTaglineProPlusContest.
  ///
  /// In ar, this message translates to:
  /// **'وكيل الإغلاق والتحصيل'**
  String get tierCardTaglineProPlusContest;

  /// No description provided for @tierCardBilledAnnually.
  ///
  /// In ar, this message translates to:
  /// **'يُدفع سنوياً'**
  String get tierCardBilledAnnually;

  /// No description provided for @tierCardOldPricePro.
  ///
  /// In ar, this message translates to:
  /// **'\$31.99'**
  String get tierCardOldPricePro;

  /// No description provided for @tierCardOldPriceProPlus.
  ///
  /// In ar, this message translates to:
  /// **'\$62.99'**
  String get tierCardOldPriceProPlus;

  /// No description provided for @tierCompareTitle.
  ///
  /// In ar, this message translates to:
  /// **'قارن المزايا'**
  String get tierCompareTitle;

  /// No description provided for @tierCompareSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اضغط فئة لعرض ما تتضمنه كل خطة'**
  String get tierCompareSubtitle;

  /// No description provided for @tierMatrixGroupWorkspace.
  ///
  /// In ar, this message translates to:
  /// **'مساحة العمل'**
  String get tierMatrixGroupWorkspace;

  /// No description provided for @tierMatrixGroupData.
  ///
  /// In ar, this message translates to:
  /// **'البيانات والنسخ الاحتياطي'**
  String get tierMatrixGroupData;

  /// No description provided for @tierMatrixGroupCloud.
  ///
  /// In ar, this message translates to:
  /// **'السحابة والأتمتة'**
  String get tierMatrixGroupCloud;

  /// No description provided for @tierMatrixGroupGrowth.
  ///
  /// In ar, this message translates to:
  /// **'نموّ الأعمال'**
  String get tierMatrixGroupGrowth;

  /// No description provided for @tierBadgeFree.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get tierBadgeFree;

  /// No description provided for @tierBadgeComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get tierBadgeComingSoon;

  /// No description provided for @tierFeatureWorkspaceLimits.
  ///
  /// In ar, this message translates to:
  /// **'الدفاتر والحسابات والمعاملات'**
  String get tierFeatureWorkspaceLimits;

  /// No description provided for @tierFeatureBackupLocalCloud.
  ///
  /// In ar, this message translates to:
  /// **'نسخ احتياطي محلي وسحابي عبر Google Drive'**
  String get tierFeatureBackupLocalCloud;

  /// No description provided for @tierFeatureDataExport.
  ///
  /// In ar, this message translates to:
  /// **'كشوف PDF'**
  String get tierFeatureDataExport;

  /// No description provided for @tierFeatureAiVoice.
  ///
  /// In ar, this message translates to:
  /// **'الإدخال الصوتي بالذكاء الاصطناعي'**
  String get tierFeatureAiVoice;

  /// No description provided for @tierFeatureWhatsappStatements.
  ///
  /// In ar, this message translates to:
  /// **'كشوف واتساب شهرية آلية'**
  String get tierFeatureWhatsappStatements;

  /// No description provided for @tierFeatureAnalyticsDashboard.
  ///
  /// In ar, this message translates to:
  /// **'لوحة تحليلات ورسوم بيانية متقدمة'**
  String get tierFeatureAnalyticsDashboard;

  /// No description provided for @tierFeatureStoreBranding.
  ///
  /// In ar, this message translates to:
  /// **'هوية متجرك على التقارير المصدّرة'**
  String get tierFeatureStoreBranding;

  /// No description provided for @tierFeatureCustomerPortal.
  ///
  /// In ar, this message translates to:
  /// **'بوابة لحظية للعملاء'**
  String get tierFeatureCustomerPortal;

  /// No description provided for @tierValueBasicPdf.
  ///
  /// In ar, this message translates to:
  /// **'PDF أساسي'**
  String get tierValueBasicPdf;

  /// No description provided for @tierValueBrandedExport.
  ///
  /// In ar, this message translates to:
  /// **'PDF بعلامتك'**
  String get tierValueBrandedExport;

  /// No description provided for @tierFeatureLedgers.
  ///
  /// In ar, this message translates to:
  /// **'دفاتر نشطة'**
  String get tierFeatureLedgers;

  /// No description provided for @tierFeatureContacts.
  ///
  /// In ar, this message translates to:
  /// **'حسابات نشطة'**
  String get tierFeatureContacts;

  /// No description provided for @tierFeatureTransactions.
  ///
  /// In ar, this message translates to:
  /// **'معاملات نشطة'**
  String get tierFeatureTransactions;

  /// No description provided for @tierFeatureCsvImport.
  ///
  /// In ar, this message translates to:
  /// **'استيراد CSV'**
  String get tierFeatureCsvImport;

  /// No description provided for @tierFeatureBrandedPdf.
  ///
  /// In ar, this message translates to:
  /// **'كشوف PDF بعلامتك'**
  String get tierFeatureBrandedPdf;

  /// No description provided for @tierFeatureLedgerArchiving.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة الدفاتر واستعادتها'**
  String get tierFeatureLedgerArchiving;

  /// No description provided for @tierFeatureSync.
  ///
  /// In ar, this message translates to:
  /// **'مزامنة متعددة الأجهزة'**
  String get tierFeatureSync;

  /// No description provided for @tierFeatureWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'أتمتة واتساب'**
  String get tierFeatureWhatsapp;

  /// No description provided for @tierFeatureAnalytics.
  ///
  /// In ar, this message translates to:
  /// **'تحليلات متقدمة'**
  String get tierFeatureAnalytics;

  /// No description provided for @tierFeaturePortal.
  ///
  /// In ar, this message translates to:
  /// **'بوابة العملاء'**
  String get tierFeaturePortal;

  /// No description provided for @tierUnlimited.
  ///
  /// In ar, this message translates to:
  /// **'غير محدود'**
  String get tierUnlimited;

  /// No description provided for @tierValueStarter.
  ///
  /// In ar, this message translates to:
  /// **'1 / 50 / 500'**
  String get tierValueStarter;

  /// No description provided for @tierLimitLedgersFree.
  ///
  /// In ar, this message translates to:
  /// **'1'**
  String get tierLimitLedgersFree;

  /// No description provided for @tierLimitContactsFree.
  ///
  /// In ar, this message translates to:
  /// **'50'**
  String get tierLimitContactsFree;

  /// No description provided for @tierLimitTransactionsFree.
  ///
  /// In ar, this message translates to:
  /// **'500'**
  String get tierLimitTransactionsFree;

  /// No description provided for @manageSubscriptionTitle.
  ///
  /// In ar, this message translates to:
  /// **'الخطة والتفعيل'**
  String get manageSubscriptionTitle;

  /// No description provided for @manageSubscriptionSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اعرض خطتك، فعّل رمزاً، أو قارن الباقات.'**
  String get manageSubscriptionSubtitle;

  /// No description provided for @manageSubscriptionCta.
  ///
  /// In ar, this message translates to:
  /// **'فتح مركز الخطط'**
  String get manageSubscriptionCta;

  /// No description provided for @limitUpsellTitle.
  ///
  /// In ar, this message translates to:
  /// **'تجاوزت حد المجاني'**
  String get limitUpsellTitle;

  /// No description provided for @limitUpsellSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'رقِّ إلى Pro لمساحة عمل غير محدودة — الاستيراد يبقى مجانياً دائماً.'**
  String get limitUpsellSubtitle;

  /// No description provided for @limitUpsellProgress.
  ///
  /// In ar, this message translates to:
  /// **'{current} من {max} مستخدم'**
  String limitUpsellProgress(Object current, Object max);

  /// No description provided for @limitUpsellCta.
  ///
  /// In ar, this message translates to:
  /// **'فعّل Pro'**
  String get limitUpsellCta;

  /// No description provided for @limitUpsellDismiss.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get limitUpsellDismiss;

  /// No description provided for @premiumBadgeFree.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get premiumBadgeFree;

  /// No description provided for @premiumBadgePro.
  ///
  /// In ar, this message translates to:
  /// **'Pro'**
  String get premiumBadgePro;

  /// No description provided for @premiumBadgeProPlus.
  ///
  /// In ar, this message translates to:
  /// **'Pro+'**
  String get premiumBadgeProPlus;

  /// No description provided for @securityTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأمان'**
  String get securityTitle;

  /// No description provided for @securitySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'احمِ دفترك برمز PIN وفتح القفل بالبصمة.'**
  String get securitySubtitle;

  /// No description provided for @securityAppLockTitle.
  ///
  /// In ar, this message translates to:
  /// **'قفل التطبيق (PIN)'**
  String get securityAppLockTitle;

  /// No description provided for @securityAppLockSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يطلب رمز PIN عند العودة إلى دفتر بعد مهلة.'**
  String get securityAppLockSubtitle;

  /// No description provided for @securityChangePinTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الرمز'**
  String get securityChangePinTitle;

  /// No description provided for @securityChangePinSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'حدّث رمز فتح القفل'**
  String get securityChangePinSubtitle;

  /// No description provided for @securityBiometricTitle.
  ///
  /// In ar, this message translates to:
  /// **'فتح بالبصمة'**
  String get securityBiometricTitle;

  /// No description provided for @securityBiometricSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'استخدم البصمة أو Face ID عند التوفّر'**
  String get securityBiometricSubtitle;

  /// No description provided for @securityBiometricEnrollReason.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من هويتك لتفعيل فتح القفل بالبصمة في دفتر'**
  String get securityBiometricEnrollReason;

  /// No description provided for @securityBiometricRequiresAppLock.
  ///
  /// In ar, this message translates to:
  /// **'فعّل قفل التطبيق أولاً لاستخدام فتح القفل بالبصمة.'**
  String get securityBiometricRequiresAppLock;

  /// No description provided for @securityTimeoutTitle.
  ///
  /// In ar, this message translates to:
  /// **'قفل تلقائي'**
  String get securityTimeoutTitle;

  /// No description provided for @securityTimeoutSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'مدة بقاء التطبيق في الخلفية قبل إعادة القفل'**
  String get securityTimeoutSubtitle;

  /// No description provided for @securityTimeoutImmediate.
  ///
  /// In ar, this message translates to:
  /// **'فوراً'**
  String get securityTimeoutImmediate;

  /// No description provided for @securityTimeoutOneMinute.
  ///
  /// In ar, this message translates to:
  /// **'1 د'**
  String get securityTimeoutOneMinute;

  /// No description provided for @securityTimeoutFiveMinutes.
  ///
  /// In ar, this message translates to:
  /// **'5 د'**
  String get securityTimeoutFiveMinutes;

  /// No description provided for @securityTimeoutFifteenMinutes.
  ///
  /// In ar, this message translates to:
  /// **'15 د'**
  String get securityTimeoutFifteenMinutes;

  /// No description provided for @securityPinCreateTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء رمز PIN'**
  String get securityPinCreateTitle;

  /// No description provided for @securityPinConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الرمز'**
  String get securityPinConfirmTitle;

  /// No description provided for @securityPinChangeTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الرمز'**
  String get securityPinChangeTitle;

  /// No description provided for @securityPinCurrentTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرمز الحالي'**
  String get securityPinCurrentTitle;

  /// No description provided for @securityPinNewTitle.
  ///
  /// In ar, this message translates to:
  /// **'رمز جديد'**
  String get securityPinNewTitle;

  /// No description provided for @securityPinDisableTitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز للإيقاف'**
  String get securityPinDisableTitle;

  /// No description provided for @securityPinSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر رمزاً من 4 أرقام'**
  String get securityPinSubtitle;

  /// No description provided for @securityPinConfirmSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أعد إدخال نفس الرمز'**
  String get securityPinConfirmSubtitle;

  /// No description provided for @securityPinCurrentSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمزك الحالي'**
  String get securityPinCurrentSubtitle;

  /// No description provided for @securityPinDisableSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الرمز لإيقاف قفل التطبيق'**
  String get securityPinDisableSubtitle;

  /// No description provided for @securityPinHint.
  ///
  /// In ar, this message translates to:
  /// **'4 أرقام'**
  String get securityPinHint;

  /// No description provided for @securityPinMismatch.
  ///
  /// In ar, this message translates to:
  /// **'الرمزان غير متطابقين. حاول مجدداً.'**
  String get securityPinMismatch;

  /// No description provided for @securityPinIncorrect.
  ///
  /// In ar, this message translates to:
  /// **'رمز غير صحيح'**
  String get securityPinIncorrect;

  /// No description provided for @securityPinLockedOut.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. انتظر ثم حاول.'**
  String get securityPinLockedOut;

  /// No description provided for @securityPinInvalid.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن يكون الرمز 4 أرقام'**
  String get securityPinInvalid;

  /// No description provided for @securityPinSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ إعدادات الأمان'**
  String get securityPinSaveFailed;

  /// No description provided for @securitySettingsError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ. حاول مجدداً.'**
  String get securitySettingsError;

  /// No description provided for @securityStatusProtected.
  ///
  /// In ar, this message translates to:
  /// **'محمي بالكامل'**
  String get securityStatusProtected;

  /// No description provided for @securityStatusProtectedSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'رمز PIN وفتح القفل بالبصمة مفعّلان'**
  String get securityStatusProtectedSubtitle;

  /// No description provided for @securityStatusPinOnly.
  ///
  /// In ar, this message translates to:
  /// **'محمي برمز PIN'**
  String get securityStatusPinOnly;

  /// No description provided for @securityStatusPinOnlySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يُقفل دفترك عند مغادرة التطبيق'**
  String get securityStatusPinOnlySubtitle;

  /// No description provided for @securityStatusUnprotected.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد قفل'**
  String get securityStatusUnprotected;

  /// No description provided for @securityStatusUnprotectedSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أي شخص يملك هاتفك يمكنه فتح دفتر'**
  String get securityStatusUnprotectedSubtitle;

  /// No description provided for @securityGroupAccess.
  ///
  /// In ar, this message translates to:
  /// **'التحكم بالوصول'**
  String get securityGroupAccess;

  /// No description provided for @securityGroupAutoLock.
  ///
  /// In ar, this message translates to:
  /// **'قفل تلقائي'**
  String get securityGroupAutoLock;

  /// No description provided for @securityTrustPinSecure.
  ///
  /// In ar, this message translates to:
  /// **'يُخزَّن الرمز مشفّراً في الخزنة الآمنة للجهاز — وليس في قاعدة البيانات'**
  String get securityTrustPinSecure;

  /// No description provided for @securityTrustBiometricLocal.
  ///
  /// In ar, this message translates to:
  /// **'بيانات البصمة لا تغادر جهازك أبداً'**
  String get securityTrustBiometricLocal;

  /// No description provided for @securityHeroPinRing.
  ///
  /// In ar, this message translates to:
  /// **'PIN'**
  String get securityHeroPinRing;

  /// No description provided for @securityHeroBiometricRing.
  ///
  /// In ar, this message translates to:
  /// **'بصمة'**
  String get securityHeroBiometricRing;

  /// No description provided for @lockScreenTitle.
  ///
  /// In ar, this message translates to:
  /// **'دفتر مقفل'**
  String get lockScreenTitle;

  /// No description provided for @lockScreenSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز PIN للمتابعة'**
  String get lockScreenSubtitle;

  /// No description provided for @lockScreenBiometricRetry.
  ///
  /// In ar, this message translates to:
  /// **'فتح بالبصمة'**
  String get lockScreenBiometricRetry;

  /// No description provided for @lockScreenForgotPin.
  ///
  /// In ar, this message translates to:
  /// **'نسيت رمز الدخول؟'**
  String get lockScreenForgotPin;

  /// No description provided for @lockScreenForgotPinTitle.
  ///
  /// In ar, this message translates to:
  /// **'مسح البيانات المحلية؟'**
  String get lockScreenForgotPinTitle;

  /// No description provided for @lockScreenForgotPinBody.
  ///
  /// In ar, this message translates to:
  /// **'لحماية معلوماتك، استعادة الوصول بدون الرمز سيمسح نهائياً كل البيانات على هذا الجهاز—الدفاتر والجهات والمعاملات. يجب أن يكون لديك ملف نسخ احتياطي بصيغة .daftar لاستعادة سجلاتك. لا يمكن التراجع عن هذا الإجراء.'**
  String get lockScreenForgotPinBody;

  /// No description provided for @lockScreenForgotPinCta.
  ///
  /// In ar, this message translates to:
  /// **'مسح البيانات والمتابعة'**
  String get lockScreenForgotPinCta;

  /// No description provided for @lockScreenForgotPinTypeCode.
  ///
  /// In ar, this message translates to:
  /// **'اكتب هذا الرمز للتأكيد'**
  String get lockScreenForgotPinTypeCode;

  /// No description provided for @lockScreenForgotPinCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز المكوّن من 4 أرقام'**
  String get lockScreenForgotPinCodeHint;

  /// No description provided for @lockScreenForgotPinPreparing.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تجهيز بيئة آمنة…'**
  String get lockScreenForgotPinPreparing;

  /// No description provided for @fatalErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'عذراً، حدث خطأ غير متوقع'**
  String get fatalErrorTitle;

  /// No description provided for @fatalErrorBody.
  ///
  /// In ar, this message translates to:
  /// **'لا تقلق، جميع بياناتك ودفاترك في أمان تام.'**
  String get fatalErrorBody;

  /// No description provided for @fatalErrorRestart.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تشغيل التطبيق'**
  String get fatalErrorRestart;

  /// No description provided for @errorSheetDismiss.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get errorSheetDismiss;

  /// No description provided for @errorGenericTitle.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ ما'**
  String get errorGenericTitle;

  /// No description provided for @errorGenericMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إتمام هذا الإجراء. يُرجى المحاولة مرة أخرى.'**
  String get errorGenericMessage;

  /// No description provided for @errorValidationTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من المدخلات'**
  String get errorValidationTitle;

  /// No description provided for @errorValidationMessage.
  ///
  /// In ar, this message translates to:
  /// **'يُرجى تصحيح بعض التفاصيل قبل المتابعة.'**
  String get errorValidationMessage;

  /// No description provided for @errorDatabaseTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ التغييرات'**
  String get errorDatabaseTitle;

  /// No description provided for @errorDatabaseMessage.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك في أمان. يُرجى المحاولة بعد قليل.'**
  String get errorDatabaseMessage;

  /// No description provided for @errorNetworkTitle.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة في الاتصال'**
  String get errorNetworkTitle;

  /// No description provided for @errorNetworkMessage.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من اتصال الإنترنت وحاول مجدداً.'**
  String get errorNetworkMessage;

  /// No description provided for @errorRateLimitedTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبات كثيرة جداً'**
  String get errorRateLimitedTitle;

  /// No description provided for @errorRateLimitedMessage.
  ///
  /// In ar, this message translates to:
  /// **'أرسلت عدة دعوات خلال وقت قصير. انتظر قليلاً ثم حاول مجدداً.'**
  String get errorRateLimitedMessage;

  /// No description provided for @errorRateLimitedMessageWithRetry.
  ///
  /// In ar, this message translates to:
  /// **'أرسلت عدة دعوات خلال وقت قصير. حاول مجدداً بعد نحو {minutes} دقيقة.'**
  String errorRateLimitedMessageWithRetry(int minutes);

  /// No description provided for @errorSeatCapTitle.
  ///
  /// In ar, this message translates to:
  /// **'الفريق مكتمل'**
  String get errorSeatCapTitle;

  /// No description provided for @errorSeatCapMessage.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك دعوة حتى {maxWorkers} عاملين في برو+. أزل عاملاً معلقاً أو نشطاً لدعوة شخص آخر.'**
  String errorSeatCapMessage(int maxWorkers);

  /// No description provided for @errorForbiddenTitle.
  ///
  /// In ar, this message translates to:
  /// **'غير مسموح'**
  String get errorForbiddenTitle;

  /// No description provided for @errorForbiddenMessage.
  ///
  /// In ar, this message translates to:
  /// **'صلاحيتك في مساحة العمل لا تسمح بهذا الإجراء. اطلب الإذن من مالك مساحة العمل.'**
  String get errorForbiddenMessage;

  /// No description provided for @errorInvalidRequestMessage.
  ///
  /// In ar, this message translates to:
  /// **'لم يُقبل هذا الطلب. حدّث التطبيق ثم أعد المحاولة.'**
  String get errorInvalidRequestMessage;

  /// No description provided for @errorInvalidActionMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت مزامنة هذا التغيير لأن الخادم لم يتعرّف عليه. حدّث التطبيق ثم أعد المحاولة.'**
  String get errorInvalidActionMessage;

  /// No description provided for @errorNotFoundMessage.
  ///
  /// In ar, this message translates to:
  /// **'لم نعثر على هذا العنصر. ربما تم حذفه.'**
  String get errorNotFoundMessage;

  /// No description provided for @errorConflictMessage.
  ///
  /// In ar, this message translates to:
  /// **'قام شخص آخر بتعديل هذا قبلك. حدّث الصفحة ثم أعد المحاولة.'**
  String get errorConflictMessage;

  /// No description provided for @errorServerMessage.
  ///
  /// In ar, this message translates to:
  /// **'واجه خادم المزامنة مشكلة. بياناتك محفوظة على هذا الجهاز — أعد المحاولة لاحقاً.'**
  String get errorServerMessage;

  /// No description provided for @errorServiceUnavailableMessage.
  ///
  /// In ar, this message translates to:
  /// **'خادم المزامنة غير متاح مؤقتاً. بياناتك محفوظة على هذا الجهاز.'**
  String get errorServiceUnavailableMessage;

  /// No description provided for @errorDeviceCapMessage.
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى عدد الأجهزة المسموح به في مساحة العمل. أزل جهازاً لإضافة آخر.'**
  String get errorDeviceCapMessage;

  /// No description provided for @errorSyncEventCapMessage.
  ///
  /// In ar, this message translates to:
  /// **'بلغت مساحة العمل حد المزامنة الشهري. ستُستأنف المزامنة الشهر القادم.'**
  String get errorSyncEventCapMessage;

  /// No description provided for @errorStorageTitle.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة في التخزين'**
  String get errorStorageTitle;

  /// No description provided for @errorStorageMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى مساحة الجهاز. حرّر مساحة إن لزم، ثم أعد المحاولة.'**
  String get errorStorageMessage;

  /// No description provided for @errorAuthTitle.
  ///
  /// In ar, this message translates to:
  /// **'يلزم تسجيل الدخول'**
  String get errorAuthTitle;

  /// No description provided for @errorAuthMessage.
  ///
  /// In ar, this message translates to:
  /// **'يُرجى تسجيل الدخول مجدداً للمتابعة.'**
  String get errorAuthMessage;

  /// No description provided for @errorInvalidAmountTitle.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ غير صالح'**
  String get errorInvalidAmountTitle;

  /// No description provided for @errorInvalidAmountMessage.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغاً صحيحاً أكبر من صفر.'**
  String get errorInvalidAmountMessage;

  /// No description provided for @errorQuotaExceededTitle.
  ///
  /// In ar, this message translates to:
  /// **'المساحة ممتلئة'**
  String get errorQuotaExceededTitle;

  /// No description provided for @errorQuotaExceededMessage.
  ///
  /// In ar, this message translates to:
  /// **'مساحة التخزين السحابي ممتلئة. حرّر مساحة وحاول مجدداً.'**
  String get errorQuotaExceededMessage;

  /// No description provided for @errorContactNameExists.
  ///
  /// In ar, this message translates to:
  /// **'يوجد حساب بهذا الاسم في الدفتر بالفعل.'**
  String get errorContactNameExists;

  /// No description provided for @errorExportFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التصدير'**
  String get errorExportFailedTitle;

  /// No description provided for @errorExportFailedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء الملف أو مشاركته. يُرجى المحاولة مرة أخرى.'**
  String get errorExportFailedMessage;

  /// No description provided for @errorStorageFullTitle.
  ///
  /// In ar, this message translates to:
  /// **'مساحة التخزين ممتلئة'**
  String get errorStorageFullTitle;

  /// No description provided for @errorStorageFullMessage.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تفريغ 50 ميغابايت على الأقل من مساحة الجهاز للمتابعة بأمان.'**
  String get errorStorageFullMessage;

  /// No description provided for @cloudSyncStatusOffline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل — بياناتك محفوظة على هذا الجهاز'**
  String get cloudSyncStatusOffline;

  /// No description provided for @cloudSyncStatusSyncing.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ مزامنة النسخة الاحتياطية مع السحابة'**
  String get cloudSyncStatusSyncing;

  /// No description provided for @cloudSyncStatusSynced.
  ///
  /// In ar, this message translates to:
  /// **'تم النسخ الاحتياطي إلى السحابة'**
  String get cloudSyncStatusSynced;

  /// No description provided for @cloudSyncStatusNeedsReauth.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول مجدداً لاستئناف النسخ الاحتياطي'**
  String get cloudSyncStatusNeedsReauth;

  /// No description provided for @cloudSyncStatusQuota.
  ///
  /// In ar, this message translates to:
  /// **'مساحة التخزين السحابي ممتلئة'**
  String get cloudSyncStatusQuota;

  /// No description provided for @recoveryTitle.
  ///
  /// In ar, this message translates to:
  /// **'استرداد النظام'**
  String get recoveryTitle;

  /// No description provided for @recoveryBody.
  ///
  /// In ar, this message translates to:
  /// **'تعرض ملف البيانات المحلي للتلف بسبب انقطاع في التخزين أو الطاقة. لحماية أموالك، تم إيقاف التطبيق مؤقتاً.'**
  String get recoveryBody;

  /// No description provided for @recoveryRestoreDrive.
  ///
  /// In ar, this message translates to:
  /// **'استعادة من Google Drive'**
  String get recoveryRestoreDrive;

  /// No description provided for @recoveryStartFresh.
  ///
  /// In ar, this message translates to:
  /// **'بدء من جديد (حذف البيانات المحلية)'**
  String get recoveryStartFresh;

  /// No description provided for @recoveryStartFreshConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف البيانات المحلية؟'**
  String get recoveryStartFreshConfirmTitle;

  /// No description provided for @recoveryStartFreshConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيؤدي هذا إلى إزالة قاعدة البيانات التالفة من هذا الجهاز نهائياً. نسخ Google Drive الاحتياطية لن تتأثر. سيعيد التطبيق التشغيل بدفتر فارغ جديد.'**
  String get recoveryStartFreshConfirmBody;

  /// No description provided for @recoveryNoDriveBackups.
  ///
  /// In ar, this message translates to:
  /// **'لم يُعثر على نسخ احتياطية في Google Drive لهذا الحساب.'**
  String get recoveryNoDriveBackups;

  /// No description provided for @recoveryPickBackupTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر نسخة للاستعادة'**
  String get recoveryPickBackupTitle;

  /// No description provided for @recoveryRestoreFromFile.
  ///
  /// In ar, this message translates to:
  /// **'استعادة من ملف نسخة احتياطية'**
  String get recoveryRestoreFromFile;

  /// No description provided for @settingsCloudBackupLegend.
  ///
  /// In ar, this message translates to:
  /// **'السحابة'**
  String get settingsCloudBackupLegend;

  /// No description provided for @quickAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة سريعة'**
  String get quickAddTitle;

  /// No description provided for @quickAddNewAccountBadge.
  ///
  /// In ar, this message translates to:
  /// **'حساب جديد'**
  String get quickAddNewAccountBadge;

  /// No description provided for @quickAddSelectLedgerHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر الدفتر الذي ينتمي إليه هذا الحساب'**
  String get quickAddSelectLedgerHint;

  /// No description provided for @quickAddLedgerLockedHint.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديد الدفتر تلقائياً'**
  String get quickAddLedgerLockedHint;

  /// No description provided for @quickAddNoLedgerTitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ دفتراً أولاً'**
  String get quickAddNoLedgerTitle;

  /// No description provided for @quickAddNoLedgerMessage.
  ///
  /// In ar, this message translates to:
  /// **'كل معاملة تنتمي إلى دفتر. أنشئ دفترك الأول لتسجيل الديون والمدفوعات.'**
  String get quickAddNoLedgerMessage;

  /// No description provided for @onboardingSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطّي'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الآن'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingTrackDebtsTitle.
  ///
  /// In ar, this message translates to:
  /// **'نظّم ديونك بسهولة'**
  String get onboardingTrackDebtsTitle;

  /// No description provided for @onboardingTrackDebtsBody.
  ///
  /// In ar, this message translates to:
  /// **'استبدل الكشكول الورقي بدفتر رقمي بسيط يعمل بدون إنترنت.'**
  String get onboardingTrackDebtsBody;

  /// No description provided for @onboardingDriveBackupTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسخ احتياطي آمن على Google Drive'**
  String get onboardingDriveBackupTitle;

  /// No description provided for @onboardingDriveBackupBody.
  ///
  /// In ar, this message translates to:
  /// **'نسختك الاحتياطية المشفّرة في حسابك على Google — مخفية وخاصة.'**
  String get onboardingDriveBackupBody;

  /// No description provided for @onboardingSharePdfTitle.
  ///
  /// In ar, this message translates to:
  /// **'شارك كشوفات PDF بعلامتك'**
  String get onboardingSharePdfTitle;

  /// No description provided for @onboardingSharePdfBody.
  ///
  /// In ar, this message translates to:
  /// **'أرسل كشف حساب احترافي لعملائك عبر واتساب بلمسة واحدة.'**
  String get onboardingSharePdfBody;

  /// No description provided for @onboardingPremiumTitle.
  ///
  /// In ar, this message translates to:
  /// **'فعّل مزايا Pro'**
  String get onboardingPremiumTitle;

  /// No description provided for @onboardingPremiumBody.
  ///
  /// In ar, this message translates to:
  /// **'احصل على التصدير بعلامتك التجارية، أرشفة الدفاتر، والمزيد من الأدوات المتقدمة.'**
  String get onboardingPremiumBody;

  /// No description provided for @onboardingSetupHeroLine.
  ///
  /// In ar, this message translates to:
  /// **'حِسابك مضبوط، وحقّك محفوظ.'**
  String get onboardingSetupHeroLine;

  /// No description provided for @onboardingSetupLanguageTitle.
  ///
  /// In ar, this message translates to:
  /// **'لغة التطبيق'**
  String get onboardingSetupLanguageTitle;

  /// No description provided for @onboardingSetupLookTitle.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get onboardingSetupLookTitle;

  /// No description provided for @onboardingSetupLookDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get onboardingSetupLookDark;

  /// No description provided for @onboardingSetupLookLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get onboardingSetupLookLight;

  /// No description provided for @onboardingSetupLookSystem.
  ///
  /// In ar, this message translates to:
  /// **'حسب الجهاز'**
  String get onboardingSetupLookSystem;

  /// No description provided for @onboardingSetupCurrencyLabel.
  ///
  /// In ar, this message translates to:
  /// **'عملة الدفتر'**
  String get onboardingSetupCurrencyLabel;

  /// No description provided for @onboardingSetupStoreTitle.
  ///
  /// In ar, this message translates to:
  /// **'اسم المحل'**
  String get onboardingSetupStoreTitle;

  /// No description provided for @onboardingSetupStoreNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثل: متجر نموذجي'**
  String get onboardingSetupStoreNameHint;

  /// No description provided for @onboardingSetupStoreLogoPro.
  ///
  /// In ar, this message translates to:
  /// **'الشعار ميزة Pro — يمكنك تسميه المحل الآن.'**
  String get onboardingSetupStoreLogoPro;

  /// No description provided for @onboardingSetupGoogleTitle.
  ///
  /// In ar, this message translates to:
  /// **'حفظ نسخة على Google'**
  String get onboardingSetupGoogleTitle;

  /// No description provided for @onboardingSetupGooglePrimary.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة مع Google'**
  String get onboardingSetupGooglePrimary;

  /// No description provided for @onboardingSetupGoogleLater.
  ///
  /// In ar, this message translates to:
  /// **'إعداد لاحقاً'**
  String get onboardingSetupGoogleLater;

  /// No description provided for @onboardingSetupGoogleFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل الدخول. دفترك يعمل بدون إنترنت — أعد المحاولة من هنا.'**
  String get onboardingSetupGoogleFailed;

  /// No description provided for @onboardingSetupProExpander.
  ///
  /// In ar, this message translates to:
  /// **'لديك رمز؟'**
  String get onboardingSetupProExpander;

  /// No description provided for @onboardingSetupProHint.
  ///
  /// In ar, this message translates to:
  /// **'رمز التفعيل اختياري. يمكنك المتابعة بدونه.'**
  String get onboardingSetupProHint;

  /// No description provided for @onboardingSetupLedgerTitle.
  ///
  /// In ar, this message translates to:
  /// **'أول دفتر'**
  String get onboardingSetupLedgerTitle;

  /// No description provided for @onboardingSetupLanguageBody.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تغييرها لاحقاً من الإعدادات.'**
  String get onboardingSetupLanguageBody;

  /// No description provided for @onboardingSetupLookBody.
  ///
  /// In ar, this message translates to:
  /// **'يُطبَّق اختيارك على هذا الشاشة فوراً.'**
  String get onboardingSetupLookBody;

  /// No description provided for @onboardingSetupStoreBody.
  ///
  /// In ar, this message translates to:
  /// **'يظهر على كشوف PDF التي ترسلها للعملاء.'**
  String get onboardingSetupStoreBody;

  /// No description provided for @onboardingTryDemoStore.
  ///
  /// In ar, this message translates to:
  /// **'تجربة متجر افتراضي'**
  String get onboardingTryDemoStore;

  /// No description provided for @onboardingSetupGoogleBody.
  ///
  /// In ar, this message translates to:
  /// **'نسخة احتياطية مشفّرة في حساب Google. دفترك يبقى على هذا الجهاز.'**
  String get onboardingSetupGoogleBody;

  /// No description provided for @onboardingSetupGoogleCompleteDrive.
  ///
  /// In ar, this message translates to:
  /// **'إكمال صلاحية Drive'**
  String get onboardingSetupGoogleCompleteDrive;

  /// No description provided for @onboardingSetupGoogleGrantError.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل تفويض Drive. تحقق من الاتصال وحاول مجدداً.'**
  String get onboardingSetupGoogleGrantError;

  /// No description provided for @onboardingSetupGoogleSignedIn.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الدخول — خطوة واحدة للنسخ التلقائي.'**
  String get onboardingSetupGoogleSignedIn;

  /// No description provided for @onboardingSetupProTitle.
  ///
  /// In ar, this message translates to:
  /// **'علامة المحل Pro'**
  String get onboardingSetupProTitle;

  /// No description provided for @onboardingSetupProBrandingSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اسم محلك وشعارك على كل PDF تشاركه.'**
  String get onboardingSetupProBrandingSubtitle;

  /// No description provided for @onboardingSetupProStoreFallback.
  ///
  /// In ar, this message translates to:
  /// **'محلك'**
  String get onboardingSetupProStoreFallback;

  /// No description provided for @onboardingSetupLedgerLedgerLine.
  ///
  /// In ar, this message translates to:
  /// **'الدفتر هو الكشكول — زبائن، موردين، أو شخصي.'**
  String get onboardingSetupLedgerLedgerLine;

  /// No description provided for @onboardingSetupLedgerAccountsLine.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات هي الأشخاص داخل هذا الكشكول.'**
  String get onboardingSetupLedgerAccountsLine;

  /// No description provided for @onboardingSetupLedgerCustomChip.
  ///
  /// In ar, this message translates to:
  /// **'اسم مخصص'**
  String get onboardingSetupLedgerCustomChip;

  /// No description provided for @onboardingSetupLedgerCustomHint.
  ///
  /// In ar, this message translates to:
  /// **'مثل: ديون الورشة'**
  String get onboardingSetupLedgerCustomHint;

  /// No description provided for @onboardingSetupLedgerCreate.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الدفتر'**
  String get onboardingSetupLedgerCreate;

  /// No description provided for @demoSeedReportTitle.
  ///
  /// In ar, this message translates to:
  /// **'المتجر النموذجي جاهز'**
  String get demoSeedReportTitle;

  /// No description provided for @demoSeedReportStoreKept.
  ///
  /// In ar, this message translates to:
  /// **'اسم المحل: {name} (محفوظ)'**
  String demoSeedReportStoreKept(String name);

  /// No description provided for @demoSeedReportStoreGenerated.
  ///
  /// In ar, this message translates to:
  /// **'اسم المحل: {name} (تم إنشاؤه)'**
  String demoSeedReportStoreGenerated(String name);

  /// No description provided for @demoSeedReportLedger.
  ///
  /// In ar, this message translates to:
  /// **'الدفتر: {name}'**
  String demoSeedReportLedger(String name);

  /// No description provided for @demoSeedReportContacts.
  ///
  /// In ar, this message translates to:
  /// **'{count} حسابات متأخرة مع بريد'**
  String demoSeedReportContacts(int count);

  /// No description provided for @demoSeedReportTones.
  ///
  /// In ar, this message translates to:
  /// **'نطاقات ودية، تذكير، وحازمة'**
  String get demoSeedReportTones;

  /// No description provided for @demoSeedReportSendSplit.
  ///
  /// In ar, this message translates to:
  /// **'أعلى {pdfCount} بكشف PDF؛ {textCount} بتذكير نصي'**
  String demoSeedReportSendSplit(int pdfCount, int textCount);

  /// No description provided for @demoSeedReportDone.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get demoSeedReportDone;

  /// No description provided for @demoSeedReportError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المتجر النموذجي. أعد المحاولة.'**
  String get demoSeedReportError;

  /// No description provided for @settingsSampleStoreSection.
  ///
  /// In ar, this message translates to:
  /// **'متجر نموذجي'**
  String get settingsSampleStoreSection;

  /// No description provided for @settingsSampleStoreBody.
  ///
  /// In ar, this message translates to:
  /// **'ملء دفتر زبائن نموذجي بسبعة حسابات متأخرة للمقيّمين.'**
  String get settingsSampleStoreBody;

  /// No description provided for @settingsSampleStoreReset.
  ///
  /// In ar, this message translates to:
  /// **'إعادة بيانات المتجر النموذجي'**
  String get settingsSampleStoreReset;

  /// No description provided for @settingsSampleStoreFootnote.
  ///
  /// In ar, this message translates to:
  /// **'يستبدل الحسابات والدفاتر والحركات. اسم المحل يُحفظ إن كان مضبوطاً.'**
  String get settingsSampleStoreFootnote;

  /// No description provided for @settingsSampleStoreResetConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المتجر النموذجي؟'**
  String get settingsSampleStoreResetConfirmTitle;

  /// No description provided for @settingsSampleStoreResetConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيستبدل هذا الحسابات والدفاتر والحركات ببيانات تجريبية. اسم المحل يبقى إن كان مضبوطاً.'**
  String get settingsSampleStoreResetConfirmBody;

  /// No description provided for @settingsSampleStoreResetConfirm.
  ///
  /// In ar, this message translates to:
  /// **'إعادة'**
  String get settingsSampleStoreResetConfirm;

  /// No description provided for @settingsSampleStoreResetCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get settingsSampleStoreResetCancel;

  /// No description provided for @settingsTeam.
  ///
  /// In ar, this message translates to:
  /// **'الفريق'**
  String get settingsTeam;

  /// No description provided for @settingsTeamSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ادعُ العمال إلى مساحة عملك'**
  String get settingsTeamSubtitle;

  /// No description provided for @settingsJoinWorkspace.
  ///
  /// In ar, this message translates to:
  /// **'لديك رمز دعوة؟'**
  String get settingsJoinWorkspace;

  /// No description provided for @settingsJoinWorkspaceSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الصق رابط دعوة الفريق للانضمام إلى مساحة العمل'**
  String get settingsJoinWorkspaceSubtitle;

  /// No description provided for @joinWorkspaceTitle.
  ///
  /// In ar, this message translates to:
  /// **'الانضمام إلى مساحة العمل'**
  String get joinWorkspaceTitle;

  /// No description provided for @joinWorkspaceBody.
  ///
  /// In ar, this message translates to:
  /// **'الصق رابط الدعوة أو الرمز من صاحب المحل. ستسجّل الدخول بحساب Google الذي تلقّى الدعوة.'**
  String get joinWorkspaceBody;

  /// No description provided for @joinWorkspaceCodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'رابط الدعوة أو الرمز'**
  String get joinWorkspaceCodeLabel;

  /// No description provided for @joinWorkspaceCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'https://daftar.app/i/… أو الصق الرمز'**
  String get joinWorkspaceCodeHint;

  /// No description provided for @joinWorkspaceContinue.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get joinWorkspaceContinue;

  /// No description provided for @joinWorkspaceInvalidCode.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رابط دعوة أو رمزًا صالحًا.'**
  String get joinWorkspaceInvalidCode;

  /// No description provided for @joinWorkspaceAlreadyUsed.
  ///
  /// In ar, this message translates to:
  /// **'سبق فتح هذه الدعوة على هذا الجهاز.'**
  String get joinWorkspaceAlreadyUsed;

  /// No description provided for @joinWorkspaceBusy.
  ///
  /// In ar, this message translates to:
  /// **'ما زال فتح الدعوة السابقة جاريًا. حاول بعد لحظات.'**
  String get joinWorkspaceBusy;

  /// No description provided for @inviteAcceptWorkspaceMismatch.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الانضمام إلى مساحة عمل التاجر. جرّب تسجيل الخروج والمحاولة مجددًا أو تواصل مع صاحب المحل.'**
  String get inviteAcceptWorkspaceMismatch;

  /// No description provided for @settingsSyncReport.
  ///
  /// In ar, this message translates to:
  /// **'تقرير المزامنة'**
  String get settingsSyncReport;

  /// No description provided for @settingsSyncReportSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'حالة المزامنة بين الأجهزة والمزامنة اليدوية'**
  String get settingsSyncReportSubtitle;

  /// No description provided for @memberManagementTitle.
  ///
  /// In ar, this message translates to:
  /// **'الفريق'**
  String get memberManagementTitle;

  /// No description provided for @memberManagementSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ادعُ حتى عاملين للتعاون على دفاترك.'**
  String get memberManagementSubtitle;

  /// No description provided for @memberManagementSeatsHint.
  ///
  /// In ar, this message translates to:
  /// **'المالك + حتى عاملين (3 مقاعد كحد أقصى).'**
  String get memberManagementSeatsHint;

  /// No description provided for @memberManagementUpgradeTitle.
  ///
  /// In ar, this message translates to:
  /// **'التعاون الجماعي ميزة Pro+'**
  String get memberManagementUpgradeTitle;

  /// No description provided for @memberManagementUpgradeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'قم بالترقية لدعوة عمال يمكنهم عرض أو تعديل دفاترك عبر الأجهزة.'**
  String get memberManagementUpgradeSubtitle;

  /// No description provided for @memberManagementUpgradeCta.
  ///
  /// In ar, this message translates to:
  /// **'عرض الخطط'**
  String get memberManagementUpgradeCta;

  /// No description provided for @memberManagementPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'مالك مساحة العمل فقط يمكنه إدارة أعضاء الفريق.'**
  String get memberManagementPermissionDenied;

  /// No description provided for @memberManagementActiveSection.
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء النشطون'**
  String get memberManagementActiveSection;

  /// No description provided for @memberManagementPendingSection.
  ///
  /// In ar, this message translates to:
  /// **'الدعوات المعلّقة'**
  String get memberManagementPendingSection;

  /// No description provided for @memberManagementEmptySection.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أعضاء في هذا القسم.'**
  String get memberManagementEmptySection;

  /// No description provided for @memberManagementInviteCta.
  ///
  /// In ar, this message translates to:
  /// **'دعوة عامل'**
  String get memberManagementInviteCta;

  /// No description provided for @memberManagementInviteSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'دعوة عامل'**
  String get memberManagementInviteSheetTitle;

  /// No description provided for @memberManagementEmailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get memberManagementEmailLabel;

  /// No description provided for @memberManagementRoleLabel.
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get memberManagementRoleLabel;

  /// No description provided for @memberManagementRoleOwner.
  ///
  /// In ar, this message translates to:
  /// **'مالك'**
  String get memberManagementRoleOwner;

  /// No description provided for @memberManagementRoleEditor.
  ///
  /// In ar, this message translates to:
  /// **'محرّر'**
  String get memberManagementRoleEditor;

  /// No description provided for @memberManagementRoleViewer.
  ///
  /// In ar, this message translates to:
  /// **'مشاهد'**
  String get memberManagementRoleViewer;

  /// No description provided for @memberManagementStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'معلّق'**
  String get memberManagementStatusPending;

  /// No description provided for @memberManagementStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get memberManagementStatusActive;

  /// No description provided for @memberManagementSendInvite.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الدعوة'**
  String get memberManagementSendInvite;

  /// No description provided for @memberManagementInviteSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'رابط الدعوة جاهز'**
  String get memberManagementInviteSuccessTitle;

  /// No description provided for @memberManagementInviteRoleGranted.
  ///
  /// In ar, this message translates to:
  /// **'الصلاحية الممنوحة: {role}'**
  String memberManagementInviteRoleGranted(String role);

  /// No description provided for @memberManagementInviteDowngradedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تمت الدعوة كمشاهد وليس كمحرّر'**
  String get memberManagementInviteDowngradedTitle;

  /// No description provided for @memberManagementInviteDowngradedBody.
  ///
  /// In ar, this message translates to:
  /// **'جميع مقاعد المحرّرين مستخدمة، لذلك أُنشئت هذه الدعوة بصلاحية الاطلاع فقط. أزل محرّرًا أولًا إذا كنت تحتاج مقعدًا آخر.'**
  String get memberManagementInviteDowngradedBody;

  /// No description provided for @memberManagementCopyLink.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الرابط'**
  String get memberManagementCopyLink;

  /// No description provided for @memberManagementShareLink.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الرابط'**
  String get memberManagementShareLink;

  /// No description provided for @memberManagementLinkCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ رابط الدعوة'**
  String get memberManagementLinkCopied;

  /// No description provided for @memberManagementRevokeInvite.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get memberManagementRevokeInvite;

  /// No description provided for @memberManagementRemoveMember.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get memberManagementRemoveMember;

  /// No description provided for @memberManagementRevokeConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الدعوة؟'**
  String get memberManagementRevokeConfirmTitle;

  /// No description provided for @memberManagementRevokeConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُلغى هذا الطلب المعلّق ويُحرّر المقعد.'**
  String get memberManagementRevokeConfirmBody;

  /// No description provided for @memberManagementRemoveConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'إزالة العضو؟'**
  String get memberManagementRemoveConfirmTitle;

  /// No description provided for @memberManagementRemoveConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيفقد هذا العضو الوصول عند المزامنة التالية.'**
  String get memberManagementRemoveConfirmBody;

  /// No description provided for @memberManagementRenewalSection.
  ///
  /// In ar, this message translates to:
  /// **'طلبات تجديد الدعوة'**
  String get memberManagementRenewalSection;

  /// No description provided for @memberManagementRenewalEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات تجديد معلّقة.'**
  String get memberManagementRenewalEmpty;

  /// No description provided for @memberManagementRenewalResend.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الدعوة'**
  String get memberManagementRenewalResend;

  /// No description provided for @memberManagementRenewalRequestedAt.
  ///
  /// In ar, this message translates to:
  /// **'طُلب في {date}'**
  String memberManagementRenewalRequestedAt(String date);

  /// No description provided for @closingAgentTitle.
  ///
  /// In ar, this message translates to:
  /// **'وكيل الإقفال'**
  String get closingAgentTitle;

  /// No description provided for @closingAgentEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما الذي نسجّل؟'**
  String get closingAgentEmptyTitle;

  /// No description provided for @closingAgentEmptySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اضغط مثالاً أو اكتب الاسم والمبلغ'**
  String get closingAgentEmptySubtitle;

  /// No description provided for @closingAgentComposerHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب في الدفتر'**
  String get closingAgentComposerHint;

  /// No description provided for @closingAgentSpeakWorking.
  ///
  /// In ar, this message translates to:
  /// **'جاري مراجعة وتدقيق الدفتر...'**
  String get closingAgentSpeakWorking;

  /// No description provided for @closingAgentExampleChip1.
  ///
  /// In ar, this message translates to:
  /// **'محمد سدد 500'**
  String get closingAgentExampleChip1;

  /// No description provided for @closingAgentExampleChip2.
  ///
  /// In ar, this message translates to:
  /// **'أحمد عليه 200'**
  String get closingAgentExampleChip2;

  /// No description provided for @closingAgentCloseToday.
  ///
  /// In ar, this message translates to:
  /// **'أقفل اليوم'**
  String get closingAgentCloseToday;

  /// No description provided for @closingAgentCloseTodayGoal.
  ///
  /// In ar, this message translates to:
  /// **'اقفل يومي'**
  String get closingAgentCloseTodayGoal;

  /// No description provided for @closingAgentCloseTodaySemantics.
  ///
  /// In ar, this message translates to:
  /// **'أقفل اليوم وابدأ إقفال نهاية اليوم'**
  String get closingAgentCloseTodaySemantics;

  /// No description provided for @closingAgentSendSemantics.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الهدف'**
  String get closingAgentSendSemantics;

  /// No description provided for @closingAgentMicSemantics.
  ///
  /// In ar, this message translates to:
  /// **'الصوت'**
  String get closingAgentMicSemantics;

  /// No description provided for @closingAgentMicBanner.
  ///
  /// In ar, this message translates to:
  /// **'اضغط مطولاً للتحدث'**
  String get closingAgentMicBanner;

  /// No description provided for @closingAgentMicRecording.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التسجيل'**
  String get closingAgentMicRecording;

  /// No description provided for @closingAgentMicSlideToCancel.
  ///
  /// In ar, this message translates to:
  /// **'اسحب للأعلى للإلغاء'**
  String get closingAgentMicSlideToCancel;

  /// No description provided for @closingAgentMicReleaseToCancel.
  ///
  /// In ar, this message translates to:
  /// **'ارفع لإلغاء التسجيل'**
  String get closingAgentMicReleaseToCancel;

  /// No description provided for @closingAgentMicRecordingElapsed.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التسجيل، مضى {seconds} ثانية'**
  String closingAgentMicRecordingElapsed(int seconds);

  /// No description provided for @closingAgentMicPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'الوصول إلى الميكروفون متوقف. افتح الإعدادات للسماح لدفتر بالتسجيل.'**
  String get closingAgentMicPermissionDenied;

  /// No description provided for @closingAgentMicOpenSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get closingAgentMicOpenSettings;

  /// No description provided for @closingAgentContactsPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'الوصول إلى جهات الاتصال متوقف. افتح الإعدادات للسماح لدفتر بملء الاسم والهاتف.'**
  String get closingAgentContactsPermissionDenied;

  /// No description provided for @closingAgentPermissionBannerSemantics.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه صلاحية'**
  String get closingAgentPermissionBannerSemantics;

  /// No description provided for @backupDriveNotSignedIn.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لحفظ نسخة على درايف.'**
  String get backupDriveNotSignedIn;

  /// No description provided for @closingAgentConfirmDebt.
  ///
  /// In ar, this message translates to:
  /// **'سجل الدين'**
  String get closingAgentConfirmDebt;

  /// No description provided for @closingAgentConfirmPayment.
  ///
  /// In ar, this message translates to:
  /// **'سجّل السداد'**
  String get closingAgentConfirmPayment;

  /// No description provided for @closingAgentConfirmCreateContact.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ الحساب'**
  String get closingAgentConfirmCreateContact;

  /// No description provided for @closingAgentConfirmCreateLedger.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ الدفتر'**
  String get closingAgentConfirmCreateLedger;

  /// No description provided for @closingAgentConfirmAll.
  ///
  /// In ar, this message translates to:
  /// **'سجّل في الدفتر'**
  String get closingAgentConfirmAll;

  /// No description provided for @closingAgentConfirmPlan.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الخطة'**
  String get closingAgentConfirmPlan;

  /// No description provided for @closingAgentIntentDebt.
  ///
  /// In ar, this message translates to:
  /// **'دين'**
  String get closingAgentIntentDebt;

  /// No description provided for @closingAgentIntentPayment.
  ///
  /// In ar, this message translates to:
  /// **'سداد'**
  String get closingAgentIntentPayment;

  /// No description provided for @closingAgentIntentNewAccount.
  ///
  /// In ar, this message translates to:
  /// **'حساب جديد'**
  String get closingAgentIntentNewAccount;

  /// No description provided for @closingAgentIntentLedger.
  ///
  /// In ar, this message translates to:
  /// **'دفتر'**
  String get closingAgentIntentLedger;

  /// No description provided for @closingAgentIntentStatement.
  ///
  /// In ar, this message translates to:
  /// **'كشف'**
  String get closingAgentIntentStatement;

  /// No description provided for @closingAgentSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get closingAgentSkip;

  /// No description provided for @closingAgentConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم التسجيل'**
  String get closingAgentConfirmed;

  /// No description provided for @closingAgentSkipped.
  ///
  /// In ar, this message translates to:
  /// **'تم التخطي'**
  String get closingAgentSkipped;

  /// No description provided for @closingAgentSelectLedger.
  ///
  /// In ar, this message translates to:
  /// **'اختر الدفتر'**
  String get closingAgentSelectLedger;

  /// No description provided for @closingAgentSelectCurrency.
  ///
  /// In ar, this message translates to:
  /// **'اختر العملة'**
  String get closingAgentSelectCurrency;

  /// No description provided for @closingAgentContactUnresolvedHelper.
  ///
  /// In ar, this message translates to:
  /// **'حدّد الحساب قبل التسجيل.'**
  String get closingAgentContactUnresolvedHelper;

  /// No description provided for @closingAgentWhichContact.
  ///
  /// In ar, this message translates to:
  /// **'أي حساب؟'**
  String get closingAgentWhichContact;

  /// No description provided for @closingAgentDidYouMean.
  ///
  /// In ar, this message translates to:
  /// **'هل تقصد أحد هؤلاء، أم إنشاء حساب جديد باسم {name}؟'**
  String closingAgentDidYouMean(String name);

  /// No description provided for @closingAgentCreateNewNamed.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ «{name}»'**
  String closingAgentCreateNewNamed(String name);

  /// No description provided for @closingAgentContactAlreadyExists.
  ///
  /// In ar, this message translates to:
  /// **'يوجد حساب باسم {name} في الدفتر.'**
  String closingAgentContactAlreadyExists(String name);

  /// No description provided for @closingAgentLedgerTypeCustomers.
  ///
  /// In ar, this message translates to:
  /// **'زبائن'**
  String get closingAgentLedgerTypeCustomers;

  /// No description provided for @closingAgentLedgerTypeSuppliers.
  ///
  /// In ar, this message translates to:
  /// **'موردون'**
  String get closingAgentLedgerTypeSuppliers;

  /// No description provided for @closingAgentLedgerTypePersonal.
  ///
  /// In ar, this message translates to:
  /// **'شخصي'**
  String get closingAgentLedgerTypePersonal;

  /// No description provided for @closingAgentLedgerTypeCustom.
  ///
  /// In ar, this message translates to:
  /// **'مخصص'**
  String get closingAgentLedgerTypeCustom;

  /// No description provided for @closingAgentAskOverdueTitle.
  ///
  /// In ar, this message translates to:
  /// **'من عليه باقٍ'**
  String get closingAgentAskOverdueTitle;

  /// No description provided for @closingAgentAskLargestTitle.
  ///
  /// In ar, this message translates to:
  /// **'أكبر دين'**
  String get closingAgentAskLargestTitle;

  /// No description provided for @closingAgentAskSmallestTitle.
  ///
  /// In ar, this message translates to:
  /// **'أقل دين'**
  String get closingAgentAskSmallestTitle;

  /// No description provided for @closingAgentAskLastPaymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'آخر دفعة'**
  String get closingAgentAskLastPaymentTitle;

  /// No description provided for @closingAgentAskLastDebtTitle.
  ///
  /// In ar, this message translates to:
  /// **'آخر دين'**
  String get closingAgentAskLastDebtTitle;

  /// No description provided for @closingAgentAskNoLastPayment.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد دفعة في الدفتر لـ {name}.'**
  String closingAgentAskNoLastPayment(String name);

  /// No description provided for @closingAgentAskNoLastDebt.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد دين في الدفتر لـ {name}.'**
  String closingAgentAskNoLastDebt(String name);

  /// No description provided for @closingAgentAskNeedName.
  ///
  /// In ar, this message translates to:
  /// **'حدّد اسم الحساب.'**
  String get closingAgentAskNeedName;

  /// No description provided for @closingAgentAskEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا أحد عليه شيء الآن.'**
  String get closingAgentAskEmpty;

  /// No description provided for @closingAgentAskBalanceTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get closingAgentAskBalanceTitle;

  /// No description provided for @closingAgentAskUnresolved.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب مطابق في الدفتر.'**
  String get closingAgentAskUnresolved;

  /// No description provided for @closingAgentSpeakDebt.
  ///
  /// In ar, this message translates to:
  /// **'{name} عليه {amount}'**
  String closingAgentSpeakDebt(String name, String amount);

  /// No description provided for @closingAgentSpeakPayment.
  ///
  /// In ar, this message translates to:
  /// **'{name} سدد {amount}'**
  String closingAgentSpeakPayment(String name, String amount);

  /// No description provided for @closingAgentSpeakDebtWithItem.
  ///
  /// In ar, this message translates to:
  /// **'{name} عليه {amount} {item}'**
  String closingAgentSpeakDebtWithItem(String name, String amount, String item);

  /// No description provided for @closingAgentSpeakPaymentWithItem.
  ///
  /// In ar, this message translates to:
  /// **'{name} سدد {amount} {item}'**
  String closingAgentSpeakPaymentWithItem(
    String name,
    String amount,
    String item,
  );

  /// No description provided for @closingAgentSpeakBalance.
  ///
  /// In ar, this message translates to:
  /// **'{name} عليه {amount}'**
  String closingAgentSpeakBalance(String name, String amount);

  /// No description provided for @closingAgentSpeakCredit.
  ///
  /// In ar, this message translates to:
  /// **'{name} له {amount}'**
  String closingAgentSpeakCredit(String name, String amount);

  /// No description provided for @closingAgentSpeakSettled.
  ///
  /// In ar, this message translates to:
  /// **'{name} لا عليه شيء'**
  String closingAgentSpeakSettled(String name);

  /// No description provided for @closingAgentSpeakThisAccount.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب'**
  String get closingAgentSpeakThisAccount;

  /// No description provided for @closingAgentSpeakPlanReady.
  ///
  /// In ar, this message translates to:
  /// **'خطة إقفال اليوم جاهزة. راجعها على الشاشة ثم أكّد.'**
  String get closingAgentSpeakPlanReady;

  /// No description provided for @closingAgentSpeakRiyals.
  ///
  /// In ar, this message translates to:
  /// **'{amount} ريال'**
  String closingAgentSpeakRiyals(String amount);

  /// No description provided for @closingAgentSpeakDollars.
  ///
  /// In ar, this message translates to:
  /// **'{amount} دولار'**
  String closingAgentSpeakDollars(String amount);

  /// No description provided for @closingAgentSpeakConfirmDebt.
  ///
  /// In ar, this message translates to:
  /// **'سأسجل {amount} ديناً على {name}. اضغط {cta}.'**
  String closingAgentSpeakConfirmDebt(String amount, String name, String cta);

  /// No description provided for @closingAgentSpeakConfirmPayment.
  ///
  /// In ar, this message translates to:
  /// **'سأسجل {amount} سداداً من {name}. اضغط {cta}.'**
  String closingAgentSpeakConfirmPayment(
    String amount,
    String name,
    String cta,
  );

  /// No description provided for @closingAgentSpeakConfirmDebtCreate.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب باسم {name}. سأنشئ الحساب وأسجل عليه ديناً بمبلغ {amount}. اضغط {cta}.'**
  String closingAgentSpeakConfirmDebtCreate(
    String name,
    String amount,
    String cta,
  );

  /// No description provided for @closingAgentSpeakConfirmPaymentCreate.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب باسم {name}. سأنشئ الحساب وأسجل عليه سداداً بمبلغ {amount}. اضغط {cta}.'**
  String closingAgentSpeakConfirmPaymentCreate(
    String name,
    String amount,
    String cta,
  );

  /// No description provided for @closingAgentSpeakConfirmDebtItem.
  ///
  /// In ar, this message translates to:
  /// **'سأسجل {amount} ديناً على {name} مقابل {item}. اضغط {cta}.'**
  String closingAgentSpeakConfirmDebtItem(
    String amount,
    String name,
    String item,
    String cta,
  );

  /// No description provided for @closingAgentSpeakConfirmPaymentItem.
  ///
  /// In ar, this message translates to:
  /// **'سأسجل {amount} سداداً من {name} مقابل {item}. اضغط {cta}.'**
  String closingAgentSpeakConfirmPaymentItem(
    String amount,
    String name,
    String item,
    String cta,
  );

  /// No description provided for @closingAgentSpeakConfirmDebtCreateItem.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب باسم {name}. سأنشئ الحساب وأسجل عليه ديناً بمبلغ {amount} مقابل {item}. اضغط {cta}.'**
  String closingAgentSpeakConfirmDebtCreateItem(
    String name,
    String amount,
    String item,
    String cta,
  );

  /// No description provided for @closingAgentSpeakConfirmPaymentCreateItem.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب باسم {name}. سأنشئ الحساب وأسجل عليه سداداً بمبلغ {amount} مقابل {item}. اضغط {cta}.'**
  String closingAgentSpeakConfirmPaymentCreateItem(
    String name,
    String amount,
    String item,
    String cta,
  );

  /// No description provided for @closingAgentSpeakConfirmStatement.
  ///
  /// In ar, this message translates to:
  /// **'سأجهّز كشف حساب بي دي إف لـ {name}. اضغط {cta}.'**
  String closingAgentSpeakConfirmStatement(String name, String cta);

  /// No description provided for @closingAgentSpeakConfirmCreateContact.
  ///
  /// In ar, this message translates to:
  /// **'سأنشئ حساباً باسم {name}. اضغط {cta}.'**
  String closingAgentSpeakConfirmCreateContact(String name, String cta);

  /// No description provided for @closingAgentSpeakConfirmCreateLedger.
  ///
  /// In ar, this message translates to:
  /// **'سأنشئ دفتراً باسم {name}. اضغط {cta}.'**
  String closingAgentSpeakConfirmCreateLedger(String name, String cta);

  /// No description provided for @closingAgentStatementTitle.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب {name}'**
  String closingAgentStatementTitle(String name);

  /// No description provided for @closingAgentSpeakOverdueIntro.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{حساب واحد عليه باقٍ.} other{{count} حسابات عليها باقٍ.}}'**
  String closingAgentSpeakOverdueIntro(int count);

  /// No description provided for @closingAgentSpeakWhichCandidates.
  ///
  /// In ar, this message translates to:
  /// **'أي حساب؟ {names}.'**
  String closingAgentSpeakWhichCandidates(String names);

  /// No description provided for @closingAgentLedgerRequiredHelper.
  ///
  /// In ar, this message translates to:
  /// **'اختر دفتراً قبل إنشاء الحساب.'**
  String get closingAgentLedgerRequiredHelper;

  /// No description provided for @closingAgentUnknownContactHelper.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب باسم {name}. إنشاؤه وتسجيل المبلغ؟'**
  String closingAgentUnknownContactHelper(String name);

  /// No description provided for @closingAgentNoLedgerHelper.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد دفتر بعد. سمِّ دفتراً لإنشائه.'**
  String get closingAgentNoLedgerHelper;

  /// No description provided for @closingAgentLedgerNameHint.
  ///
  /// In ar, this message translates to:
  /// **'اسم الدفتر'**
  String get closingAgentLedgerNameHint;

  /// No description provided for @closingAgentConfirmCreateAndRecordDebt.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ الحساب وسجّل الدين'**
  String get closingAgentConfirmCreateAndRecordDebt;

  /// No description provided for @closingAgentConfirmCreateAndRecordPayment.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ الحساب وسجّل السداد'**
  String get closingAgentConfirmCreateAndRecordPayment;

  /// No description provided for @closingAgentCurrencyRequiredHelper.
  ///
  /// In ar, this message translates to:
  /// **'اختر عملة قبل إنشاء هذا الحساب.'**
  String get closingAgentCurrencyRequiredHelper;

  /// No description provided for @closingAgentPlanTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطة الإقفال'**
  String get closingAgentPlanTitle;

  /// No description provided for @closingAgentPlanSendSplit.
  ///
  /// In ar, this message translates to:
  /// **'أعلى خمسة حسابات ثقلاً تحصل على كشف حساب مرفق. بقية مجموعة الإرسال تحصل على تذكير بالبريد. الترتيب من التقادم؛ لا يختار جيميناي المعرّفات.'**
  String get closingAgentPlanSendSplit;

  /// No description provided for @closingAgentPlanDeviceRuns.
  ///
  /// In ar, this message translates to:
  /// **'بعد النسخ الاحتياطي والتقادم يقسم مكتب التحصيل المتصلين المؤهلين عن البريد. اليمن والمناطق غير المدعومة تبقى على البريد. النص ثابت؛ لا يختار جيميناي المعرّفات.'**
  String get closingAgentPlanDeviceRuns;

  /// No description provided for @closingAgentPlanOutreachConsent.
  ///
  /// In ar, this message translates to:
  /// **'هذان الزران يبدآن الإقفال. بعد النسخ ومسح التقادم، مكتب التحصيل هو موضع تأكيد الاتصال والبريد.'**
  String get closingAgentPlanOutreachConsent;

  /// No description provided for @closingAgentTaskmasterTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطة إقفال اليوم'**
  String get closingAgentTaskmasterTitle;

  /// No description provided for @closingAgentApprovePlan.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد الخطة'**
  String get closingAgentApprovePlan;

  /// No description provided for @closingAgentStartClose.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الإقفال'**
  String get closingAgentStartClose;

  /// No description provided for @closingAgentStartCloseWithoutOutreach.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الإقفال دون تواصل'**
  String get closingAgentStartCloseWithoutOutreach;

  /// No description provided for @closingAgentConfirmAndSend.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد وإرسال الكشوفات'**
  String get closingAgentConfirmAndSend;

  /// No description provided for @closingAgentConfirmWithoutSending.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد دون إرسال'**
  String get closingAgentConfirmWithoutSending;

  /// No description provided for @closingTaskmasterSealed.
  ///
  /// In ar, this message translates to:
  /// **'أُنجزت {count} مهمة'**
  String closingTaskmasterSealed(int count);

  /// No description provided for @closingTaskBindLedger.
  ///
  /// In ar, this message translates to:
  /// **'مطابقة القيود'**
  String get closingTaskBindLedger;

  /// No description provided for @closingTaskCollectDebts.
  ///
  /// In ar, this message translates to:
  /// **'جمع ديون اليوم'**
  String get closingTaskCollectDebts;

  /// No description provided for @closingTaskCollectPayments.
  ///
  /// In ar, this message translates to:
  /// **'جمع دفعات اليوم'**
  String get closingTaskCollectPayments;

  /// No description provided for @closingTaskTallyTotals.
  ///
  /// In ar, this message translates to:
  /// **'جمع المجاميع لكل عملة'**
  String get closingTaskTallyTotals;

  /// No description provided for @closingTaskStampSnapshot.
  ///
  /// In ar, this message translates to:
  /// **'ختم لقطة اليوم'**
  String get closingTaskStampSnapshot;

  /// No description provided for @closingTaskPrepareVault.
  ///
  /// In ar, this message translates to:
  /// **'تحضير حمولة الخزنة'**
  String get closingTaskPrepareVault;

  /// No description provided for @closingTaskSealDrive.
  ///
  /// In ar, this message translates to:
  /// **'ختم النسخة على درايف'**
  String get closingTaskSealDrive;

  /// No description provided for @closingTaskScanAging.
  ///
  /// In ar, this message translates to:
  /// **'مسح أرصدة التقادم'**
  String get closingTaskScanAging;

  /// No description provided for @closingTaskRankUrgency.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب حسب الإلحاح'**
  String get closingTaskRankUrgency;

  /// No description provided for @closingTaskBuildSendSet.
  ///
  /// In ar, this message translates to:
  /// **'تجهيز قائمة المدينين المستهدفين'**
  String get closingTaskBuildSendSet;

  /// No description provided for @closingTaskOpenDesk.
  ///
  /// In ar, this message translates to:
  /// **'فتح مكتب التحصيل'**
  String get closingTaskOpenDesk;

  /// No description provided for @closingTaskComposeReport.
  ///
  /// In ar, this message translates to:
  /// **'تأليف تقرير اليوم'**
  String get closingTaskComposeReport;

  /// No description provided for @closingTaskPresentSeal.
  ///
  /// In ar, this message translates to:
  /// **'عرض ختم اليوم'**
  String get closingTaskPresentSeal;

  /// No description provided for @closingTaskCaptionDebts.
  ///
  /// In ar, this message translates to:
  /// **'{count} ديون اليوم'**
  String closingTaskCaptionDebts(int count);

  /// No description provided for @closingTaskCaptionPayments.
  ///
  /// In ar, this message translates to:
  /// **'{count} دفعات اليوم'**
  String closingTaskCaptionPayments(int count);

  /// No description provided for @closingTaskCaptionCurrencies.
  ///
  /// In ar, this message translates to:
  /// **'{count} عملات'**
  String closingTaskCaptionCurrencies(int count);

  /// No description provided for @closingTaskCaptionSendSet.
  ///
  /// In ar, this message translates to:
  /// **'حتى {count} حساباً'**
  String closingTaskCaptionSendSet(int count);

  /// No description provided for @closingTaskCaptionOverdue.
  ///
  /// In ar, this message translates to:
  /// **'{count} متأخرون'**
  String closingTaskCaptionOverdue(int count);

  /// No description provided for @closingTaskCaptionSendAuth.
  ///
  /// In ar, this message translates to:
  /// **'يلزم إذن Google قبل الإرسال'**
  String get closingTaskCaptionSendAuth;

  /// No description provided for @closingAgentCurrencyLabel.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get closingAgentCurrencyLabel;

  /// No description provided for @closingAgentNoteLabel.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get closingAgentNoteLabel;

  /// No description provided for @closingAgentReadOnlyTool.
  ///
  /// In ar, this message translates to:
  /// **'هذه الخطوة للعرض فقط في هذه النسخة.'**
  String get closingAgentReadOnlyTool;

  /// No description provided for @closingAgentFabTipTitle.
  ///
  /// In ar, this message translates to:
  /// **'الوكيل والإدخال اليدوي'**
  String get closingAgentFabTipTitle;

  /// No description provided for @closingAgentFabTipBody.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للوكيل · اضغط مطولاً للإدخال اليدوي'**
  String get closingAgentFabTipBody;

  /// No description provided for @closingAgentFabTipTapRow.
  ///
  /// In ar, this message translates to:
  /// **'اضغط → الوكيل'**
  String get closingAgentFabTipTapRow;

  /// No description provided for @closingAgentFabTipHoldRow.
  ///
  /// In ar, this message translates to:
  /// **'اضغط مطولاً → إدخال يدوي'**
  String get closingAgentFabTipHoldRow;

  /// No description provided for @closingAgentFabTipSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get closingAgentFabTipSkip;

  /// No description provided for @closingAgentFabTipDismiss.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get closingAgentFabTipDismiss;

  /// No description provided for @closingAgentFabTipSemantics.
  ///
  /// In ar, this message translates to:
  /// **'تلميح زر الإضافة: اضغط للوكيل، اضغط مطولاً للإدخال اليدوي'**
  String get closingAgentFabTipSemantics;

  /// No description provided for @closingAgentConfirmCoachTitle.
  ///
  /// In ar, this message translates to:
  /// **'أكد المبلغ'**
  String get closingAgentConfirmCoachTitle;

  /// No description provided for @closingAgentConfirmCoachBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يُسجَّل شيء حتى تؤكد.'**
  String get closingAgentConfirmCoachBody;

  /// No description provided for @closingAgentConfirmCoachSemantics.
  ///
  /// In ar, this message translates to:
  /// **'تلميح تأكيد المبلغ'**
  String get closingAgentConfirmCoachSemantics;

  /// No description provided for @collectionsDeskApproveCoachTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد وإرسال الكشوفات'**
  String get collectionsDeskApproveCoachTitle;

  /// No description provided for @collectionsDeskApproveCoachBody.
  ///
  /// In ar, this message translates to:
  /// **'تُرسل التذكيرات دفعة واحدة. أثقل خمسة حسابات تحصل على كشف.'**
  String get collectionsDeskApproveCoachBody;

  /// No description provided for @collectionsDeskApproveCoachSemantics.
  ///
  /// In ar, this message translates to:
  /// **'تلميح تأكيد وإرسال الكشوفات'**
  String get collectionsDeskApproveCoachSemantics;

  /// No description provided for @closingRitualBackupUnsigned.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لحفظ نسخة الليلة على درايف.'**
  String get closingRitualBackupUnsigned;

  /// No description provided for @closingRitualBackupGrantMissing.
  ///
  /// In ar, this message translates to:
  /// **'لم تُمنح صلاحية Drive. وافق عليها مرة واحدة لحفظ نسخة الليلة.'**
  String get closingRitualBackupGrantMissing;

  /// No description provided for @closingRitualRunning.
  ///
  /// In ar, this message translates to:
  /// **'جاري إقفال اليوم…'**
  String get closingRitualRunning;

  /// No description provided for @closingRitualProgressSummary.
  ///
  /// In ar, this message translates to:
  /// **'جاري عدّ قيود اليوم'**
  String get closingRitualProgressSummary;

  /// No description provided for @closingRitualProgressBackup.
  ///
  /// In ar, this message translates to:
  /// **'جاري حفظ نسخة على درايف'**
  String get closingRitualProgressBackup;

  /// No description provided for @closingRitualProgressShortlist.
  ///
  /// In ar, this message translates to:
  /// **'جاري إيجاد الحسابات المتأخرة'**
  String get closingRitualProgressShortlist;

  /// No description provided for @closingRitualRemindersTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحضير تذكيرات التحصيل؟'**
  String get closingRitualRemindersTitle;

  /// No description provided for @closingRitualRemindersYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get closingRitualRemindersYes;

  /// No description provided for @closingRitualRemindersTop5.
  ///
  /// In ar, this message translates to:
  /// **'أعلى 5'**
  String get closingRitualRemindersTop5;

  /// No description provided for @closingRitualRemindersNo.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get closingRitualRemindersNo;

  /// No description provided for @closingRitualPdfsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق كشوف الحساب؟'**
  String get closingRitualPdfsTitle;

  /// No description provided for @closingRitualPdfsNone.
  ///
  /// In ar, this message translates to:
  /// **'بدون'**
  String get closingRitualPdfsNone;

  /// No description provided for @closingRitualPdfsSelective.
  ///
  /// In ar, this message translates to:
  /// **'انتقائي'**
  String get closingRitualPdfsSelective;

  /// No description provided for @closingRitualPdfsSelected.
  ///
  /// In ar, this message translates to:
  /// **'المحددون'**
  String get closingRitualPdfsSelected;

  /// No description provided for @closingRitualReportTitle.
  ///
  /// In ar, this message translates to:
  /// **'أُقفل اليوم'**
  String get closingRitualReportTitle;

  /// No description provided for @closingRitualSpeakBooks.
  ///
  /// In ar, this message translates to:
  /// **'اليوم سجّلت {debtCount} ديون و{paymentCount} دفعات'**
  String closingRitualSpeakBooks(int debtCount, int paymentCount);

  /// No description provided for @closingRitualSpeakBackupSafe.
  ///
  /// In ar, this message translates to:
  /// **'نسخة الليلة على درايف. دفترك بأمان'**
  String get closingRitualSpeakBackupSafe;

  /// No description provided for @closingRitualSpeakBackupQueued.
  ///
  /// In ar, this message translates to:
  /// **'ستكتمل نسخة الليلة عند عودة الاتصال'**
  String get closingRitualSpeakBackupQueued;

  /// No description provided for @closingRitualSpeakBackupUnsigned.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لحفظ نسخة الليلة على درايف'**
  String get closingRitualSpeakBackupUnsigned;

  /// No description provided for @closingRitualSpeakBackupGrant.
  ///
  /// In ar, this message translates to:
  /// **'وافق على صلاحية درايف مرة واحدة لحفظ نسخة الليلة'**
  String get closingRitualSpeakBackupGrant;

  /// No description provided for @closingRitualSpeakBackupFailed.
  ///
  /// In ar, this message translates to:
  /// **'نسخة درايف تحتاج محاولة أخرى'**
  String get closingRitualSpeakBackupFailed;

  /// No description provided for @closingRitualSpeakQueue.
  ///
  /// In ar, this message translates to:
  /// **'{prepared} جاهزة، {sent} أُرسلت، {failed} فشلت'**
  String closingRitualSpeakQueue(int prepared, int sent, int failed);

  /// No description provided for @closingRitualSpeakOverdueRemain.
  ///
  /// In ar, this message translates to:
  /// **'{count} حسابات ما زالت متأخرة'**
  String closingRitualSpeakOverdueRemain(int count);

  /// No description provided for @closingRitualSpeakClose.
  ///
  /// In ar, this message translates to:
  /// **'هذا إقفال اليوم'**
  String get closingRitualSpeakClose;

  /// No description provided for @closingRitualReportDebtCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} ديون'**
  String closingRitualReportDebtCount(int count);

  /// No description provided for @closingRitualReportDebtsUnit.
  ///
  /// In ar, this message translates to:
  /// **'ديون اليوم'**
  String get closingRitualReportDebtsUnit;

  /// No description provided for @closingRitualReportPaymentCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} دفعات'**
  String closingRitualReportPaymentCount(int count);

  /// No description provided for @closingRitualReportPaymentsUnit.
  ///
  /// In ar, this message translates to:
  /// **'دفعات اليوم'**
  String get closingRitualReportPaymentsUnit;

  /// No description provided for @closingRitualReportTotals.
  ///
  /// In ar, this message translates to:
  /// **'{currencyCode}: {debt} دين · {payment} سداد'**
  String closingRitualReportTotals(
    String currencyCode,
    String debt,
    String payment,
  );

  /// No description provided for @closingRitualBackupUploaded.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت النسخة على درايف'**
  String get closingRitualBackupUploaded;

  /// No description provided for @closingRitualEmptyOverdue.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء للتحصيل'**
  String get closingRitualEmptyOverdue;

  /// No description provided for @closingRitualSkipAll.
  ///
  /// In ar, this message translates to:
  /// **'تم تخطي التذكيرات'**
  String get closingRitualSkipAll;

  /// No description provided for @closingRitualReminderAll.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات: مجموعة الإرسال (حتى 20)'**
  String get closingRitualReminderAll;

  /// No description provided for @closingRitualReminderTop5.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات: أعلى 5'**
  String get closingRitualReminderTop5;

  /// No description provided for @closingRitualReminderNone.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات: لا شيء'**
  String get closingRitualReminderNone;

  /// No description provided for @closingRitualPdfNone.
  ///
  /// In ar, this message translates to:
  /// **'الكشوف: بدون'**
  String get closingRitualPdfNone;

  /// No description provided for @closingRitualPdfSelective.
  ///
  /// In ar, this message translates to:
  /// **'الكشوف: انتقائي'**
  String get closingRitualPdfSelective;

  /// No description provided for @closingRitualPdfAll.
  ///
  /// In ar, this message translates to:
  /// **'الكشوف: المحددون'**
  String get closingRitualPdfAll;

  /// No description provided for @closingRitualPdfRankedTop5.
  ///
  /// In ar, this message translates to:
  /// **'الكشوف: أعلى 5 مرتبة'**
  String get closingRitualPdfRankedTop5;

  /// No description provided for @closingRitualNeedsHuman.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج انتباهك'**
  String get closingRitualNeedsHuman;

  /// No description provided for @closingRitualOverdueCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} متأخرون'**
  String closingRitualOverdueCount(int count);

  /// No description provided for @closingRitualRetry.
  ///
  /// In ar, this message translates to:
  /// **'متابعة إقفال اليوم'**
  String get closingRitualRetry;

  /// No description provided for @collectionsDeskTitle.
  ///
  /// In ar, this message translates to:
  /// **'التحصيل'**
  String get collectionsDeskTitle;

  /// No description provided for @collectionsDeskCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} تذكيرات'**
  String collectionsDeskCount(int count);

  /// No description provided for @collectionsDeskOpenWhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'فتح واتساب'**
  String get collectionsDeskOpenWhatsApp;

  /// No description provided for @collectionsDeskCopy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get collectionsDeskCopy;

  /// No description provided for @collectionsDeskSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get collectionsDeskSkip;

  /// No description provided for @collectionsDeskAttachStatement.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق كشف الحساب'**
  String get collectionsDeskAttachStatement;

  /// No description provided for @collectionsDeskStartSending.
  ///
  /// In ar, this message translates to:
  /// **'بدء الإرسال'**
  String get collectionsDeskStartSending;

  /// No description provided for @collectionsDeskApproveSend.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد وإرسال الكشوفات'**
  String get collectionsDeskApproveSend;

  /// No description provided for @collectionsDeskSkipOutreach.
  ///
  /// In ar, this message translates to:
  /// **'تخطي التواصل'**
  String get collectionsDeskSkipOutreach;

  /// No description provided for @collectionsDeskRetrySend.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال'**
  String get collectionsDeskRetrySend;

  /// No description provided for @collectionsDeskSending.
  ///
  /// In ar, this message translates to:
  /// **'جاري الإرسال…'**
  String get collectionsDeskSending;

  /// No description provided for @collectionsDeskPdfAttached.
  ///
  /// In ar, this message translates to:
  /// **'PDF مرفق'**
  String get collectionsDeskPdfAttached;

  /// No description provided for @collectionsDeskReminderOnly.
  ///
  /// In ar, this message translates to:
  /// **'تذكير فقط'**
  String get collectionsDeskReminderOnly;

  /// No description provided for @collectionsDeskDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get collectionsDeskDone;

  /// No description provided for @collectionsDeskCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ التذكير'**
  String get collectionsDeskCopied;

  /// No description provided for @collectionsDeskWhatsAppFailed.
  ///
  /// In ar, this message translates to:
  /// **'لم يُفتح واتساب. انسخ التذكير وأرسله بنفسك.'**
  String get collectionsDeskWhatsAppFailed;

  /// No description provided for @collectionsDeskToneFriendly.
  ///
  /// In ar, this message translates to:
  /// **'ودي'**
  String get collectionsDeskToneFriendly;

  /// No description provided for @collectionsDeskToneReminder.
  ///
  /// In ar, this message translates to:
  /// **'تذكير'**
  String get collectionsDeskToneReminder;

  /// No description provided for @collectionsDeskToneFirm.
  ///
  /// In ar, this message translates to:
  /// **'حازم'**
  String get collectionsDeskToneFirm;

  /// No description provided for @collectionsDeskAgeDays.
  ///
  /// In ar, this message translates to:
  /// **'{days} يوماً'**
  String collectionsDeskAgeDays(int days);

  /// No description provided for @collectionsDeskLastPaymentDays.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =0{آخر سداد اليوم} =1{آخر سداد قبل يوم} other{آخر سداد قبل {days} يوماً}}'**
  String collectionsDeskLastPaymentDays(int days);

  /// No description provided for @collectionsDeskOpened.
  ///
  /// In ar, this message translates to:
  /// **'فُتح'**
  String get collectionsDeskOpened;

  /// No description provided for @collectionsDeskSkippedStatus.
  ///
  /// In ar, this message translates to:
  /// **'مُتخطى'**
  String get collectionsDeskSkippedStatus;

  /// No description provided for @collectionsDeskSentStatus.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل'**
  String get collectionsDeskSentStatus;

  /// No description provided for @collectionsDeskFailedStatus.
  ///
  /// In ar, this message translates to:
  /// **'فشل'**
  String get collectionsDeskFailedStatus;

  /// No description provided for @collectionsDeskConfirmAndCall.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد والاتصال'**
  String get collectionsDeskConfirmAndCall;

  /// No description provided for @collectionsDeskConfirmWithoutCalling.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد دون اتصال'**
  String get collectionsDeskConfirmWithoutCalling;

  /// No description provided for @collectionsDeskPromiseNotPayment.
  ///
  /// In ar, this message translates to:
  /// **'الوعد ليس دفعة'**
  String get collectionsDeskPromiseNotPayment;

  /// No description provided for @collectionsDeskPromiseNotPaymentSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يسجّل CALL-E ما قاله العميل أنه سيدفع. لا يُدخل المال إلى دفترك.'**
  String get collectionsDeskPromiseNotPaymentSubtitle;

  /// No description provided for @contactPendingPromiseBody.
  ///
  /// In ar, this message translates to:
  /// **'وعد بـ {amount} في {date}'**
  String contactPendingPromiseBody(String amount, String date);

  /// No description provided for @collectionsDeskCallPreviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما سيقوله CALL-E'**
  String get collectionsDeskCallPreviewTitle;

  /// No description provided for @collectionsDeskCallingProgress.
  ///
  /// In ar, this message translates to:
  /// **'جاري الاتصال {index} من {total}'**
  String collectionsDeskCallingProgress(int index, int total);

  /// No description provided for @collectionsDeskCallCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مكالمة واحدة} =2{مكالمتان} few{{count} مكالمات} many{{count} مكالمة} other{{count} مكالمة}}'**
  String collectionsDeskCallCount(int count);

  /// No description provided for @collectionsDeskEmailCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بريد واحد} =2{بريدان} few{{count} رسائل} many{{count} رسالة} other{{count} رسالة}}'**
  String collectionsDeskEmailCount(int count);

  /// No description provided for @collectionsDeskRailCall.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get collectionsDeskRailCall;

  /// No description provided for @collectionsDeskRailEmail.
  ///
  /// In ar, this message translates to:
  /// **'بريد'**
  String get collectionsDeskRailEmail;

  /// No description provided for @collectionsDeskRailBoth.
  ///
  /// In ar, this message translates to:
  /// **'الاثنان'**
  String get collectionsDeskRailBoth;

  /// No description provided for @collectionsDeskRailCallUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن الاتصال'**
  String get collectionsDeskRailCallUnavailable;

  /// No description provided for @collectionsDeskRailSkipped.
  ///
  /// In ar, this message translates to:
  /// **'متخطى'**
  String get collectionsDeskRailSkipped;

  /// No description provided for @collectionsQueueSending.
  ///
  /// In ar, this message translates to:
  /// **'إرسال {index} من {total}'**
  String collectionsQueueSending(int index, int total);

  /// No description provided for @collectionsQueuePaused.
  ///
  /// In ar, this message translates to:
  /// **'متوقف · {index} من {total}'**
  String collectionsQueuePaused(int index, int total);

  /// No description provided for @collectionsQueuePause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get collectionsQueuePause;

  /// No description provided for @collectionsQueueResume.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get collectionsQueueResume;

  /// No description provided for @closingRitualQueuePrepared.
  ///
  /// In ar, this message translates to:
  /// **'{count} جاهزة'**
  String closingRitualQueuePrepared(int count);

  /// No description provided for @closingRitualQueueOpened.
  ///
  /// In ar, this message translates to:
  /// **'{count} فُتحت'**
  String closingRitualQueueOpened(int count);

  /// No description provided for @closingRitualQueueSkipped.
  ///
  /// In ar, this message translates to:
  /// **'{count} مُتخطاة'**
  String closingRitualQueueSkipped(int count);

  /// No description provided for @closingRitualQueueSent.
  ///
  /// In ar, this message translates to:
  /// **'{count} أُرسلت'**
  String closingRitualQueueSent(int count);

  /// No description provided for @closingRitualQueueFailed.
  ///
  /// In ar, this message translates to:
  /// **'{count} فشلت'**
  String closingRitualQueueFailed(int count);

  /// No description provided for @errorGoalTextRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الهدف أولاً.'**
  String get errorGoalTextRequired;

  /// No description provided for @errorAgentIdTokenMissing.
  ///
  /// In ar, this message translates to:
  /// **'يلزم تسجيل الدخول إلى Google لاستخدام الوكيل.'**
  String get errorAgentIdTokenMissing;

  /// No description provided for @errorAgentOpenIdGrantRequired.
  ///
  /// In ar, this message translates to:
  /// **'يلزم تحديث صلاحية Google مرة واحدة ليبقى الوكيل متصلاً. وافق مرة واحدة — النسخ الاحتياطي على Drive دون تغيير.'**
  String get errorAgentOpenIdGrantRequired;

  /// No description provided for @errorClosingAgentForbidden.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب لا يملك صلاحية استخدام الوكيل. سجّل الدخول بحساب Google المصرّح.'**
  String get errorClosingAgentForbidden;

  /// No description provided for @errorClosingAgentRequestFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى الوكيل. دفترك آمن على هذا الجهاز — اضغط مطولاً على + لإضافة قيد.'**
  String get errorClosingAgentRequestFailed;

  /// No description provided for @errorProposalInFlight.
  ///
  /// In ar, this message translates to:
  /// **'التأكيد جارٍ لهذه العملية.'**
  String get errorProposalInFlight;

  /// No description provided for @errorContactUnresolved.
  ///
  /// In ar, this message translates to:
  /// **'لم يُعثر على حساب واحد مطابق. وضّح الاسم أو أنشئ الحساب.'**
  String get errorContactUnresolved;

  /// No description provided for @errorLedgerRequired.
  ///
  /// In ar, this message translates to:
  /// **'اختر دفتراً قبل إنشاء هذا الحساب.'**
  String get errorLedgerRequired;

  /// No description provided for @errorCurrencyRequired.
  ///
  /// In ar, this message translates to:
  /// **'اختر عملة قبل إنشاء هذا الحساب.'**
  String get errorCurrencyRequired;

  /// No description provided for @errorProposalAlreadyCommitted.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل هذا القيد مسبقاً.'**
  String get errorProposalAlreadyCommitted;

  /// No description provided for @errorClosingAgentParseFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر قراءة رد الوكيل. حاول مرة أخرى.'**
  String get errorClosingAgentParseFailed;

  /// No description provided for @errorSmtpTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم يُرسل البريد'**
  String get errorSmtpTitle;

  /// No description provided for @errorSmtpNeedsHuman.
  ///
  /// In ar, this message translates to:
  /// **'رفضت Gmail على Cloud Run كلمة مرور التطبيق. تسجيل الدخول إلى التطبيق مجدداً لن يفيد. دفترك لم يتغيّر.'**
  String get errorSmtpNeedsHuman;

  /// No description provided for @errorSmtpSenderMisconfigured.
  ///
  /// In ar, this message translates to:
  /// **'مرسل البريد غير مُعدّ على Cloud Run. تسجيل الدخول إلى Drive غير مرتبط. دفترك لم يتغيّر.'**
  String get errorSmtpSenderMisconfigured;

  /// No description provided for @errorCalleKillSwitchTitle.
  ///
  /// In ar, this message translates to:
  /// **'المكالمات متوقفة'**
  String get errorCalleKillSwitchTitle;

  /// No description provided for @errorCalleKillSwitch.
  ///
  /// In ar, this message translates to:
  /// **'المكالمات الهاتفية مغلقة. البريد ما زال يعمل. دفترك لم يتغيّر.'**
  String get errorCalleKillSwitch;

  /// No description provided for @errorCalleNeedsHumanTitle.
  ///
  /// In ar, this message translates to:
  /// **'المكالمة تحتاج نظرة'**
  String get errorCalleNeedsHumanTitle;

  /// No description provided for @errorCalleNeedsHuman.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج المكالمة مراجعة شخص. دفترك لم يتغيّر.'**
  String get errorCalleNeedsHuman;

  /// No description provided for @errorCallePollTimeoutTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهى وقت المكالمة'**
  String get errorCallePollTimeoutTitle;

  /// No description provided for @errorCallePollTimeout.
  ///
  /// In ar, this message translates to:
  /// **'لم تكتمل المكالمة في الوقت المحدد. دفترك لم يتغيّر. لا تضغط تأكيد والاتصال مرة أخرى.'**
  String get errorCallePollTimeout;

  /// No description provided for @errorCollectionsEmailCap.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك إرسال 20 تذكيراً كحد أقصى في المرة الواحدة.'**
  String get errorCollectionsEmailCap;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
