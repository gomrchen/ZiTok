import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

/// 轻量封装：高级视频播放器组件
/// - 支持全屏（Chewie 内置）
/// - 支持进度、暂停/播放控制（Chewie 内置控件）
/// - 支持音量调节（简单级：循环 0/50%/100%）
/// - 支持清晰度切换（传入多个源时切换）
/// - 尺寸自适应容器宽度（16:9 默认比）
class AdvancedVideoPlayer extends StatefulWidget {
  final List<VideoSource> sources;
  final String? initialLabel;
  final bool autoPlay;
  final bool looping;
  final VoidCallback? onBack; // 可选返回回调
  final VoidCallback? onInitialized;

  const AdvancedVideoPlayer({
    super.key,
    required this.sources,
    this.initialLabel,
    this.autoPlay = true,
    this.looping = false,
    this.onBack,
    this.onInitialized,
  });

  @override
  State<AdvancedVideoPlayer> createState() => _AdvancedVideoPlayerState();
}

class _AdvancedVideoPlayerState extends State<AdvancedVideoPlayer> {
  VideoPlayerController? _vp;
  ChewieController? _chewie;
  late String _currentLabel;
  double _volume = 1.0;
  String? _error;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    _currentLabel = widget.initialLabel ?? widget.sources.first.label;
    _setupController(_currentSourceByLabel(_currentLabel));
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _vp?.dispose();
    super.dispose();
  }

  VideoSource _currentSourceByLabel(String label) {
    return widget.sources.firstWhere((s) => s.label == label, orElse: () => widget.sources.first);
  }

  Future<void> _setupController(VideoSource src) async {
    final oldVp = _vp;
    final oldChewie = _chewie;
    _error = null;
    setState(() {});
    // 探测资源可达性（Range: bytes=0-1）
    _probing = true;
    try {
      final ok = await _probeUrl(src.url);
      debugPrint('AdvancedVideoPlayer: probe ${src.url} ok=$ok');
      if (!ok) {
        _error = '视频资源不可访问';
        _probing = false;
        setState(() {});
        return;
      }
    } catch (e) {
      debugPrint('AdvancedVideoPlayer: probe error $e');
    } finally {
      _probing = false;
    }
    _vp = VideoPlayerController.networkUrl(Uri.parse(src.url));
    try {
      await _vp!.initialize();
    } catch (e) {
      debugPrint('AdvancedVideoPlayer: initialize error $e');
      _error = '播放器初始化失败';
      setState(() {});
      oldChewie?.dispose();
      oldVp?.dispose();
      return;
    }
    _vp!.setLooping(widget.looping);
    _vp!.setVolume(_volume);
    _chewie = ChewieController(
      videoPlayerController: _vp!,
      autoPlay: widget.autoPlay,
      looping: widget.looping,
      allowFullScreen: true,
      showControlsOnInitialize: true,
      allowedScreenSleep: false,
    );
    setState(() {});
    if (widget.onInitialized != null) widget.onInitialized!();
    // 清理旧实例，避免内存泄漏
    oldChewie?.dispose();
    oldVp?.dispose();
  }

  Future<bool> _probeUrl(String url) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(url);
      final req = await client.getUrl(uri);
      req.headers.add('Range', 'bytes=0-1');
      final resp = await req.close();
      return resp.statusCode == 200 || resp.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  void _switchQuality(String label) async {
    if (label == _currentLabel) return;
    _currentLabel = label;
    await _setupController(_currentSourceByLabel(label));
  }

  void _cycleVolume() {
    // 在 0 → 0.5 → 1.0 间循环切换
    const levels = [0.0, 0.5, 1.0];
    final idx = levels.indexWhere((v) => (v - _volume).abs() < 0.01);
    final next = levels[(idx + 1) % levels.length];
    _volume = next;
    _vp?.setVolume(_volume);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _chewie;
    // 自适应：默认 16:9，高度以容器宽度计算
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final ratio = (_vp?.value.isInitialized ?? false) ? _vp!.value.aspectRatio : (16 / 9);
        final h = w / ratio;
        return Stack(
          alignment: Alignment.topRight,
          children: [
            SizedBox(
              width: w,
              height: h,
              child: () {
                if (_error != null) {
                  return Center(child: Text(_error!, style: const TextStyle(color: Colors.white)));
                }
                if (ctrl == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Chewie(controller: ctrl);
              }(),
            ),
            // 左上角：返回按钮（圆形、半透明、48x48 点击区域）
            Positioned(
              left: 8,
              top: 8,
              child: Tooltip(
                message: '返回',
                child: Semantics(
                  button: true,
                  label: '返回',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        debugPrint('AdvancedVideoPlayer: back pressed');
                        // 优先使用外部回调；否则尝试页面返回
                        if (widget.onBack != null) {
                          debugPrint('AdvancedVideoPlayer: delegate to external onBack');
                          widget.onBack!();
                          return;
                        }
                        final popped = await Navigator.of(context).maybePop();
                        debugPrint('AdvancedVideoPlayer: Navigator.maybePop result=$popped');
                        if (!popped) {
                          debugPrint('AdvancedVideoPlayer: no route to pop');
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 右上角：清晰度按钮（移除音量按钮）
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                children: [
                  if (widget.sources.length > 1)
                    Container(
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: PopupMenuButton<String>(
                        tooltip: '清晰度',
                        onSelected: _switchQuality,
                        initialValue: _currentLabel,
                        itemBuilder: (_) => [
                          for (final s in widget.sources)
                            PopupMenuItem<String>(value: s.label, child: Text(s.label)),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(_currentLabel, style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class VideoSource {
  final String label; // 如：480p/720p/原画
  final String url;
  const VideoSource({required this.label, required this.url});
}
