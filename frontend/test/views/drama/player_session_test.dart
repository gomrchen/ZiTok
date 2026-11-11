import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/models/drama_models.dart';
import 'package:zitok/views/drama/player_session.dart';

const _drama = Drama(id: 1, title: 't');
const _ep = Episode(id: 1, dramaId: 1, episodeNo: 1);

PlayInfo _info({
  bool locked = false,
  bool canPlay = true,
  String videoUrl = 'https://cdn.example/a.mp4',
}) {
  return PlayInfo(
    episode: _ep,
    drama: _drama,
    locked: locked,
    canPlay: canPlay,
    videoUrl: videoUrl,
  );
}

void main() {
  test('isPlayInfoBlocked respects flags and empty url', () {
    expect(isPlayInfoBlocked(_info()), isFalse);
    expect(isPlayInfoBlocked(_info(locked: true)), isTrue);
    expect(isPlayInfoBlocked(_info(canPlay: false)), isTrue);
    expect(isPlayInfoBlocked(_info(videoUrl: ''), fallbackUrl: ''), isTrue);
    expect(
      isPlayInfoBlocked(_info(videoUrl: ''), fallbackUrl: 'https://cdn.example/b.mp4'),
      isFalse,
    );
  });

  test('resolvePlayUrl prefers primary then fallback', () {
    expect(resolvePlayUrl(_info(videoUrl: ' https://a '), 'https://b'), 'https://a');
    expect(resolvePlayUrl(_info(videoUrl: '  '), ' https://b '), 'https://b');
  });

  test('EpisodePrepareOutcome factories', () {
    expect(EpisodePrepareOutcome.cancelled().cancelled, isTrue);
    expect(EpisodePrepareOutcome.fail('x').error, 'x');
    final locked = EpisodePrepareOutcome.lock(_info(locked: true));
    expect(locked.locked, isTrue);
    expect(locked.isReady, isFalse);
    final ready = EpisodePrepareOutcome.ready(_info(), 'https://cdn.example/a.mp4');
    expect(ready.isReady, isTrue);
    expect(ready.url, 'https://cdn.example/a.mp4');
  });
}
