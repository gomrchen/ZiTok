import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'widgets/edit_field_dialog.dart';
import '../../models/user_models.dart'; // 导入用户模型以使用 Gender 枚举

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

  // 可编辑字段
  String _nickname = '哒哒哒哒对对对';
  String _bio = '介绍喜好、个性或@你的亲友';
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
        _bio = user.bio ?? '介绍喜好、个性或@你的亲友';
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

  @override
  void dispose() {
    // 移除监听器
    context.read<ProfileProvider>().removeListener(_onProfileChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerHeight = constraints.maxWidth * 0.36;
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: false,
                  floating: false,
                  snap: false,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 56,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: _buildHeader(context, headerHeight, cs),
                  expandedHeight: headerHeight,
                ),
                SliverToBoxAdapter(child: _buildInfoCard(context, cs)),
              ],
            );
          },
        ),
      ),
    );
  }

// 顶部头部（封面 + 头像）
  Widget _buildHeader(BuildContext context, double headerHeight, ColorScheme cs) {
    // 检查是否有背景图URL
    final profileProvider = context.read<ProfileProvider>();
    final user = profileProvider.user;
    final String? backdropUrl = user?.profileBackgroundImageUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景容器 - 支持预览图和网络图
        _buildHeaderBackground(headerHeight, backdropUrl),
        Positioned(
          top: Spacing.sm,
          left: Spacing.sm,
          child: _roundIcon(
            icon: Icons.arrow_back,
            onPressed: () => context.pop(),
          ),
        ),
        Positioned(
          top: Spacing.sm,
          right: Spacing.sm,
          child: _roundIcon(
            icon: Icons.camera_alt_outlined,
            onPressed: _uploadingBackdrop ? null : _onChangeBackdrop,
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAvatarButton(cs),
                  const SizedBox(height: Spacing.sm),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: _buildProgress(cs),
                  ),
                ],
              ),
            ),
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
    final double radius = 42;
    return Semantics(
      label: '更换头像',
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: InkWell(
          onTap: _uploadingAvatar ? null : _showAvatarPickerSheet,
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
              alignment: Alignment.center,
              children: [
                // 头像显示：优先显示预览图，其次显示网络头像，最后显示默认图标
                if (_avatarPreview != null)
                  Container(
                    width: radius * 2,
                    height: radius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2BD2C4),
                      image: DecorationImage(
                        image: MemoryImage(_avatarPreview!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  Container(
                    width: radius * 2,
                    height: radius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2BD2C4),
                      image: DecorationImage(
                        image: NetworkImage(_avatarUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: radius * 2,
                    height: radius * 2,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2BD2C4),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                // 覆盖层：相机图标和文字
                Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _uploadingAvatar ? Icons.hourglass_bottom : Icons.camera_alt,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _uploadingAvatar ? '上传中' : '更换头像',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }

  Widget _buildProgress(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: Radii.sm,
            child: LinearProgressIndicator(
              value: _completion / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.35),
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Text('资料完成度 $_completion%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
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
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: cs.primary),
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
          _item(title: '简介', value: _bio, titleStyle: titleStyle, valueStyle: valueStyle, onTap: _onEditBio),
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
    if (_birthday == null) return '生日当天会收到抖音的祝福';
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
    final v = await EditTextDialog.show(context, title: '编辑简介', initial: _bio, hint: '一句话介绍自己', maxLines: 3, maxLength: 80);
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
    // 简介非默认值：增加20分
    if (_bio.isNotEmpty && _bio != '介绍喜好、个性或@你的亲友') {
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

  // 统一半透明圆形 icon
  Widget _roundIcon({required IconData icon, required VoidCallback? onPressed}) {
    return Container(
      decoration: const ShapeDecoration(color: Color(0x33000000), shape: CircleBorder()),
      child: IconButton(
        iconSize: 22,
        splashRadius: 20,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
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
        _showError('选择头像失败：$e');
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
      _showError('选择封面失败：$e');
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
          _avatarUrl = profileProvider.user?.avatarUrl;
        });
        _showToast('头像已更新');
      }
    } catch (e) {
      if (mounted) {
        _showError('头像上传失败：$e');
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
        _showToast('封面已更新');
      }
    } catch (e) {
      if (mounted) {
        _showError('封面上传失败：$e');
      }
    } finally {
      if (mounted) setState(() => _uploadingBackdrop = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }
}