import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../providers/theme_provider.dart';
import '../../theme/theme_tokens.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  DateTime? _birthday;
  String? _country;
  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('user_box');
    _nicknameCtrl.text = box.get('nickname', defaultValue: '安东尼没有绿山墙');
    _bioCtrl.text = box.get('bio', defaultValue: '');
    _phoneCtrl.text = box.get('phone', defaultValue: '1023044583');
    _jobCtrl.text = box.get('job', defaultValue: '室内设计师');
    final int? ts = box.get('birthday');
    _birthday = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
    _country = box.get('country', defaultValue: 'China');
    final List<int>? bytes = box.get('avatar_bytes');
    if (bytes != null) _avatarBytes = Uint8List.fromList(bytes);
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _phoneCtrl.dispose();
    _jobCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final box = Hive.box('user_box');
    await box.put('nickname', _nicknameCtrl.text.trim());
    await box.put('bio', _bioCtrl.text.trim());
    await box.put('phone', _phoneCtrl.text.trim());
    await box.put('job', _jobCtrl.text.trim());
    await box.put('birthday', _birthday?.millisecondsSinceEpoch);
    await box.put('country', _country);
    if (_avatarBytes != null) await box.put('avatar_bytes', _avatarBytes!.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: constraints.maxWidth > 520 ? 520 : constraints.maxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                              child: _avatarBytes == null ? const Icon(Icons.person, size: 40) : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Semantics(
                                label: '上传头像',
                                button: true,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt),
                                  onPressed: _pickAvatar,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      TextFormField(
                        controller: _nicknameCtrl,
                        decoration: const InputDecoration(labelText: '昵称'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? '请输入昵称' : null,
                      ),
                      const SizedBox(height: Spacing.md),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: '手机号'),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return '请输入手机号';
                          if (s.length < 7) return '手机号格式不正确';
                          return null;
                        },
                      ),
                      const SizedBox(height: Spacing.md),
                      TextFormField(
                        controller: _jobCtrl,
                        decoration: const InputDecoration(labelText: '职位'),
                      ),
                      const SizedBox(height: Spacing.md),
                      _BirthdayField(
                        value: _birthday,
                        onChanged: (d) => setState(() => _birthday = d),
                      ),
                      const SizedBox(height: Spacing.md),
                      _CountryField(
                        value: _country,
                        onChanged: (c) => setState(() => _country = c),
                      ),
                      const SizedBox(height: Spacing.md),
                      TextFormField(
                        controller: _bioCtrl,
                        decoration: const InputDecoration(labelText: '简介'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: Spacing.lg),
                      FilledButton(
                        onPressed: _save,
                        child: const Text('保存更改'),
                      ),
                      const SizedBox(height: Spacing.md),
                      Row(
                        children: [
                          const Text('主题'),
                          const SizedBox(width: Spacing.md),
                          FilledButton(
                            onPressed: () => context.read<ThemeProvider>().toggleDark(),
                            child: const Text('切换明暗'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BirthdayField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const _BirthdayField({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final txt = value == null ? '选择日期' : '${value!.year}/${value!.month}/${value!.day}';
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final res = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(now.year - 20, 1, 1),
          firstDate: DateTime(1900),
          lastDate: now,
        );
        onChanged(res);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: '出生日期'),
        child: Text(txt),
      ),
    );
  }
}

class _CountryField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _CountryField({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    const countries = ['China', 'Nigeria', 'USA', 'UK'];
    return DropdownButtonFormField<String>(
      initialValue: value ?? countries.first,
      items: countries.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(labelText: '国家/地区'),
    );
  }
}