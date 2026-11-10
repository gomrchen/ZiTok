import 'package:flutter/material.dart';

import '../../../l10n/l10n_ext.dart';
import '../../home/shell_surface.dart';

class EditTextDialog extends StatelessWidget {
  final String title;
  final String initial;
  final String hint;
  final int maxLines;
  final int maxLength;

  const EditTextDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.hint,
    this.maxLines = 1,
    this.maxLength = 40,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String initial,
    required String hint,
    int maxLines = 1,
    int maxLength = 40,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EditTextDialog(
        title: title,
        initial: initial,
        hint: hint,
        maxLines: maxLines,
        maxLength: maxLength,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: initial);
    final ink = ShellSurface.inkOf(context);
    final l10n = context.l10n;
    return ShellSurface.dialog(
      context: context,
      title: title,
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            maxLength: maxLength,
            style: TextStyle(color: ink, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: ink.withValues(alpha: 0.35)),
              filled: true,
              fillColor: ShellSurface.canvasOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ShellSurface.lineOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ShellSurface.lineOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ShellSurface.coral, width: 1.4),
              ),
            ),
          ),
        ),
      ),
      actions: [
        ShellSurface.cancelAction(
          context,
          onPressed: () => Navigator.pop(context),
          label: l10n.commonCancel,
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: ShellSurface.coral),
          child: Text(l10n.commonSave),
        ),
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
    final l10n = context.l10n;
    return ShellSurface.dialog(
      context: context,
      title: l10n.dialogSelectGender,
      content: StatefulBuilder(
        builder: (context, setState) {
          return RadioGroup<int>(
            groupValue: current,
            onChanged: (v) {
              setState(() => current = v);
              Navigator.pop(context, v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<int>(title: Text(l10n.dialogGenderMale), value: 1),
                RadioListTile<int>(title: Text(l10n.dialogGenderFemale), value: 2),
                RadioListTile<int>(title: Text(l10n.dialogGenderHidden), value: 3),
              ],
            ),
          );
        },
      ),
      actions: [
        ShellSurface.cancelAction(
          context,
          onPressed: () => Navigator.pop(context),
          label: l10n.commonCancel,
        ),
      ],
    );
  }
}
