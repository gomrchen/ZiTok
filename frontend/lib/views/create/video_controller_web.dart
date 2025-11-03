import 'package:video_player/video_player.dart';

VideoPlayerController buildController(String source) {
  // Web 仅支持网络 URL
  return VideoPlayerController.networkUrl(Uri.parse(source));
}