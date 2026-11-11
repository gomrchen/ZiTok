import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/views/drama/media_url.dart';

void main() {
  test('accepts http(s) media urls', () {
    expect(isHttpMediaUrl('https://cdn.example/a.mp4'), isTrue);
    expect(isHttpMediaUrl('http://127.0.0.1:28880/videos/a.mp4'), isTrue);
  });

  test('rejects dangerous schemes', () {
    expect(isHttpMediaUrl('file:///tmp/x.mp4'), isFalse);
    expect(isHttpMediaUrl('javascript:alert(1)'), isFalse);
    expect(isHttpMediaUrl(''), isFalse);
  });

  test('blocks private hosts in release sanitize', () {
    expect(isBlockedMediaHost('127.0.0.1'), isTrue);
    expect(isBlockedMediaHost('10.0.0.1'), isTrue);
    expect(isBlockedMediaHost('192.168.1.1'), isTrue);
    expect(isBlockedMediaHost('169.254.1.1'), isTrue);
    expect(isBlockedMediaHost('cdn.example'), isFalse);
    expect(
      sanitizeHttpMediaUrl('http://192.168.0.5/a.mp4', allowPrivateHosts: false),
      isNull,
    );
    expect(
      sanitizeHttpMediaUrl('https://cdn.example/a.mp4', allowPrivateHosts: false),
      'https://cdn.example/a.mp4',
    );
  });

  test('progressive detection', () {
    expect(isProgressiveVideoUrl('https://x/a.mp4'), isTrue);
    expect(isProgressiveVideoUrl('https://x/a.m3u8'), isFalse);
  });

  test('playerFriendlyError never echoes stack', () {
    expect(playerFriendlyError(Exception('DioException [bad]')), '加载失败，请稍后重试');
    expect(playerFriendlyError(Exception('网络超时')), '网络异常，请检查连接后重试');
  });
}
