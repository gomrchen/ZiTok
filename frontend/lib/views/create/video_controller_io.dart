import 'dart:io';
import 'package:video_player/video_player.dart';

VideoPlayerController buildController(String source) {
  if (source.startsWith('http')) {
    return VideoPlayerController.networkUrl(Uri.parse(source));
  }
  return VideoPlayerController.file(File(source));
}