import 'dart:async';

import 'package:flutter/material.dart';

import 'player_handle.dart';

enum PauseToggleResult { skipped, paused, resumed }

enum EpisodeEndDecision { ignore, countdown, goNext }

/// 片尾判定：距片尾 [threshold] 内触发倒计时或切集
EpisodeEndDecision evaluateEpisodeEnd({
  required Duration position,
  required Duration duration,
  required bool endedHandled,
  required bool active,
  required bool hasNext,
  required bool useCountdown,
  Duration threshold = const Duration(milliseconds: 400),
}) {
  if (!active || endedHandled || duration.inMilliseconds <= 0) {
    return EpisodeEndDecision.ignore;
  }
  if (position < duration - threshold) return EpisodeEndDecision.ignore;
  if (useCountdown && hasNext) return EpisodeEndDecision.countdown;
  return EpisodeEndDecision.goNext;
}

bool isNearEpisodeEnd({
  required Duration position,
  required Duration duration,
  required bool hasNext,
  Duration window = const Duration(seconds: 8),
}) {
  if (!hasNext || duration.inMilliseconds <= 0) return false;
  return duration - position <= window;
}

/// 双击点赞爆发动画位置
class LikeBurstSession {
  Offset? position;
  Timer? _timer;

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// 成功触发返回 true
  bool fire({
    required Offset local,
    required bool locked,
    required bool loading,
    required VoidCallback onUpdate,
    required VoidCallback onLike,
  }) {
    if (locked || loading) return false;
    position = local;
    onUpdate();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 750), () {
      position = null;
      onUpdate();
    });
    onLike();
    return true;
  }
}

/// 单击暂停/续播；倍速中跳过
PauseToggleResult applyPauseToggle(
  PlayHandle? player, {
  required bool locked,
  required bool loading,
  required bool speedUp,
}) {
  if (player == null || !player.isInitialized || locked || loading || speedUp) {
    return PauseToggleResult.skipped;
  }
  if (player.isPlaying) {
    player.pause();
    return PauseToggleResult.paused;
  }
  player.play();
  return PauseToggleResult.resumed;
}

/// 长按 2x；成功返回 true
bool beginSpeedBoost(
  PlayHandle? player, {
  required bool locked,
  required bool loading,
}) {
  if (player == null || !player.isInitialized || locked || loading) return false;
  player.setPlaybackSpeed(2.0);
  if (!player.isPlaying) player.play();
  return true;
}

void endSpeedBoost(PlayHandle? player, double baseSpeed) {
  player?.setPlaybackSpeed(baseSpeed);
}

/// 切换静音；成功返回新 muted，否则 null
Future<bool?> toggleMuteVolume(PlayHandle? player, bool muted) async {
  if (player == null || !player.isInitialized) return null;
  final next = !muted;
  await player.setVolume(next ? 0 : 1);
  return next;
}
