// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ZiTok Drama';

  @override
  String get brandName => 'ZiTok';

  @override
  String get brandSuffix => 'Drama';

  @override
  String get tagline => 'Vertical binge · Finish in one sitting';

  @override
  String get demoHint => 'Demo account zitok / demo1234';

  @override
  String get tabHome => 'Home';

  @override
  String get tabTheater => 'Theater';

  @override
  String get tabMessages => 'Messages';

  @override
  String get tabProfile => 'Me';

  @override
  String get navMain => 'Main navigation';

  @override
  String get welcomeDemoEnter => 'Enter with demo account';

  @override
  String get welcomeAccountLogin => 'Sign in';

  @override
  String get welcomeRegister => 'Create account';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginUsername => 'Username';

  @override
  String get loginUsernameHint => 'Enter username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginPasswordHint => 'Enter password';

  @override
  String get loginForgot => 'Forgot password?';

  @override
  String get loginAction => 'Sign in';

  @override
  String get loginNoAccount => 'No account?';

  @override
  String get loginRegisterNow => 'Register';

  @override
  String get loginNeedCredentials => 'Enter username and password';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle =>
      'Follow dramas, sync progress, and keep watching';

  @override
  String get registerUsernameHint => 'Choose a nickname';

  @override
  String get registerEmail => 'Email';

  @override
  String get registerEmailHint => 'For verification codes';

  @override
  String get registerPasswordHint => 'Letters + numbers, 8–20 chars';

  @override
  String get registerCode => 'Code';

  @override
  String get registerCodeHint => '6-digit code';

  @override
  String get registerGetCode => 'Get code';

  @override
  String get registerSubmit => 'Register & sign in';

  @override
  String get registerHasAccount => 'Already have an account?';

  @override
  String get registerBackLogin => 'Back to sign in';

  @override
  String get registerSuccess => 'Registered. Please sign in';

  @override
  String get registerNeedUsername => 'Enter a username';

  @override
  String get registerNeedEmail => 'Enter an email';

  @override
  String get registerInvalidEmail => 'Enter a valid email';

  @override
  String get registerNeedPassword => 'Set a password';

  @override
  String get registerInvalidPassword =>
      'Password needs letters and numbers, 8–20 chars';

  @override
  String get registerNeedCode => 'Enter the code';

  @override
  String get registerInvalidCode => 'Code must be 6 digits';

  @override
  String get registerNeedEmailFirst => 'Enter email first';

  @override
  String get codeSent => 'Code sent. Check your inbox';

  @override
  String get codeSendFailed => 'Failed to send code';

  @override
  String get forgotTitle => 'Reset password';

  @override
  String get forgotSubtitle => 'Reset securely with an email verification code';

  @override
  String get forgotEmailHint => 'Email used at registration';

  @override
  String get forgotNewPassword => 'New password';

  @override
  String get forgotNewPasswordHint => 'Letters + numbers, 8–20 chars';

  @override
  String get forgotSubmit => 'Confirm reset';

  @override
  String get forgotRemember => 'Remember password?';

  @override
  String get forgotBackLogin => 'Back to sign in';

  @override
  String get forgotSuccess => 'Password reset. Please sign in';

  @override
  String get forgotNeedEmail => 'Enter email';

  @override
  String get forgotNeedCode => 'Enter the code';

  @override
  String get forgotNeedPassword => 'Enter a new password';

  @override
  String get forgotInvalidPassword =>
      'New password needs letters and numbers, 8–20 chars';

  @override
  String get forgotFailed => 'Reset failed';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsHeroTitle => 'Personalize your drama';

  @override
  String get settingsHeroSubtitle =>
      'Notifications, gestures, and account security';

  @override
  String get settingsAccountSecurity => 'Account & security';

  @override
  String get settingsAccountSecuritySub => 'Manage identity and password';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAccountSub => 'Switch account / Sign out';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsSecuritySub => 'Reset password via email';

  @override
  String get settingsSecurityHeroTitle => 'Reset password';

  @override
  String get settingsSecurityHeroSub =>
      'Verify your registered email, then set a new password';

  @override
  String get settingsRegisteredEmail => 'Registered email';

  @override
  String get settingsBackToSettings => 'Back to settings';

  @override
  String get settingsAccountTitle => 'Account';

  @override
  String get settingsCurrentAccount => 'Signed in as';

  @override
  String get settingsAccountManage => 'Account management';

  @override
  String get settingsAccountManageSub => 'Switch or sign out';

  @override
  String get settingsSwitchAccount => 'Switch account';

  @override
  String get settingsSwitchAccountSub => 'Jump between saved accounts';

  @override
  String get settingsLogout => 'Sign out';

  @override
  String get settingsLogoutSub => 'Clear local session';

  @override
  String get settingsLogoutConfirm => 'Sign out of this account?';

  @override
  String settingsLogoutFailed(String error) {
    return 'Sign out failed: $error';
  }

  @override
  String get settingsLogoutCurrent => 'Sign out of this account';

  @override
  String get settingsSwitchTitle => 'Switch account';

  @override
  String get settingsAddAccount => 'Add account';

  @override
  String get settingsDeleteAccount => 'Remove account';

  @override
  String get settingsDeleteAccountConfirm => 'Remove this saved account?';

  @override
  String get settingsDelete => 'Remove';

  @override
  String get settingsNoSavedAccounts => 'No saved accounts';

  @override
  String get settingsNoSavedAccountsHint => 'Add one to switch with a tap';

  @override
  String get settingsSwitchToAccount => 'Switch to this account';

  @override
  String get settingsSwitchingAccount => 'Switching account…';

  @override
  String get settingsSwitchFailed => 'Could not switch account';

  @override
  String settingsPasswordMasked(String masked) {
    return 'Password $masked';
  }

  @override
  String get settingsNotify => 'Notifications';

  @override
  String get settingsNotifySub => 'Control how you get alerts';

  @override
  String get settingsRing => 'Sound alerts';

  @override
  String get settingsRingSub => 'Important interactions';

  @override
  String get settingsEmailNotify => 'Email alerts';

  @override
  String get settingsEmailNotifySub => 'Billing and security mail';

  @override
  String get settingsMsgPush => 'Push messages';

  @override
  String get settingsMsgPushSub => 'System and product pushes';

  @override
  String get settingsPlayback => 'Playback & prefs';

  @override
  String get settingsPlaybackSub => 'Tune watching experience';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsNightMode => 'Night mode';

  @override
  String get settingsNightModeSub => 'Reduce screen brightness strain';

  @override
  String get settingsPlayerMore => 'More menu on player';

  @override
  String get settingsPlayerMoreSub => 'Top-right overflow on detail player';

  @override
  String get settingsAutoNext => 'End-card countdown';

  @override
  String get settingsAutoNextSub => '3s confirm; off jumps to next episode';

  @override
  String get settingsCompliance => 'Compliance & about';

  @override
  String get settingsYouth => 'Youth mode';

  @override
  String get settingsYouthSub => 'Limit payments & social (placeholder)';

  @override
  String get settingsYouthDialog =>
      'Placeholder: limits paid unlocks and DMs when enabled.';

  @override
  String get settingsGotIt => 'Got it';

  @override
  String get settingsFeedback => 'Report & feedback';

  @override
  String get settingsFeedbackDone => 'Feedback entry recorded';

  @override
  String get settingsAbout => 'About ZiTok';

  @override
  String get settingsAboutSub => 'Drama · v0.1.0';

  @override
  String get settingsSelectLanguage => 'Choose language';

  @override
  String get langZh => '简体中文';

  @override
  String get langEn => 'English';

  @override
  String get profileQuickEntries => 'Shortcuts';

  @override
  String get profileWallet => 'Wallet';

  @override
  String get profileWalletSub => 'Top up to unlock';

  @override
  String get profileWatching => 'Watchlist';

  @override
  String get profileWatchingSub => 'Discover dramas';

  @override
  String profileWatchingSubCount(int count) {
    return '$count continuing';
  }

  @override
  String get profileMessages => 'Messages';

  @override
  String get profileMessagesSub => 'Activity alerts';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileSettingsSub => 'Account & prefs';

  @override
  String get profileContinue => 'Continue watching';

  @override
  String get profileFavorites => 'Favorites';

  @override
  String get profileAll => 'All';

  @override
  String get profileCoins => 'My coins';

  @override
  String get profileContinueCount => 'Continue';

  @override
  String get profileFavCount => 'Favorites';

  @override
  String get profileRetry => 'Retry';

  @override
  String get profileDemoBio => 'ZiTok demo account';

  @override
  String get profileWriteBio => 'Write your watching motto';

  @override
  String get theaterTitle => 'Theater';

  @override
  String get theaterCatAll => 'All';

  @override
  String get theaterCatRomance => 'Romance';

  @override
  String get theaterCatCostume => 'Costume';

  @override
  String get theaterCatYouth => 'Youth';

  @override
  String get watchingTitle => 'Watchlist';

  @override
  String get watchingEmptyContinue =>
      'No progress yet — pick a drama in Theater';

  @override
  String get watchingEmptyFav =>
      'No favorites yet — tap the heart on a player page';

  @override
  String watchingEpisodes(int count) {
    return '$count eps';
  }

  @override
  String get watchingUnknownDrama => 'Unknown drama';

  @override
  String get profileEmptyFavTitle => 'No favorites yet';

  @override
  String get profileEmptyFavSub => 'Discover a short drama in Theater';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get dialogClearSearchHistory => 'Clear search history';

  @override
  String get dialogClearSearchHistoryBody => 'Clear all search history?';

  @override
  String get dialogSearchHistoryCleared => 'Search history cleared';

  @override
  String dialogFollowUser(String name) {
    return 'Follow $name';
  }

  @override
  String get dialogFollowRemarkHint => 'Add a note (optional)';

  @override
  String get dialogAddTag => 'Add tag';

  @override
  String get dialogConfirmDelete => 'Delete?';

  @override
  String get dialogDeleteIrreversible => 'This cannot be undone';

  @override
  String get dialogResetModeTitle => 'Change publish mode';

  @override
  String get dialogResetModeBody =>
      'Changing mode clears what you already filled in. Continue?';

  @override
  String get dialogResetModeConfirm => 'Clear and continue';

  @override
  String get dialogExitTitle => 'Leave without saving?';

  @override
  String get dialogExitBody => 'Unsaved edits will be lost. Leave now?';

  @override
  String get dialogExitKeep => 'Keep editing';

  @override
  String get dialogExitConfirm => 'Leave';

  @override
  String get dialogDiscardTitle => 'Discard changes?';

  @override
  String get dialogDiscardBody => 'You have unsaved changes. Discard them?';

  @override
  String get dialogDiscard => 'Discard';

  @override
  String get dialogSelectGender => 'Select gender';

  @override
  String get dialogGenderMale => 'Male';

  @override
  String get dialogGenderFemale => 'Female';

  @override
  String get dialogGenderHidden => 'Prefer not to say';

  @override
  String get messagesFilterTitle => 'Filter messages';

  @override
  String get messagesFilterAll => 'All messages';

  @override
  String get messagesFilterAllSub => 'People and groups';

  @override
  String get messagesFilterMutual => 'Mutual friends';

  @override
  String get messagesFilterMutualSub => 'Follow each other';

  @override
  String get messagesFilterFollowing => 'Following';

  @override
  String get messagesFilterFollowingSub => 'Accounts you follow';

  @override
  String get messagesFilterFollowers => 'Followers';

  @override
  String get messagesFilterFollowersSub => 'Accounts following you';

  @override
  String get messagesFilterGroups => 'Groups';

  @override
  String get messagesFilterGroupsSub => 'Groups you joined';

  @override
  String get messagesAddFriend => 'Add friend';

  @override
  String get messagesNewGroup => 'New group';

  @override
  String get messagesRetry => 'Retry';

  @override
  String get globalSearchHint => 'Search all users…';

  @override
  String get globalSearchEmpty => 'Search by user ID or nickname';

  @override
  String get globalSearchNotFound => 'No users found';

  @override
  String get globalSearchFailed => 'Search failed';

  @override
  String get globalSearchNetworkError => 'Network error';

  @override
  String get globalSearchUnknownUser => 'Unknown user';

  @override
  String get globalSearchFollow => 'Follow';

  @override
  String get globalSearchFollowed => 'Following';

  @override
  String get globalSearchFollowOk => 'Followed';

  @override
  String get createGroupTitle => 'New group';

  @override
  String get createGroupAction => 'Create';

  @override
  String get createGroupName => 'Group name';

  @override
  String get createGroupNameHint => 'e.g. Weekend squad';

  @override
  String createGroupSelectMembers(int count) {
    return 'Select members ($count)';
  }

  @override
  String get createGroupNoFriends => 'No mutual friends to pick';

  @override
  String get createGroupNeedName => 'Enter a group chat name';

  @override
  String get createGroupNeedMember => 'Pick at least one member';

  @override
  String get createGroupSuccess => 'Group created';

  @override
  String createGroupFailed(String error) {
    return 'Could not create: $error';
  }

  @override
  String userIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get playerNewDrama => 'New';

  @override
  String get playerExpand => 'More';

  @override
  String get playerCollapse => 'Less';

  @override
  String playerWatchFull(int count) {
    return 'Watch full drama · $count eps';
  }

  @override
  String get playerDanmaku => '弹';

  @override
  String playerEpisodeNo(int episode) {
    return 'Ep. $episode';
  }

  @override
  String get sessionExpired => 'Session expired. Please sign in again';

  @override
  String get settingsAboutLegalese => 'Immersive vertical short dramas';

  @override
  String get profileUserFallback => 'User';

  @override
  String profileEpisodeSeen(int episode) {
    return 'Ep. $episode';
  }
}
