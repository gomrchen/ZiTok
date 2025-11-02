import 'package:flutter/material.dart';
import '../repositories/video_repository.dart';
import '../models/video.dart';

class VideoProvider extends ChangeNotifier {
  final VideoRepository repo;
  List<Video> _discover = [];
  List<Video> _featured = [];
  // 关注流
  List<Video> _follow = [];
  // 简单本地点赞状态，避免死代码并用于切换逻辑
  final Set<String> _likedVideoIds = {};
  bool _loadingDiscover = false;
  bool _loadingFeatured = false;
  bool _loadingFollow = false;
  bool _discoverHasMore = true;
  bool _featuredHasMore = true;
  bool _followHasMore = true;
  int _discoverPage = 1;
  int _featuredPage = 1;
  int _followPage = 1;
  String? _keyword;
  List<String>? _filters;
  // 关注页状态
  String? _followError;
  double _followScrollOffset = 0.0;
  int? _recommendStartIndexInFollow;

  VideoProvider({required this.repo});

  List<Video> get discover => _discover;
  List<Video> get featured => _featured;
  List<Video> get follow => _follow;
  bool get loadingDiscover => _loadingDiscover;
  bool get loadingFeatured => _loadingFeatured;
  bool get loadingFollow => _loadingFollow;
  bool get discoverHasMore => _discoverHasMore;
  bool get featuredHasMore => _featuredHasMore;
  bool get followHasMore => _followHasMore;
  String? get keyword => _keyword;
  List<String>? get filters => _filters;
  String? get followError => _followError;
  double get followScrollOffset => _followScrollOffset;
  int? get recommendStartIndexInFollow => _recommendStartIndexInFollow;

  Future<void> refreshDiscover({String? keyword, List<String>? tags}) async {
    _discoverPage = 1;
    _keyword = keyword;
    _filters = tags;
    _discover = [];
    _discoverHasMore = true;
    await loadMoreDiscover();
  }

  Future<void> loadMoreDiscover() async {
    if (_loadingDiscover || !_discoverHasMore) return;
    _loadingDiscover = true;
    notifyListeners();
    final res = await repo.fetchDiscover(VideoQuery(page: _discoverPage, pageSize: 20, keyword: _keyword, tags: _filters));
    _discover.addAll(res.items);
    _discoverHasMore = res.hasMore;
    _discoverPage += 1;
    _loadingDiscover = false;
    notifyListeners();
  }

  /// 刷新关注流：当关注内容不足时，自动拼接精选推荐
  Future<void> refreshFollow() async {
    _followPage = 1;
    _follow = [];
    _followHasMore = true;
    _followError = null;
    _recommendStartIndexInFollow = null;
    await loadMoreFollow();
  }

  Future<void> loadMoreFollow() async {
    if (_loadingFollow || !_followHasMore) return;
    _loadingFollow = true;
    notifyListeners();
    try {
      final res = await repo.fetchFollow(VideoQuery(page: _followPage, pageSize: 20, keyword: _keyword, tags: _filters));
      final startLen = _follow.length;
      _follow.addAll(res.items);
      _followHasMore = res.hasMore;
      _followPage += 1;

      // 当关注内容不足（首屏很少或已无更多），拼接精选推荐以保证滚动体验
      if (!_followHasMore && _follow.length < 10) {
        final rec = await repo.fetchFeatured(const VideoQuery(page: 1, pageSize: 20));
        _recommendStartIndexInFollow = _follow.length;
        _follow.addAll(rec.items);
        // 推荐内容视为“更多”已耗尽，仅供展示
        _followHasMore = rec.hasMore;
      }
      // 如果本次加载未获取到任何新内容，标记为无更多
      if (_follow.length == startLen) {
        _followHasMore = false;
      }
    } catch (e) {
      _followError = e.toString();
    } finally {
      _loadingFollow = false;
      notifyListeners();
    }
  }

  /// 更新关注页的滚动位置，以便返回时恢复
  void setFollowScrollOffset(double offset) {
    _followScrollOffset = offset;
  }

  /// 点赞（本地更新），真实项目中应调用后端接口并做失败回滚
  void toggleLike(String videoId) {
    final idx = _follow.indexWhere((v) => v.id == videoId);
    if (idx >= 0) {
      final v = _follow[idx];
      final liked = _likedVideoIds.contains(videoId);
      final int newLikes = liked ? (v.likes - 1).clamp(0, 0x7fffffff).toInt() : v.likes + 1;
      _follow[idx] = Video(
        id: v.id,
        title: v.title,
        coverUrl: v.coverUrl,
        videoUrl: v.videoUrl,
        durationSeconds: v.durationSeconds,
        author: v.author,
        likes: newLikes,
        tags: v.tags,
      );
      if (liked) {
        _likedVideoIds.remove(videoId);
      } else {
        _likedVideoIds.add(videoId);
      }
      notifyListeners();
    }
  }

  Future<void> refreshFeatured({String? keyword, List<String>? tags}) async {
    _featuredPage = 1;
    _keyword = keyword;
    _filters = tags;
    _featured = [];
    _featuredHasMore = true;
    await loadMoreFeatured();
  }

  Future<void> loadMoreFeatured() async {
    if (_loadingFeatured || !_featuredHasMore) return;
    _loadingFeatured = true;
    notifyListeners();
    final res = await repo.fetchFeatured(VideoQuery(page: _featuredPage, pageSize: 20, keyword: _keyword, tags: _filters));
    _featured.addAll(res.items);
    _featuredHasMore = res.hasMore;
    _featuredPage += 1;
    _loadingFeatured = false;
    notifyListeners();
  }
}