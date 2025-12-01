import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/app_config.dart';
import 'package:web_socket_channel/status.dart' as status;

class SocketService {
  WebSocketChannel? _channel;
  Function(dynamic)? onMessage;
  Function()? onDisconnect;

  // 【修改】去掉了 headers 参数，改回通用连接方式
  void connect(String url) {
    try {
      // 使用通用方法，支持所有平台，不会报 Platform 错误
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
            (message) {
          if (onMessage != null) {
            // 调试日志：打印原始消息
            AppConfig.netLog('[SocketService] 收到原始消息: ${message.runtimeType}');

            try {
              final data = jsonDecode(message);
              AppConfig.netLog('[SocketService] JSON解析成功');
              onMessage!(data);
            } catch (e) {
              AppConfig.netLog('[SocketService] JSON解析失败，传递原始消息');
              onMessage!(message);
            }
          }
        },
        onDone: () {
          if (onDisconnect != null) onDisconnect!();
        },
        onError: (error) {
          AppConfig.netLog('[SocketService] WebSocket错误: $error');
        },
      );
    } catch (e) {
      AppConfig.netLog('[SocketService] 连接错误: $e');
    }
  }

  void send(dynamic data) {
    if (_channel != null) {
      try {
        if (data is Map) {
          final jsonStr = jsonEncode(data);
          _channel!.sink.add(jsonStr);
        } else {
          _channel!.sink.add(data.toString());
        }
      } catch (e) {
        // Ignore error silently
      }
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
      _channel = null;
    }
  }
}
