import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/trade_model.dart';
import '../models/user_model.dart';
import '../providers/app_providers.dart';
import '../widgets/player_avatar.dart';
import 'live_trade_room_screen.dart';



class _TradingStyle {
  static const Color warmBackground = AppTheme.warmBackground;
  static const Color card = AppTheme.cardWhite;
  static const Color navy = AppTheme.primaryNavy;
  static const Color ink = AppTheme.ink;
  static const Color inkSoft = AppTheme.inkSoft;
  static const Color muted = AppTheme.slateGray;
  static const Color line = AppTheme.line;
  static const Color gold = AppTheme.gold;
  static const Color goldBorder = AppTheme.goldBorder;
  static const Color softBlue = AppTheme.blueTint;
  static const Color inputBackground = AppTheme.inputBackground;
  static const Color success = AppTheme.success;
  static const Color error = AppTheme.danger;

  static BoxDecoration neonBox({
    required Color glowColor,
    required double borderRadius,
  }) {
    return AppTheme.premiumNeonBox(
      glowColor: glowColor,
      borderRadius: borderRadius,
      bgColor: card,
    );
  }

  static BoxDecoration stickerBox({required bool isShiny}) {
    return AppTheme.premiumStickerBox(isShiny: isShiny);
  }
}

class TradingScreen extends ConsumerStatefulWidget {
  const TradingScreen({super.key});

  @override
  ConsumerState<TradingScreen> createState() => _TradingScreenState();
}

class _TradingScreenState extends ConsumerState<TradingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tradesAsync = ref.watch(openTradesProvider);
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: _TradingStyle.warmBackground,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: _TradingStyle.neonBox(
              glowColor: _TradingStyle.navy,
              borderRadius: 24,
            ),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: _TradingStyle.navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.swap_horizontal_circle,
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
                        'Sticker Trading Hub',
                        style: TextStyle(
                          color: _TradingStyle.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Trade duplicates and connect with collectors',
                        style: TextStyle(
                          color: _TradingStyle.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _TradingStyle.goldBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _TradingStyle.navy,
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: _TradingStyle.inkSoft,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
              tabs: const [
                Tab(text: 'MARKET'),
                Tab(text: 'FRIENDS'),
                Tab(text: 'MY OFFERS'),
              ],
            ),
          ),
          Expanded(
            child: userAsync.when(
              data: (user) {
                if (user == null) return const Center(child: Text('Please sign in.'));
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTradesList(tradesAsync, user.id, isMarket: true),
                    _buildFriendsTab(user),
                    _buildTradesList(tradesAsync, user.id, isMarket: false),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error user: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _TradingStyle.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add),
        label: const Text('NEW TRADE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        onPressed: () => _showCreateTradeSheet(context),
      ),
    );
  }

  Widget _buildTradesList(
    AsyncValue<List<TradeModel>> tradesAsync,
    String currentUserId, {
    required bool isMarket,
  }) {
    return tradesAsync.when(
      data: (trades) {
        final list = trades.where((t) {
          if (isMarket) return t.senderId != currentUserId && t.status == 'pending';
          return t.senderId == currentUserId;
        }).toList();

        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Text(
                isMarket
                    ? 'No open trades on the market yet.\nTap + NEW TRADE to post your first offer!'
                    : 'You have no active trade offers.\nCreate a trade to offer your duplicates!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _TradingStyle.inkSoft, height: 1.5),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: list.length,
          itemBuilder: (context, idx) => _buildTradeCard(list[idx], currentUserId, isMarket),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading trades: $e')),
    );
  }

  Widget _buildTradeCard(TradeModel trade, String currentUserId, bool isMarket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _TradingStyle.neonBox(
        glowColor: isMarket ? _TradingStyle.navy : _TradingStyle.line,
        borderRadius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'By: ${trade.senderUsername ?? "Collector"}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _TradingStyle.inkSoft),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(trade.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _getStatusColor(trade.status), width: 0.5),
                ),
                child: Text(
                  trade.status.toUpperCase(),
                  style: TextStyle(color: _getStatusColor(trade.status), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: _TradingStyle.line),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OFFERING:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _TradingStyle.navy)),
                    const SizedBox(height: 8),
                    ...trade.offeredItems.map((item) => _buildMiniStickerBullet(item.player, item.quantity)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 20),
                child: Icon(Icons.swap_horiz, color: _TradingStyle.muted),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WANTS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _TradingStyle.error)),
                    const SizedBox(height: 8),
                    ...trade.requestedItems.map((item) => _buildMiniStickerBullet(item.player, item.quantity)),
                  ],
                ),
              ),
            ],
          ),
          if (trade.status == 'pending') ...[
            const SizedBox(height: 16),
            if (isMarket)
              ElevatedButton(
                onPressed: () => _executeAcceptTrade(trade.id, currentUserId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _TradingStyle.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('ACCEPT SWAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              )
            else
              OutlinedButton(
                onPressed: () => _executeCancelTrade(trade.id, currentUserId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _TradingStyle.error,
                  side: const BorderSide(color: _TradingStyle.error),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('CANCEL OFFER', style: TextStyle(fontSize: 12)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStickerBullet(PlayerModel? player, int qty) {
    if (player == null) return const Text('Loading player...', style: TextStyle(fontSize: 11));
    final star = player.isShiny ? ' ★' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        '${player.name}$star (${player.position} #${player.number})',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: _TradingStyle.ink),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted': return _TradingStyle.success;
      case 'rejected':
      case 'cancelled': return _TradingStyle.error;
      default: return _TradingStyle.navy;
    }
  }

  Future<void> _executeAcceptTrade(String tradeId, String receiverId) async {
    try {
      await ref.read(openTradesProvider.notifier).acceptTrade(tradeId, receiverId);
      ref.invalidate(collectionProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _TradingStyle.success,
          content: Text('Swap completed! Album updated.', style: TextStyle(fontWeight: FontWeight.bold)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _TradingStyle.error,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ));
      }
    }
  }

  Future<void> _executeCancelTrade(String tradeId, String userId) async {
    try {
      await ref.read(openTradesProvider.notifier).cancelTrade(tradeId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _TradingStyle.muted,
          content: Text('Trade offer cancelled.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _TradingStyle.error,
          content: Text(e.toString()),
        ));
      }
    }
  }

  void _showCreateTradeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const _CreateTradeSheetContent(),
    ).then((_) => ref.invalidate(openTradesProvider));
  }

  Widget _buildFriendsTab(UserModel currentUser) {
    final usersAsync = ref.watch(allUsersProvider);
    final tradesAsync = ref.watch(userTradesProvider(currentUser.id));
    final addedFriendIds = ref.watch(addedFriendsProvider);

    return usersAsync.when(
      data: (users) {
        final friends = users.where((u) => addedFriendIds.contains(u.id) && u.id != currentUser.id).toList();

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: _TradingStyle.neonBox(
                glowColor: _TradingStyle.navy,
                borderRadius: 16,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      PlayerAvatar(url: currentUser.avatarUrl, size: 54),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser.username.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: _TradingStyle.ink,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'ALBUM COLLECTOR',
                              style: TextStyle(
                                color: _TradingStyle.navy,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: _TradingStyle.navy.withValues(alpha: 0.2), height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR FRIEND CODE',
                              style: TextStyle(
                                color: _TradingStyle.inkSoft,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              getFriendCodeForUser(currentUser),
                              style: const TextStyle(
                                color: _TradingStyle.navy,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: _TradingStyle.navy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: getFriendCodeForUser(currentUser)));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: _TradingStyle.navy,
                              duration: Duration(seconds: 1),
                              content: Text(
                                'Friend code copied to clipboard!',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                        tooltip: 'Copy Code',
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: () => _showAddFriendSheet(context, currentUser, users),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _TradingStyle.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          shadowColor: _TradingStyle.error,
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 14),
                        label: const Text(
                          'ADD FRIEND',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.people, color: _TradingStyle.navy, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'SYNCED FRIENDS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: _TradingStyle.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: tradesAsync.when(
                data: (trades) {
                  if (friends.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sensors_off, size: 48, color: _TradingStyle.inkSoft.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text(
                              'NO COLLECTORS CONNECTED',
                              style: TextStyle(
                                color: _TradingStyle.inkSoft,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: friends.length,
                    itemBuilder: (context, idx) {
                      final friend = friends[idx];
                      
                      TradeModel? activeTrade;
                      for (final t in trades) {
                        if (t.status == 'pending' &&
                            ((t.senderId == currentUser.id && t.receiverId == friend.id) ||
                             (t.senderId == friend.id && t.receiverId == currentUser.id))) {
                          activeTrade = t;
                          break;
                        }
                      }

                      final isLive = activeTrade != null;

                      return GestureDetector(
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          if (isLive && activeTrade != null) {
                            navigator.push(
                              MaterialPageRoute(
                                builder: (context) => LiveTradeRoomScreen(tradeId: activeTrade!.id),
                              ),
                            );
                          } else {
                            try {
                              messenger.showSnackBar(
                                const SnackBar(
                                  duration: Duration(milliseconds: 600),
                                  content: Text('Starting live swap room...'),
                                ),
                              );
                              final newTrade = await ref.read(userTradesProvider(currentUser.id).notifier).createTrade(
                                senderId: currentUser.id,
                                offeredItems: [],
                                requestedItems: [],
                                receiverId: friend.id,
                              );
                              ref.invalidate(openTradesProvider);
                              
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (context) => LiveTradeRoomScreen(tradeId: newTrade.id),
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: _TradingStyle.error,
                                  content: Text('Failed to start live session: $e'),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: _TradingStyle.neonBox(
                            glowColor: isLive ? _TradingStyle.navy : _TradingStyle.line,
                            borderRadius: 12,
                          ),
                          child: Row(
                            children: [
                              PlayerAvatar(url: friend.avatarUrl, size: 42),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.username.toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _TradingStyle.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (isLive)
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: _TradingStyle.success,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            '● LIVE SWAP ACTIVE',
                                            style: TextStyle(
                                              color: _TradingStyle.navy,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Text(
                                            friend.id.startsWith('mock-bot') 
                                                ? '🤖 PARODY AI SWAP BOT'
                                                : 'ONLINE COLLECTOR',
                                            style: const TextStyle(
                                              color: _TradingStyle.inkSoft,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          GestureDetector(
                                            onTap: () {
                                              ref.read(addedFriendsProvider.notifier).removeFriend(friend.id);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: _TradingStyle.error,
                                                  duration: const Duration(seconds: 1),
                                                  content: Text('Removed ${friend.username} from friends.'),
                                                ),
                                              );
                                            },
                                            child: const Icon(
                                              Icons.delete_outline,
                                              color: _TradingStyle.error,
                                              size: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading trades: $e')),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading friends: $e')),
    );
  }

  void _showAddFriendSheet(BuildContext context, UserModel currentUser, List<UserModel> allUsers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddFriendSheet(currentUser: currentUser, allUsers: allUsers),
      ),
    );
  }
}

class _AddFriendSheet extends ConsumerStatefulWidget {
  final UserModel currentUser;
  final List<UserModel> allUsers;

  const _AddFriendSheet({required this.currentUser, required this.allUsers});

  @override
  ConsumerState<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<_AddFriendSheet> with TickerProviderStateMixin {
  late TabController _sheetTabController;
  final TextEditingController _codeController = TextEditingController();
  bool _isScanning = false;
  bool _scanComplete = false;
  UserModel? _scannedUser;
  String? _errorMessage;
  String? _successMessage;
  late AnimationController _scannerAnimationController;

  @override
  void initState() {
    super.initState();
    _sheetTabController = TabController(length: 2, vsync: this);
    _sheetTabController.addListener(_handleTabChange);
    _scannerAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  void _handleTabChange() {
    if (_sheetTabController.index == 1 && !_isScanning && !_scanComplete) _startScanning();
  }

  @override
  void dispose() {
    _sheetTabController.removeListener(_handleTabChange);
    _sheetTabController.dispose();
    _codeController.dispose();
    _scannerAnimationController.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _scanComplete = false;
      _scannedUser = null;
      _errorMessage = null;
      _successMessage = null;
    });
    _scannerAnimationController.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      final addedIds = ref.read(addedFriendsProvider);
      final candidates = widget.allUsers.where((u) => u.id != widget.currentUser.id && !addedIds.contains(u.id)).toList();
      if (candidates.isEmpty) {
        setState(() {
          _isScanning = false;
          _scanComplete = true;
          _errorMessage = "NO NEW COLLECTORS DETECTED";
        });
        _scannerAnimationController.stop();
        return;
      }
      final randomUser = candidates[Random().nextInt(candidates.length)];
      await ref.read(addedFriendsProvider.notifier).addFriendById(randomUser.id);
      setState(() {
        _isScanning = false;
        _scanComplete = true;
        _scannedUser = randomUser;
        _successMessage = "NEW FRIEND SYNCED!";
      });
      _scannerAnimationController.stop();
    });
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() { _errorMessage = "FRIEND CODE CANNOT BE EMPTY"; _successMessage = null; _scannedUser = null; });
      return;
    }
    setState(() { _errorMessage = null; _successMessage = null; _scannedUser = null; });
    final success = await ref.read(addedFriendsProvider.notifier).addFriendByCode(code, widget.allUsers);
    if (success) {
      final cleanCode = code.replaceAll(' ', '').replaceAll('-', '').toUpperCase();
      UserModel? matchedUser;
      for (var u in widget.allUsers) {
        if (getFriendCodeForUser(u).replaceAll('-', '').toUpperCase() == cleanCode) {
          matchedUser = u; break;
        }
      }
      setState(() { _scannedUser = matchedUser; _successMessage = "SUCCESS"; _codeController.clear(); });
    } else {
      setState(() { _errorMessage = "INVALID FRIEND CODE"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _TradingStyle.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _TradingStyle.navy.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _TradingStyle.muted, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('ADD NEW COLLECTOR', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _TradingStyle.ink, letterSpacing: 1.5)),
          const SizedBox(height: 20),
          Container(
            height: 45,
            decoration: BoxDecoration(color: _TradingStyle.inputBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: _TradingStyle.goldBorder)),
            child: TabBar(
              controller: _sheetTabController,
              indicatorColor: _TradingStyle.navy,
              labelColor: _TradingStyle.navy,
              unselectedLabelColor: _TradingStyle.inkSoft,
              indicator: BoxDecoration(
                color: _TradingStyle.navy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _TradingStyle.navy.withValues(alpha: 0.3)),
              ),
              tabs: const [Tab(text: 'FRIEND CODE'), Tab(text: 'LIVE SCANNER')],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _sheetTabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildDecryptCodeTab(), _buildScannerTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecryptCodeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Enter a collector\'s unique friend code to sync channels and establish a live swap bridge.', style: TextStyle(color: _TradingStyle.inkSoft, fontSize: 12, height: 1.4)),
        const SizedBox(height: 20),
        TextField(
          controller: _codeController,
          style: const TextStyle(color: _TradingStyle.ink, fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 1.5),
          decoration: InputDecoration(
            hintText: 'SWAP-XXXX-XXXX',
            hintStyle: const TextStyle(color: _TradingStyle.muted, fontFamily: 'Courier', letterSpacing: 1.5),
            filled: true,
            fillColor: _TradingStyle.inputBackground,
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _TradingStyle.navy.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _TradingStyle.navy), borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.vpn_key, color: _TradingStyle.navy, size: 18),
          ),
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _TradingStyle.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _TradingStyle.error.withValues(alpha: 0.4))),
            child: Row(children: [const Icon(Icons.error, color: _TradingStyle.error, size: 16), const SizedBox(width: 8), Expanded(child: Text(_errorMessage!, style: const TextStyle(color: _TradingStyle.error, fontSize: 11, fontWeight: FontWeight.bold)))]),
          )
        else if (_successMessage != null && _scannedUser != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _TradingStyle.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _TradingStyle.success.withValues(alpha: 0.4))),
            child: Row(children: [PlayerAvatar(url: _scannedUser!.avatarUrl, size: 24), const SizedBox(width: 8), Expanded(child: Text('CONNECTED TO ${_scannedUser!.username.toUpperCase()}!', style: const TextStyle(color: _TradingStyle.success, fontSize: 11, fontWeight: FontWeight.bold)))]),
          ),
        const Spacer(),
        ElevatedButton(
          onPressed: _submitCode,
          style: ElevatedButton.styleFrom(backgroundColor: _TradingStyle.navy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('CONNECT & SYNC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        ),
      ],
    );
  }

  Widget _buildScannerTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Scan for nearby collectors and start a live swap room.', style: TextStyle(color: _TradingStyle.inkSoft, fontSize: 12, height: 1.4), textAlign: TextAlign.center), const SizedBox(height: 16), _buildScannerViewport()]);
  }

  Widget _buildScannerViewport() {
    return AspectRatio(
      aspectRatio: 1.6,
      child: Container(
        decoration: BoxDecoration(color: _TradingStyle.softBlue, borderRadius: BorderRadius.circular(16), border: Border.all(color: _TradingStyle.navy.withValues(alpha: 0.3), width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _ScannerGridPainter())),
            AnimatedBuilder(
              animation: _scannerAnimationController,
              builder: (context, child) => Positioned(left: 0, right: 0, top: _scannerAnimationController.value * 150, child: Container(height: 4, decoration: BoxDecoration(color: _TradingStyle.success, boxShadow: [BoxShadow(color: _TradingStyle.success.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2)]))),
            ),
            Center(
              child: _isScanning ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.radar, color: _TradingStyle.success, size: 36), Text('SCANNING...', style: TextStyle(color: _TradingStyle.success, fontSize: 11))]) : 
                     _scanComplete ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [PlayerAvatar(url: _scannedUser?.avatarUrl ?? '', size: 48), Text('SYNCED!', style: const TextStyle(color: _TradingStyle.success, fontSize: 10))]) : 
                     IconButton(icon: const Icon(Icons.play_circle_fill, color: _TradingStyle.navy, size: 44), onPressed: _startScanning),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _TradingStyle.success.withValues(alpha: 0.08)..strokeWidth = 1.0;
    for (int i = 0; i <= 10; i++) {
      canvas.drawLine(Offset(i * (size.width / 10), 0), Offset(i * (size.width / 10), size.height), paint);
      canvas.drawLine(Offset(0, i * (size.height / 10)), Offset(size.width, i * (size.height / 10)), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE TRADE SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _CreateTradeSheetContent extends ConsumerStatefulWidget {
  const _CreateTradeSheetContent();

  @override
  ConsumerState<_CreateTradeSheetContent> createState() => _CreateTradeSheetContentState();
}

class _CreateTradeSheetContentState extends ConsumerState<_CreateTradeSheetContent> {
  PlayerModel? _offeredSticker;
  PlayerModel? _requestedSticker;
  bool _isPublishing = false;

  // Opens the full-screen sticker picker and returns the chosen player
  Future<PlayerModel?> _openPicker({
    required List<PlayerModel> players,
    required List<TeamModel> teams,
    required Map<int, int> collection,
    required bool duplicatesOnly,
    required String title,
  }) {
    return showModalBottomSheet<PlayerModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _StickerPickerSheet(
        title: title,
        players: players,
        teams: teams,
        collection: collection,
        duplicatesOnly: duplicatesOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(collectionProvider);
    final playersAsync = ref.watch(playersProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final userAsync = ref.watch(authStateProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: _TradingStyle.warmBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: _TradingStyle.goldBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: collectionAsync.when(
        data: (coll) => playersAsync.when(
          data: (players) => teamsAsync.when(
            data: (teams) => _buildSheet(context, coll, players, teams, userAsync),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSheet(
    BuildContext context,
    Map<int, int> coll,
    List<PlayerModel> players,
    List<TeamModel> teams,
    AsyncValue userAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: _TradingStyle.muted, borderRadius: BorderRadius.circular(2)),
          ),
        ),

        const Center(
          child: Text(
            'POST A TRADE OFFER',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2, color: _TradingStyle.navy),
          ),
        ),
        const SizedBox(height: 24),

        // ── STEP 1: Offer ─────────────────────────────────────────────────
        _buildStepLabel('1', 'STICKER YOU\'RE OFFERING', _TradingStyle.navy),
        const SizedBox(height: 8),
        _buildStickerSelector(
          selected: _offeredSticker,
          hint: 'Pick a duplicate from your collection',
          accentColor: _TradingStyle.navy,
          onTap: () async {
            final picked = await _openPicker(
              players: players,
              teams: teams,
              collection: coll,
              duplicatesOnly: true,
              title: 'Choose Sticker to Offer',
            );
            if (picked != null) setState(() => _offeredSticker = picked);
          },
        ),

        const SizedBox(height: 6),
        const Center(child: Icon(Icons.swap_vert, color: _TradingStyle.muted, size: 28)),
        const SizedBox(height: 6),

        // ── STEP 2: Request ───────────────────────────────────────────────
        _buildStepLabel('2', 'STICKER YOU WANT IN RETURN', _TradingStyle.error),
        const SizedBox(height: 8),
        _buildStickerSelector(
          selected: _requestedSticker,
          hint: 'Browse all 576 stickers by team, position…',
          accentColor: _TradingStyle.error,
          onTap: () async {
            final picked = await _openPicker(
              players: players,
              teams: teams,
              collection: coll,
              duplicatesOnly: false,
              title: 'Choose Sticker to Request',
            );
            if (picked != null) setState(() => _requestedSticker = picked);
          },
        ),

        const Spacer(),

        // ── Publish ───────────────────────────────────────────────────────
        userAsync.when(
          data: (user) => ElevatedButton(
            onPressed: (_offeredSticker == null || _requestedSticker == null || _isPublishing || user == null)
                ? null
                : () => _publishOffer(user.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: _TradingStyle.navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _TradingStyle.line,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isPublishing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('PUBLISH TO MARKET', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          loading: () => const SizedBox(),
          error: (_, e2) => const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildStepLabel(String step, String label, Color color) {
    return Row(
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(step, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildStickerSelector({
    required PlayerModel? selected,
    required String hint,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _TradingStyle.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected != null ? accentColor : _TradingStyle.line, width: selected != null ? 1.5 : 1),
        ),
        child: selected == null
            ? Row(
                children: [
                  Icon(Icons.search, color: _TradingStyle.muted, size: 18),
                  const SizedBox(width: 10),
                  Text(hint, style: const TextStyle(color: _TradingStyle.muted, fontSize: 13)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: _TradingStyle.muted, size: 18),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 36, height: 46,
                    decoration: _TradingStyle.stickerBox(isShiny: selected.isShiny),
                    child: Center(
                      child: PlayerAvatar(url: selected.avatarUrl, size: 36),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                selected.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selected.isShiny)
                              const Icon(Icons.star, size: 12, color: _TradingStyle.gold),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${selected.position}  ·  Rating ${selected.rating}  ·  #${selected.number}',
                          style: const TextStyle(color: _TradingStyle.inkSoft, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      if (onTap == () {}) _offeredSticker = null;
                    }),
                    child: Icon(Icons.edit, size: 16, color: accentColor),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _publishOffer(String userId) async {
    setState(() => _isPublishing = true);
    try {
      final notifier = ref.read(openTradesProvider.notifier);
      final offItem = TradeItemModel(id: '', tradeId: '', playerId: _offeredSticker!.id, isOffered: true);
      final reqItem = TradeItemModel(id: '', tradeId: '', playerId: _requestedSticker!.id, isOffered: false);
      await notifier.createTrade(senderId: userId, offeredItems: [offItem], requestedItems: [reqItem]);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _TradingStyle.success,
          content: Text('Trade offer published!'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _TradingStyle.error,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STICKER PICKER SHEET — full-screen grid with filters
// ─────────────────────────────────────────────────────────────────────────────
class _StickerPickerSheet extends StatefulWidget {
  final String title;
  final List<PlayerModel> players;
  final List<TeamModel> teams;
  final Map<int, int> collection;
  final bool duplicatesOnly;

  const _StickerPickerSheet({
    required this.title,
    required this.players,
    required this.teams,
    required this.collection,
    required this.duplicatesOnly,
  });

  @override
  State<_StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<_StickerPickerSheet> {
  final TextEditingController _search = TextEditingController();
  TeamModel? _selectedTeam;   // null = All Teams
  String _position = 'ALL';   // ALL, GK, DF, MF, FW
  bool _shinyOnly = false;
  bool _ownedOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PlayerModel> get _filtered {
    List<PlayerModel> list = widget.players;

    // Duplicates-only mode (offering side)
    if (widget.duplicatesOnly) {
      list = list.where((p) => (widget.collection[p.id] ?? 0) > 1).toList();
    }

    // Team filter
    if (_selectedTeam != null) {
      list = list.where((p) => p.teamId == _selectedTeam!.id).toList();
    }

    // Position filter
    if (_position != 'ALL') {
      list = list.where((p) => p.position == _position).toList();
    }

    // Shiny filter
    if (_shinyOnly) {
      list = list.where((p) => p.isShiny).toList();
    }

    // Owned filter (only show cards in collection)
    if (_ownedOnly) {
      list = list.where((p) => (widget.collection[p.id] ?? 0) > 0).toList();
    }

    // Search
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    }

    return list;
  }

  // Team lookup map
  Map<int, TeamModel> get _teamMap => {for (final t in widget.teams) t.id: t};

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    final teamMap = _teamMap;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _TradingStyle.warmBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1, color: _TradingStyle.navy),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _TradingStyle.inkSoft),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    // ── Search bar ───────────────────────────────────────
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: _TradingStyle.ink, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search player name…',
                        hintStyle: const TextStyle(color: _TradingStyle.muted),
                        prefixIcon: const Icon(Icons.search, color: _TradingStyle.muted, size: 18),
                        suffixIcon: _search.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16, color: _TradingStyle.muted),
                                onPressed: () { _search.clear(); setState(() {}); },
                              )
                            : null,
                        filled: true,
                        fillColor: _TradingStyle.inputBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Team selector ────────────────────────────────────
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _teamChip(null, 'ALL TEAMS', Icons.public),
                          ...widget.teams.map((t) => _teamChip(t, t.name, null)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Position + toggles row ───────────────────────────
                    Row(
                      children: [
                        // Position chips
                        ...['ALL', 'GK', 'DF', 'MF', 'FW'].map((pos) {
                          final active = _position == pos;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => setState(() => _position = pos),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: active ? _TradingStyle.navy.withValues(alpha: 0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: active ? _TradingStyle.navy : _TradingStyle.muted),
                                ),
                                child: Text(
                                  pos,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: active ? _TradingStyle.navy : _TradingStyle.inkSoft,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),

                        const Spacer(),

                        // Shiny toggle
                        GestureDetector(
                          onTap: () => setState(() => _shinyOnly = !_shinyOnly),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _shinyOnly ? _TradingStyle.gold.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _shinyOnly ? _TradingStyle.gold : _TradingStyle.muted),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.star, size: 12, color: _shinyOnly ? _TradingStyle.gold : _TradingStyle.muted),
                                const SizedBox(width: 3),
                                Text('SHINY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _shinyOnly ? _TradingStyle.gold : _TradingStyle.muted)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        // Owned toggle (only show if not duplicatesOnly)
                        if (!widget.duplicatesOnly)
                          GestureDetector(
                            onTap: () => setState(() => _ownedOnly = !_ownedOnly),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _ownedOnly ? _TradingStyle.navy.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _ownedOnly ? _TradingStyle.navy : _TradingStyle.muted),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 12, color: _ownedOnly ? _TradingStyle.navy : _TradingStyle.muted),
                                  const SizedBox(width: 3),
                                  Text('OWNED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _ownedOnly ? _TradingStyle.navy : _TradingStyle.muted)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    // ── Results count ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Text(
                            '${results.length} sticker${results.length == 1 ? '' : 's'}',
                            style: const TextStyle(color: _TradingStyle.muted, fontSize: 11),
                          ),
                          if (widget.duplicatesOnly) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _TradingStyle.navy.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _TradingStyle.navy.withValues(alpha: 0.3)),
                              ),
                              child: const Text('DUPLICATES ONLY', style: TextStyle(fontSize: 9, color: _TradingStyle.navy, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: _TradingStyle.line),

              // ── Sticker grid ─────────────────────────────────────────────
              Expanded(
                child: results.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: _TradingStyle.muted),
                            SizedBox(height: 12),
                            Text('No stickers match your filters', style: TextStyle(color: _TradingStyle.muted)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final player = results[i];
                          final owned = (widget.collection[player.id] ?? 0);
                          final team = teamMap[player.teamId];
                          return _buildPickerCard(player, owned, team);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _teamChip(TeamModel? team, String label, IconData? icon) {
    final active = _selectedTeam?.id == team?.id;
    Color accent = _TradingStyle.navy;
    if (team != null) {
      try {
        accent = Color(int.parse(team.primaryColor.replaceAll('#', '0xFF')));
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedTeam = team),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.2) : _TradingStyle.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? accent : _TradingStyle.line, width: active ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 13, color: active ? accent : _TradingStyle.muted),
            if (team != null) Text(team.flagEmoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: active ? (accent.computeLuminance() > 0.5 ? Colors.black : Colors.white) : _TradingStyle.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerCard(PlayerModel player, int owned, TeamModel? team) {
    final isOwned = owned > 0;
    final isDuplicate = owned > 1;

    return GestureDetector(
      onTap: () => Navigator.pop(context, player),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: player.isShiny
                ? _TradingStyle.gold
                : isOwned
                    ? _TradingStyle.navy.withValues(alpha: 0.6)
                    : _TradingStyle.line,
            width: player.isShiny ? 1.5 : 1,
          ),
          gradient: player.isShiny
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _TradingStyle.gold.withValues(alpha: 0.2),
                    _TradingStyle.card,
                    _TradingStyle.gold.withValues(alpha: 0.1),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isOwned ? _TradingStyle.navy.withValues(alpha: 0.08) : Colors.transparent,
                    _TradingStyle.card,
                  ],
                ),
        ),
        padding: const EdgeInsets.all(5),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Rating + Position row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        '${player.rating}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: player.isShiny ? _TradingStyle.gold : Colors.white,
                        ),
                      ),
                    ),
                    Text(player.position, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _TradingStyle.inkSoft)),
                  ],
                ),
                // Avatar
                Expanded(
                  child: Center(child: PlayerAvatar(url: player.avatarUrl, fit: BoxFit.contain)),
                ),
                // Name
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(3)),
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),

            // Team flag
            if (team != null)
              Positioned(
                bottom: 16,
                left: 2,
                child: Text(team.flagEmoji, style: const TextStyle(fontSize: 9)),
              ),

            // Shiny star
            if (player.isShiny)
              const Positioned(top: 0, right: 0, child: Icon(Icons.star, size: 10, color: _TradingStyle.gold)),

            // Owned indicator
            if (isOwned)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: _TradingStyle.navy,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(6), bottomRight: Radius.circular(4)),
                  ),
                  child: Text(
                    isDuplicate ? '+${owned - 1}' : '✓',
                    style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),

            // Not owned dim overlay
            if (!isOwned)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC STICKER PICKER SHEET CONTENT FOR REAL-TIME ROOM
// ─────────────────────────────────────────────────────────────────────────────
class StickerPickerSheetContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final bool isOffer;
  final void Function(PlayerModel player, int quantity) onStickerSelected;

  const StickerPickerSheetContent({
    super.key,
    required this.scrollController,
    required this.isOffer,
    required this.onStickerSelected,
  });

  @override
  ConsumerState<StickerPickerSheetContent> createState() => _StickerPickerSheetContentState();
}

class _StickerPickerSheetContentState extends ConsumerState<StickerPickerSheetContent> {
  final TextEditingController _search = TextEditingController();
  TeamModel? _selectedTeam;   // null = All Teams
  String _position = 'ALL';   // ALL, GK, DF, MF, FW
  bool _shinyOnly = false;
  bool _ownedOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(collectionProvider);
    final playersAsync = ref.watch(playersProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return collectionAsync.when(
      data: (collection) => playersAsync.when(
        data: (players) => teamsAsync.when(
          data: (teams) => _buildContent(context, collection, players, teams),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error teams: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error players: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error collection: $e')),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<int, int> collection,
    List<PlayerModel> players,
    List<TeamModel> teams,
  ) {
    // filter logic
    List<PlayerModel> list = players;

    if (widget.isOffer) {
      list = list.where((p) => (collection[p.id] ?? 0) > 1).toList();
    }

    if (_selectedTeam != null) {
      list = list.where((p) => p.teamId == _selectedTeam!.id).toList();
    }

    if (_position != 'ALL') {
      list = list.where((p) => p.position == _position).toList();
    }

    if (_shinyOnly) {
      list = list.where((p) => p.isShiny).toList();
    }

    if (_ownedOnly && !widget.isOffer) {
      list = list.where((p) => (collection[p.id] ?? 0) > 0).toList();
    }

    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    }

    final teamMap = {for (final t in teams) t.id: t};

    return Column(
      children: [
        // Title and close
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.isOffer ? 'OFFER DUPLICATE STICKER' : 'REQUEST STICKER',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1,
                    color: widget.isOffer ? _TradingStyle.navy : _TradingStyle.error,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: _TradingStyle.inkSoft),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              // Search
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: _TradingStyle.ink, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search player name…',
                  hintStyle: const TextStyle(color: _TradingStyle.muted),
                  prefixIcon: const Icon(Icons.search, color: _TradingStyle.muted, size: 18),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16, color: _TradingStyle.muted),
                          onPressed: () { _search.clear(); setState(() {}); },
                        )
                      : null,
                  filled: true,
                  fillColor: _TradingStyle.inputBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 10),

              // Teams
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _teamChip(null, 'ALL TEAMS', Icons.public),
                    ...teams.map((t) => _teamChip(t, t.name, null)),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Positions & Toggles
              Row(
                children: [
                  ...['ALL', 'GK', 'DF', 'MF', 'FW'].map((pos) {
                    final active = _position == pos;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _position = pos),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: active ? _TradingStyle.navy.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: active ? _TradingStyle.navy : _TradingStyle.muted),
                          ),
                          child: Text(
                            pos,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: active ? _TradingStyle.navy : _TradingStyle.inkSoft,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),

                  // Shiny toggle
                  GestureDetector(
                    onTap: () => setState(() => _shinyOnly = !_shinyOnly),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _shinyOnly ? _TradingStyle.gold.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _shinyOnly ? _TradingStyle.gold : _TradingStyle.muted),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 12, color: _shinyOnly ? _TradingStyle.gold : _TradingStyle.muted),
                          const SizedBox(width: 3),
                          Text('SHINY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _shinyOnly ? _TradingStyle.gold : _TradingStyle.muted)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Owned toggle
                  if (!widget.isOffer)
                    GestureDetector(
                      onTap: () => setState(() => _ownedOnly = !_ownedOnly),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _ownedOnly ? _TradingStyle.navy.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _ownedOnly ? _TradingStyle.navy : _TradingStyle.muted),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 12, color: _ownedOnly ? _TradingStyle.navy : _TradingStyle.muted),
                            const SizedBox(width: 3),
                            Text('OWNED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _ownedOnly ? _TradingStyle.navy : _TradingStyle.muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Count
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      '${list.length} sticker${list.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: _TradingStyle.muted, fontSize: 11),
                    ),
                    if (widget.isOffer) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _TradingStyle.navy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _TradingStyle.navy.withValues(alpha: 0.3)),
                        ),
                        child: const Text('DUPLICATES ONLY', style: TextStyle(fontSize: 9, color: _TradingStyle.navy, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: _TradingStyle.line),

        // Grid
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: _TradingStyle.muted),
                      SizedBox(height: 12),
                      Text('No stickers match your filters', style: TextStyle(color: _TradingStyle.muted)),
                    ],
                  ),
                )
              : GridView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final player = list[i];
                    final owned = (collection[player.id] ?? 0);
                    final team = teamMap[player.teamId];
                    return _buildPickerCard(player, owned, team);
                  },
                ),
        ),
      ],
    );
  }

  Widget _teamChip(TeamModel? team, String label, IconData? icon) {
    final active = _selectedTeam?.id == team?.id;
    Color accent = _TradingStyle.navy;
    if (team != null) {
      try {
        accent = Color(int.parse(team.primaryColor.replaceAll('#', '0xFF')));
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedTeam = team),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.2) : _TradingStyle.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? accent : _TradingStyle.line, width: active ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 13, color: active ? accent : _TradingStyle.muted),
            if (team != null) Text(team.flagEmoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: active ? (accent.computeLuminance() > 0.5 ? Colors.black : Colors.white) : _TradingStyle.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerCard(PlayerModel player, int owned, TeamModel? team) {
    final isOwned = owned > 0;
    final isDuplicate = owned > 1;

    return GestureDetector(
      onTap: () {
        if (widget.isOffer) {
          final maxQty = owned - 1;
          if (maxQty > 1) {
            _showQuantityDialog(player, maxQty);
          } else {
            widget.onStickerSelected(player, 1);
          }
        } else {
          widget.onStickerSelected(player, 1);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: player.isShiny
                ? _TradingStyle.gold
                : isOwned
                    ? _TradingStyle.navy.withValues(alpha: 0.6)
                    : _TradingStyle.line,
            width: player.isShiny ? 1.5 : 1,
          ),
          gradient: player.isShiny
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _TradingStyle.gold.withValues(alpha: 0.2),
                    _TradingStyle.card,
                    _TradingStyle.gold.withValues(alpha: 0.1),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isOwned ? _TradingStyle.navy.withValues(alpha: 0.08) : Colors.transparent,
                    _TradingStyle.card,
                  ],
                ),
        ),
        padding: const EdgeInsets.all(5),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        '${player.rating}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: player.isShiny ? _TradingStyle.gold : Colors.white,
                        ),
                      ),
                    ),
                    Text(player.position, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _TradingStyle.inkSoft)),
                  ],
                ),
                Expanded(
                  child: Center(child: PlayerAvatar(url: player.avatarUrl, fit: BoxFit.contain)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(3)),
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            if (team != null)
              Positioned(
                bottom: 16,
                left: 2,
                child: Text(team.flagEmoji, style: const TextStyle(fontSize: 9)),
              ),
            if (player.isShiny)
              const Positioned(top: 0, right: 0, child: Icon(Icons.star, size: 10, color: _TradingStyle.gold)),
            if (isOwned)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: _TradingStyle.navy,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(6), bottomRight: Radius.circular(4)),
                  ),
                  child: Text(
                    isDuplicate ? '+${owned - 1}' : '✓',
                    style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            if (!isOwned)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showQuantityDialog(PlayerModel player, int maxQty) {
    int selectedQty = 1;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _TradingStyle.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _TradingStyle.navy, width: 1.5),
              ),
              title: Text(
                'SELECT QUANTITY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _TradingStyle.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How many copies of ${player.name} do you want to offer?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _TradingStyle.inkSoft, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: _TradingStyle.navy),
                        onPressed: selectedQty > 1
                            ? () => setDialogState(() => selectedQty--)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _TradingStyle.inputBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _TradingStyle.line),
                        ),
                        child: Text(
                          '$selectedQty',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _TradingStyle.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: _TradingStyle.navy),
                        onPressed: selectedQty < maxQty
                            ? () => setDialogState(() => selectedQty++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Available duplicates: $maxQty',
                    style: const TextStyle(color: _TradingStyle.muted, fontSize: 10),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: _TradingStyle.inkSoft, fontSize: 12)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _TradingStyle.navy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onStickerSelected(player, selectedQty);
                  },
                  child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}