import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/services/deep_link_service.dart';

void main() {
  test('zitok://drama/{id}?ep=', () {
    expect(
      DeepLinkService.mapToAppPath(Uri.parse('zitok://drama/12?ep=34')),
      '/drama/12?ep=34',
    );
  });

  test('zitok:///drama/{id}', () {
    expect(
      DeepLinkService.mapToAppPath(Uri.parse('zitok:///drama/12')),
      '/drama/12',
    );
  });

  test('https path on allowlisted host', () {
    expect(
      DeepLinkService.mapToAppPath(Uri.parse('https://zitok.app/drama/9?ep=8')),
      '/drama/9?ep=8',
    );
  });

  test('app path passthrough digits only', () {
    expect(
      DeepLinkService.mapToAppPath(Uri.parse('/drama/1?ep=2')),
      '/drama/1?ep=2',
    );
  });

  test('zitok://watching', () {
    expect(DeepLinkService.mapToAppPath(Uri.parse('zitok://watching')), '/watching');
  });

  test('unknown returns null', () {
    expect(DeepLinkService.mapToAppPath(Uri.parse('zitok://other/1')), isNull);
  });

  test('rejects non-digit drama id', () {
    expect(
      DeepLinkService.mapToAppPath(Uri.parse('zitok://drama/../etc?ep=1')),
      isNull,
    );
    expect(
      DeepLinkService.mapToAppPath(Uri.parse('zitok://drama/abc?ep=1')),
      isNull,
    );
  });

  test('strips non-digit ep and keeps drama', () {
    expect(
      DeepLinkService.mapToAppPath(Uri.parse('zitok://drama/12?ep=1;drop')),
      '/drama/12',
    );
  });

  test('rejects foreign https host', () {
    expect(
      DeepLinkService.mapToAppPath(Uri.parse('https://evil.example/drama/1?ep=2')),
      isNull,
    );
  });

  test('buildDramaEpisodeLink', () {
    expect(
      DeepLinkService.buildDramaEpisodeLink(dramaId: 1, episodeId: 12),
      'zitok://drama/1?ep=12',
    );
  });
}
