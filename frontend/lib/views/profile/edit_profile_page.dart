import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../theme/theme_tokens.dart';
import '../../app.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/user_service.dart';
import '../../utils/image_utils.dart';
import '../../utils/error_handler.dart';
import '../../utils/url_utils.dart';
import 'widgets/edit_field_dialog.dart';
import '../../models/user_models.dart'; // 导入用户模型以使用 Gender 枚举
import '../../widgets/glass_nav.dart';
import '../home/shell_surface.dart';

/// 编辑资料页
class EditProfilePage extends StatefulWidget {
  final UserService? userService;
  const EditProfilePage({super.key, this.userService});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ImagePicker _picker = ImagePicker();
  final CropController _cropController = CropController();

  // 预览字节
  Uint8List? _avatarPreview;
  Uint8List? _backdropPreview;

  // Loading 状态
  bool _uploadingAvatar = false;
  bool _uploadingBackdrop = false;

  // 资料完成度
  int _completion = 40;

  // 提示文字常量
  static const String _bioPlaceholder = '介绍喜好、个性或@你的亲友';

  // 可编辑字段
  String _nickname = '';
  String _bio = ''; // 实际值，空字符串表示未设置
  Gender _gender = Gender.unknown; // 修改：使用 Gender 枚举
  DateTime? _birthday;
  String _email = '';
  String? _avatarUrl;

  // 用于检测用户切换
  String? _lastUserId;

  // 便捷：当前用户 ID
  String get _userId => context.read<AuthProvider>().user?.id ?? '0';

  UserService get _userApi => widget.userService ?? UserService(AppBootstrap.apiClient.dio);

  @override
  void initState() {
    super.initState();
    // 监听 ProfileProvider 变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      context.read<ProfileProvider>().addListener(_onProfileChanged);
    });
  }

  /// 当 ProfileProvider 数据变化时检查是否需要重新加载
  void _onProfileChanged() {
    final profileProvider = context.read<ProfileProvider>();
    final currentUserId = profileProvider.user?.id;

    // 检测用户 ID 是否变化
    if (currentUserId != null && currentUserId != _lastUserId) {
      _loadUserData();
    }
  }

  void _loadUserData() {
    final profileProvider = context.read<ProfileProvider>();
    final user = profileProvider.user;

    if (user != null) {
      // 记录当前用户 ID
      _lastUserId = user.id;

      setState(() {
        _nickname = user.username;
        _email = user.email ?? '未设置邮箱';
        _bio = user.bio ?? ''; // 保存实际值，空字符串表示未设置
        _avatarUrl = user.avatarUrl;
        _gender = user.gender; // 直接使用 Gender 枚举

        // 清空预览图（切换账号时需要重置）
        _avatarPreview = null;
        _backdropPreview = null;

        // 从 Hive 加载其他字段（如果存在）
        final box = Hive.box('user_box');
        final birthdayStr = box.get('birthday') as String?;
        if (birthdayStr != null) {
          _birthday = DateTime.tryParse(birthdayStr);
        } else {
          _birthday = null;
        }
      });
      _recalcCompletion();
    }
  }

  ProfileProvider? _profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // dispose 时 Element 已 deactivate，不能再 context.read
    _profile ??= context.read<ProfileProvider>();
  }

  @override
  void dispose() {
    _profile?.removeListener(_onProfileChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: cs.surface,
        body: LayoutBuilder(
          builder: (context, constraints) {
            // 沉浸封面：状态栏 + 导航 + 头像区
            final headerHeight = topInset + 188;
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  snap: false,
                  stretch: true,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 52,
                  expandedHeight: headerHeight,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  // 导航固定在 AppBar 层，收起后仍可操作
                  leadingWidth: 56,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GlassNavButton(
                        tooltip: '返回',
                        icon: Icons.arrow_back_ios_new_rounded,
                        onPressed: () => ShellSurface.popOrHome(context),
                      ),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: GlassNavChip(
                          icon: _uploadingBackdrop
                              ? Icons.hourglass_top_rounded
                              : Icons.photo_camera_outlined,
                          label: _uploadingBackdrop ? '上传中' : '更换封面',
                          onPressed: _uploadingBackdrop ? null : _onChangeBackdrop,
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.fadeTitle,
                    ],
                    background: _buildHeader(context, headerHeight, cs),
                  ),
                ),
                // 内容卡片上沿圆角压住封面，形成柔和衔接
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: _buildInfoCard(context, cs),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 顶部头部背景：沉浸封面 + 渐变遮罩 + 头像/完成度（导航在 AppBar leading/actions）
  Widget _buildHeader(
    BuildContext context,
    double headerHeight,
    ColorScheme cs,
  ) {
    final profileProvider = context.watch<ProfileProvider>();
    final String? backdropUrl = profileProvider.user?.profileBackgroundImageUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildHeaderBackground(headerHeight, backdropUrl),
        // 顶部遮罩：状态栏与导航可读
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 120,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Color(0x33000000),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 底部遮罩：头像与进度条可读
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 140,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xB3000000),
                    Color(0x40000000),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 36,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatarButton(cs),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _buildProgress(),
              ),
            ],
          ),
        ),
      ],
    );
  }

// 重构头部背景构建方法
  Widget _buildHeaderBackground(double headerHeight, String? backdropUrl) {
    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2ED3BE), Color(0xFF1AAE9A)],
        ),
        image: _buildBackgroundImage(backdropUrl),
      ),
    );
  }

// 构建背景图片
  DecorationImage? _buildBackgroundImage(String? backdropUrl) {
    // 优先显示预览图
    if (_backdropPreview != null) {
      return DecorationImage(
        image: MemoryImage(_backdropPreview!),
        fit: BoxFit.cover,
      );
    }

    // 其次显示网络背景图
    if (backdropUrl != null && backdropUrl.isNotEmpty && backdropUrl != 'null') {
      return DecorationImage(
        image: NetworkImage(backdropUrl),
        fit: BoxFit.cover,
      );
    }

    return null;
  }


  Widget _buildAvatarButton(ColorScheme cs) {
    const double radius = 44;
    DecorationImage? image;
    if (_avatarPreview != null) {
      image = DecorationImage(image: MemoryImage(_avatarPreview!), fit: BoxFit.cover);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      image = DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover);
    }

    return Semantics(
      label: '更换头像',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _uploadingAvatar ? null : _showAvatarPickerSheet,
          customBorder: const CircleBorder(),
          child: Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2BD2C4),
              image: image,
              border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image == null)
                  const Icon(Icons.person_rounded, color: Colors.white, size: 36),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _uploadingAvatar ? Icons.hourglass_top_rounded : Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _uploadingAvatar ? '上传中' : '更换头像',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _completion / 100,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.28),
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '资料完成度 $_completion%',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, ColorScheme cs) {
    final titleStyle = Theme.of(context).textTheme.bodyMedium;
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    final highlightValueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final disabledValueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.5));

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部拖拽感装饰条
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: cs.primary, size: 18),
                const SizedBox(width: Spacing.sm),
                Text('完善资料，获得更多关注', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          // 名称 - 不可编辑
          _item(
            title: '名字',
            value: _nickname,
            titleStyle: titleStyle,
            valueStyle: highlightValueStyle,
            showArrow: false,
            enabled: false,
          ),
          // 邮箱 - 不可编辑
          _item(
            title: '邮箱',
            value: _email,
            titleStyle: titleStyle,
            valueStyle: disabledValueStyle,
            showArrow: false,
            enabled: false,
          ),
          // 可编辑字段
          _item(title: '简介', value: _bio.isEmpty ? _bioPlaceholder : _bio, titleStyle: titleStyle, valueStyle: valueStyle, onTap: _onEditBio),
          _item(title: '性别', value: _genderText(), titleStyle: titleStyle, valueStyle: valueStyle, onTap: _onEditGender),
          _item(title: '生日', value: _birthdayText(), titleStyle: titleStyle, valueStyle: valueStyle, onTap: _onEditBirthday),
          const SizedBox(height: Spacing.lg),
        ],
      ),
    );
  }

  Widget _item({
    required String title,
    required String value,
    TextStyle? titleStyle,
    TextStyle? valueStyle,
    VoidCallback? onTap,
    bool showArrow = true,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.md),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.6,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    const SizedBox(height: 6),
                    Text(value, style: valueStyle, textAlign: TextAlign.left),
                  ],
                ),
              ),
              if (showArrow && enabled) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _genderText() {
    switch (_gender) {
      case Gender.male:
        return '男';
      case Gender.female:
        return '女';
      case Gender.unknown:
        return '选择性别，表达自我';
    }
  }

  Future<void> _onEditGender() async {
    // 将当前 Gender 枚举转换为编辑对话框需要的 int? 格式
    int? currentValue = switch (_gender) {
      Gender.male => 1,
      Gender.female => 2,
      Gender.unknown => 3,
    };

    final v = await GenderSelectDialog.show(context, value: currentValue);

    // 如果用户取消选择，直接返回
    if (v == null) {
      return;
    }

    // 将返回的 int 转换回 Gender 枚举
    Gender newGender = switch (v) {
      1 => Gender.male,
      2 => Gender.female,
      _ => Gender.unknown,
    };

    setState(() {
      _gender = newGender;
    });

    // 保存到 Hive
    final box = Hive.box('user_box');
    await box.put('gender', v); // 直接使用对话框返回的值

    // 更新到服务器
    if (mounted) {
      context.read<ProfileProvider>().debounceUpdateInfo(gender: v);
    }

    _recalcCompletion();
  }

  String _birthdayText() {
    if (_birthday == null) return '生日当天会收到ZiTok 短剧的祝福';
    return '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}';
  }

  Future<void> _onEditBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthday = picked);
      Hive.box('user_box').put('birthday', picked.toIso8601String());
      final ymd = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      if (mounted) {
        context.read<ProfileProvider>().debounceUpdateInfo(birthday: ymd);
      }
      _recalcCompletion();
    }
  }

  Future<void> _onEditBio() async {
    // 传入实际值，空字符串让用户从空白开始输入
    final v = await EditTextDialog.show(context, title: '编辑简介', initial: _bio, hint: _bioPlaceholder, maxLines: 3, maxLength: 80);
    if (v != null) {
      setState(() => _bio = v);
      Hive.box('user_box').put('bio', v);
      if (mounted) {
        context.read<ProfileProvider>().debounceUpdateInfo(signature: v);
      }
      _recalcCompletion();
    }
  }

  void _recalcCompletion() {
    int score = 40; // 初始完成度
    // 简介非空：增加20分
    if (_bio.isNotEmpty) {
      score += 20;
    }
    // 性别非默认值（非null）：增加20分
    if (_gender != Gender.unknown) {
      score += 20;
    }
    // 生日非默认值（非null）：增加20分
    if (_birthday != null) {
      score += 20;
    }
    _completion = score.clamp(0, 100);
    setState(() {});
  }

  // 头像：显示选择来源弹窗
  Future<void> _showAvatarPickerSheet() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: Radii.lg),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sourceButton(icon: Icons.photo_library, text: '从相册选择', color: cs.primary, onTap: () {
                  Navigator.pop(context);
                  _onPickAvatar(ImageSource.gallery);
                }),
                _sourceButton(icon: Icons.camera_alt, text: '拍照', color: cs.primary, onTap: () {
                  Navigator.pop(context);
                  _onPickAvatar(ImageSource.camera);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sourceButton({required IconData icon, required String text, required Color color, required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Ink(
          decoration: ShapeDecoration(color: color, shape: const CircleBorder()),
          child: IconButton(onPressed: onTap, icon: Icon(icon, color: Colors.white)),
        ),
        const SizedBox(height: Spacing.sm),
        Text(text),
      ],
    );
  }

  Future<void> _onPickAvatar(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 95);
      if (xFile == null) {
        return;
      }

      final bytes = await xFile.readAsBytes();

      // 裁剪为 1:1
      final cropped = await _cropBytes(bytes, aspectRatio: 1.0);
      if (cropped == null) {
        return;
      }

      // 压缩到 200x200
      final compressed = ImageUtils.resizeToJpeg(cropped, width: 200, height: 200);

      setState(() => _avatarPreview = compressed);

      await _uploadAvatar(compressed);

    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, prefix: '选择头像失败');
      }
    }
  }

// 在 edit_profile_page.dart 中修改 _onChangeBackdrop 方法
  Future<void> _onChangeBackdrop() async {
    try {
      final xFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2400, maxHeight: 2400, imageQuality: 95);
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();

      // 获取个人页面头部高度和最大宽度
      final profileHeaderHeight = 176.0; // 与 profile_page.dart 中的 headerHeight 一致
      final profileMaxWidth = 520.0; // 与 profile_page.dart 中的 maxW 一致

      // 计算个人页面背景图的宽高比（水平填充）
      final aspectRatio = profileMaxWidth / profileHeaderHeight;

      final cropped = await _cropBytes(bytes, aspectRatio: aspectRatio);
      if (cropped == null) return;

      // 压缩到个人页面显示尺寸
      final preview = ImageUtils.resizeContainToJpeg(cropped, maxWidth: profileMaxWidth.toInt(), maxHeight: profileHeaderHeight.toInt());
      setState(() => _backdropPreview = preview);
      await _uploadBackdrop(preview);
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, prefix: '选择封面失败');
      }
    }
  }

// 修改 _cropBytes 方法中的界面高度计算
  Future<Uint8List?> _cropBytes(Uint8List bytes, {required double aspectRatio}) async {
    return showDialog<Uint8List>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(context).size.width;
        // 根据宽高比计算裁剪界面的高度
        final cropHeight = screenWidth / aspectRatio;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: screenWidth,
            height: cropHeight + 56, // 加上标题栏高度
            color: Colors.black,
            child: SafeArea(
              child: Column(
                children: [
                  // 标题栏
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('取消', style: TextStyle(color: Colors.white)),
                        ),
                        const Text('裁剪图片', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => _cropController.crop(),
                          child: const Text('完成', style: TextStyle(color: Colors.blue)),
                        ),
                      ],
                    ),
                  ),
                  // 裁剪区域 - 使用计算的高度
                  SizedBox(
                    width: screenWidth,
                    height: cropHeight,
                    child: Crop(
                      image: bytes,
                      controller: _cropController,
                      aspectRatio: aspectRatio,
                      onCropped: (data) {
                        Navigator.pop(ctx, data);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadAvatar(Uint8List bytes) async {
    setState(() => _uploadingAvatar = true);
    try {
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // Content-Type 可能为空，网关按 .jpg 扩展名兜底为 image/jpeg
      final mf = MultipartFile.fromBytes(bytes, filename: fileName);
      await _userApi.uploadAvatar(userId: _userId, avatarData: mf);

      // 更新本地缓存
      Hive.box('user_box').put('avatar', bytes);

      if (!mounted) return;

      // 刷新 ProfileProvider - 这里可能触发父组件的重建
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.load(userId: _userId);

      // 这里可能已经不在 mounted 状态
      if (mounted) {
        setState(() {
          _avatarUrl = UrlUtils.resolveStorageUrl(
            profileProvider.user?.avatarUrl,
            defaultDir: 'avatars',
          );
        });
        ErrorHandler.showSuccess(context, '头像已更新');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, prefix: '头像上传失败');
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _uploadBackdrop(Uint8List bytes) async {
    setState(() => _uploadingBackdrop = true);
    try {
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final mf = MultipartFile.fromBytes(bytes, filename: fileName);
      await _userApi.uploadProfileBackground(userId: _userId, backgroundData: mf);

      // 更新本地缓存
      Hive.box('user_box').put('backdrop', bytes);

      if (!mounted) return;

      // 刷新 ProfileProvider 以获取新的背景URL
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.load(userId: _userId);

      if (mounted) {
        ErrorHandler.showSuccess(context, '封面已更新');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, prefix: '封面上传失败');
      }
    } finally {
      if (mounted) setState(() => _uploadingBackdrop = false);
    }
  }
}