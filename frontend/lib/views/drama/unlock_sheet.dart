import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';

/// 探测已解锁集（限量并发探测，避免详情/选集重复实现）
Future<Set<int>> probeUnlockedEpisodeIds(
  DramaProvider dp,
  List<Episode> episodes, {
  int limit = 12,
}) async {
  final unlocked = <int>{};
  for (final ep in episodes.where((e) => !e.isFree).take(limit)) {
    final info = await dp.loadPlayInfo(ep.id);
    if (info != null && !info.locked) unlocked.add(ep.id);
  }
  return unlocked;
}

Future<bool?> showUnlockSheet(
  BuildContext context, {
  required int episodeId,
  required int unlockPrice,
  int? bundlePrice,
  int? dramaId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.grey.shade900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _UnlockSheetBody(
      episodeId: episodeId,
      unlockPrice: unlockPrice,
      bundlePrice: bundlePrice,
      dramaId: dramaId,
    ),
  );
}

class _UnlockSheetBody extends StatefulWidget {
  final int episodeId;
  final int unlockPrice;
  final int? bundlePrice;
  final int? dramaId;

  const _UnlockSheetBody({
    required this.episodeId,
    required this.unlockPrice,
    this.bundlePrice,
    this.dramaId,
  });

  @override
  State<_UnlockSheetBody> createState() => _UnlockSheetBodyState();
}

class _UnlockSheetBodyState extends State<_UnlockSheetBody> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<bool> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await action();
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = '操作失败，请稍后重试');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '操作失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DramaProvider>();
    final bal = dp.wallet?.balance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('本集需解锁后观看', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            bal == null ? '登录后可用金币解锁或看广告免费解锁' : '当前金币：$bal',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() => dp.unlockEpisode(widget.episodeId)),
            child: Text('金币解锁（${widget.unlockPrice}）'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      // Mock 广告：稍等再回调成功
                      await Future<void>.delayed(const Duration(milliseconds: 800));
                      return dp.adUnlock(widget.episodeId);
                    }),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('看广告免费解锁（24h）'),
          ),
          if (widget.dramaId != null && (widget.bundlePrice ?? 0) > 0) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final resp = await dp.commerceService.unlockDrama(widget.dramaId!);
                        final code = resp.data is Map ? resp.data['code'] : null;
                        final ok = '$code' == '10000';
                        if (ok) await dp.refreshWallet();
                        return ok;
                      }),
              child: Text('整剧解锁（${widget.bundlePrice} 金币）', style: const TextStyle(color: Colors.amberAccent)),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    await dp.mockTopup(100);
                    if (mounted) setState(() {});
                  },
            child: const Text('Mock 充值 +100', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
