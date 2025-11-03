import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zitok/utils/image_utils.dart';

void main() {
  test('resizeToJpeg outputs 200x200', () {
    final src = img.Image(width: 400, height: 400);
    img.fill(src, color: img.ColorRgb8(10, 200, 150));
    final bytes = Uint8List.fromList(img.encodeJpg(src));

    final out = ImageUtils.resizeToJpeg(bytes, width: 200, height: 200);
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 200);
    expect(decoded.height, 200);
  });

  test('resizeContainToJpeg keeps aspect ratio', () {
    final src = img.Image(width: 1000, height: 500);
    img.fill(src, color: img.ColorRgb8(120, 50, 230));
    final bytes = Uint8List.fromList(img.encodeJpg(src));

    final out = ImageUtils.resizeContainToJpeg(bytes, maxWidth: 400, maxHeight: 300);
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 400);
    expect(decoded.height, 200); // 保持 2:1 比例
  });
}