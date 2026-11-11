import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import 'unlock_sheet.dart';

class DramaDetailLoadResult {
  final Drama? drama;
  final List<Episode> episodes;
  final bool favorite;
  final Set<int> unlocked;

  const DramaDetailLoadResult({
    this.drama,
    required this.episodes,
    this.favorite = false,
    this.unlocked = const {},
  });
}

/// 详情接口：解析分集（排序）+ 可选解锁探测 / 剧信息
Future<DramaDetailLoadResult> loadDramaDetailBundle(
  DramaProvider dp,
  int dramaId, {
  bool probeUnlocked = false,
  bool requireEpisodes = false,
  bool parseDrama = false,
}) async {
  final resp = await dp.dramaService.detail(dramaId);
  final raw = resp.data;
  if (raw is! Map || '${raw['code']}' != '10000') {
    throw StateError('drama_detail_failed');
  }
  final data = Map<String, dynamic>.from(raw['data'] as Map);
  final eps = (data['episodes'] as List? ?? [])
      .whereType<Map>()
      .map((e) => Episode.fromJson(Map<String, dynamic>.from(e)))
      .toList()
    ..sort((a, b) => a.episodeNo.compareTo(b.episodeNo));
  if (requireEpisodes && eps.isEmpty) {
    throw StateError('no_episodes');
  }
  Drama? drama;
  if (parseDrama) {
    if (data['drama'] is! Map) throw StateError('drama_missing');
    drama = Drama.fromJson(Map<String, dynamic>.from(data['drama'] as Map));
  }
  final unlocked =
      probeUnlocked ? await probeUnlockedEpisodeIds(dp, eps) : const <int>{};
  return DramaDetailLoadResult(
    drama: drama,
    episodes: eps,
    favorite: data['favorite'] == true,
    unlocked: unlocked,
  );
}
