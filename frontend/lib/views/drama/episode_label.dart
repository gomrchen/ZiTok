import '../../models/drama_models.dart';

/// 从短剧拆出信息层标签：分类 + tags，最多 [max] 个
List<String> dramaMetaTags(Drama drama, {int max = 4}) {
  final out = <String>[];
  final cat = drama.category.trim();
  if (cat.isNotEmpty) out.add(cat);
  for (final raw in drama.tags.split(RegExp(r'[,，、|/\s]+'))) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    if (out.any((e) => e == t)) continue;
    out.add(t);
    if (out.length >= max) break;
  }
  return out;
}

/// 剧情摘要：优先剧简介，否则本集标题
String dramaSynopsis(Drama drama, Episode episode) {
  final d = drama.description.trim();
  if (d.isNotEmpty) return d;
  final t = episode.title.trim();
  if (t.isNotEmpty && !RegExp(r'^第\s*\d+\s*集$').hasMatch(t)) return t;
  return '';
}

bool dramaShowNewBadge(Drama drama) {
  final blob = '${drama.tags}${drama.category}${drama.title}';
  if (blob.contains('新剧') || blob.contains('上新') || blob.contains('新上')) {
    return true;
  }
  return drama.playCount > 0 && drama.playCount < 8000;
}
