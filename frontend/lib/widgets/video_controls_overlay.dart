import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// 自定义视频控制层 - 覆盖在视频上方，不影响视频区域大小
///
/// 功能：
/// - 播放/暂停
/// - 进度条拖动
/// - 音量调节（右侧滑动）
/// - 亮度调节（左侧滑动）
/// - 倍速选择
/// - 全屏切换
/// - 视频完结重播
/// - 5秒自动隐藏
class VideoControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback? onBack;
  final VoidCallback? onFullscreenToggle;
  final bool isFullscreen;
  final String? title;

  const VideoControlsOverlay({
    super.key,
    required this.controller,
    this.onBack,
    this.onFullscreenToggle,
    this.isFullscreen = false,
    this.title,
  });

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay>
    with SingleTickerProviderStateMixin {
  bool _showControls = true;
  bool _isDraggingProgress = false;
  bool _isDraggingVolume = false;
  bool _isDraggingBrightness = false;

  Timer? _hideTimer;
  double _currentVolume = 1.0;
  double _currentBrightness = 0.5;
  double _playbackSpeed = 1.0;

  // 进度条拖动
  double _dragProgress = 0.0;

  // 动画控制器
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // 可用倍速选项
  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();

    widget.controller.addListener(_onVideoStateChanged);
    _initBrightness();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animController.dispose();
    widget.controller.removeListener(_onVideoStateChanged);
    super.dispose();
  }

  Future<void> _initBrightness() async {
    try {
      _currentBrightness = await ScreenBrightness().application;
    } catch (_) {
      _currentBrightness = 0.5;
    }
  }

  void _onVideoStateChanged() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (widget.controller.value.isPlaying && !_isDraggingProgress) {
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && widget.controller.value.isPlaying) {
          setState(() => _showControls = false);
          _animController.reverse();
        }
      });
    }
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
  }

  void _showControlsAndResetTimer() {
    setState(() => _showControls = true);
    _animController.forward();
    _startHideTimer();
  }

  void _toggleControls() {
    if (_showControls) {
      setState(() => _showControls = false);
      _animController.reverse();
      _cancelHideTimer();
    } else {
      _showControlsAndResetTimer();
    }
  }

  void _togglePlayPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
      _cancelHideTimer();
    } else {
      widget.controller.play();
      _startHideTimer();
    }
    setState(() {});
  }

  void _replay() {
    widget.controller.seekTo(Duration.zero);
    widget.controller.play();
    _showControlsAndResetTimer();
  }

  Future<void> _setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    await widget.controller.setVolume(_currentVolume);
    setState(() {});
  }

  Future<void> _setBrightness(double brightness) async {
    _currentBrightness = brightness.clamp(0.0, 1.0);
    try {
      await ScreenBrightness().setApplicationScreenBrightness(_currentBrightness);
    } catch (_) {}
    setState(() {});
  }

  void _setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    widget.controller.setPlaybackSpeed(speed);
    setState(() {});
    _showControlsAndResetTimer();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _cancelHideTimer();
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    if (duration.inMilliseconds > 0) {
      _dragProgress = position.inMilliseconds / duration.inMilliseconds;
      setState(() => _isDraggingProgress = true);
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double width) {
    if (!_isDraggingProgress) return;
    final delta = details.delta.dx / width;
    _dragProgress = (_dragProgress + delta).clamp(0.0, 1.0);
    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDraggingProgress) return;
    final duration = widget.controller.value.duration;
    final newPosition = Duration(
      milliseconds: (_dragProgress * duration.inMilliseconds).toInt(),
    );
    widget.controller.seekTo(newPosition);
    setState(() => _isDraggingProgress = false);
    _startHideTimer();
  }

  void _onVerticalDragStart(DragStartDetails details, double width) {
    _cancelHideTimer();
    final isLeftSide = details.localPosition.dx < width / 2;
    if (isLeftSide) {
      _isDraggingBrightness = true;
    } else {
      _isDraggingVolume = true;
    }
    setState(() {});
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, double height) {
    // 向上滑动增加，向下滑动减少
    final delta = -details.delta.dy / height;

    if (_isDraggingBrightness) {
      _setBrightness(_currentBrightness + delta);
    } else if (_isDraggingVolume) {
      _setVolume(_currentVolume + delta);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _isDraggingBrightness = false;
    _isDraggingVolume = false;
    setState(() {});
    _startHideTimer();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final isPlaying = value.isPlaying;
    final isBuffering = value.isBuffering;
    final isEnded = value.position >= value.duration && value.duration.inSeconds > 0;
    final position = _isDraggingProgress
        ? Duration(milliseconds: (_dragProgress * value.duration.inMilliseconds).toInt())
        : value.position;
    final duration = value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return GestureDetector(
          onTap: _toggleControls,
          onDoubleTap: _togglePlayPause,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, width),
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onVerticalDragStart: (d) => _onVerticalDragStart(d, width),
          onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, height),
          onVerticalDragEnd: _onVerticalDragEnd,
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 缓冲指示器
                if (isBuffering)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),

                // 视频结束重播按钮
                if (isEnded && !isBuffering)
                  Center(
                    child: _buildIconButton(
                      icon: Icons.replay,
                      size: 64,
                      onTap: _replay,
                      tooltip: '重播',
                    ),
                  ),

                // 音量/亮度调节指示器
                if (_isDraggingVolume || _isDraggingBrightness)
                  Center(
                    child: _buildAdjustIndicator(
                      icon: _isDraggingVolume ? Icons.volume_up : Icons.brightness_6,
                      value: _isDraggingVolume ? _currentVolume : _currentBrightness,
                      label: _isDraggingVolume ? '音量' : '亮度',
                    ),
                  ),

                // 控制层
                if (_showControls && !isEnded)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x80000000),
                            Colors.transparent,
                            Colors.transparent,
                            Color(0x80000000),
                          ],
                          stops: [0.0, 0.2, 0.8, 1.0],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // 顶部栏
                          _buildTopBar(),

                          // 中央播放按钮
                          if (!isBuffering)
                            Center(
                              child: _buildIconButton(
                                icon: isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 56,
                                onTap: _togglePlayPause,
                                tooltip: isPlaying ? '暂停' : '播放',
                              ),
                            ),

                          // 底部栏
                          _buildBottomBar(position, duration, progress),
                        ],
                      ),
                    ),
                  ),

                // 进度条拖动时的时间显示
                if (_isDraggingProgress)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // 返回按钮
              _buildIconButton(
                icon: Icons.arrow_back,
                onTap: widget.onBack,
                tooltip: '返回',
              ),
              const SizedBox(width: 8),
              // 标题
              if (widget.title != null)
                Expanded(
                  child: Text(
                    widget.title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Duration position, Duration duration, double progress) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              _buildProgressBar(progress),
              const SizedBox(height: 4),
              // 控制按钮行
              Row(
                children: [
                  // 时间显示
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const Spacer(),
                  // 倍速按钮
                  _buildSpeedButton(),
                  const SizedBox(width: 8),
                  // 全屏按钮
                  _buildIconButton(
                    icon: widget.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    onTap: widget.onFullscreenToggle,
                    tooltip: widget.isFullscreen ? '退出全屏' : '全屏',
                    size: 28,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, MediaQuery.of(context).size.width),
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Container(
        height: 20,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // 背景轨道
            Container(
              height: _isDraggingProgress ? 4 : 2,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 缓冲进度
            FractionallySizedBox(
              widthFactor: widget.controller.value.buffered.isNotEmpty
                  ? widget.controller.value.buffered.last.end.inMilliseconds /
                      widget.controller.value.duration.inMilliseconds
                  : 0.0,
              child: Container(
                height: _isDraggingProgress ? 4 : 2,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 播放进度
            FractionallySizedBox(
              widthFactor: _isDraggingProgress ? _dragProgress : progress,
              child: Container(
                height: _isDraggingProgress ? 4 : 2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 拖动指示器
            if (_isDraggingProgress)
              Positioned(
                left: (_isDraggingProgress ? _dragProgress : progress) *
                    (MediaQuery.of(context).size.width - 32) - 6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedButton() {
    return GestureDetector(
      onTap: () => _showSpeedDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  void _showSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '播放速度',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _speedOptions.map((speed) {
                  final isSelected = _playbackSpeed == speed;
                  return GestureDetector(
                    onTap: () {
                      _setPlaybackSpeed(speed);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onTap,
    String? tooltip,
    double size = 32,
  }) {
    final button = GestureDetector(
      onTap: () {
        onTap?.call();
        _showControlsAndResetTimer();
      },
      child: Container(
        width: size + 16,
        height: size + 16,
        decoration: const BoxDecoration(
          color: Color(0x44000000),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildAdjustIndicator({
    required IconData icon,
    required double value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(value * 100).toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
