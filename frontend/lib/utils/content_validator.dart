class ContentValidator {
  static const _illegalWords = <String>[
    '违法', '赌博', '色情', '暴力', '仇恨', '毒品', '恐怖', '诈骗'
  ];

  static bool isSupportedVideo(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.mp4') || n.endsWith('.mov') || n.endsWith('.avi') || n.endsWith('.mkv');
  }

  static bool isSupportedMarkdown(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.md') || n.endsWith('.markdown');
  }

  static String summarize(String text, {int maxLen = 100}) {
    final t = text.trim();
    if (t.length <= maxLen) return t;
    return t.substring(0, maxLen) + '…';
  }

  static List<String> extractTags(String text) {
    final regex = RegExp(r'#([\w\-]+)');
    return regex
        .allMatches(text)
        .map((m) => m.group(1)!)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
  }

  static String? findIllegal(String text) {
    final t = text.toLowerCase();
    for (final w in _illegalWords) {
      if (t.contains(w)) return w;
    }
    return null;
  }
}