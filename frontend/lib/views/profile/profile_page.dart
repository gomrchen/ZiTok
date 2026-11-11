import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n_ext.dart';
import '../../models/drama_models.dart';
import '../../providers/drama_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/url_utils.dart';
import '../../widgets/glass_nav.dart';
import '../home/shell_surface.dart';

/// 短剧个人中心 — 夜戏光影：墨色氛围头图 + 金币条 + 色块入口 + 横滑海报
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  static const _coral = ShellSurface.coral;

  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 720))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final profile = context.read<ProfileProvider>();
      final drama = context.read<DramaProvider>();
      await profile.loadCurrentUser();
      if (!mounted) return;
      await drama.refreshWallet();
      if (!mounted) return;
      await drama.refreshWatching();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final profile = context.read<ProfileProvider>();
    final drama = context.read<DramaProvider>();
    await profile.loadCurrentUser();
    if (!mounted) return;
    await drama.refreshWallet();
    if (!mounted) return;
    await drama.refreshWatching();
  }

  Animation<double> _fade(double start, double end) {
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final drama = context.watch<DramaProvider>();
    final user = profile.user;
    // viewPadding：即使父 Scaffold extendBody 改写了 padding，也能顶到刘海
    final top = MediaQuery.viewPaddingOf(context).top;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    if (profile.loading && user == null) {
      return Scaffold(
        backgroundColor: ShellSurface.canvasOf(context),
        body: const Center(child: CircularProgressIndicator(color: _coral)),
      );
    }
    if (profile.error != null && user == null) {
      return Scaffold(
        backgroundColor: ShellSurface.canvasOf(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${profile.error}',
                style: TextStyle(color: ShellSurface.inkOf(context)),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _coral),
                onPressed: _refresh,
                child: Text(context.l10n.profileRetry),
              ),
            ],
          ),
        ),
      );
    }

    final l10n = context.l10n;
    final name = user?.username ?? l10n.profileUserFallback;
    final avatar = user?.avatarUrl;
    final bio = (user?.bio ?? '').trim();
    final balance = drama.wallet?.balance ?? 0;
    final favs = drama.favorites;

    final continues = drama.continueList;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: ShellSurface.canvasOf(context),
        extendBodyBehindAppBar: true,
        body: RefreshIndicator(
          color: _coral,
          backgroundColor: ShellSurface.cardOf(context),
          displacement: top + 12,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 头图 + 金币条同一层：顶到刘海，不再用纸色溶入盖住金币
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fade(0.0, 0.5),
                  child: _HeroBlock(
                    topInset: top,
                    name: name,
                    bio: bio.isEmpty ? l10n.profileWriteBio : bio,
                    avatarUrl: avatar,
                    balance: balance,
                    watching: continues.length,
                    favorites: favs.length,
                    onEdit: () => context.push('/profile/edit'),
                    onWallet: () => context.push('/wallet'),
                    onWatching: () => context.push('/watching'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: FadeTransition(
                    opacity: _fade(0.22, 0.65),
                    child: _QuickGrid(
                      continueCount: continues.length,
                      onWallet: () => context.push('/wallet'),
                      onWatching: () => context.push('/watching'),
                      onMessages: () => context.go('/home?tab=2'),
                      onSettings: () => context.push('/settings'),
                    ),
                  ),
                ),
              ),
              if (continues.isNotEmpty)
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fade(0.36, 0.8),
                    child: _ContinueRail(
                      items: continues.take(8).toList(),
                      onAll: () => context.push('/watching'),
                      onTap: (c) {
                        final d = c.drama;
                        if (d == null) return;
                        final ep = c.resumeEpisodeId;
                        context.push(ep > 0 ? '/drama/${d.id}?ep=$ep' : '/drama/${d.id}');
                      },
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fade(0.4, 0.85),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          l10n.profileFavorites,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ShellSurface.inkOf(context),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        if (favs.isNotEmpty)
                          GestureDetector(
                            onTap: () => context.push('/watching'),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    l10n.profileAll,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _coral,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, size: 18, color: _coral),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (favs.isEmpty)
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fade(0.45, 0.9),
                    child: const _EmptyFavorites(),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fade(0.45, 0.9),
                    child: SizedBox(
                      height: 236,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        scrollDirection: Axis.horizontal,
                        itemCount: favs.length.clamp(0, 12),
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _PosterCard(
                          drama: favs[i],
                          onTap: () => context.push('/drama/${favs[i].id}'),
                        ),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: 72 + bottom)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 头图与金币条一体：背景从 y=0 铺满刘海，金币叠在暗色区上，不再被纸色雾盖住
class _HeroBlock extends StatelessWidget {
  final double topInset;
  final String name;
  final String bio;
  final String? avatarUrl;
  final int balance;
  final int watching;
  final int favorites;
  final VoidCallback onEdit;
  final VoidCallback onWallet;
  final VoidCallback onWatching;

  const _HeroBlock({
    required this.topInset,
    required this.name,
    required this.bio,
    required this.avatarUrl,
    required this.balance,
    required this.watching,
    required this.favorites,
    required this.onEdit,
    required this.onWallet,
    required this.onWatching,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0E1117),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 真实夜戏街景底图，铺满含刘海
          Positioned.fill(
            child: Image.asset(
              'assets/images/profile_hero_bg.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.35),
              filterQuality: FilterQuality.high,
            ),
          ),
          // 可读性压暗 + 底部接到纸色
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.42),
                    const Color(0xFF0E1117).withValues(alpha: 0.78),
                    ShellSurface.canvas,
                  ],
                  stops: const [0.0, 0.38, 0.78, 1.0],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                // 刘海下方再留一口气，避免贴 Dynamic Island
                padding: EdgeInsets.fromLTRB(16, topInset + 22, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _Avatar(name: name, avatarUrl: avatarUrl),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ZiTok',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.8,
                                  shadows: const [
                                    Shadow(color: Color(0x88000000), blurRadius: 8),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.08,
                                  letterSpacing: 0.2,
                                  shadows: [
                                    Shadow(color: Color(0x99000000), blurRadius: 10),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                bio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 13,
                                  height: 1.35,
                                  shadows: const [
                                    Shadow(color: Color(0x88000000), blurRadius: 6),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GlassNavButton(
                          icon: Icons.edit_outlined,
                          size: 42,
                          onPressed: onEdit,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _CoinStrip(
                      balance: balance,
                      watching: watching,
                      favorites: favorites,
                      onWallet: onWallet,
                      onWatching: onWatching,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _Avatar({required this.name, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final has = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: has
            ? Image.network(
                UrlUtils.resolveStorageUrl(avatarUrl!, defaultDir: 'avatars'),
                key: ValueKey(avatarUrl),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: const Color(0xFF2ED3BE),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CoinStrip extends StatelessWidget {
  final int balance;
  final int watching;
  final int favorites;
  final VoidCallback onWallet;
  final VoidCallback onWatching;

  const _CoinStrip({
    required this.balance,
    required this.watching,
    required this.favorites,
    required this.onWallet,
    required this.onWatching,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onWallet,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFE8B84A), Color(0xFFFF6B4A)],
                        ),
                      ),
                      child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.profileCoins,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$balance',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.only(right: 4),
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    _MiniStat(label: context.l10n.profileContinueCount, value: '$watching', onTap: onWatching),
                    _MiniStat(label: context.l10n.profileFavCount, value: '$favorites', onTap: onWatching),
                    Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.45), size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _MiniStat({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  final int continueCount;
  final VoidCallback onWallet;
  final VoidCallback onWatching;
  final VoidCallback onMessages;
  final VoidCallback onSettings;

  const _QuickGrid({
    required this.continueCount,
    required this.onWallet,
    required this.onWatching,
    required this.onMessages,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Text(
            l10n.profileQuickEntries,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ShellSurface.inkOf(context),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                title: l10n.profileWallet,
                subtitle: l10n.profileWalletSub,
                icon: Icons.account_balance_wallet_rounded,
                tint: const Color(0xFFFFE8C8),
                iconColor: const Color(0xFFC47A12),
                onTap: onWallet,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickTile(
                title: l10n.profileWatching,
                subtitle: continueCount > 0
                    ? l10n.profileWatchingSubCount(continueCount)
                    : l10n.profileWatchingSub,
                icon: Icons.bookmark_rounded,
                tint: const Color(0xFFFFE0D8),
                iconColor: const Color(0xFFFF6B4A),
                onTap: onWatching,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                title: l10n.profileMessages,
                subtitle: l10n.profileMessagesSub,
                icon: Icons.chat_bubble_rounded,
                tint: const Color(0xFFD8F5F0),
                iconColor: const Color(0xFF0F9B8A),
                onTap: onMessages,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickTile(
                title: l10n.profileSettings,
                subtitle: l10n.profileSettingsSub,
                icon: Icons.settings_rounded,
                tint: const Color(0xFFE8E6E2),
                iconColor: const Color(0xFF3D4450),
                onTap: onSettings,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ShellSurface.inkOf(context);
    return Material(
      color: ShellSurface.cardOf(context),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ink.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 13, 10, 13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ink.withValues(alpha: 0.42),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueRail extends StatelessWidget {
  final List<ContinueItem> items;
  final VoidCallback onAll;
  final ValueChanged<ContinueItem> onTap;

  const _ContinueRail({
    required this.items,
    required this.onAll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Row(
            children: [
              Text(
                l10n.profileContinue,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ShellSurface.inkOf(context),
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAll,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    children: [
                      Text(
                        l10n.profileAll,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6B4A),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFFF6B4A)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = items[i];
              final d = c.drama;
              final title = d?.title ?? context.l10n.watchingUnknownDrama;
              final cover = d?.coverUrl ?? '';
              return GestureDetector(
                onTap: () => onTap(c),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF12151C).withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: SizedBox(
                          width: 56,
                          height: 80,
                          child: cover.isNotEmpty
                              ? Image.network(cover, fit: BoxFit.cover)
                              : const ColoredBox(color: Color(0xFFD9D4CC)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF12151C),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.l10n.profileEpisodeSeen(c.episodeNo),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFF6B4A).withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: const Color(0xFF12151C).withValues(alpha: 0.2),
                        size: 28,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PosterCard extends StatelessWidget {
  final Drama drama;
  final VoidCallback onTap;

  const _PosterCard({required this.drama, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4.15,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (drama.coverUrl.isNotEmpty)
                      Image.network(
                        drama.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFD9D4CC)),
                      )
                    else
                      const ColoredBox(color: Color(0xFFD9D4CC)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.58),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Text(
                        '${drama.totalEpisodes}集',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              drama.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF12151C),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              drama.category.isEmpty ? context.l10n.brandSuffix : drama.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF12151C).withValues(alpha: 0.45),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.movie_filter_outlined, size: 36, color: const Color(0xFF12151C).withValues(alpha: 0.28)),
          const SizedBox(height: 10),
          Text(
            context.l10n.profileEmptyFavTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF12151C).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.profileEmptyFavSub,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF12151C).withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
