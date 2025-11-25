import 'package:flutter/material.dart';
import '../../../theme/theme_tokens.dart';

class EditTextDialog extends StatelessWidget {
  final String title;
  final String initial;
  final String hint;
  final int maxLines;
  final int maxLength;

  const EditTextDialog({super.key, required this.title, required this.initial, required this.hint, this.maxLines = 1, this.maxLength = 40});

  static Future<String?> show(BuildContext context, {required String title, required String initial, required String hint, int maxLines = 1, int maxLength = 40}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EditTextDialog(title: title, initial: initial, hint: hint, maxLines: maxLines, maxLength: maxLength),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: initial);
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            maxLength: maxLength,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('保存')),
      ],
    );
  }
}

class GenderSelectDialog extends StatelessWidget {
  final int? value;
  const GenderSelectDialog({super.key, required this.value});

  static Future<int?> show(BuildContext context, {required int? value}) {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => GenderSelectDialog(value: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    int? current = value;
    return AlertDialog(
      title: const Text('选择性别'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<int>(
              title: const Text('男'),
              value: 1, // 改为1
              groupValue: current,
              onChanged: (v) => Navigator.pop(context, v)
          ),
          RadioListTile<int>(
              title: const Text('女'),
              value: 2, // 改为2
              groupValue: current,
              onChanged: (v) => Navigator.pop(context, v)
          ),
          RadioListTile<int>(
              title: const Text('不显示'),
              value: 3,
              groupValue: current ?? 0,
              onChanged: (v) => Navigator.pop(context, v) // 直接返回v，不是null
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')
        ),
      ],
    );
  }
}