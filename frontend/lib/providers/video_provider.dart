import 'package:flutter/material.dart';
import '../repositories/video_repository.dart';
import '../models/video.dart';
import '../models/video_publish.dart';
import '../services/user_session.dart';
import '../utils/app_config.dart';

class VideoProvider extends ChangeNotifier {
  final VideoRepository repo;
  final UserSession userSession;

  /// 上一次的用户 ID，用于检测用户切换
  String? _lastUserId;

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

  // 点赞状态缓存 - 记录已点赞的视频ID
  final Set<String> _likedIds = {};

  // 投稿相关状态
  PublishProgress _publishProgress = PublishProgress.idle();

  // 搜索状态
  List<Video> _searchResults = [];
  bool _loadingSearch = false;
  bool _searchHasMore = true;
  int _searchPage = 1;
  String? _searchKeyword;

  VideoProvider({required this.repo, UserSession? userSession})
      : userSession = userSession ?? UserSession.instance {
    // 监听 UserSession 变化，当用户切换时清理数据
    this.userSession.addListener(_onUserSessionChanged);
    _lastUserId = this.userSession.userId;
  }

  /// 当 UserSession 变化时调用
  void _onUserSessionChanged() {
    final currentUserId = userSession.userId;

    // 检测用户 ID 是否变化（包括登出变为 null）
    if (currentUserId != _lastUserId) {
      AppConfig.log('VideoProvider: 用户切换 $_lastUserId -> $currentUserId，清理缓存数据');
      _lastUserId = currentUserId;
      clearUserData();
    }
  }

  /// 清理所有用户相关的数据（用户切换或登出时调用）
  void clearUserData() {
    // 清理收藏相关
    _favorites = [];
    _favoritedIds.clear();
    _favoritesPage = 1;
    _favoritesHasMore = true;
    _loadingFavorites = false;

    // 清理点赞缓存
    _likedIds.clear();

    // 清理关注流
    _follow = [];
    _followPage = 1;
    _followHasMore = true;
    _loadingFollow = false;
    _followError = null;
    _followScrollOffset = 0.0;

    // 清理推荐（用户相关的推荐）
    _recommend = [];
    _lastVisit = 0;
    _recommendHasMore = true;
    _loadingRecommend = false;
    _recommendStartIndexInFollow = null;

    // 清理搜索结果
    _searchResults = [];
    _searchPage = 1;
    _searchHasMore = true;
    _loadingSearch = false;
    _searchKeyword = null;

    // 清理投稿进度
    _publishProgress = PublishProgress.idle();

    notifyListeners();
  }

  @override
  void dispose() {
    userSession.removeListener(_onUserSessionChanged);
    super.dispose();
  }

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

  /// 检查视频是否已点赞
  bool isLiked(String videoId) => _likedIds.contains(videoId);

  /// 切换点赞状态
  Future<bool> toggleLike(String videoId) async {
    final isCurrentlyLiked = _likedIds.contains(videoId);

    // 乐观更新UI
    if (isCurrentlyLiked) {
      _likedIds.remove(videoId);
    } else {
      _likedIds.add(videoId);
    }
    _updateLikeInLists(videoId, !isCurrentlyLiked);
    notifyListeners();

    // 调用API（目前只有点赞，没有取消点赞接口）
    try {
      if (!isCurrentlyLiked) {
        await repo.like(videoId);
      }
      // 如果是取消点赞，后端暂不支持，只在本地更新
      return true;
    } catch (e) {
      // API调用失败，回滚状态
      if (isCurrentlyLiked) {
        _likedIds.add(videoId);
      } else {
        _likedIds.remove(videoId);
      }
      _updateLikeInLists(videoId, isCurrentlyLiked);
      notifyListeners();
      return false;
    }
  }

  /// 更新所有列表中视频的点赞状态
  void _updateLikeInLists(String videoId, bool isLiked) {
    void updateList(List<Video> list) {
      final i = list.indexWhere((v) => v.id == videoId);
      if (i >= 0) {
        final v = list[i];
        final likeDelta = isLiked ? 1 : -1;
        list[i] = v.copyWith(
          isLiked: isLiked,
          likes: ((v.likes ?? 0) + likeDelta).clamp(0, double.maxFinite.toInt()),
        );
      }
    }

    updateList(_follow);
    updateList(_discover);
    updateList(_featured);
    updateList(_recommend);
    updateList(_searchResults);
  }

  /// 旧版点赞方法（兼容，建议使用 toggleLike）
  Future<void> like(String videoId) async {
    await toggleLike(videoId);
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
    AppConfig.log('VideoProvider.loadMoreFeatured: page=$_featuredPage items_now=${_featured.length} hasMore=$_featuredHasMore');
  }
  
  /// 刷新搜索结果
  Future<void> refreshSearch(String keyword) async {
    AppConfig.log('VideoProvider.refreshSearch: start keyword=$keyword');
    _searchPage = 1;
    _searchKeyword = keyword;
    _searchResults = [];
    _searchHasMore = true;
    await loadMoreSearch();
    AppConfig.log('VideoProvider.refreshSearch: done items=${_searchResults.length}');
  }
  
  /// 加载更多搜索结果
  Future<void> loadMoreSearch() async {
    if (_loadingSearch || !_searchHasMore || _searchKeyword == null) return;
    AppConfig.log('VideoProvider.loadMoreSearch: page=$_searchPage keyword=$_searchKeyword');
    _loadingSearch = true;
    notifyListeners();
    
    try {
      final res = await repo.fetchSearch(_searchKeyword!, _searchPage, 20);
      _searchResults.addAll(res.items);
      _searchHasMore = res.hasMore;
      _searchPage += 1;
    } catch (e) {
      AppConfig.log('VideoProvider.loadMoreSearch: error=$e');
    } finally {
      _loadingSearch = false;
      notifyListeners();
      AppConfig.log('VideoProvider.loadMoreSearch: page=$_searchPage items_now=${_searchResults.length} hasMore=$_searchHasMore');
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
    _lastVisit = 0;
    _recommendHasMore = true;
    await loadMoreRecommend(category: category);
  }

  /// 加载更多推荐视频
  /// 实现无限滚动：UI层使用虚拟索引循环显示，Provider持续尝试获取新内容
  Future<void> loadMoreRecommend({String? category}) async {
    if (_loadingRecommend) return;

    _loadingRecommend = true;
    notifyListeners();

    try {
      final res = await repo.fetchRecommend(
        limit: 10,
        category: category,
        lastVisit: _lastVisit,
      );

      // 标记已收藏和已点赞的视频
      final items = res.items.map((v) {
        Video updated = v;
        if (_favoritedIds.contains(v.id)) {
          updated = updated.copyWith(isFavorited: true);
        }
        if (_likedIds.contains(v.id)) {
          updated = updated.copyWith(isLiked: true);
        }
        return updated;
      }).toList();

      // 过滤掉已存在的视频ID，避免列表中出现重复
      final existingIds = _recommend.map((v) => v.id).toSet();
      final newItems = items.where((v) => !existingIds.contains(v.id)).toList();

      if (newItems.isNotEmpty) {
        // 有新视频，添加到列表
        _recommend.addAll(newItems);
        AppConfig.log('VideoProvider.loadMoreRecommend: 添加 ${newItems.length} 个新视频，总数 ${_recommend.length}');
      }

      // 更新游标
      if (items.isNotEmpty) {
        _lastVisit = items.last.views ?? DateTime.now().millisecondsSinceEpoch;
      }

      // 如果后端没有更多数据，重置游标从头开始获取
      // 这样下次调用时会从头开始，可能获取到之前没看过的视频
      if (!res.hasMore) {
        AppConfig.log('VideoProvider.loadMoreRecommend: 后端无更多数据，重置游标准备下一轮');
        _lastVisit = 0;
      }

      // 始终保持 hasMore 为 true，让 UI 可以继续请求
      // UI 层会通过虚拟索引循环显示已有视频
      _recommendHasMore = true;

      AppConfig.log('VideoProvider.loadMoreRecommend: fetched=${items.length} new=${newItems.length} total=${_recommend.length}');
    } catch (e) {
      AppConfig.log('VideoProvider.loadMoreRecommend: error=$e');
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
      AppConfig.log('VideoProvider.loadMoreFavorites: page=$_favoritesPage items=${res.items.length} total=${_favorites.length}');
    } catch (e) {
      AppConfig.log('VideoProvider.loadMoreFavorites: error=$e');
    } finally {
      _loadingFavorites = false;
      notifyListeners();
    }
  }

}
