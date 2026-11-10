import 'package:flutter/foundation.dart';
import '../models/drama_models.dart';
import '../services/drama_service.dart';

bool _ok(dynamic code) {
  final s = '$code';
  return s == '10000' || s == '200' || s == '0';
}

Map<String, dynamic>? _data(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  if (!_ok(m['code'])) return null;
  final d = m['data'];
  if (d is Map) return Map<String, dynamic>.from(d);
  return m;
}

class DramaProvider extends ChangeNotifier {
  final DramaService dramaService;
  final CommerceService commerceService;

  DramaProvider({required this.dramaService, required this.commerceService});

  List<FeedItem> feed = [];
  int _feedPage = 1;
  bool loadingFeed = false;
  bool hasMoreFeed = true;
  String? feedError;

  List<Drama> theater = [];
  bool loadingTheater = false;

  List<ContinueItem> continueList = [];
  List<Drama> favorites = [];
  bool loadingWatching = false;

  WalletInfo? wallet;
  List<Map<String, dynamic>> ledger = [];

  Future<void> refreshFeed() async {
    loadingFeed = true;
    feedError = null;
    notifyListeners();
    try {
      final resp = await dramaService.feed(page: 1, size: 10);
      final data = _data(resp.data);
      if (data == null) throw Exception('feed failed');
      final list = (data['list'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      feed = list;
      _feedPage = 1;
      hasMoreFeed = list.isNotEmpty;
    } catch (e) {
      feedError = '$e';
    } finally {
      loadingFeed = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreFeed() async {
    if (loadingFeed || !hasMoreFeed) return;
    loadingFeed = true;
    notifyListeners();
    try {
      final next = _feedPage + 1;
      final resp = await dramaService.feed(page: next, size: 10);
      final data = _data(resp.data);
      if (data == null) return;
      final list = (data['list'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isEmpty) {
        hasMoreFeed = false;
      } else {
        feed = [...feed, ...list];
        _feedPage = next;
      }
    } finally {
      loadingFeed = false;
      notifyListeners();
    }
  }

  Future<void> refreshTheater({String? category}) async {
    loadingTheater = true;
    notifyListeners();
    try {
      final resp = await dramaService.list(category: category);
      final data = _data(resp.data);
      theater = (data?['list'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Drama.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } finally {
      loadingTheater = false;
      notifyListeners();
    }
  }

  Future<void> refreshWatching() async {
    loadingWatching = true;
    notifyListeners();
    try {
      final c = await dramaService.continueWatching();
      final cd = _data(c.data);
      continueList = (cd?['list'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ContinueItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final f = await dramaService.favorites();
      final fd = _data(f.data);
      favorites = (fd?['list'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Drama.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      // 未登录时忽略
    } finally {
      loadingWatching = false;
      notifyListeners();
    }
  }

  Future<PlayInfo?> loadPlayInfo(int episodeId) async {
    final resp = await dramaService.playInfo(episodeId);
    final data = _data(resp.data);
    if (data == null) return null;
    return PlayInfo.fromJson(data);
  }

  Future<void> reportProgress(FeedItem item, {int positionSec = 0}) async {
    final no = item.episode.episodeNo > 0 ? item.episode.episodeNo : 1;
    try {
      await dramaService.reportProgress(
        dramaId: item.drama.id,
        episodeId: item.episode.id,
        episodeNo: no,
        positionSec: positionSec,
      );
    } catch (_) {}
  }

  Future<bool> unlockEpisode(int episodeId) async {
    final resp = await commerceService.unlockEpisode(episodeId);
    final data = _data(resp.data);
    if (data == null) return false;
    if (data['balance'] != null) {
      wallet = WalletInfo(userId: wallet?.userId ?? 0, balance: _asInt(data['balance']));
    }
    notifyListeners();
    return true;
  }

  Future<bool> adUnlock(int episodeId) async {
    final resp = await commerceService.adUnlock(episodeId);
    final data = _data(resp.data);
    if (data == null) return false;
    await refreshWallet();
    return true;
  }

  Future<void> refreshWallet() async {
    try {
      final resp = await commerceService.wallet();
      final data = _data(resp.data);
      if (data != null) wallet = WalletInfo.fromJson(data);
      final led = await commerceService.ledger();
      final ld = _data(led.data);
      ledger = (ld?['list'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> mockTopup([int amount = 100]) async {
    final resp = await commerceService.mockTopup(amount: amount);
    final data = _data(resp.data);
    if (data != null && data['balance'] != null) {
      wallet = WalletInfo(userId: wallet?.userId ?? 0, balance: _asInt(data['balance']));
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(int dramaId, {required bool currentlyFav}) async {
    if (currentlyFav) {
      await dramaService.unfavorite(dramaId);
    } else {
      await dramaService.favorite(dramaId);
    }
    await refreshWatching();
  }
}

int _asInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}
