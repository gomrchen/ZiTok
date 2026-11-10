// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'ZiTok 短剧';

  @override
  String get brandName => 'ZiTok';

  @override
  String get brandSuffix => '短剧';

  @override
  String get tagline => '竖屏连播 · 一口气看完';

  @override
  String get demoHint => '演示账号 zitok / demo1234';

  @override
  String get tabHome => '首页';

  @override
  String get tabTheater => '剧场';

  @override
  String get tabMessages => '消息';

  @override
  String get tabProfile => '我的';

  @override
  String get navMain => '主导航';

  @override
  String get welcomeDemoEnter => '演示账号进入';

  @override
  String get welcomeAccountLogin => '账号登录';

  @override
  String get welcomeRegister => '新用户注册';

  @override
  String get loginWelcomeBack => '欢迎回来';

  @override
  String get loginUsername => '用户名';

  @override
  String get loginUsernameHint => '请输入用户名';

  @override
  String get loginPassword => '密码';

  @override
  String get loginPasswordHint => '请输入密码';

  @override
  String get loginForgot => '忘记密码？';

  @override
  String get loginAction => '登录';

  @override
  String get loginNoAccount => '没有账号？';

  @override
  String get loginRegisterNow => '立即注册';

  @override
  String get loginNeedCredentials => '请输入用户名和密码';

  @override
  String get registerTitle => '创建账号';

  @override
  String get registerSubtitle => '注册后即可追短剧、同步进度与追剧';

  @override
  String get registerUsernameHint => '设置你的昵称';

  @override
  String get registerEmail => '邮箱';

  @override
  String get registerEmailHint => '用于接收验证码';

  @override
  String get registerPasswordHint => '字母+数字，8–20 位';

  @override
  String get registerCode => '验证码';

  @override
  String get registerCodeHint => '6位验证码';

  @override
  String get registerGetCode => '获取验证码';

  @override
  String get registerSubmit => '注册并去登录';

  @override
  String get registerHasAccount => '已有账号？';

  @override
  String get registerBackLogin => '返回登录';

  @override
  String get registerSuccess => '注册成功，请登录';

  @override
  String get registerNeedUsername => '请输入用户名';

  @override
  String get registerNeedEmail => '请输入邮箱';

  @override
  String get registerInvalidEmail => '请输入有效邮箱';

  @override
  String get registerNeedPassword => '请设置密码';

  @override
  String get registerInvalidPassword => '密码需含字母和数字，长度 8–20 位';

  @override
  String get registerNeedCode => '请输入验证码';

  @override
  String get registerInvalidCode => '验证码须为 6 位数字';

  @override
  String get registerNeedEmailFirst => '请先填写邮箱';

  @override
  String get codeSent => '验证码已发送，请查收邮箱';

  @override
  String get codeSendFailed => '验证码发送失败';

  @override
  String get forgotTitle => '重置密码';

  @override
  String get forgotSubtitle => '通过邮箱验证码安全更新登录密码';

  @override
  String get forgotEmailHint => '注册时使用的邮箱';

  @override
  String get forgotNewPassword => '新密码';

  @override
  String get forgotNewPasswordHint => '字母+数字，8–20 位';

  @override
  String get forgotSubmit => '确认重置';

  @override
  String get forgotRemember => '记得密码？';

  @override
  String get forgotBackLogin => '返回登录';

  @override
  String get forgotSuccess => '密码已重置，请登录';

  @override
  String get forgotNeedEmail => '请输入邮箱';

  @override
  String get forgotNeedCode => '请输入验证码';

  @override
  String get forgotNeedPassword => '请输入新密码';

  @override
  String get forgotInvalidPassword => '新密码需含字母和数字，长度 8–20 位';

  @override
  String get forgotFailed => '重置失败';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsHeroTitle => '个性化你的短剧';

  @override
  String get settingsHeroSubtitle => '通知、播放手势与账户安全一站管理';

  @override
  String get settingsAccountSecurity => '账户与安全';

  @override
  String get settingsAccountSecuritySub => '管理登录身份与密码';

  @override
  String get settingsAccount => '账户';

  @override
  String get settingsAccountSub => '切换账号 / 退出登录';

  @override
  String get settingsSecurity => '安全';

  @override
  String get settingsSecuritySub => '邮箱验证重置密码';

  @override
  String get settingsSecurityHeroTitle => '重置登录密码';

  @override
  String get settingsSecurityHeroSub => '通过注册邮箱验证后设置新密码';

  @override
  String get settingsRegisteredEmail => '注册邮箱';

  @override
  String get settingsBackToSettings => '返回设置';

  @override
  String get settingsAccountTitle => '账户设置';

  @override
  String get settingsCurrentAccount => '当前账号';

  @override
  String get settingsAccountManage => '账户管理';

  @override
  String get settingsAccountManageSub => '切换或退出当前登录态';

  @override
  String get settingsSwitchAccount => '切换账号';

  @override
  String get settingsSwitchAccountSub => '在已保存账号间快速切换';

  @override
  String get settingsLogout => '退出登录';

  @override
  String get settingsLogoutSub => '清除本机登录态';

  @override
  String get settingsLogoutConfirm => '确定要退出当前账号吗？';

  @override
  String settingsLogoutFailed(String error) {
    return '登出失败: $error';
  }

  @override
  String get settingsLogoutCurrent => '退出当前账号';

  @override
  String get settingsSwitchTitle => '切换账号';

  @override
  String get settingsAddAccount => '添加账号';

  @override
  String get settingsDeleteAccount => '删除账号';

  @override
  String get settingsDeleteAccountConfirm => '确定要删除这个账号吗？';

  @override
  String get settingsDelete => '删除';

  @override
  String get settingsNoSavedAccounts => '暂无保存的账号';

  @override
  String get settingsNoSavedAccountsHint => '添加后可一键切换登录';

  @override
  String get settingsSwitchToAccount => '切换到此账号';

  @override
  String get settingsSwitchingAccount => '正在切换账号…';

  @override
  String get settingsSwitchFailed => '切换账号失败';

  @override
  String settingsPasswordMasked(String masked) {
    return '密码 $masked';
  }

  @override
  String get settingsNotify => '通知与消息';

  @override
  String get settingsNotifySub => '控制提醒触达方式';

  @override
  String get settingsRing => '铃声通知';

  @override
  String get settingsRingSub => '重要互动即时提醒';

  @override
  String get settingsEmailNotify => '邮件通知';

  @override
  String get settingsEmailNotifySub => '账单与安全邮件';

  @override
  String get settingsMsgPush => '消息推送';

  @override
  String get settingsMsgPushSub => '系统与运营推送';

  @override
  String get settingsPlayback => '播放与偏好';

  @override
  String get settingsPlaybackSub => '短剧观看体验细调';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsNightMode => '夜晚模式';

  @override
  String get settingsNightModeSub => '降低屏幕亮度刺激';

  @override
  String get settingsPlayerMore => '内页更多入口';

  @override
  String get settingsPlayerMoreSub => '详情播放右上角收纳图标，默认开启';

  @override
  String get settingsAutoNext => '片尾倒计时切集';

  @override
  String get settingsAutoNextSub => '3 秒确认；关闭则直接下一集';

  @override
  String get settingsCompliance => '合规与关于';

  @override
  String get settingsYouth => '青少年模式';

  @override
  String get settingsYouthSub => '限制付费与社交（一期占位）';

  @override
  String get settingsYouthDialog => '一期占位：开启后将限制付费解锁与私信功能。';

  @override
  String get settingsGotIt => '知道了';

  @override
  String get settingsFeedback => '举报与反馈';

  @override
  String get settingsFeedbackDone => '已记录反馈入口';

  @override
  String get settingsAbout => '关于 ZiTok';

  @override
  String get settingsAboutSub => '短剧 · v0.1.0';

  @override
  String get settingsSelectLanguage => '选择语言';

  @override
  String get langZh => '简体中文';

  @override
  String get langEn => 'English';

  @override
  String get profileQuickEntries => '常用入口';

  @override
  String get profileWallet => '钱包';

  @override
  String get profileWalletSub => '充值解锁';

  @override
  String get profileWatching => '追剧';

  @override
  String get profileWatchingSub => '去发现好剧';

  @override
  String profileWatchingSubCount(int count) {
    return '续看 $count 部';
  }

  @override
  String get profileMessages => '消息';

  @override
  String get profileMessagesSub => '互动通知';

  @override
  String get profileSettings => '设置';

  @override
  String get profileSettingsSub => '账号与偏好';

  @override
  String get profileContinue => '继续观看';

  @override
  String get profileFavorites => '我的收藏';

  @override
  String get profileAll => '全部';

  @override
  String get profileCoins => '我的金币';

  @override
  String get profileContinueCount => '续看';

  @override
  String get profileFavCount => '收藏';

  @override
  String get profileRetry => '重试';

  @override
  String get profileDemoBio => 'ZiTok 演示账号';

  @override
  String get profileWriteBio => '写下你的追剧宣言';

  @override
  String get theaterTitle => '剧场';

  @override
  String get theaterCatAll => '全部';

  @override
  String get theaterCatRomance => '甜宠';

  @override
  String get theaterCatCostume => '古装';

  @override
  String get theaterCatYouth => '青春';

  @override
  String get watchingTitle => '追剧';

  @override
  String get watchingEmptyContinue => '暂无进度，去剧场挑一部开追';

  @override
  String get watchingEmptyFav => '还没有追剧，点进播放页即可收藏';

  @override
  String watchingEpisodes(int count) {
    return '$count集';
  }

  @override
  String get watchingUnknownDrama => '未知剧';

  @override
  String get profileEmptyFavTitle => '还没有收藏';

  @override
  String get profileEmptyFavSub => '去剧场挑一部心动短剧吧';

  @override
  String get messagesTitle => '消息';

  @override
  String get commonBack => '返回';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonAdd => '添加';

  @override
  String get commonLoading => '加载中…';

  @override
  String get dialogClearSearchHistory => '清除搜索历史';

  @override
  String get dialogClearSearchHistoryBody => '确定要清除所有搜索历史吗？';

  @override
  String get dialogSearchHistoryCleared => '搜索历史已清除';

  @override
  String dialogFollowUser(String name) {
    return '关注 $name';
  }

  @override
  String get dialogFollowRemarkHint => '设置备注（选填）';

  @override
  String get dialogAddTag => '添加标签';

  @override
  String get dialogConfirmDelete => '确认删除';

  @override
  String get dialogDeleteIrreversible => '删除后不可恢复';

  @override
  String get dialogResetModeTitle => '重新选择模式';

  @override
  String get dialogResetModeBody => '重新选择发布模式将清空已填写的所有数据，确定要继续吗？';

  @override
  String get dialogResetModeConfirm => '确定清空';

  @override
  String get dialogExitTitle => '确认退出';

  @override
  String get dialogExitBody => '您有未保存的内容，退出后将丢失所有编辑数据，确定要退出吗？';

  @override
  String get dialogExitKeep => '继续编辑';

  @override
  String get dialogExitConfirm => '确认退出';

  @override
  String get dialogDiscardTitle => '放弃更改？';

  @override
  String get dialogDiscardBody => '您有未保存的更改，确定要放弃吗？';

  @override
  String get dialogDiscard => '放弃';

  @override
  String get dialogSelectGender => '选择性别';

  @override
  String get dialogGenderMale => '男';

  @override
  String get dialogGenderFemale => '女';

  @override
  String get dialogGenderHidden => '不显示';

  @override
  String get messagesFilterTitle => '筛选消息';

  @override
  String get messagesFilterAll => '全部消息';

  @override
  String get messagesFilterAllSub => '显示所有联系人和群聊';

  @override
  String get messagesFilterMutual => '互关好友';

  @override
  String get messagesFilterMutualSub => '双向关注的好友';

  @override
  String get messagesFilterFollowing => '我关注的';

  @override
  String get messagesFilterFollowingSub => '我关注的用户';

  @override
  String get messagesFilterFollowers => '我的粉丝';

  @override
  String get messagesFilterFollowersSub => '关注我的用户';

  @override
  String get messagesFilterGroups => '群聊';

  @override
  String get messagesFilterGroupsSub => '我加入的群组';

  @override
  String get messagesAddFriend => '添加好友';

  @override
  String get messagesNewGroup => '新建群聊';

  @override
  String get messagesRetry => '重试';

  @override
  String get globalSearchHint => '搜索全网用户…';

  @override
  String get globalSearchEmpty => '搜索用户 ID 或昵称';

  @override
  String get globalSearchNotFound => '未找到相关用户';

  @override
  String get globalSearchFailed => '搜索失败';

  @override
  String get globalSearchNetworkError => '网络错误';

  @override
  String get globalSearchUnknownUser => '未知用户';

  @override
  String get globalSearchFollow => '关注';

  @override
  String get globalSearchFollowed => '已关注';

  @override
  String get globalSearchFollowOk => '关注成功';

  @override
  String get createGroupTitle => '发起群聊';

  @override
  String get createGroupAction => '创建';

  @override
  String get createGroupName => '群聊名称';

  @override
  String get createGroupNameHint => '例如：周末开黑群';

  @override
  String createGroupSelectMembers(int count) {
    return '选择成员 ($count)';
  }

  @override
  String get createGroupNoFriends => '暂无互关好友可选';

  @override
  String get createGroupNeedName => '请输入群聊名称';

  @override
  String get createGroupNeedMember => '请至少选择一个成员';

  @override
  String get createGroupSuccess => '群聊创建成功';

  @override
  String createGroupFailed(String error) {
    return '创建失败: $error';
  }

  @override
  String userIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get sessionExpired => '登录已失效，请重新登录';

  @override
  String get settingsAboutLegalese => '沉浸竖屏短剧体验';

  @override
  String get profileUserFallback => '用户';

  @override
  String profileEpisodeSeen(int episode) {
    return '看到第$episode集';
  }
}
