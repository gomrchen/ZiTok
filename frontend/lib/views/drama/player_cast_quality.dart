import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'player_overlay.dart';

class VideoQualityOption {
  final String label;
  final String url;
  final bool isHls;
  /// media_kit 内部视频轨 id；非空时切轨不换 URL
  final String? trackId;
  const VideoQualityOption({
    required this.label,
    required this.url,
    this.isHls = false,
    this.trackId,
  });

  bool get isEngineTrack => trackId != null && trackId!.isNotEmpty;
}

/// 从主 URL + 可选 qualities 字段合成清晰度列表（兼容单地址）
List<VideoQualityOption> buildQualityOptions({
  required String primaryUrl,
  List<dynamic>? rawQualities,
}) {
  final out = <VideoQualityOption>[];
  if (rawQualities != null) {
    for (final e in rawQualities) {
      if (e is! Map) continue;
      final url = '${e['url'] ?? e['video_url'] ?? ''}'.trim();
      if (url.isEmpty) continue;
      final label = '${e['label'] ?? e['name'] ?? '清晰度'}'.trim();
      out.add(VideoQualityOption(
        label: label.isEmpty ? '清晰度' : label,
        url: url,
        isHls: url.toLowerCase().contains('m3u8'),
      ));
    }
  }
  if (out.isEmpty && primaryUrl.trim().isNotEmpty) {
    final u = primaryUrl.trim();
    final hls = u.toLowerCase().contains('m3u8');
    // 无真实多码率时只展示当前档，避免「高清/标清」同 URL 假切换
    out.add(VideoQualityOption(label: hls ? '自动 · HLS' : '自动', url: u, isHls: hls));
  }
  // 去重：同 URL 只保留第一条
  final seen = <String>{};
  out.retainWhere((e) => seen.add(e.url));
  return out;
}

Future<VideoQualityOption?> showQualitySheet(
  BuildContext context, {
  required List<VideoQualityOption> options,
  required String currentUrl,
  String? currentTrackId,
}) {
  return showModalBottomSheet<VideoQualityOption>(
    context: context,
    backgroundColor: const Color(0xFF16181F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('清晰度', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                options.length <= 1
                    ? '当前仅单一清晰度；多码率需 qualities 或 HLS 多轨'
                    : '可切换服务端码率源，或 media_kit 引擎轨',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final q in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(q.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    q.isEngineTrack
                        ? '引擎轨'
                        : (q.isHls ? 'HLS 源' : '渐进式源'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                  ),
                  trailing: (q.isEngineTrack
                          ? q.trackId == currentTrackId
                          : q.url == currentUrl)
                      ? const Icon(Icons.check_rounded, color: kPlayerAccent)
                      : null,
                  onTap: () => Navigator.pop(ctx, q),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// 投屏入口：AirPlay 引导 + 复制播放链接（外接投屏 App 过渡方案）
Future<void> showCastSheet(
  BuildContext context, {
  String playUrl = '',
  String deepLink = '',
}) {
  final url = playUrl.trim();
  final link = deepLink.trim();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF16181F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('投屏', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '系统级 Chromecast / DLNA 仍后置；可先复制链接到电视端 App',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.airplay_rounded, color: Colors.white),
                title: const Text('AirPlay / 控制中心投屏', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  '请从系统控制中心选择屏幕镜像或视频播放',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('请下拉控制中心使用 AirPlay / 屏幕镜像'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: url.isNotEmpty,
                leading: Icon(
                  Icons.link_rounded,
                  color: Colors.white.withValues(alpha: url.isEmpty ? 0.35 : 1),
                ),
                title: Text(
                  '复制播放链接',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: url.isEmpty ? 0.45 : 1),
                  ),
                ),
                subtitle: Text(
                  url.isEmpty ? '当前无可复制地址' : '用于电视 / 浏览器 / 第三方投屏 App',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                ),
                onTap: url.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (!context.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('播放链接已复制'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(milliseconds: 1400),
                          ),
                        );
                      },
              ),
              if (link.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.share_rounded, color: Colors.white),
                  title: const Text('复制打开链接', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    '好友用手机打开本集：zitok://…',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                  ),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('打开链接已复制'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(milliseconds: 1400),
                      ),
                    );
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cast_rounded, color: Colors.white.withValues(alpha: 0.55)),
                title: Text('Chromecast / DLNA', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                subtitle: Text(
                  '原生 SDK 后置接入中',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('可先「复制播放链接」到电视端 App'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
