import 'package:video_player/video_player.dart';
// 在 Web 与非 Web 平台使用不同的控制器构造
import 'video_controller_web.dart' if (dart.library.io) 'video_controller_io.dart' as impl;

VideoPlayerController buildVideoController(String source) {
  return impl.buildController(source);
}