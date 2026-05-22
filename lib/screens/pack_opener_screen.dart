import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/player_model.dart';
import '../models/user_model.dart';
import '../providers/app_providers.dart';
import '../widgets/player_avatar.dart';

final _optimisticPackClaimsTodayProvider = StateProvider<int?>((ref) => null);
final _optimisticPackLastClaimedAtProvider = StateProvider<DateTime?>((ref) => null);

class PackOpenerScreen extends ConsumerStatefulWidget {
  const PackOpenerScreen({super.key});

  @override
  ConsumerState<PackOpenerScreen> createState() => _PackOpenerScreenState();
}

class _PackOpenerScreenState extends ConsumerState<PackOpenerScreen> {
  bool _isOpening = false;
  bool _showReveal = false;

  List<PlayerModel> _pulledStickers = [];
  Map<int, int> _collectionBeforeOpen = {};

  Timer? _countdownTimer;
  String _timeRemaining = '';

  static const int _dailyPackLimit = 10;

  @override
  void initState() {
    super.initState();
    _startCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Force fresh user data when this screen opens.
      ref.invalidate(authStateProvider);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _updateCountdown();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);

    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');

    if (mounted) {
      setState(() => _timeRemaining = '$h:$m:$s');
    }
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isNewDay(UserModel user) {
    final now = DateTime.now();
    final last = user.lastFreePackClaimedAt;

    if (last == null) return true;

    return !_isSameLocalDay(last, now);
  }

  int _getRealClaimsToday(UserModel user) {
    return _isNewDay(user) ? 0 : user.freePacksClaimedToday;
  }

  int _getEffectiveClaimsToday(UserModel user) {
    final realClaimsToday = _getRealClaimsToday(user);

    final optimisticClaims = ref.watch(_optimisticPackClaimsTodayProvider);
    final optimisticDate = ref.watch(_optimisticPackLastClaimedAtProvider);

    if (optimisticClaims == null || optimisticDate == null) {
      return realClaimsToday;
    }

    final now = DateTime.now();

    if (!_isSameLocalDay(optimisticDate, now)) {
      return realClaimsToday;
    }

    return max(realClaimsToday, optimisticClaims);
  }

  Future<void> _openPack(UserModel user) async {
    if (_isOpening) return;

    final currentClaimsToday = _getEffectiveClaimsToday(user);

    if (currentClaimsToday >= _dailyPackLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Daily pack limit reached.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
      return;
    }

    final collectionBefore = Map<int, int>.from(
      ref.read(collectionProvider).valueOrNull ?? {},
    );

    setState(() {
      _isOpening = true;
      _showReveal = false;
      _pulledStickers = [];
      _collectionBeforeOpen = collectionBefore;
    });

    // Persist optimistic count in Riverpod so it survives navigation.
    ref.read(_optimisticPackClaimsTodayProvider.notifier).state =
        currentClaimsToday + 1;
    ref.read(_optimisticPackLastClaimedAtProvider.notifier).state =
        DateTime.now();

    try {
      final repo = ref.read(stickerRepositoryProvider);
      final pulled = await repo.openPack(user.id);

      ref.read(collectionProvider.notifier).addStickers(pulled);

      // Refresh real user data after DB update.
      ref.invalidate(authStateProvider);

      if (!mounted) return;

      setState(() {
        _pulledStickers = pulled;
        _showReveal = true;
      });
    } catch (e) {
      // Roll back optimistic count if opening failed.
      ref.read(_optimisticPackClaimsTodayProvider.notifier).state =
          currentClaimsToday;
      ref.read(_optimisticPackLastClaimedAtProvider.notifier).state =
          DateTime.now();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.neonPink,
          behavior: SnackBarBehavior.floating,
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showReveal && _pulledStickers.isNotEmpty) {
      return _CardRevealView(
        stickers: _pulledStickers,
        collectionBeforeOpen: _collectionBeforeOpen,
        onDone: () {
          setState(() {
            _showReveal = false;
            _pulledStickers = [];
            _collectionBeforeOpen = {};
          });

          // Refresh again when leaving reveal screen.
          ref.invalidate(authStateProvider);
        },
      );
    }

    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const Center(
            child: Text('Please sign in.'),
          );
        }

        final claimsToday = _getEffectiveClaimsToday(user);
        final packsLeft = (_dailyPackLimit - claimsToday)
            .clamp(0, _dailyPackLimit)
            .toInt();

        return Container(
          color: AppTheme.warmBackground,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DailyPackHeader(
                    claimsToday: claimsToday,
                    packsLeft: packsLeft,
                    dailyLimit: _dailyPackLimit,
                  ),
                  const SizedBox(height: 28),
                  if (packsLeft > 0)
                    _StickerPackCard(
                      isOpening: _isOpening,
                      packsLeft: packsLeft,
                      onTap: () => _openPack(user),
                    )
                  else
                    _PackLimitCard(timeRemaining: _timeRemaining),
                  const SizedBox(height: 24),
                  _PackInfoCard(
                    packsLeft: packsLeft,
                    dailyLimit: _dailyPackLimit,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _DailyPackHeader extends StatelessWidget {
  final int claimsToday;
  final int packsLeft;
  final int dailyLimit;

  const _DailyPackHeader({
    required this.claimsToday,
    required this.packsLeft,
    required this.dailyLimit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = dailyLimit == 0 ? 0.0 : claimsToday / dailyLimit;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.goldBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Packs',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Open packs and complete your album',
                      style: TextStyle(
                        color: AppTheme.subtext,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$packsLeft left',
                style: TextStyle(
                  color: packsLeft > 0
                      ? AppTheme.success
                      : AppTheme.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppTheme.progressTrack,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryNavy,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dailyLimit, (index) {
              final claimed = index < claimsToday;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 26,
                width: 26,
                decoration: BoxDecoration(
                  color: claimed
                      ? AppTheme.primaryNavy
                      : AppTheme.progressBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: claimed
                        ? AppTheme.primaryNavy
                        : AppTheme.line,
                  ),
                ),
                child: Icon(
                  claimed ? Icons.check : Icons.style,
                  size: 13,
                  color: claimed ? Colors.white : AppTheme.muted,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PACK CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StickerPackCard extends StatelessWidget {
  final bool isOpening;
  final int packsLeft;
  final VoidCallback onTap;

  const _StickerPackCard({
    required this.isOpening,
    required this.packsLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isOpening ? null : onTap,
      child: AnimatedScale(
        scale: isOpening ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Container(
          height: 360,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.nearWhite,
                AppTheme.blueTint,
                AppTheme.warmCream,
              ],
            ),
            border: Border.all(
              color: AppTheme.goldMuted,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -38,
                top: -34,
                child: Icon(
                  Icons.sports_soccer,
                  size: 178,
                  color: AppTheme.primaryNavy.withValues(alpha: 0.07),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -40,
                child: Container(
                  height: 130,
                  width: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.gold.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _PackStripePainter(),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'DAILY PACK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.goldBorder,
                          ),
                        ),
                        child: Text(
                          '$packsLeft left',
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'World\nSticker Pack',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 42,
                      height: 0.92,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '5 random stickers · chance of gold foil',
                    style: TextStyle(
                      color: AppTheme.subtext,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isOpening ? null : onTap,
                      icon: isOpening
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        isOpening ? 'Opening Pack…' : 'Open Pack',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                        disabledBackgroundColor:
                            AppTheme.primaryNavy.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
            .animate(target: isOpening ? 1 : 0)
            .shake(
              hz: 5,
              duration: 900.milliseconds,
              curve: Curves.easeInOut,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIMIT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PackLimitCard extends StatelessWidget {
  final String timeRemaining;

  const _PackLimitCard({
    required this.timeRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.goldBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: AppTheme.dangerLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.lock_clock,
              size: 36,
              color: AppTheme.danger,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Daily limit reached',
            style: TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You opened all free packs for today.\nNew packs unlock after midnight.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.subtext,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Next reset',
            style: TextStyle(
              color: AppTheme.slateGray,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            timeRemaining,
            style: const TextStyle(
              color: AppTheme.primaryNavy,
              fontSize: 34,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PackInfoCard extends StatelessWidget {
  final int packsLeft;
  final int dailyLimit;
  

  const _PackInfoCard({
    required this.packsLeft,
    required this.dailyLimit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.goldBorder,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.subtext,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              packsLeft > 0
                  ? 'You can open $packsLeft more free pack${packsLeft == 1 ? '' : 's'} today.'
                  : 'You reached the $dailyLimit-pack daily limit.',
              style: const TextStyle(
                color: AppTheme.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD REVEAL VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _CardRevealView extends StatefulWidget {
  final List<PlayerModel> stickers;
  final Map<int, int> collectionBeforeOpen;
  final VoidCallback onDone;

  const _CardRevealView({
    required this.stickers,
    required this.collectionBeforeOpen,
    required this.onDone,
  });

  @override
  State<_CardRevealView> createState() => _CardRevealViewState();
}

class _CardRevealViewState extends State<_CardRevealView> {
  final PageController _pageController = PageController(viewportFraction: 0.84);

  int _currentPage = 0;
  final Set<int> _flipped = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isNewStickerAtIndex(int index) {
    final player = widget.stickers[index];
    final ownedBeforePack = widget.collectionBeforeOpen[player.id] ?? 0;

    final sameStickerEarlierInPack = widget.stickers
        .take(index)
        .where((sticker) => sticker.id == player.id)
        .length;

    return ownedBeforePack == 0 && sameStickerEarlierInPack == 0;
  }

  int get _newCount {
    int count = 0;

    for (int i = 0; i < widget.stickers.length; i++) {
      if (_isNewStickerAtIndex(i)) count++;
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.stickers.length;
    final newCount = _newCount;
    final duplicateCount = total - newCount;

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pack Reveal',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.goldBorder,
                      ),
                    ),
                    child: Text(
                      '${_currentPage + 1} / $total',
                      style: const TextStyle(
                        color: AppTheme.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _RevealStatPill(
                    label: 'New',
                    value: newCount,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 8),
                  _RevealStatPill(
                    label: 'Duplicates',
                    value: duplicateCount,
                    color: AppTheme.goldDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(total, (i) {
                final active = i == _currentPage;
                final seen = i <= _currentPage;
                final isNew = _isNewStickerAtIndex(i);
                final sticker = widget.stickers[i];

                final color = sticker.isShiny
                    ? AppTheme.gold
                    : isNew
                        ? AppTheme.success
                        : AppTheme.goldDark;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: seen ? color : AppTheme.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: total,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                },
                itemBuilder: (context, index) {
                  final player = widget.stickers[index];
                  final isFlipped = _flipped.contains(index);
                  final isCurrent = index == _currentPage;
                  final isNew = _isNewStickerAtIndex(index);

                  return AnimatedScale(
                    scale: isCurrent ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isFlipped) {
                            _flipped.remove(index);
                          } else {
                            _flipped.add(index);
                          }
                        });
                      },
                      child: _FlipCard(
                        player: player,
                        isFlipped: isFlipped,
                        isNew: isNew,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Swipe to see all stickers · Tap to flip',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentPage > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left, size: 18),
                      label: const Text(
                        'Prev',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryNavy,
                        disabledForegroundColor: AppTheme.mutedDisabled,
                        side: const BorderSide(
                          color: AppTheme.line,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _currentPage < total - 1
                        ? ElevatedButton.icon(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.chevron_right, size: 18),
                            label: const Text(
                              'Next Sticker',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: widget.onDone,
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text(
                              'Add to Album',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealStatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _RevealStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.goldBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 9,
              width: 9,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value $label',
              style: const TextStyle(
                color: AppTheme.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLIP CARD
// ─────────────────────────────────────────────────────────────────────────────

class _FlipCard extends StatefulWidget {
  final PlayerModel player;
  final bool isFlipped;
  final bool isNew;

  const _FlipCard({
    required this.player,
    required this.isFlipped,
    required this.isNew,
  });

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isFlipped) {
      _ctrl.value = 1;
    }
  }

  @override
  void didUpdateWidget(_FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final showFront = _anim.value < 0.5;
        final angle = _anim.value * pi;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: showFront ? _buildFront() : _buildBack(),
        );
      },
    );
  }

  Widget _buildFront() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryNavy,
            AppTheme.navyDark,
            AppTheme.navyMid,
          ],
        ),
        border: Border.all(
          color: AppTheme.gold,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: CustomPaint(
                painter: _CardBackPatternPainter(),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 92,
                width: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppTheme.gold,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 48,
                  color: AppTheme.gold,
                ),
              )
                  .animate(onPlay: (controller) {
                    controller.repeat(reverse: true);
                  })
                  .scaleXY(
                    begin: 0.96,
                    end: 1.04,
                    duration: 1500.milliseconds,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 24),
              const Text(
                'MYSTERY STICKER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to reveal',
                style: TextStyle(
                  color: AppTheme.line,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    final player = widget.player;
    final badgeColor =
        widget.isNew ? AppTheme.success : AppTheme.goldDark;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: player.isShiny
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.goldLight,
                    AppTheme.goldMedium,
                    AppTheme.goldDeepDark,
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    AppTheme.blueTint,
                  ],
                ),
          border: Border.all(
            color: player.isShiny
                ? AppTheme.gold
                : AppTheme.blueBorder,
            width: player.isShiny ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              if (player.isShiny)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ShimmerLinePainter(),
                  ),
                ),
              Positioned(
                left: -30,
                top: -20,
                child: Icon(
                  Icons.sports_soccer,
                  size: 120,
                  color: AppTheme.primaryNavy.withValues(alpha: 0.04),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _StickerMiniStat(
                          label: 'Rating',
                          value: '${player.rating}',
                          isGold: player.isShiny,
                        ),
                        const Spacer(),
                        _StickerMiniStat(
                          label: 'POS',
                          value: player.position,
                          isGold: player.isShiny,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: PlayerAvatar(
                            url: player.avatarUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      player.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: player.isShiny
                            ? AppTheme.goldDeep
                            : AppTheme.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (player.isShiny) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.goldDeep,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 11,
                                  color: AppTheme.shinyGold,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'GOLD FOIL',
                                  style: TextStyle(
                                    color: AppTheme.shinyGold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '#${player.number}',
                          style: TextStyle(
                            color: player.isShiny
                                ? AppTheme.goldDeep.withValues(alpha: 0.65)
                                : AppTheme.subtext,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.isNew ? 'NEW!' : 'DUPLICATE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().scaleXY(
            begin: 0.88,
            end: 1.0,
            duration: 320.milliseconds,
            curve: Curves.easeOutBack,
          ),
    );
  }
}

class _StickerMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isGold;

  const _StickerMiniStat({
    required this.label,
    required this.value,
    required this.isGold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: isGold
            ? AppTheme.goldDeep.withValues(alpha: 0.88)
            : AppTheme.primaryNavy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _PackStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 18;

    for (int i = -8; i < 18; i++) {
      final x = i * 42.0;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardBackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }

    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppTheme.gold.withValues(alpha: 0.18);

    for (double r = 40; r < size.width; r += 38) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        r,
        circlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShimmerLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 14;

    for (int i = -6; i < 22; i++) {
      final x = i * 34.0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}