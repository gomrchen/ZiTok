import 'package:flutter/foundation.dart';

import '../../app.dart';
import '../../services/comment_service.dart';
import 'player_danmaku.dart';

class EpisodeLikeSnapshot {
  final bool liked;
  final int likeCount;
  const EpisodeLikeSnapshot({required this.liked, required this.likeCount});
}

/// Feed / 全集页共用的点赞、评论数、弹幕数据访问
class EpisodeEngagement {
  EpisodeEngagement._();

  static CommentService get _api => CommentService(AppBootstrap.apiClient.dio);

  static bool _ok(dynamic raw) => raw is Map && '${raw['code']}' == '10000';

  static Map<String, dynamic>? _data(dynamic raw) {
    if (!_ok(raw)) return null;
    final d = (raw as Map)['data'];
    if (d is Map) return Map<String, dynamic>.from(d);
    return null;
  }

  static Future<EpisodeLikeSnapshot?> fetchLikeStatus(int episodeId) async {
    try {
      final resp = await _api.episodeLikeStatus(episodeId: episodeId);
      final data = _data(resp.data);
      if (data == null) return null;
      final c = data['like_count'];
      return EpisodeLikeSnapshot(
        liked: data['liked'] == true,
        likeCount: c is num ? c.toInt() : 0,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('fetchLikeStatus: $e');
      return null;
    }
  }

  static Future<int?> fetchCommentTotal(int episodeId) async {
    try {
      final resp = await _api.episodeCommentList(episodeId: episodeId, page: 1, size: 1);
      final data = _data(resp.data);
      if (data == null) return null;
      final t = data['total'];
      return t is num ? t.toInt() : null;
    } catch (e) {
      if (kDebugMode) debugPrint('fetchCommentTotal: $e');
      return null;
    }
  }

  /// 切换点赞；[forceLike] 为 true 时若服务端变成取消则再点一次打回赞
  static Future<EpisodeLikeSnapshot?> toggleLike({
    required int episodeId,
    required bool currentlyLiked,
    required int likeCount,
    bool forceLike = false,
  }) async {
    if (forceLike && currentlyLiked) {
      return EpisodeLikeSnapshot(liked: true, likeCount: likeCount);
    }
    try {
      final resp = await _api.likeEpisode(episodeId: episodeId);
      final data = _data(resp.data);
      if (data != null) {
        var liked = data['liked'] == true;
        var count = data['like_count'];
        if (forceLike && !liked) {
          final again = await _api.likeEpisode(episodeId: episodeId);
          final d2 = _data(again.data);
          if (d2 != null) {
            liked = d2['liked'] == true;
            count = d2['like_count'];
          }
        }
        return EpisodeLikeSnapshot(
          liked: liked,
          likeCount: count is num ? count.toInt() : likeCount,
        );
      }
      final next = !currentlyLiked;
      return EpisodeLikeSnapshot(
        liked: next,
        likeCount: (likeCount + (next ? 1 : -1)).clamp(0, 1 << 30),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('toggleLike: $e');
      return null;
    }
  }

  static Future<List<String>?> fetchCommentTexts(int episodeId, {int size = 30}) async {
    try {
      final resp = await _api.episodeCommentList(episodeId: episodeId, page: 1, size: size);
      final data = _data(resp.data);
      if (data == null) return null;
      final list = (data['list'] as List? ?? data['comments'] as List? ?? const []);
      final out = <String>[];
      for (final e in list) {
        if (e is! Map) continue;
        final text = '${e['content'] ?? e['text'] ?? ''}'.trim();
        if (text.isEmpty) continue;
        out.add(text);
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('fetchCommentTexts: $e');
      return null;
    }
  }

  static List<DanmakuItem> buildDanmakuItems({
    required List<String> texts,
    required int episodeNo,
    required int durationMs,
  }) {
    final raw = List<String>.from(texts);
    if (raw.isEmpty) {
      raw.add('第$episodeNo集好看');
      raw.add('来 ZiTok 一起追');
    }
    final dur = durationMs.clamp(0, 1 << 30);
    final items = <DanmakuItem>[];
    for (var i = 0; i < raw.length; i++) {
      final at = dur > 0 ? ((i + 1) * dur / (raw.length + 1)).round() : null;
      items.add(DanmakuItem(raw[i], atMs: at));
    }
    items.add(DanmakuItem('第$episodeNo集'));
    return items;
  }
}
