class Drama {
  final int id;
  final String title;
  final String coverUrl;
  final String description;
  final String category;
  final String tags;
  final int totalEpisodes;
  final int freeEpisodeCount;
  final int bundlePrice;
  final int status;
  final int playCount;
  final int likeCount;

  const Drama({
    required this.id,
    required this.title,
    this.coverUrl = '',
    this.description = '',
    this.category = '',
    this.tags = '',
    this.totalEpisodes = 0,
    this.freeEpisodeCount = 3,
    this.bundlePrice = 0,
    this.status = 1,
    this.playCount = 0,
    this.likeCount = 0,
  });

  factory Drama.fromJson(Map<String, dynamic> j) => Drama(
        id: _asInt(j['id']),
        title: '${j['title'] ?? ''}',
        coverUrl: '${j['cover_url'] ?? ''}',
        description: '${j['description'] ?? ''}',
        category: '${j['category'] ?? ''}',
        tags: '${j['tags'] ?? ''}',
        totalEpisodes: _asInt(j['total_episodes']),
        freeEpisodeCount: _asInt(j['free_episode_count'], 3),
        bundlePrice: _asInt(j['bundle_price']),
        status: _asInt(j['status'], 1),
        playCount: _asInt(j['play_count']),
        likeCount: _asInt(j['like_count']),
      );
}

class Episode {
  final int id;
  final int dramaId;
  final int episodeNo;
  final String title;
  final String videoUrl;
  final String coverUrl;
  final int duration;
  final bool isFree;
  final int unlockPrice;
  final int visitCount;
  final int likeCount;

  const Episode({
    required this.id,
    required this.dramaId,
    required this.episodeNo,
    this.title = '',
    this.videoUrl = '',
    this.coverUrl = '',
    this.duration = 0,
    this.isFree = false,
    this.unlockPrice = 10,
    this.visitCount = 0,
    this.likeCount = 0,
  });

  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
        id: _asInt(j['id']),
        dramaId: _asInt(j['drama_id']),
        episodeNo: _asInt(j['episode_no']),
        title: '${j['title'] ?? ''}',
        videoUrl: '${j['video_url'] ?? ''}',
        coverUrl: '${j['cover_url'] ?? ''}',
        duration: _asInt(j['duration']),
        isFree: j['is_free'] == true || j['is_free'] == 1,
        unlockPrice: _asInt(j['unlock_price'], 10),
        visitCount: _asInt(j['visit_count']),
        likeCount: _asInt(j['like_count']),
      );
}

class FeedItem {
  final Drama drama;
  final Episode episode;
  final bool locked;

  const FeedItem({
    required this.drama,
    required this.episode,
    this.locked = false,
  });

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
        drama: Drama.fromJson(Map<String, dynamic>.from(j['drama'] as Map? ?? {})),
        episode: Episode.fromJson(Map<String, dynamic>.from(j['episode'] as Map? ?? {})),
        locked: j['locked'] == true,
      );
}

class PlayInfo {
  final Episode episode;
  final Drama drama;
  final bool locked;
  final int unlockPrice;
  final bool canPlay;
  final String videoUrl;
  /// 外挂字幕（WebVTT/SRT 文本或可下载 URL，客户端自行判断）
  final String subtitleUrl;
  /// 多清晰度原始列表（[{label,url}]），可空
  final List<dynamic> qualities;

  const PlayInfo({
    required this.episode,
    required this.drama,
    this.locked = false,
    this.unlockPrice = 10,
    this.canPlay = false,
    this.videoUrl = '',
    this.subtitleUrl = '',
    this.qualities = const [],
  });

  factory PlayInfo.fromJson(Map<String, dynamic> j) => PlayInfo(
        episode: Episode.fromJson(Map<String, dynamic>.from(j['episode'] as Map? ?? {})),
        drama: Drama.fromJson(Map<String, dynamic>.from(j['drama'] as Map? ?? {})),
        locked: j['locked'] == true,
        unlockPrice: _asInt(j['unlock_price'], 10),
        canPlay: j['can_play'] == true,
        videoUrl: '${j['video_url'] ?? ''}',
        subtitleUrl: '${j['subtitle_url'] ?? j['subtitle'] ?? ''}',
        qualities: (j['qualities'] as List?) ?? const [],
      );
}

class WalletInfo {
  final int userId;
  final int balance;

  const WalletInfo({required this.userId, required this.balance});

  factory WalletInfo.fromJson(Map<String, dynamic> j) => WalletInfo(
        userId: _asInt(j['user_id']),
        balance: _asInt(j['balance']),
      );
}

class ContinueItem {
  final Drama? drama;
  final Episode? episode;
  final int episodeId;
  final int episodeNo;
  final int positionSec;

  const ContinueItem({
    this.drama,
    this.episode,
    this.episodeId = 0,
    this.episodeNo = 1,
    this.positionSec = 0,
  });

  /// 跳转详情用的集 ID（优先嵌套 episode，其次 progress）
  int get resumeEpisodeId {
    if (episodeId > 0) return episodeId;
    return episode?.id ?? 0;
  }

  factory ContinueItem.fromJson(Map<String, dynamic> j) {
    final progress = j['progress'] is Map ? Map<String, dynamic>.from(j['progress'] as Map) : <String, dynamic>{};
    final episode = j['episode'] is Map ? Episode.fromJson(Map<String, dynamic>.from(j['episode'] as Map)) : null;
    final no = _asInt(progress['episode_no']);
    final epId = _asInt(progress['episode_id']);
    return ContinueItem(
      drama: j['drama'] is Map ? Drama.fromJson(Map<String, dynamic>.from(j['drama'] as Map)) : null,
      episode: episode,
      episodeId: epId > 0 ? epId : (episode?.id ?? 0),
      episodeNo: no > 0 ? no : (episode?.episodeNo ?? 1),
      positionSec: _asInt(progress['position_sec']),
    );
  }
}

int _asInt(dynamic v, [int def = 0]) {
  if (v == null) return def;
  if (v is int) return v;
  return int.tryParse('$v') ?? def;
}
