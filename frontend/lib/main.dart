import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';
import 'utils/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized();
  } catch (_) {
    // 原生库未就绪时回退 video_player 路径
  }

  // 生产模式性能优化
  _configurePerformance();

  await AppBootstrap.init();
  runApp(const ZitokApp());
}

/// 配置全局性能优化
void _configurePerformance() {
  // 配置图片缓存
  PaintingBinding.instance.imageCache.maximumSize = NetworkConfig.imageCacheMaxCount;
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      NetworkConfig.imageCacheMaxSizeMB * 1024 * 1024;

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 边缘到边：状态栏/导航栏透明，视频可铺满
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // 生产模式额外标记（缓存策略等已在上方配置）
  if (AppConfig.isProduction) {
    // no-op：保留分支便于后续加生产专用开关
  }
}
