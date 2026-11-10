import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/messaging_provider.dart';
import '../../models/social_models.dart';
import '../home/shell_surface.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final Set<int> _selectedIds = {};
  List<Friend> _candidates = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mp = context.read<MessagingProvider>();
      // 与空态文案一致：仅互关好友可拉群
      setState(() => _candidates = List<Friend>.from(mp.mutualFriends));
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ShellSurface.showTip(context, l10n.createGroupNeedName);
      return;
    }
    if (_candidates.isEmpty) {
      ShellSurface.showTip(context, l10n.createGroupNoFriends);
      return;
    }
    if (_selectedIds.isEmpty) {
      ShellSurface.showTip(context, l10n.createGroupNeedMember);
      return;
    }

    final mp = context.read<MessagingProvider>();
    final msg = await mp.createGroupAction(name, _selectedIds.toList());
    if (!mounted) return;

    if (msg == 'OK') {
      Navigator.pop(context);
      ShellSurface.showTip(context, l10n.createGroupSuccess);
    } else {
      ShellSurface.showTip(context, l10n.createGroupFailed(msg));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ink = ShellSurface.inkOf(context);
    return AnnotatedRegion(
      value: ShellSurface.systemUiOf(context),
      child: Scaffold(
        backgroundColor: ShellSurface.canvasOf(context),
        appBar: ShellSurface.appBar(
          title: l10n.createGroupTitle,
          context: context,
          actions: [
            TextButton(
              onPressed: _submit,
              child: Text(
                l10n.createGroupAction,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ShellSurface.accent,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ShellSurface.pagePad,
                12,
                ShellSurface.pagePad,
                8,
              ),
              child: TextField(
                controller: _nameCtrl,
                style: TextStyle(color: ink, fontSize: 15),
                decoration: InputDecoration(
                  labelText: l10n.createGroupName,
                  hintText: l10n.createGroupNameHint,
                  labelStyle: TextStyle(color: ink.withValues(alpha: 0.55)),
                  hintStyle: TextStyle(color: ink.withValues(alpha: 0.28)),
                  prefixIcon: Icon(Icons.group_add_rounded, color: ShellSurface.mutedOf(context)),
                  filled: true,
                  fillColor: ShellSurface.cardOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: ShellSurface.lineOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: ShellSurface.lineOf(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: ShellSurface.coral, width: 1.4),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: ShellSurface.lineOf(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.createGroupSelectMembers(_selectedIds.length),
                  style: ShellSurface.captionOf(context).copyWith(fontSize: 13),
                ),
              ),
            ),
            Expanded(
              child: _candidates.isEmpty
                  ? Center(
                      child: Text(
                        l10n.createGroupNoFriends,
                        style: ShellSurface.captionOf(context).copyWith(fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _candidates.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, indent: 72, color: ShellSurface.lineOf(context)),
                      itemBuilder: (context, index) {
                        final friend = _candidates[index];
                        final fid = int.tryParse(friend.id) ?? 0;
                        final isSelected = _selectedIds.contains(fid);
                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: ShellSurface.accent,
                          checkColor: Colors.white,
                          side: BorderSide(color: ShellSurface.mutedOf(context)),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedIds.add(fid);
                              } else {
                                _selectedIds.remove(fid);
                              }
                            });
                          },
                          secondary: CircleAvatar(
                            backgroundColor: ShellSurface.cardOf(context),
                            backgroundImage: friend.avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(friend.avatarUrl)
                                : null,
                            child: friend.avatarUrl.isEmpty
                                ? Icon(Icons.person_rounded, color: ShellSurface.mutedOf(context))
                                : null,
                          ),
                          title: Text(
                            friend.name,
                            style: ShellSurface.bodyStrongOf(context),
                          ),
                          subtitle: Text(
                            l10n.userIdLabel(friend.id),
                            style: ShellSurface.captionOf(context),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
