import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/video/video_performance_monitor.dart';
import 'video_visibility_handler.dart';

/// 优化的视频播放器组件
///
/// 特性：
/// - 智能预加载
/// - 自动暂停/恢复（页面不可见时）
/// - 缓冲状态显示
/// - 加载状态显示
/// - 错误重试
/// - 手势控制
class OptimizedVideoPlayer extends StatefulWidget {
  final String videoId;
  final String videoUrl;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final VoidCallback? onBack;
  final VoidCallback? onTap;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedVideoPlayer({
    super.key,
    required this.videoId,
    required this.videoUrl,
    this.autoPlay = true,
    this.looping = true,
    this.showControls = true,
    this.onBack,
    this.onTap,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<OptimizedVideoPlayer> createState() => _OptimizedVideoPlayerState();
}

class _OptimizedVideoPlayerState extends State<OptimizedVideoPlayer>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasError = false;
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _showControlsOverlay = false;
  late AnimationController _controlsAnimationController;

  final VideoPerformanceMonitor _monitor = VideoPerformanceMonitor.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controlsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializePlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsAnimationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseIfPlaying();
    }
  }

  @override
  void didUpdateWidget(OptimizedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isInitialized = false;
      _hasError = false;
      _errorMessage = null;
    });

    _monitor.recordLoadStart(widget.videoId);

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

      _controller!.addListener(_onControllerUpdate);

      await _controller!.initialize();

      if (!mounted) return;

      _monitor.recordFirstFrame(widget.videoId);

      setState(() {
        _isInitialized = true;
        _duration = _controller!.value.duration;
      });

      if (widget.looping) {
        await _controller!.setLooping(true);
      }

      if (widget.autoPlay) {
        await _controller!.play();
        _monitor.recordPlayStart(widget.videoId);
      }
    } catch (e) {
      _monitor.recordLoadError(widget.videoId, e.toString());
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '视频加载失败';
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null) return;

    final value = _controller!.value;

    setState(() {
      _position = value.position;
      _isPlaying = value.isPlaying;

      // 检测缓冲状态
      final wasBuffering = _isBuffering;
      _isBuffering = value.isBuffering;

      if (_isBuffering && !wasBuffering) {
        _monitor.recordBufferingStart(widget.videoId);
      } else if (!_isBuffering && wasBuffering) {
        _monitor.recordBufferingEnd(widget.videoId);
      }

      // 检测错误
      if (value.hasError) {
        _hasError = true;
        _errorMessage = value.errorDescription ?? '播放错误';
        _monitor.recordError(widget.videoId, _errorMessage!);
      }
    });
  }

  void _pauseIfPlaying() {
    if (_controller?.value.isPlaying ?? false) {
      _controller!.pause();
      _monitor.recordPlayPause(widget.videoId);
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _monitor.recordPlayPause(widget.videoId);
    } else {
      _controller!.play();
      _monitor.recordPlayResume(widget.videoId);
    }
  }

  void _toggleControls() {
    setState(() {
      _showControlsOverlay = !_showControlsOverlay;
    });

    if (_showControlsOverlay) {
      _controlsAnimationController.forward();
      // 3秒后自动隐藏
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _showControlsOverlay && _isPlaying) {
          setState(() => _showControlsOverlay = false);
          _controlsAnimationController.reverse();
        }
      });
    } else {
      _controlsAnimationController.reverse();
    }
  }

  Future<void> _retry() async {
    await _controller?.dispose();
    await _initializePlayer();
  }

  @override
  Widget build(BuildContext context) {
    return VideoVisibilityWrapper(
      onBecameVisible: () {
        if (widget.autoPlay && _isInitialized && !_isPlaying) {
          _controller?.play();
        }
      },
      onBecameHidden: _pauseIfPlaying,
      child: GestureDetector(
        onTap: () {
          if (widget.onTap != null) {
            widget.onTap!();
          } else {
            _toggleControls();
          }
        },
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 视频层
              _buildVideoLayer(),

              // 缓冲指示器
              if (_isBuffering && _isInitialized) _buildBufferingIndicator(),

              // 加载指示器
              if (!_isInitialized && !_hasError) _buildLoadingIndicator(),

              // 错误层
              if (_hasError) _buildErrorLayer(),

              // 控制层
              if (widget.showControls && _isInitialized && !_hasError)
                AnimatedOpacity(
                  opacity: _showControlsOverlay ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildControlsOverlay(),
                ),

              // 返回按钮
              if (widget.onBack != null) _buildBackButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    if (!_isInitialized || _controller == null) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            SizedBox(height: 12),
            Text(
              '缓冲中...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              '加载中...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorLayer() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? '视频加载失败',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 中央播放/暂停按钮
          Expanded(
            child: Center(
              child: IconButton(
                iconSize: 64,
                onPressed: _togglePlayPause,
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // 底部进度条和时间
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // 进度条
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble(),
                    max: _duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                    onChanged: (value) {
                      final position = Duration(milliseconds: value.toInt());
                      _controller?.seekTo(position);
                      _monitor.recordSeek(widget.videoId, _position, position);
                    },
                  ),
                ),

                // 时间显示
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      left: 8,
      top: MediaQuery.of(context).padding.top + 8,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: widget.onBack,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
