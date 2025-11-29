import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// 视频缓存配置
class VideoCacheConfig {
  /// 最大缓存大小（字节）
  final int maxCacheSize;

  /// 缓存有效期（小时）
  final int cacheValidityHours;

  /// 是否启用磁盘缓存
  final bool enableDiskCache;

  /// 是否启用内存缓存
  final bool enableMemoryCache;

  /// 内存缓存最大条目数
  final int maxMemoryCacheEntries;

  const VideoCacheConfig({
    this.maxCacheSize = 500 * 1024 * 1024, // 500MB
    this.cacheValidityHours = 24,
    this.enableDiskCache = true,
    this.enableMemoryCache = true,
    this.maxMemoryCacheEntries = 10,
  });
}

/// 缓存条目元数据
class CacheEntry {
  final String url;
  final String localPath;
  final DateTime createdAt;
  final int fileSize;
  DateTime lastAccessedAt;

  CacheEntry({
    required this.url,
    required this.localPath,
    required this.createdAt,
    required this.fileSize,
    DateTime? lastAccessedAt,
  }) : lastAccessedAt = lastAccessedAt ?? createdAt;

  Map<String, dynamic> toJson() => {
        'url': url,
        'localPath': localPath,
        'createdAt': createdAt.toIso8601String(),
        'fileSize': fileSize,
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        url: json['url'] as String,
        localPath: json['localPath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        fileSize: json['fileSize'] as int,
        lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
      );

  bool get isExpired {
    final validityDuration = const Duration(hours: 24);
    return DateTime.now().difference(createdAt) > validityDuration;
  }
}

/// 视频缓存服务
///
/// 功能：
/// - 多级缓存：内存缓存 + 磁盘缓存
/// - LRU淘汰策略
/// - 自动清理过期和超量缓存
/// - 缓存预热
class VideoCacheService {
  static VideoCacheService? _instance;
  static VideoCacheService get instance => _instance ??= VideoCacheService._();

  VideoCacheService._();

  final VideoCacheConfig _config = const VideoCacheConfig();

  // 内存缓存：URL -> 本地路径
  final Map<String, String> _memoryCache = {};

  // 磁盘缓存元数据
  final Map<String, CacheEntry> _diskCacheIndex = {};

  Directory? _cacheDir;
  bool _initialized = false;
  int _currentCacheSize = 0;

  /// 初始化缓存服务
  Future<void> init() async {
    if (_initialized) return;

    try {
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        _cacheDir = Directory('${appDir.path}/video_cache');
        if (!await _cacheDir!.exists()) {
          await _cacheDir!.create(recursive: true);
        }

        // 加载缓存索引
        await _loadCacheIndex();

        // 清理过期缓存
        await _cleanupExpiredCache();
      }

      _initialized = true;
      debugPrint('VideoCacheService: initialized, cache size=${_formatSize(_currentCacheSize)}');
    } catch (e) {
      debugPrint('VideoCacheService: init failed: $e');
    }
  }

  /// 获取缓存的视频路径
  Future<String?> getCachedVideoPath(String url) async {
    if (!_initialized) await init();

    // 先检查内存缓存
    if (_config.enableMemoryCache && _memoryCache.containsKey(url)) {
      final path = _memoryCache[url]!;
      if (await File(path).exists()) {
        debugPrint('VideoCacheService: memory cache hit for $url');
        return path;
      } else {
        _memoryCache.remove(url);
      }
    }

    // 检查磁盘缓存
    if (_config.enableDiskCache) {
      final entry = _diskCacheIndex[url];
      if (entry != null && !entry.isExpired) {
        final file = File(entry.localPath);
        if (await file.exists()) {
          // 更新访问时间
          entry.lastAccessedAt = DateTime.now();

          // 加入内存缓存
          if (_config.enableMemoryCache) {
            _addToMemoryCache(url, entry.localPath);
          }

          debugPrint('VideoCacheService: disk cache hit for $url');
          return entry.localPath;
        } else {
          // 文件不存在，移除索引
          _diskCacheIndex.remove(url);
        }
      }
    }

    return null;
  }

  /// 缓存视频文件
  Future<String?> cacheVideo(String url, {Stream<List<int>>? dataStream}) async {
    if (!_initialized) await init();
    if (!_config.enableDiskCache || kIsWeb) return null;

    try {
      final fileName = _generateFileName(url);
      final localPath = '${_cacheDir!.path}/$fileName';
      final file = File(localPath);

      // 如果已有缓存，直接返回
      if (await file.exists()) {
        return localPath;
      }

      // 检查是否需要清理空间
      await _ensureCacheSpace();

      // 下载并保存视频
      if (dataStream != null) {
        final sink = file.openWrite();
        int totalSize = 0;
        await for (final chunk in dataStream) {
          sink.add(chunk);
          totalSize += chunk.length;
        }
        await sink.close();

        // 添加到缓存索引
        final entry = CacheEntry(
          url: url,
          localPath: localPath,
          createdAt: DateTime.now(),
          fileSize: totalSize,
        );
        _diskCacheIndex[url] = entry;
        _currentCacheSize += totalSize;

        // 保存索引
        await _saveCacheIndex();

        debugPrint('VideoCacheService: cached video $url, size=${_formatSize(totalSize)}');
        return localPath;
      }

      return null;
    } catch (e) {
      debugPrint('VideoCacheService: cache failed for $url: $e');
      return null;
    }
  }

  /// 预热缓存（提前下载）
  Future<void> warmUp(List<String> urls) async {
    if (!_initialized) await init();

    for (final url in urls) {
      if (!_diskCacheIndex.containsKey(url)) {
        // TODO: 实现后台下载
        debugPrint('VideoCacheService: warmUp scheduled for $url');
      }
    }
  }

  /// 清除所有缓存
  Future<void> clearAll() async {
    if (!_initialized) await init();

    _memoryCache.clear();

    if (_cacheDir != null && await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
    }

    _diskCacheIndex.clear();
    _currentCacheSize = 0;

    await _saveCacheIndex();
    debugPrint('VideoCacheService: all cache cleared');
  }

  /// 获取缓存大小
  int get cacheSize => _currentCacheSize;

  /// 获取缓存条目数
  int get cacheEntryCount => _diskCacheIndex.length;

  /// 添加到内存缓存
  void _addToMemoryCache(String url, String path) {
    if (_memoryCache.length >= _config.maxMemoryCacheEntries) {
      // LRU: 移除第一个
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[url] = path;
  }

  /// 生成缓存文件名
  String _generateFileName(String url) {
    final hash = md5.convert(utf8.encode(url)).toString();
    final ext = _getExtension(url);
    return '$hash$ext';
  }

  /// 获取文件扩展名
  String _getExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final dotIndex = path.lastIndexOf('.');
      if (dotIndex > 0 && dotIndex < path.length - 1) {
        return path.substring(dotIndex);
      }
    } catch (_) {}
    return '.mp4';
  }

  /// 加载缓存索引
  Future<void> _loadCacheIndex() async {
    if (_cacheDir == null) return;

    final indexFile = File('${_cacheDir!.path}/cache_index.json');
    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        final List<dynamic> list = json.decode(content);
        _currentCacheSize = 0;

        for (final item in list) {
          final entry = CacheEntry.fromJson(item as Map<String, dynamic>);
          // 验证文件是否存在
          if (await File(entry.localPath).exists()) {
            _diskCacheIndex[entry.url] = entry;
            _currentCacheSize += entry.fileSize;
          }
        }

        debugPrint('VideoCacheService: loaded ${_diskCacheIndex.length} cache entries');
      } catch (e) {
        debugPrint('VideoCacheService: failed to load cache index: $e');
      }
    }
  }

  /// 保存缓存索引
  Future<void> _saveCacheIndex() async {
    if (_cacheDir == null) return;

    try {
      final indexFile = File('${_cacheDir!.path}/cache_index.json');
      final list = _diskCacheIndex.values.map((e) => e.toJson()).toList();
      await indexFile.writeAsString(json.encode(list));
    } catch (e) {
      debugPrint('VideoCacheService: failed to save cache index: $e');
    }
  }

  /// 清理过期缓存
  Future<void> _cleanupExpiredCache() async {
    final expired = <String>[];

    for (final entry in _diskCacheIndex.entries) {
      if (entry.value.isExpired) {
        expired.add(entry.key);
      }
    }

    for (final url in expired) {
      final entry = _diskCacheIndex.remove(url);
      if (entry != null) {
        try {
          await File(entry.localPath).delete();
          _currentCacheSize -= entry.fileSize;
        } catch (_) {}
      }
    }

    if (expired.isNotEmpty) {
      await _saveCacheIndex();
      debugPrint('VideoCacheService: cleaned up ${expired.length} expired entries');
    }
  }

  /// 确保有足够的缓存空间
  Future<void> _ensureCacheSpace() async {
    while (_currentCacheSize >= _config.maxCacheSize && _diskCacheIndex.isNotEmpty) {
      // 找到最久未访问的条目
      CacheEntry? oldest;
      String? oldestUrl;

      for (final entry in _diskCacheIndex.entries) {
        if (oldest == null || entry.value.lastAccessedAt.isBefore(oldest.lastAccessedAt)) {
          oldest = entry.value;
          oldestUrl = entry.key;
        }
      }

      if (oldestUrl != null && oldest != null) {
        _diskCacheIndex.remove(oldestUrl);
        try {
          await File(oldest.localPath).delete();
          _currentCacheSize -= oldest.fileSize;
          debugPrint('VideoCacheService: evicted ${_formatSize(oldest.fileSize)} to free space');
        } catch (_) {}
      } else {
        break;
      }
    }

    await _saveCacheIndex();
  }

  /// 格式化文件大小
  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// 调试信息
  Map<String, dynamic> get debugInfo => {
        'initialized': _initialized,
        'cacheSize': _formatSize(_currentCacheSize),
        'maxCacheSize': _formatSize(_config.maxCacheSize),
        'entryCount': _diskCacheIndex.length,
        'memoryCacheCount': _memoryCache.length,
      };
}
