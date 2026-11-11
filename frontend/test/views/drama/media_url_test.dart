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

  test('progressive detection', () {
    expect(isProgressiveVideoUrl('https://x/a.mp4'), isTrue);
    expect(isProgressiveVideoUrl('https://x/a.m3u8'), isFalse);
  });
}
