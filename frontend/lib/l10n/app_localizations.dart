import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'ZiTok 短剧'**
  String get appTitle;

  /// No description provided for @brandName.
  ///
  /// In zh, this message translates to:
  /// **'ZiTok'**
  String get brandName;

  /// No description provided for @brandSuffix.
  ///
  /// In zh, this message translates to:
  /// **'短剧'**
  String get brandSuffix;

  /// No description provided for @tagline.
  ///
  /// In zh, this message translates to:
  /// **'竖屏连播 · 一口气看完'**
  String get tagline;

  /// No description provided for @demoHint.
  ///
  /// In zh, this message translates to:
  /// **'演示账号 zitok / demo1234'**
  String get demoHint;

  /// No description provided for @tabHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tabHome;

  /// No description provided for @tabTheater.
  ///
  /// In zh, this message translates to:
  /// **'剧场'**
  String get tabTheater;

  /// No description provided for @tabMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get tabMessages;

  /// No description provided for @tabProfile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabProfile;

  /// No description provided for @navMain.
  ///
  /// In zh, this message translates to:
  /// **'主导航'**
  String get navMain;

  /// No description provided for @welcomeDemoEnter.
  ///
  /// In zh, this message translates to:
  /// **'演示账号进入'**
  String get welcomeDemoEnter;

  /// No description provided for @welcomeAccountLogin.
  ///
  /// In zh, this message translates to:
  /// **'账号登录'**
  String get welcomeAccountLogin;

  /// No description provided for @welcomeRegister.
  ///
  /// In zh, this message translates to:
  /// **'新用户注册'**
  String get welcomeRegister;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来'**
  String get loginWelcomeBack;

  /// No description provided for @loginUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get loginUsername;

  /// No description provided for @loginUsernameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get loginUsernameHint;

  /// No description provided for @loginPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get loginPassword;

  /// No description provided for @loginPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get loginPasswordHint;

  /// No description provided for @loginForgot.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码？'**
  String get loginForgot;

  /// No description provided for @loginAction.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginAction;

  /// No description provided for @loginNoAccount.
  ///
  /// In zh, this message translates to:
  /// **'没有账号？'**
  String get loginNoAccount;

  /// No description provided for @loginRegisterNow.
  ///
  /// In zh, this message translates to:
  /// **'立即注册'**
  String get loginRegisterNow;

  /// No description provided for @loginNeedCredentials.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名和密码'**
  String get loginNeedCredentials;

  /// No description provided for @registerTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建账号'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'注册后即可追短剧、同步进度与追剧'**
  String get registerSubtitle;

  /// No description provided for @registerUsernameHint.
  ///
  /// In zh, this message translates to:
  /// **'设置你的昵称'**
  String get registerUsernameHint;

  /// No description provided for @registerEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get registerEmail;

  /// No description provided for @registerEmailHint.
  ///
  /// In zh, this message translates to:
  /// **'用于接收验证码'**
  String get registerEmailHint;

  /// No description provided for @registerPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'字母+数字，8–20 位'**
  String get registerPasswordHint;

  /// No description provided for @registerCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get registerCode;

  /// No description provided for @registerCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'6位验证码'**
  String get registerCodeHint;

  /// No description provided for @registerGetCode.
  ///
  /// In zh, this message translates to:
  /// **'获取验证码'**
  String get registerGetCode;

  /// No description provided for @registerSubmit.
  ///
  /// In zh, this message translates to:
  /// **'注册并去登录'**
  String get registerSubmit;

  /// No description provided for @registerHasAccount.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？'**
  String get registerHasAccount;

  /// No description provided for @registerBackLogin.
  ///
  /// In zh, this message translates to:
  /// **'返回登录'**
  String get registerBackLogin;

  /// No description provided for @registerSuccess.
  ///
  /// In zh, this message translates to:
  /// **'注册成功，请登录'**
  String get registerSuccess;

  /// No description provided for @registerNeedUsername.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get registerNeedUsername;

  /// No description provided for @registerNeedEmail.
  ///
  /// In zh, this message translates to:
  /// **'请输入邮箱'**
  String get registerNeedEmail;

  /// No description provided for @registerInvalidEmail.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效邮箱'**
  String get registerInvalidEmail;

  /// No description provided for @registerNeedPassword.
  ///
  /// In zh, this message translates to:
  /// **'请设置密码'**
  String get registerNeedPassword;

  /// No description provided for @registerInvalidPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码需含字母和数字，长度 8–20 位'**
  String get registerInvalidPassword;

  /// No description provided for @registerNeedCode.
  ///
  /// In zh, this message translates to:
  /// **'请输入验证码'**
  String get registerNeedCode;

  /// No description provided for @registerInvalidCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码须为 6 位数字'**
  String get registerInvalidCode;

  /// No description provided for @registerNeedEmailFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先填写邮箱'**
  String get registerNeedEmailFirst;

  /// No description provided for @codeSent.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送，请查收邮箱'**
  String get codeSent;

  /// No description provided for @codeSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证码发送失败'**
  String get codeSendFailed;

  /// No description provided for @forgotTitle.
  ///
  /// In zh, this message translates to:
  /// **'重置密码'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'通过邮箱验证码安全更新登录密码'**
  String get forgotSubtitle;

  /// No description provided for @forgotEmailHint.
  ///
  /// In zh, this message translates to:
  /// **'注册时使用的邮箱'**
  String get forgotEmailHint;

  /// No description provided for @forgotNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get forgotNewPassword;

  /// No description provided for @forgotNewPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'字母+数字，8–20 位'**
  String get forgotNewPasswordHint;

  /// No description provided for @forgotSubmit.
  ///
  /// In zh, this message translates to:
  /// **'确认重置'**
  String get forgotSubmit;

  /// No description provided for @forgotRemember.
  ///
  /// In zh, this message translates to:
  /// **'记得密码？'**
  String get forgotRemember;

  /// No description provided for @forgotBackLogin.
  ///
  /// In zh, this message translates to:
  /// **'返回登录'**
  String get forgotBackLogin;

  /// No description provided for @forgotSuccess.
  ///
  /// In zh, this message translates to:
  /// **'密码已重置，请登录'**
  String get forgotSuccess;

  /// No description provided for @forgotNeedEmail.
  ///
  /// In zh, this message translates to:
  /// **'请输入邮箱'**
  String get forgotNeedEmail;

  /// No description provided for @forgotNeedCode.
  ///
  /// In zh, this message translates to:
  /// **'请输入验证码'**
  String get forgotNeedCode;

  /// No description provided for @forgotNeedPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入新密码'**
  String get forgotNeedPassword;

  /// No description provided for @forgotInvalidPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码需含字母和数字，长度 8–20 位'**
  String get forgotInvalidPassword;

  /// No description provided for @forgotFailed.
  ///
  /// In zh, this message translates to:
  /// **'重置失败'**
  String get forgotFailed;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'个性化你的短剧'**
  String get settingsHeroTitle;

  /// No description provided for @settingsHeroSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'通知、播放手势与账户安全一站管理'**
  String get settingsHeroSubtitle;

  /// No description provided for @settingsAccountSecurity.
  ///
  /// In zh, this message translates to:
  /// **'账户与安全'**
  String get settingsAccountSecurity;

  /// No description provided for @settingsAccountSecuritySub.
  ///
  /// In zh, this message translates to:
  /// **'管理登录身份与密码'**
  String get settingsAccountSecuritySub;

  /// No description provided for @settingsAccount.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get settingsAccount;

  /// No description provided for @settingsAccountSub.
  ///
  /// In zh, this message translates to:
  /// **'切换账号 / 退出登录'**
  String get settingsAccountSub;

  /// No description provided for @settingsSecurity.
  ///
  /// In zh, this message translates to:
  /// **'安全'**
  String get settingsSecurity;

  /// No description provided for @settingsSecuritySub.
  ///
  /// In zh, this message translates to:
  /// **'邮箱验证重置密码'**
  String get settingsSecuritySub;

  /// No description provided for @settingsSecurityHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'重置登录密码'**
  String get settingsSecurityHeroTitle;

  /// No description provided for @settingsSecurityHeroSub.
  ///
  /// In zh, this message translates to:
  /// **'通过注册邮箱验证后设置新密码'**
  String get settingsSecurityHeroSub;

  /// No description provided for @settingsRegisteredEmail.
  ///
  /// In zh, this message translates to:
  /// **'注册邮箱'**
  String get settingsRegisteredEmail;

  /// No description provided for @settingsBackToSettings.
  ///
  /// In zh, this message translates to:
  /// **'返回设置'**
  String get settingsBackToSettings;

  /// No description provided for @settingsAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'账户设置'**
  String get settingsAccountTitle;

  /// No description provided for @settingsCurrentAccount.
  ///
  /// In zh, this message translates to:
  /// **'当前账号'**
  String get settingsCurrentAccount;

  /// No description provided for @settingsAccountManage.
  ///
  /// In zh, this message translates to:
  /// **'账户管理'**
  String get settingsAccountManage;

  /// No description provided for @settingsAccountManageSub.
  ///
  /// In zh, this message translates to:
  /// **'切换或退出当前登录态'**
  String get settingsAccountManageSub;

  /// No description provided for @settingsSwitchAccount.
  ///
  /// In zh, this message translates to:
  /// **'切换账号'**
  String get settingsSwitchAccount;

  /// No description provided for @settingsSwitchAccountSub.
  ///
  /// In zh, this message translates to:
  /// **'在已保存账号间快速切换'**
  String get settingsSwitchAccountSub;

  /// No description provided for @settingsLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutSub.
  ///
  /// In zh, this message translates to:
  /// **'清除本机登录态'**
  String get settingsLogoutSub;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出当前账号吗？'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsLogoutFailed.
  ///
  /// In zh, this message translates to:
  /// **'登出失败: {error}'**
  String settingsLogoutFailed(String error);

  /// No description provided for @settingsLogoutCurrent.
  ///
  /// In zh, this message translates to:
  /// **'退出当前账号'**
  String get settingsLogoutCurrent;

  /// No description provided for @settingsSwitchTitle.
  ///
  /// In zh, this message translates to:
  /// **'切换账号'**
  String get settingsSwitchTitle;

  /// No description provided for @settingsAddAccount.
  ///
  /// In zh, this message translates to:
  /// **'添加账号'**
  String get settingsAddAccount;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In zh, this message translates to:
  /// **'删除账号'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个账号吗？'**
  String get settingsDeleteAccountConfirm;

  /// No description provided for @settingsDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get settingsDelete;

  /// No description provided for @settingsNoSavedAccounts.
  ///
  /// In zh, this message translates to:
  /// **'暂无保存的账号'**
  String get settingsNoSavedAccounts;

  /// No description provided for @settingsNoSavedAccountsHint.
  ///
  /// In zh, this message translates to:
  /// **'添加后可一键切换登录'**
  String get settingsNoSavedAccountsHint;

  /// No description provided for @settingsSwitchToAccount.
  ///
  /// In zh, this message translates to:
  /// **'切换到此账号'**
  String get settingsSwitchToAccount;

  /// No description provided for @settingsSwitchingAccount.
  ///
  /// In zh, this message translates to:
  /// **'正在切换账号…'**
  String get settingsSwitchingAccount;

  /// No description provided for @settingsSwitchFailed.
  ///
  /// In zh, this message translates to:
  /// **'切换账号失败'**
  String get settingsSwitchFailed;

  /// No description provided for @settingsPasswordMasked.
  ///
  /// In zh, this message translates to:
  /// **'密码 {masked}'**
  String settingsPasswordMasked(String masked);

  /// No description provided for @settingsNotify.
  ///
  /// In zh, this message translates to:
  /// **'通知与消息'**
  String get settingsNotify;

  /// No description provided for @settingsNotifySub.
  ///
  /// In zh, this message translates to:
  /// **'控制提醒触达方式'**
  String get settingsNotifySub;

  /// No description provided for @settingsRing.
  ///
  /// In zh, this message translates to:
  /// **'铃声通知'**
  String get settingsRing;

  /// No description provided for @settingsRingSub.
  ///
  /// In zh, this message translates to:
  /// **'重要互动即时提醒'**
  String get settingsRingSub;

  /// No description provided for @settingsEmailNotify.
  ///
  /// In zh, this message translates to:
  /// **'邮件通知'**
  String get settingsEmailNotify;

  /// No description provided for @settingsEmailNotifySub.
  ///
  /// In zh, this message translates to:
  /// **'账单与安全邮件'**
  String get settingsEmailNotifySub;

  /// No description provided for @settingsMsgPush.
  ///
  /// In zh, this message translates to:
  /// **'消息推送'**
  String get settingsMsgPush;

  /// No description provided for @settingsMsgPushSub.
  ///
  /// In zh, this message translates to:
  /// **'系统与运营推送'**
  String get settingsMsgPushSub;

  /// No description provided for @settingsPlayback.
  ///
  /// In zh, this message translates to:
  /// **'播放与偏好'**
  String get settingsPlayback;

  /// No description provided for @settingsPlaybackSub.
  ///
  /// In zh, this message translates to:
  /// **'短剧观看体验细调'**
  String get settingsPlaybackSub;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsNightMode.
  ///
  /// In zh, this message translates to:
  /// **'夜晚模式'**
  String get settingsNightMode;

  /// No description provided for @settingsNightModeSub.
  ///
  /// In zh, this message translates to:
  /// **'降低屏幕亮度刺激'**
  String get settingsNightModeSub;

  /// No description provided for @settingsPlayerMore.
  ///
  /// In zh, this message translates to:
  /// **'内页更多入口'**
  String get settingsPlayerMore;

  /// No description provided for @settingsPlayerMoreSub.
  ///
  /// In zh, this message translates to:
  /// **'详情播放右上角收纳图标，默认开启'**
  String get settingsPlayerMoreSub;

  /// No description provided for @settingsAutoNext.
  ///
  /// In zh, this message translates to:
  /// **'片尾倒计时切集'**
  String get settingsAutoNext;

  /// No description provided for @settingsAutoNextSub.
  ///
  /// In zh, this message translates to:
  /// **'3 秒确认；关闭则直接下一集'**
  String get settingsAutoNextSub;

  /// No description provided for @settingsCompliance.
  ///
  /// In zh, this message translates to:
  /// **'合规与关于'**
  String get settingsCompliance;

  /// No description provided for @settingsYouth.
  ///
  /// In zh, this message translates to:
  /// **'青少年模式'**
  String get settingsYouth;

  /// No description provided for @settingsYouthSub.
  ///
  /// In zh, this message translates to:
  /// **'限制付费与社交（一期占位）'**
  String get settingsYouthSub;

  /// No description provided for @settingsYouthDialog.
  ///
  /// In zh, this message translates to:
  /// **'一期占位：开启后将限制付费解锁与私信功能。'**
  String get settingsYouthDialog;

  /// No description provided for @settingsGotIt.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get settingsGotIt;

  /// No description provided for @settingsFeedback.
  ///
  /// In zh, this message translates to:
  /// **'举报与反馈'**
  String get settingsFeedback;

  /// No description provided for @settingsFeedbackDone.
  ///
  /// In zh, this message translates to:
  /// **'已记录反馈入口'**
  String get settingsFeedbackDone;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于 ZiTok'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSub.
  ///
  /// In zh, this message translates to:
  /// **'短剧 · v0.1.0'**
  String get settingsAboutSub;

  /// No description provided for @settingsSelectLanguage.
  ///
  /// In zh, this message translates to:
  /// **'选择语言'**
  String get settingsSelectLanguage;

  /// No description provided for @langZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get langZh;

  /// No description provided for @langEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @profileQuickEntries.
  ///
  /// In zh, this message translates to:
  /// **'常用入口'**
  String get profileQuickEntries;

  /// No description provided for @profileWallet.
  ///
  /// In zh, this message translates to:
  /// **'钱包'**
  String get profileWallet;

  /// No description provided for @profileWalletSub.
  ///
  /// In zh, this message translates to:
  /// **'充值解锁'**
  String get profileWalletSub;

  /// No description provided for @profileWatching.
  ///
  /// In zh, this message translates to:
  /// **'追剧'**
  String get profileWatching;

  /// No description provided for @profileWatchingSub.
  ///
  /// In zh, this message translates to:
  /// **'去发现好剧'**
  String get profileWatchingSub;

  /// No description provided for @profileWatchingSubCount.
  ///
  /// In zh, this message translates to:
  /// **'续看 {count} 部'**
  String profileWatchingSubCount(int count);

  /// No description provided for @profileMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get profileMessages;

  /// No description provided for @profileMessagesSub.
  ///
  /// In zh, this message translates to:
  /// **'互动通知'**
  String get profileMessagesSub;

  /// No description provided for @profileSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get profileSettings;

  /// No description provided for @profileSettingsSub.
  ///
  /// In zh, this message translates to:
  /// **'账号与偏好'**
  String get profileSettingsSub;

  /// No description provided for @profileContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续观看'**
  String get profileContinue;

  /// No description provided for @profileFavorites.
  ///
  /// In zh, this message translates to:
  /// **'我的收藏'**
  String get profileFavorites;

  /// No description provided for @profileAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get profileAll;

  /// No description provided for @profileCoins.
  ///
  /// In zh, this message translates to:
  /// **'我的金币'**
  String get profileCoins;

  /// No description provided for @profileContinueCount.
  ///
  /// In zh, this message translates to:
  /// **'续看'**
  String get profileContinueCount;

  /// No description provided for @profileFavCount.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get profileFavCount;

  /// No description provided for @profileRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get profileRetry;

  /// No description provided for @profileDemoBio.
  ///
  /// In zh, this message translates to:
  /// **'ZiTok 演示账号'**
  String get profileDemoBio;

  /// No description provided for @profileWriteBio.
  ///
  /// In zh, this message translates to:
  /// **'写下你的追剧宣言'**
  String get profileWriteBio;

  /// No description provided for @theaterTitle.
  ///
  /// In zh, this message translates to:
  /// **'剧场'**
  String get theaterTitle;

  /// No description provided for @theaterCatAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get theaterCatAll;

  /// No description provided for @theaterCatRomance.
  ///
  /// In zh, this message translates to:
  /// **'甜宠'**
  String get theaterCatRomance;

  /// No description provided for @theaterCatCostume.
  ///
  /// In zh, this message translates to:
  /// **'古装'**
  String get theaterCatCostume;

  /// No description provided for @theaterCatYouth.
  ///
  /// In zh, this message translates to:
  /// **'青春'**
  String get theaterCatYouth;

  /// No description provided for @watchingTitle.
  ///
  /// In zh, this message translates to:
  /// **'追剧'**
  String get watchingTitle;

  /// No description provided for @watchingEmptyContinue.
  ///
  /// In zh, this message translates to:
  /// **'暂无进度，去剧场挑一部开追'**
  String get watchingEmptyContinue;

  /// No description provided for @watchingEmptyFav.
  ///
  /// In zh, this message translates to:
  /// **'还没有追剧，点进播放页即可收藏'**
  String get watchingEmptyFav;

  /// No description provided for @watchingEpisodes.
  ///
  /// In zh, this message translates to:
  /// **'{count}集'**
  String watchingEpisodes(int count);

  /// No description provided for @watchingUnknownDrama.
  ///
  /// In zh, this message translates to:
  /// **'未知剧'**
  String get watchingUnknownDrama;

  /// No description provided for @profileEmptyFavTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏'**
  String get profileEmptyFavTitle;

  /// No description provided for @profileEmptyFavSub.
  ///
  /// In zh, this message translates to:
  /// **'去剧场挑一部心动短剧吧'**
  String get profileEmptyFavSub;

  /// No description provided for @messagesTitle.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messagesTitle;

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get commonAdd;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get commonLoading;

  /// No description provided for @dialogClearSearchHistory.
  ///
  /// In zh, this message translates to:
  /// **'清除搜索历史'**
  String get dialogClearSearchHistory;

  /// No description provided for @dialogClearSearchHistoryBody.
  ///
  /// In zh, this message translates to:
  /// **'确定要清除所有搜索历史吗？'**
  String get dialogClearSearchHistoryBody;

  /// No description provided for @dialogSearchHistoryCleared.
  ///
  /// In zh, this message translates to:
  /// **'搜索历史已清除'**
  String get dialogSearchHistoryCleared;

  /// No description provided for @dialogFollowUser.
  ///
  /// In zh, this message translates to:
  /// **'关注 {name}'**
  String dialogFollowUser(String name);

  /// No description provided for @dialogFollowRemarkHint.
  ///
  /// In zh, this message translates to:
  /// **'设置备注（选填）'**
  String get dialogFollowRemarkHint;

  /// No description provided for @dialogAddTag.
  ///
  /// In zh, this message translates to:
  /// **'添加标签'**
  String get dialogAddTag;

  /// No description provided for @dialogConfirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get dialogConfirmDelete;

  /// No description provided for @dialogDeleteIrreversible.
  ///
  /// In zh, this message translates to:
  /// **'删除后不可恢复'**
  String get dialogDeleteIrreversible;

  /// No description provided for @dialogResetModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'重新选择模式'**
  String get dialogResetModeTitle;

  /// No description provided for @dialogResetModeBody.
  ///
  /// In zh, this message translates to:
  /// **'重新选择发布模式将清空已填写的所有数据，确定要继续吗？'**
  String get dialogResetModeBody;

  /// No description provided for @dialogResetModeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定清空'**
  String get dialogResetModeConfirm;

  /// No description provided for @dialogExitTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认退出'**
  String get dialogExitTitle;

  /// No description provided for @dialogExitBody.
  ///
  /// In zh, this message translates to:
  /// **'您有未保存的内容，退出后将丢失所有编辑数据，确定要退出吗？'**
  String get dialogExitBody;

  /// No description provided for @dialogExitKeep.
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get dialogExitKeep;

  /// No description provided for @dialogExitConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认退出'**
  String get dialogExitConfirm;

  /// No description provided for @dialogDiscardTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃更改？'**
  String get dialogDiscardTitle;

  /// No description provided for @dialogDiscardBody.
  ///
  /// In zh, this message translates to:
  /// **'您有未保存的更改，确定要放弃吗？'**
  String get dialogDiscardBody;

  /// No description provided for @dialogDiscard.
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get dialogDiscard;

  /// No description provided for @dialogSelectGender.
  ///
  /// In zh, this message translates to:
  /// **'选择性别'**
  String get dialogSelectGender;

  /// No description provided for @dialogGenderMale.
  ///
  /// In zh, this message translates to:
  /// **'男'**
  String get dialogGenderMale;

  /// No description provided for @dialogGenderFemale.
  ///
  /// In zh, this message translates to:
  /// **'女'**
  String get dialogGenderFemale;

  /// No description provided for @dialogGenderHidden.
  ///
  /// In zh, this message translates to:
  /// **'不显示'**
  String get dialogGenderHidden;

  /// No description provided for @messagesFilterTitle.
  ///
  /// In zh, this message translates to:
  /// **'筛选消息'**
  String get messagesFilterTitle;

  /// No description provided for @messagesFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部消息'**
  String get messagesFilterAll;

  /// No description provided for @messagesFilterAllSub.
  ///
  /// In zh, this message translates to:
  /// **'显示所有联系人和群聊'**
  String get messagesFilterAllSub;

  /// No description provided for @messagesFilterMutual.
  ///
  /// In zh, this message translates to:
  /// **'互关好友'**
  String get messagesFilterMutual;

  /// No description provided for @messagesFilterMutualSub.
  ///
  /// In zh, this message translates to:
  /// **'双向关注的好友'**
  String get messagesFilterMutualSub;

  /// No description provided for @messagesFilterFollowing.
  ///
  /// In zh, this message translates to:
  /// **'我关注的'**
  String get messagesFilterFollowing;

  /// No description provided for @messagesFilterFollowingSub.
  ///
  /// In zh, this message translates to:
  /// **'我关注的用户'**
  String get messagesFilterFollowingSub;

  /// No description provided for @messagesFilterFollowers.
  ///
  /// In zh, this message translates to:
  /// **'我的粉丝'**
  String get messagesFilterFollowers;

  /// No description provided for @messagesFilterFollowersSub.
  ///
  /// In zh, this message translates to:
  /// **'关注我的用户'**
  String get messagesFilterFollowersSub;

  /// No description provided for @messagesFilterGroups.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get messagesFilterGroups;

  /// No description provided for @messagesFilterGroupsSub.
  ///
  /// In zh, this message translates to:
  /// **'我加入的群组'**
  String get messagesFilterGroupsSub;

  /// No description provided for @messagesAddFriend.
  ///
  /// In zh, this message translates to:
  /// **'添加好友'**
  String get messagesAddFriend;

  /// No description provided for @messagesNewGroup.
  ///
  /// In zh, this message translates to:
  /// **'新建群聊'**
  String get messagesNewGroup;

  /// No description provided for @messagesRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get messagesRetry;

  /// No description provided for @globalSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索全网用户…'**
  String get globalSearchHint;

  /// No description provided for @globalSearchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'搜索用户 ID 或昵称'**
  String get globalSearchEmpty;

  /// No description provided for @globalSearchNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到相关用户'**
  String get globalSearchNotFound;

  /// No description provided for @globalSearchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败'**
  String get globalSearchFailed;

  /// No description provided for @globalSearchNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'网络错误'**
  String get globalSearchNetworkError;

  /// No description provided for @globalSearchUnknownUser.
  ///
  /// In zh, this message translates to:
  /// **'未知用户'**
  String get globalSearchUnknownUser;

  /// No description provided for @globalSearchFollow.
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get globalSearchFollow;

  /// No description provided for @globalSearchFollowed.
  ///
  /// In zh, this message translates to:
  /// **'已关注'**
  String get globalSearchFollowed;

  /// No description provided for @globalSearchFollowOk.
  ///
  /// In zh, this message translates to:
  /// **'关注成功'**
  String get globalSearchFollowOk;

  /// No description provided for @createGroupTitle.
  ///
  /// In zh, this message translates to:
  /// **'发起群聊'**
  String get createGroupTitle;

  /// No description provided for @createGroupAction.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get createGroupAction;

  /// No description provided for @createGroupName.
  ///
  /// In zh, this message translates to:
  /// **'群聊名称'**
  String get createGroupName;

  /// No description provided for @createGroupNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：周末开黑群'**
  String get createGroupNameHint;

  /// No description provided for @createGroupSelectMembers.
  ///
  /// In zh, this message translates to:
  /// **'选择成员 ({count})'**
  String createGroupSelectMembers(int count);

  /// No description provided for @createGroupNoFriends.
  ///
  /// In zh, this message translates to:
  /// **'暂无互关好友可选'**
  String get createGroupNoFriends;

  /// No description provided for @createGroupNeedName.
  ///
  /// In zh, this message translates to:
  /// **'请输入群聊名称'**
  String get createGroupNeedName;

  /// No description provided for @createGroupNeedMember.
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一个成员'**
  String get createGroupNeedMember;

  /// No description provided for @createGroupSuccess.
  ///
  /// In zh, this message translates to:
  /// **'群聊创建成功'**
  String get createGroupSuccess;

  /// No description provided for @createGroupFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建失败: {error}'**
  String createGroupFailed(String error);

  /// No description provided for @userIdLabel.
  ///
  /// In zh, this message translates to:
  /// **'ID: {id}'**
  String userIdLabel(String id);

  /// No description provided for @playerNewDrama.
  ///
  /// In zh, this message translates to:
  /// **'新剧'**
  String get playerNewDrama;

  /// No description provided for @playerExpand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get playerExpand;

  /// No description provided for @playerCollapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get playerCollapse;

  /// No description provided for @playerWatchFull.
  ///
  /// In zh, this message translates to:
  /// **'观看完整短剧 · 全{count}集'**
  String playerWatchFull(int count);

  /// No description provided for @playerDanmaku.
  ///
  /// In zh, this message translates to:
  /// **'弹'**
  String get playerDanmaku;

  /// No description provided for @playerEpisodeNo.
  ///
  /// In zh, this message translates to:
  /// **'第{episode}集'**
  String playerEpisodeNo(int episode);

  /// No description provided for @sessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录已失效，请重新登录'**
  String get sessionExpired;

  /// No description provided for @settingsAboutLegalese.
  ///
  /// In zh, this message translates to:
  /// **'沉浸竖屏短剧体验'**
  String get settingsAboutLegalese;

  /// No description provided for @profileUserFallback.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get profileUserFallback;

  /// No description provided for @profileEpisodeSeen.
  ///
  /// In zh, this message translates to:
  /// **'看到第{episode}集'**
  String profileEpisodeSeen(int episode);
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
