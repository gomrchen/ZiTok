import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'utils/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // 生产模式下的额外优化
  if (AppConfig.isProduction) {
    // 禁用调试横幅已由 MaterialApp 默认处理
    // 设置首选屏幕方向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // 设置系统UI覆盖样式
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }
}
