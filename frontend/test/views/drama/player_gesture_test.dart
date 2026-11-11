import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/views/drama/player_cast_quality.dart';
import 'package:zitok/views/drama/player_gesture.dart';
import 'package:zitok/views/drama/player_handle.dart';

class _FakeHandle implements PlayHandle {
  bool playing;
  bool initialized;
  double speed;
  double volume;

  _FakeHandle({
    this.playing = true,
    this.initialized = true,
    this.speed = 1,
    this.volume = 1,
  });

  @override
  bool get isInitialized => initialized;
  @override
  bool get isPlaying => playing;
  @override
  bool get isBuffering => false;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get duration => const Duration(seconds: 10);
  @override
  Size get size => const Size(720, 1280);
  @override
  String? get currentVideoTrackId => null;

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}

  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<void> setPlaybackSpeed(double s) async => speed = s;
  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Future<void> dispose() async {}

  @override
  List<VideoQualityOption> engineTrackOptions() => const [];
  @override
  Future<bool> selectEngineTrack(VideoQualityOption option) async => false;
  @override
  bool get supportsEngineSubtitle => false;
  @override
  bool get hasEngineSubtitle => false;
  @override
  Future<void> setEngineSubtitle({required bool on, String? externalUrl}) async {}
  @override
  Widget buildCover() => const SizedBox.shrink();
}

void main() {
  test('applyPauseToggle pauses and resumes', () {
    final h = _FakeHandle(playing: true);
    expect(
      applyPauseToggle(h, locked: false, loading: false, speedUp: false),
      PauseToggleResult.paused,
    );
    expect(h.playing, isFalse);
    expect(
      applyPauseToggle(h, locked: false, loading: false, speedUp: false),
      PauseToggleResult.resumed,
    );
    expect(h.playing, isTrue);
  });

  test('applyPauseToggle skips when locked or speeding', () {
    final h = _FakeHandle();
    expect(
      applyPauseToggle(h, locked: true, loading: false, speedUp: false),
      PauseToggleResult.skipped,
    );
    expect(
      applyPauseToggle(h, locked: false, loading: false, speedUp: true),
      PauseToggleResult.skipped,
    );
    expect(applyPauseToggle(null, locked: false, loading: false, speedUp: false),
        PauseToggleResult.skipped);
  });

  test('beginSpeedBoost and endSpeedBoost', () {
    final h = _FakeHandle(playing: false);
    expect(beginSpeedBoost(h, locked: false, loading: false), isTrue);
    expect(h.speed, 2.0);
    expect(h.playing, isTrue);
    endSpeedBoost(h, 1.25);
    expect(h.speed, 1.25);
  });

  test('toggleMuteVolume flips volume', () async {
    final h = _FakeHandle(volume: 1);
    expect(await toggleMuteVolume(h, false), isTrue);
    expect(h.volume, 0);
    expect(await toggleMuteVolume(h, true), isFalse);
    expect(h.volume, 1);
    expect(await toggleMuteVolume(null, false), isNull);
  });

  test('evaluateEpisodeEnd countdown vs goNext', () {
    const dur = Duration(seconds: 10);
    final nearEnd = dur - const Duration(milliseconds: 200);
    expect(
      evaluateEpisodeEnd(
        position: nearEnd,
        duration: dur,
        endedHandled: false,
        active: true,
        hasNext: true,
        useCountdown: true,
      ),
      EpisodeEndDecision.countdown,
    );
    expect(
      evaluateEpisodeEnd(
        position: nearEnd,
        duration: dur,
        endedHandled: false,
        active: true,
        hasNext: true,
        useCountdown: false,
      ),
      EpisodeEndDecision.goNext,
    );
    expect(
      evaluateEpisodeEnd(
        position: const Duration(seconds: 1),
        duration: dur,
        endedHandled: false,
        active: true,
        hasNext: true,
        useCountdown: true,
      ),
      EpisodeEndDecision.ignore,
    );
  });

  test('isNearEpisodeEnd window', () {
    const dur = Duration(seconds: 30);
    expect(
      isNearEpisodeEnd(
        position: const Duration(seconds: 25),
        duration: dur,
        hasNext: true,
      ),
      isTrue,
    );
    expect(
      isNearEpisodeEnd(
        position: const Duration(seconds: 10),
        duration: dur,
        hasNext: true,
      ),
      isFalse,
    );
    expect(
      isNearEpisodeEnd(
        position: const Duration(seconds: 29),
        duration: dur,
        hasNext: false,
      ),
      isFalse,
    );
  });
}
