import 'package:flutter/material.dart';
import '../repositories/video_repository.dart';
import '../models/video.dart';
import '../models/video_publish.dart';

class VideoProvider extends ChangeNotifier {
  final VideoRepository repo;
  List<Video> _discover = [];
  List<Video> _featured = [];
  List<Video> _follow = [];
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
  String? _followError;
  double _followScrollOffset = 0.0;
  int? _recommendStartIndexInFollow;

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

  PublishProgress get publishProgress => _publishProgress;

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

  Future<void> collect(String videoId) async {
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
          stars: (v.stars ?? 0) + 1,
          likes: v.likes,
          views: v.views,
          commentCount: v.commentCount,
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
  }

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
}
