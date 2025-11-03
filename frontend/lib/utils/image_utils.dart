import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// 图像处理工具
/// - 提供尺寸压缩（按指定宽高缩放）
/// - 输出 JPEG/PNG 二进制
class ImageUtils {
  /// 将原始图像字节缩放到指定大小并以 JPEG 编码返回
  /// [bytes] 输入图像字节（支持 JPG/PNG/WebP）
  /// [width] 目标宽度
  /// [height] 目标高度
  /// [quality] JPEG 质量（1-100）
  static Uint8List resizeToJpeg(Uint8List bytes, {required int width, required int height, int quality = 90}) {
    final src = img.decodeImage(bytes);
    if (src == null) {
      throw Exception('无法解码图片');
    }
    final resized = img.copyResize(src, width: width, height: height, interpolation: img.Interpolation.average);
    final out = img.encodeJpg(resized, quality: quality);
    return Uint8List.fromList(out);
  }

  /// 等比缩放到指定最大边界，保持宽高比例
  static Uint8List resizeContainToJpeg(Uint8List bytes, {required int maxWidth, required int maxHeight, int quality = 90}) {
    final src = img.decodeImage(bytes);
    if (src == null) {
      throw Exception('无法解码图片');
    }
    final wr = maxWidth / src.width;
    final hr = maxHeight / src.height;
    final ratio = wr < hr ? wr : hr;
    final w = (src.width * ratio).round();
    final h = (src.height * ratio).round();
    final resized = img.copyResize(src, width: w, height: h, interpolation: img.Interpolation.average);
    final out = img.encodeJpg(resized, quality: quality);
    return Uint8List.fromList(out);
  }
}