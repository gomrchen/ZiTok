import '../../models/drama_models.dart';

/// 避免「第2集 · 第2集·xxx」这类重复文案
String episodeSubtitle(Episode ep, {String? category}) {
  final title = ep.title.trim();
  final no = ep.episodeNo;
  final alreadyHasNo = RegExp(r'^第\s*\d+\s*集').hasMatch(title);
  final main = title.isEmpty
      ? '第$no集'
      : (alreadyHasNo ? title : '第$no集 · $title');
  final cat = (category ?? '').trim();
  if (cat.isEmpty) return main;
  return '$main · $cat';
}
