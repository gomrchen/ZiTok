import 'package:flutter/material.dart';
import 'package:zitok/l10n/app_localizations.dart';

/// 播放器左下信息层（红果式）：
/// 弹幕入口 → 新剧角标+标题 → 标签胶囊 → 集数|剧情+展开 → 完整短剧 CTA
class PlayerBottomMeta extends StatefulWidget {
  final String title;
  final int episodeNo;
  final String synopsis;
  final List<String> tags;
  final int totalEpisodes;
  final bool showNewBadge;
  final VoidCallback? onTitleTap;
  final VoidCallback? onEpisodeTap;
  final VoidCallback? onWatchFull;
  final ValueChanged<String>? onTagTap;
  final VoidCallback? onDanmakuTap;

  const PlayerBottomMeta({
    super.key,
    required this.title,
    required this.episodeNo,
    this.synopsis = '',
    this.tags = const [],
    this.totalEpisodes = 0,
    this.showNewBadge = false,
    this.onTitleTap,
    this.onEpisodeTap,
    this.onWatchFull,
    this.onTagTap,
    this.onDanmakuTap,
  });

  @override
  State<PlayerBottomMeta> createState() => _PlayerBottomMetaState();
}

const _kPillBg = Color(0x66000000);
const _kCtaBg = Color(0x99000000);
const _kBadgeTeal = Color(0xFF1DBA9A);

class _PlayerBottomMetaState extends State<PlayerBottomMeta> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final synopsis = widget.synopsis.trim();
    final epLabel = l10n.playerEpisodeNo(widget.episodeNo);
    final line = synopsis.isEmpty ? epLabel : '$epLabel | $synopsis';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onDanmakuTap != null) ...[
          _DanmakuChip(
            label: l10n.playerDanmaku,
            onTap: widget.onDanmakuTap!,
          ),
          const SizedBox(height: 10),
        ],
        // 标题行：新剧 + 剧名 >
        GestureDetector(
          onTap: widget.onTitleTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.showNewBadge) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kBadgeTeal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.playerNewDrama,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: 0.15,
                          shadows: [
                            Shadow(
                              color: Color(0x99000000),
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onTitleTap != null)
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in widget.tags)
                _MetaPill(
                  label: tag,
                  onTap: widget.onTagTap == null ? null : () => widget.onTagTap!(tag),
                ),
            ],
          ),
        ],
        if (line.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: synopsis.isEmpty
                ? widget.onEpisodeTap
                : () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    line,
                    maxLines: _expanded ? 6 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      height: 1.35,
                      shadows: const [
                        Shadow(
                          color: Color(0x88000000),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                if (synopsis.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    _expanded ? l10n.playerCollapse : l10n.playerExpand,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (widget.totalEpisodes > 0 && widget.onWatchFull != null) ...[
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onWatchFull,
              borderRadius: BorderRadius.circular(8),
              child: Ink(
                decoration: BoxDecoration(
                  color: _kCtaBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.playerWatchFull(widget.totalEpisodes),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DanmakuChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DanmakuChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _MetaPill({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kPillBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
