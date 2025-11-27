import 'package:flutter/material.dart';
import '../repositories/video_repository.dart';
import '../models/video.dart';
import '../models/video_publish.dart';

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

  // 投稿相关状态
  PublishProgress _publishProgress = PublishProgress.idle();

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

  // 投稿相关getter
  PublishProgress get publishProgress => _publishProgress;

  Future<void> refreshDiscover({String? keyword, List<String>? tags}) async {
    debugPrint('VideoProvider.refreshDiscover: start keyword=$keyword');
    _discoverPage = 1;
    _keyword = keyword;
    _filters = tags;
    _discover = [];
    _discoverHasMore = true;
    await loadMoreDiscover();
    debugPrint('VideoProvider.refreshDiscover: done items=${_discover.length}');
  }

  Future<void> loadMoreDiscover() async {
    if (_loadingDiscover || !_discoverHasMore) return;
    debugPrint('VideoProvider.loadMoreDiscover: page=$_discoverPage');
    _loadingDiscover = true;
    notifyListeners();
    final res = await repo.fetchDiscover(VideoQuery(page: _discoverPage, pageSize: 20, keyword: _keyword, tags: _filters));
    _discover.addAll(res.items);
    print('discoverppppppppppppp: ');print(_discover);
    _discoverHasMore = res.hasMore;
    _discoverPage += 1;
    _loadingDiscover = false;
    notifyListeners();
    debugPrint('VideoProvider.loadMoreDiscover: page=$_discoverPage items_now=${_discover.length} hasMore=$_discoverHasMore');
  }

  /// 刷新关注流：当关注内容不足时，自动拼接精选推荐
  Future<void> refreshFollow() async {
    debugPrint('VideoProvider.refreshFollow: start');
    _followPage = 1;
    _follow = [];
    _followHasMore = true;
    _followError = null;
    _recommendStartIndexInFollow = null;
    await loadMoreFollow();
    debugPrint('VideoProvider.refreshFollow: done items=${_follow.length}');
  }

  Future<void> loadMoreFollow() async {
    if (_loadingFollow || !_followHasMore) return;
    debugPrint('VideoProvider.loadMoreFollow: page=$_followPage');
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
      debugPrint('VideoProvider.loadMoreFollow: error=$_followError');
    } finally {
      _loadingFollow = false;
      notifyListeners();
      debugPrint('VideoProvider.loadMoreFollow: page=$_followPage items_now=${_follow.length} hasMore=$_followHasMore');
    }
  }

  /// 更新关注页的滚动位置，以便返回时恢复
  void setFollowScrollOffset(double offset) {
    _followScrollOffset = offset;
  }

  /// 点赞（本地更新），真实项目中应调用后端接口并做失败回滚
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
    debugPrint('VideoProvider.refreshFeatured: start');
    _featuredPage = 1;
    _keyword = keyword;
    _filters = tags;
    _featured = [];
    _featuredHasMore = true;
    await loadMoreFeatured();
    debugPrint('VideoProvider.refreshFeatured: done items=${_featured.length}');
  }

  Future<void> loadMoreFeatured() async {
    if (_loadingFeatured || !_featuredHasMore) return;
    debugPrint('VideoProvider.loadMoreFeatured: page=$_featuredPage');
    _loadingFeatured = true;
    notifyListeners();
    final res = await repo.fetchFeatured(VideoQuery(page: _featuredPage, pageSize: 20, keyword: _keyword, tags: _filters));
    _featured.addAll(res.items);
    _featuredHasMore = res.hasMore;
    _featuredPage += 1;
    _loadingFeatured = false;
    notifyListeners();
    debugPrint('VideoProvider.loadMoreFeatured: page=$_featuredPage items_now=${_featured.length} hasMore=$_featuredHasMore');
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
      debugPrint('VideoProvider.publishVideo: already in progress, skipping');
      return false;
    }

    debugPrint('VideoProvider.publishVideo: start filePath=$filePath');
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
        debugPrint('VideoProvider.publishVideo: success');
        // 发布成功后刷新发现页
        await refreshDiscover();
        return true;
      } else {
        _publishProgress = PublishProgress.failed(response.message);
        notifyListeners();
        debugPrint('VideoProvider.publishVideo: failed message=${response.message}');
        return false;
      }
    } catch (e) {
      final errorMsg = e.toString();
      _publishProgress = PublishProgress.failed(errorMsg);
      notifyListeners();
      debugPrint('VideoProvider.publishVideo: error=$errorMsg');
      return false;
    }
  }

  /// 重置发布状态
  void resetPublishProgress() {
    _publishProgress = PublishProgress.idle();
    notifyListeners();
  }
}
