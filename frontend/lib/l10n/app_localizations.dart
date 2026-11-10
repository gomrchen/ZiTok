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

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get commonLoading;

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
