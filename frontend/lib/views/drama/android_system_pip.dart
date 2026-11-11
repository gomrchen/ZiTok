import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/simple_pip.dart';

/// Android 系统画中画（iOS 仍走应用内 PlayerPipController）
class AndroidSystemPip {
  AndroidSystemPip._();

  static SimplePip? _pip;
  static VoidCallback? _onPlay;
  static VoidCallback? _onPause;
  static final ValueNotifier<bool> inPip = ValueNotifier(false);

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static SimplePip get _controller {
    return _pip ??= SimplePip(
      onPipEntered: () => inPip.value = true,
      onPipExited: () => inPip.value = false,
      onPipAction: (action) {
        switch (action) {
          case PipAction.play:
            _onPlay?.call();
          case PipAction.pause:
            _onPause?.call();
          default:
            break;
        }
      },
    );
  }

  /// 绑定当前页播放器的系统 PiP 媒体控件
  static void bindPlayer({
    required VoidCallback onPlay,
    required VoidCallback onPause,
  }) {
    if (!isSupported) return;
    _onPlay = onPlay;
    _onPause = onPause;
    // 触发 controller 初始化（含 MethodChannel handler）
    _controller;
  }

  static void unbindPlayer() {
    _onPlay = null;
    _onPause = null;
  }

  static Future<void> syncPlaying(bool playing) async {
    if (!isSupported) return;
    try {
      await _controller.setIsPlaying(playing);
    } catch (_) {}
  }

  /// 播放中尽量开启「退后台自动进 PiP」（Android 12+）
  static Future<void> preferAutoEnter({bool enable = true}) async {
    if (!isSupported) return;
    try {
      final ok = await SimplePip.isAutoPipAvailable;
      if (!ok) return;
      await _controller.setAutoPipMode(
        aspectRatio: (9, 16),
        autoEnter: enable,
        seamlessResize: true,
      );
    } catch (_) {}
  }

  static Future<bool> enter() async {
    if (!isSupported) return false;
    try {
      final available = await SimplePip.isPipAvailable;
      if (!available) return false;
      await _controller.setPipActionsLayout(PipActionsLayout.mediaOnlyPause);
      // 竖屏短剧 9:16
      final ok = await _controller.enterPipMode(
        aspectRatio: (9, 16),
        seamlessResize: true,
      );
      if (ok) inPip.value = true;
      return ok;
    } catch (_) {
      return false;
    }
  }
}
