import 'package:flutter/material.dart';
import '../repositories/video_repository.dart';
import '../models/video.dart';
import '../models/video_publish.dart';

class VideoProvider extends ChangeNotifier {
  final VideoRepository repo;
  List<Video> _discover = [];
  List<Video> _featured = [];
  List<Video> _follow = [];
  List<Video> _recommend = []; // 推荐视频列表（使用新推荐接口）
  List<Video> _favorites = []; // 收藏列表
  bool _loadingDiscover = false;
  bool _loadingFeatured = false;
  bool _loadingFollow = false;
  bool _loadingRecommend = false;
  bool _loadingFavorites = false;
  bool _discoverHasMore = true;
  bool _featuredHasMore = true;
  bool _followHasMore = true;
  bool _recommendHasMore = true;
  bool _favoritesHasMore = true;
  int _discoverPage = 1;
  int _featuredPage = 1;
  int _followPage = 1;
  int _favoritesPage = 1;
  int? _lastVisit; // 推荐接口的游标
  String? _keyword;
  List<String>? _filters;
  String? _followError;
  double _followScrollOffset = 0.0;
  int? _recommendStartIndexInFollow;

  // 收藏状态缓存 - 记录已收藏的视频ID
  final Set<String> _favoritedIds = {};

  // 投稿相关状态
  PublishProgress _publishProgress = PublishProgress.idle();

  // 搜索状态
  List<Video> _searchResults = [];
  bool _loadingSearch = false;
  bool _searchHasMore = true;
  int _searchPage = 1;
  String? _searchKeyword;

  VideoProvider({required this.repo});

  List<Video> get discover => _discover;
  List<Video> get featured => _featured;
  List<Video> get follow => _follow;
  List<Video> get recommend => _recommend;
  List<Video> get favorites => _favorites;
  bool get loadingDiscover => _loadingDiscover;
  bool get loadingFeatured => _loadingFeatured;
  bool get loadingFollow => _loadingFollow;
  bool get loadingRecommend => _loadingRecommend;
  bool get loadingFavorites => _loadingFavorites;
  bool get discoverHasMore => _discoverHasMore;
  bool get featuredHasMore => _featuredHasMore;
  bool get followHasMore => _followHasMore;
  bool get recommendHasMore => _recommendHasMore;
  bool get favoritesHasMore => _favoritesHasMore;
  String? get keyword => _keyword;
  List<String>? get filters => _filters;
  String? get followError => _followError;
  double get followScrollOffset => _followScrollOffset;
  int? get recommendStartIndexInFollow => _recommendStartIndexInFollow;

  // 搜索相关getter
  List<Video> get searchResults => _searchResults;
  bool get loadingSearch => _loadingSearch;
  bool get searchHasMore => _searchHasMore;
  String? get searchKeyword => _searchKeyword;

  // 投稿相关getter
  PublishProgress get publishProgress => _publishProgress;

  /// 检查视频是否已收藏
  bool isFavorited(String videoId) => _favoritedIds.contains(videoId);

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
    final res = await repo.fetchDiscover(
        VideoQuery(page: _discoverPage, pageSize: 20, keyword: _keyword, tags: _filters));
    _discover.addAll(res.items);
    _discoverHasMore = res.hasMore;
    _discoverPage += 1;
    _loadingDiscover = false;
    notifyListeners();
  }

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
      final res = await repo.fetchFollow(
          VideoQuery(page: _followPage, pageSize: 20, keyword: _keyword, tags: _filters));
      final startLen = _follow.length;
      _follow.addAll(res.items);
      _followHasMore = res.hasMore;
      _followPage += 1;

      if (!_followHasMore && _follow.length < 10) {
        final rec = await repo.fetchFeatured(const VideoQuery(page: 1, pageSize: 20));
        _recommendStartIndexInFollow = _follow.length;
        _follow.addAll(rec.items);
        _followHasMore = rec.hasMore;
      }
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

  void setFollowScrollOffset(double offset) {
    _followScrollOffset = offset;
  }

  Future<void> like(String videoId) async {
    await repo.like(videoId);
    void updateList(List<Video> list) {
      final i = list.indexWhere((v) => v.id == videoId);
      if (i >= 0) {
        final v = list[i];
        list[i] = Video(
          id: v.id,
          uid: v.uid,
          title: v.title,
          intro: v.intro,
          coverUrl: v.coverUrl,
          videoUrl: v.videoUrl,
          stars: v.stars,
          likes: (v.likes ?? 0) + 1,
          views: v.views,
          tags: v.tags,
        );
      }
    }

    updateList(_follow);
    updateList(_discover);
    updateList(_featured);
    notifyListeners();
  }

  /// 收藏或取消收藏视频
  /// 返回操作是否成功
  Future<bool> toggleFavorite(String videoId) async {
    final isCurrentlyFavorited = _favoritedIds.contains(videoId);

    // 乐观更新UI
    if (isCurrentlyFavorited) {
      _favoritedIds.remove(videoId);
    } else {
      _favoritedIds.add(videoId);
    }
    _updateFavoriteInLists(videoId, !isCurrentlyFavorited);
    notifyListeners();

    // 调用API
    bool success;
    if (isCurrentlyFavorited) {
      success = await repo.unfavorite(videoId);
    } else {
      success = await repo.favorite(videoId);
    }

    // 如果API调用失败，回滚状态
    if (!success) {
      if (isCurrentlyFavorited) {
        _favoritedIds.add(videoId);
      } else {
        _favoritedIds.remove(videoId);
      }
      _updateFavoriteInLists(videoId, isCurrentlyFavorited);
      notifyListeners();
    }

    return success;
  }

  /// 收藏视频（兼容旧代码）
  Future<void> collect(String videoId) async {
    await toggleFavorite(videoId);
  }

  /// 更新所有列表中视频的收藏状态（只更新状态，不更新收藏数）
  void _updateFavoriteInLists(String videoId, bool isFavorited) {
    void updateList(List<Video> list) {
      final i = list.indexWhere((v) => v.id == videoId);
      if (i >= 0) {
        final v = list[i];
        list[i] = v.copyWith(isFavorited: isFavorited);
      }
    }

    updateList(_follow);
    updateList(_discover);
    updateList(_featured);
    updateList(_recommend);
    updateList(_searchResults);
  }

  Future<void> visit(String videoId) async {
    await repo.visit(videoId);
    void updateList(List<Video> list) {
      final i = list.indexWhere((v) => v.id == videoId);
      if (i >= 0) {
        final v = list[i];
        list[i] = Video(
          id: v.id,
          uid: v.uid,
          title: v.title,
          intro: v.intro,
          coverUrl: v.coverUrl,
          videoUrl: v.videoUrl,
          stars: v.stars,
          likes: v.likes,
          views: (v.views ?? 0) + 1,
          tags: v.tags,
        );
      }
    }

    updateList(_follow);
    updateList(_discover);
    updateList(_featured);
    notifyListeners();
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
    final res = await repo.fetchFeatured(
        VideoQuery(page: _featuredPage, pageSize: 20, keyword: _keyword, tags: _filters));
    _featured.addAll(res.items);
    _featuredHasMore = res.hasMore;
    _featuredPage += 1;
    _loadingFeatured = false;
    notifyListeners();
    debugPrint('VideoProvider.loadMoreFeatured: page=$_featuredPage items_now=${_featured.length} hasMore=$_featuredHasMore');
  }
  
  /// 刷新搜索结果
  Future<void> refreshSearch(String keyword) async {
    debugPrint('VideoProvider.refreshSearch: start keyword=$keyword');
    _searchPage = 1;
    _searchKeyword = keyword;
    _searchResults = [];
    _searchHasMore = true;
    await loadMoreSearch();
    debugPrint('VideoProvider.refreshSearch: done items=${_searchResults.length}');
  }
  
  /// 加载更多搜索结果
  Future<void> loadMoreSearch() async {
    if (_loadingSearch || !_searchHasMore || _searchKeyword == null) return;
    debugPrint('VideoProvider.loadMoreSearch: page=$_searchPage keyword=$_searchKeyword');
    _loadingSearch = true;
    notifyListeners();
    
    try {
      final res = await repo.fetchSearch(_searchKeyword!, _searchPage, 20);
      _searchResults.addAll(res.items);
      _searchHasMore = res.hasMore;
      _searchPage += 1;
    } catch (e) {
      debugPrint('VideoProvider.loadMoreSearch: error=$e');
    } finally {
      _loadingSearch = false;
      notifyListeners();
      debugPrint('VideoProvider.loadMoreSearch: page=$_searchPage items_now=${_searchResults.length} hasMore=$_searchHasMore');
    }
  }

  /// 发布视频
  ///
  /// [filePath] 本地视频文件路径
  /// [title] 视频标题
  /// [description] 视频描述
  /// [userId] 用户ID
  /// [tags] 标签列表（可选）
  Future<bool> publishVideo({
    required String filePath,
    required String title,
    required String description,
    required String userId,
    List<String> tags = const [],
  }) async {
    if (_publishProgress.isInProgress) {
      return false;
    }

    _publishProgress = PublishProgress.uploading(0);
    notifyListeners();

    try {
      final request = VideoPublishRequest(
        filePath: filePath,
        title: title,
        description: description,
        userId: userId,
        tags: tags,
      );

      final response = await repo.publish(
        request,
        onProgress: (progress) {
          _publishProgress = PublishProgress.uploading(progress);
          notifyListeners();
        },
      );

      if (response.isSuccess) {
        _publishProgress = PublishProgress.success();
        notifyListeners();
        await refreshDiscover();
        return true;
      } else {
        _publishProgress = PublishProgress.failed(response.message);
        notifyListeners();
        return false;
      }
    } catch (e) {
      final errorMsg = e.toString();
      _publishProgress = PublishProgress.failed(errorMsg);
      notifyListeners();
      return false;
    }
  }

  void resetPublishProgress() {
    _publishProgress = PublishProgress.idle();
    notifyListeners();
  }

  // ==================== 推荐视频相关方法 ====================

  /// 刷新推荐视频（使用新推荐接口）
  Future<void> refreshRecommend({String? category}) async {
    _recommend = [];
    _lastVisit = null;
    _recommendHasMore = true;
    await loadMoreRecommend(category: category);
  }

  /// 加载更多推荐视频
  Future<void> loadMoreRecommend({String? category}) async {
    if (_loadingRecommend || !_recommendHasMore) return;
    _loadingRecommend = true;
    notifyListeners();

    try {
      final res = await repo.fetchRecommend(
        limit: 10,
        category: category,
        lastVisit: _lastVisit,
      );

      // 标记已收藏的视频
      final items = res.items.map((v) {
        if (_favoritedIds.contains(v.id)) {
          return v.copyWith(isFavorited: true);
        }
        return v;
      }).toList();

      _recommend.addAll(items);
      _recommendHasMore = res.hasMore;

      // 更新游标（如果最后一个视频有views，用作下次请求的last_visit）
      if (items.isNotEmpty) {
        _lastVisit = items.last.views ?? DateTime.now().millisecondsSinceEpoch;
      }

      debugPrint('VideoProvider.loadMoreRecommend: items=${items.length} total=${_recommend.length} hasMore=$_recommendHasMore');
    } catch (e) {
      debugPrint('VideoProvider.loadMoreRecommend: error=$e');
    } finally {
      _loadingRecommend = false;
      notifyListeners();
    }
  }

  // ==================== 收藏列表相关方法 ====================

  /// 刷新收藏列表
  Future<void> refreshFavorites() async {
    _favoritesPage = 1;
    _favorites = [];
    _favoritesHasMore = true;
    await loadMoreFavorites();
  }

  /// 加载更多收藏
  Future<void> loadMoreFavorites() async {
    if (_loadingFavorites || !_favoritesHasMore) return;
    _loadingFavorites = true;
    notifyListeners();

    try {
      final res = await repo.fetchFavorites(_favoritesPage, 20);
      _favorites.addAll(res.items);

      // 更新收藏ID缓存
      for (final v in res.items) {
        _favoritedIds.add(v.id);
      }

      _favoritesHasMore = res.hasMore;
      _favoritesPage += 1;
      debugPrint('VideoProvider.loadMoreFavorites: page=$_favoritesPage items=${res.items.length} total=${_favorites.length}');
    } catch (e) {
      debugPrint('VideoProvider.loadMoreFavorites: error=$e');
    } finally {
      _loadingFavorites = false;
      notifyListeners();
    }
  }

}
