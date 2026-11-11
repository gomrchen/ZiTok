import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/views/drama/episode_engagement.dart';

void main() {
  test('buildDanmakuItems fills placeholders when empty', () {
    final items = EpisodeEngagement.buildDanmakuItems(
      texts: const [],
      episodeNo: 3,
      durationMs: 10000,
    );
    expect(items.length, greaterThanOrEqualTo(3));
    expect(items.any((e) => e.text.contains('第3集')), isTrue);
    expect(items.where((e) => e.atMs != null).isNotEmpty, isTrue);
  });

  test('buildDanmakuItems spreads timed cues', () {
    final items = EpisodeEngagement.buildDanmakuItems(
      texts: const ['a', 'b'],
      episodeNo: 1,
      durationMs: 9000,
    );
    final timed = items.where((e) => e.atMs != null).toList();
    expect(timed.length, 2);
    expect(timed.first.atMs! < timed.last.atMs!, isTrue);
  });
}
