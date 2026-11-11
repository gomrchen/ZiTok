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

  test('https path', () {
    expect(
      DeepLinkService.mapToAppPath(Uri.parse('https://zitok.app/drama/9?ep=8')),
      '/drama/9?ep=8',
    );
  });

  test('app path passthrough', () {
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
}
