import 'dart:typed_data';
import 'dart:io';
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

/// 编辑资料页
/// - 贴合设计图效果：顶部可更换封面、头像圆形按钮、资料完成度
/// - 支持头像相册/拍照选择、裁剪为 1:1、压缩到 200x200 并上传
/// - 支持背景图相册选择、裁剪为头部区域比例、完整显示与上传
/// - 上传使用 multipart/form-data，处理加载状态与错误提示
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
  Uint8List? _avatarPreview; // 压缩后的 200x200 头像
  Uint8List? _backdropPreview; // 头部背景展示图（保持比例）

  // Loading 状态
  bool _uploadingAvatar = false;
  bool _uploadingBackdrop = false;

  // 资料完成度（简单根据字段是否存在演示）
  int _completion = 40; // 默认与设计图一致

  // 可编辑字段（使用 Hive 持久化）
  String _nickname = '哒哒哒哒对对对';
  String _bio = '介绍喜好、个性或@你的亲友';
  int? _gender; // 0 男 1 女 null 未设置
  DateTime? _birthday;


  // 便捷：当前用户 ID
  String get _userId => context.read<AuthProvider>().user?.id ?? '0';

  UserService get _userApi => widget.userService ?? UserService(AppBootstrap.apiClient.dio);

  @override
  void dispose() {
    // CropController 无需显式释放
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
            final headerHeight = constraints.maxWidth * 0.36; // 响应式头部高度，贴近图示比例
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景：若有预览图则显示，否则展示设计接近的青绿渐变
        Container(
          height: headerHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2ED3BE), Color(0xFF1AAE9A)],
            ),
            image: _backdropPreview == null
                ? null
                : DecorationImage(
                    image: MemoryImage(_backdropPreview!),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        // 左上角返回 icon（半透明背景）
        Positioned(
          top: Spacing.sm,
          left: Spacing.sm,
          child: _roundIcon(
            icon: Icons.arrow_back,
            onPressed: () => context.pop(),
          ),
        ),
        // 右上角替换封面 icon（半透明背景）
        Positioned(
          top: Spacing.sm,
          right: Spacing.sm,
          child: _roundIcon(
            icon: Icons.camera_alt_outlined,
            onPressed: _uploadingBackdrop ? null : _onChangeBackdrop,
          ),
        ),
        // 底部居中：头像与完成度条
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

  Widget _buildAvatarButton(ColorScheme cs) {
    final double radius = 42; // 贴近图四比例
    return Semantics(
      label: '更换头像',
      child: InkWell(
        onTap: _uploadingAvatar ? null : _showAvatarPickerSheet,
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: const Color(0xFF2BD2C4),
              backgroundImage: _avatarPreview != null ? MemoryImage(_avatarPreview!) : null,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_uploadingAvatar ? Icons.hourglass_bottom : Icons.camera_alt, color: Colors.white, size: 22),
                const SizedBox(height: 4),
                Text(_uploadingAvatar ? '上传中' : '更换头像', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
              ],
            ),
          ],
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
              backgroundColor: Colors.white.withOpacity(0.35),
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 顶部提示行
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
          _item(title: '名字', value: _nickname, titleStyle: titleStyle, valueStyle: highlightValueStyle, onTap: _onEditName),
          _item(title: '简介', value: _bio, titleStyle: titleStyle, valueStyle: valueStyle, onTap: _onEditBio),
          _item(title: '性别', value: _genderText(), titleStyle: titleStyle, valueStyle: valueStyle, onTap: _onEditGender),
          _item(title: '生日', value: _birthdayText(), titleStyle: titleStyle, valueStyle: valueStyle, onTap: _onEditBirthday),
          const SizedBox(height: Spacing.lg),
        ],
      ),
    );
  }

  Widget _item({required String title, required String value, TextStyle? titleStyle, TextStyle? valueStyle, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.md),
      child: InkWell(
        onTap: onTap,
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
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  String _nickNameFromBox() => Hive.box('user_box').get('nickname', defaultValue: '哒哒哒哒对对对');
  String _bioFromBox() => Hive.box('user_box').get('bio', defaultValue: '介绍喜好、个性或@你的亲友');

  // 文本编辑通用弹窗
  // 废弃 BottomSheet 改为 Dialog 方案，避免布局异常

  // 各字段编辑入口
  Future<void> _onEditName() async {
    final v = await EditTextDialog.show(context, title: '编辑名字', initial: _nickname, hint: '请输入2-20个字符', maxLength: 20);
    if (v != null && v.isNotEmpty && v.length >= 2) {
      setState(() => _nickname = v);
      Hive.box('user_box').put('nickname', v);
      context.read<ProfileProvider>().debounceUpdateInfo(username: v);
      _recalcCompletion();
    } else if (v != null) {
      _showError('名字长度需≥2');
    }
  }

  Future<void> _onEditBio() async {
    final v = await EditTextDialog.show(context, title: '编辑简介', initial: _bio, hint: '一句话介绍自己', maxLines: 3, maxLength: 80);
    if (v != null) {
      setState(() => _bio = v);
      Hive.box('user_box').put('bio', v);
      context.read<ProfileProvider>().debounceUpdateInfo(signature: v);
      _recalcCompletion();
    }
  }

  String _genderText() {
    switch (_gender) {
      case 0:
        return '男';
      case 1:
        return '女';
      default:
        return '选择性别，表达自我';
    }
  }

  Future<void> _onEditGender() async {
    final v = await GenderSelectDialog.show(context, value: _gender);
    setState(() => _gender = v);
    Hive.box('user_box').put('gender', v);
    context.read<ProfileProvider>().debounceUpdateInfo(gender: v);
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
      context.read<ProfileProvider>().debounceUpdateInfo(birthday: ymd);
      _recalcCompletion();
    }
  }



  void _recalcCompletion() {
    int score = 40;
    if (_nickname.isNotEmpty) score += 10;
    if (_bio.isNotEmpty) score += 10;
    if (_gender != null) score += 10;
    if (_birthday != null) score += 10;
    // 已移除：所在地对完成度的加分
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
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();

      // 裁剪为 1:1
      final cropped = await _cropBytes(bytes, aspectRatio: 1.0);
      if (cropped == null) return;
      // 压缩到 200x200
      final compressed = ImageUtils.resizeToJpeg(cropped, width: 200, height: 200);
      setState(() => _avatarPreview = compressed);
      await _uploadAvatar(compressed);
    } catch (e) {
      _showError('选择头像失败：$e');
    }
  }

  Future<void> _onChangeBackdrop() async {
    try {
      final xFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2400, maxHeight: 2400, imageQuality: 95);
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();

      // 按照头部区域比例裁剪：以设备当前宽高比为准，近似 16:9~21:9 的横幅
      final size = MediaQuery.of(context).size;
      final aspect = size.width / 200.0; // headerHeight = 200，对应横幅比例
      final cropped = await _cropBytes(bytes, aspectRatio: aspect.clamp(2.0, 4.0));
      if (cropped == null) return;
      // 为避免大图占用内存，限制最大宽高，保持比例
      final preview = ImageUtils.resizeContainToJpeg(cropped, maxWidth: 1920, maxHeight: 1080);
      setState(() => _backdropPreview = preview);
      await _uploadBackdrop(preview);
    } catch (e) {
      _showError('选择封面失败：$e');
    }
  }

  Future<Uint8List?> _cropBytes(Uint8List bytes, {required double aspectRatio}) async {
    return showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        Uint8List? result;
        return SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Crop(
                  image: bytes,
                  controller: _cropController,
                  aspectRatio: aspectRatio,
                  onCropped: (data) {
                    result = data;
                    Navigator.pop(ctx, result);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('取消')),
                    FilledButton(onPressed: () => _cropController.crop(), child: const Text('完成裁剪')),
                  ],
                ),
              ),
            ],
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
      // 更新本地缓存，立即显示
      Hive.box('user_box').put('avatar', bytes);
      _showToast('头像已更新');
    } catch (e) {
      _showError('头像上传失败：$e');
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
      Hive.box('user_box').put('backdrop', bytes);
      _showToast('封面已更新');
    } catch (e) {
      _showError('封面上传失败：$e');
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