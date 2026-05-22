import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/player_model.dart';
import '../models/trade_model.dart';
import '../models/user_model.dart';
import '../providers/app_providers.dart';
import '../widgets/player_avatar.dart';
import 'trading_screen.dart';

class LiveTradeRoomScreen extends ConsumerStatefulWidget {
  final String tradeId;

  const LiveTradeRoomScreen({
    super.key,
    required this.tradeId,
  });

  @override
  ConsumerState<LiveTradeRoomScreen> createState() =>
      _LiveTradeRoomScreenState();
}

class _LiveTradeRoomScreenState extends ConsumerState<LiveTradeRoomScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  bool _isSuccessOverlayVisible = false;

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_chatScrollController.hasClients) return;

    Timer(const Duration(milliseconds: 200), () {
      if (!_chatScrollController.hasClients) return;

      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage(String message, UserModel user) async {
    if (message.trim().isEmpty) return;

    try {
      final repo = ref.read(tradeRepositoryProvider);

      await repo.sendChatMessage(
        widget.tradeId,
        user.id,
        user.username,
        message.trim(),
      );

      _chatController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('[LiveTradeRoom] error sending chat: $e');
    }
  }

  List<TradeItemModel> _normalizeSingleItemList(List<TradeItemModel> items) {
    if (items.isEmpty) return [];

    return [
      items.first.copyWith(quantity: 1),
    ];
  }

  TradeItemModel _buildSingleTradeItem({
    required PlayerModel player,
    required bool isOffered,
  }) {
    return TradeItemModel(
      id: '',
      tradeId: widget.tradeId,
      playerId: player.id,
      isOffered: isOffered,
      quantity: 1,
      player: player,
    );
  }

  String? _getAgreementBlockReason({
    required List<TradeItemModel> offeredItems,
    required List<TradeItemModel> requestedItems,
  }) {
    final normalizedOffered = _normalizeSingleItemList(offeredItems);
    final normalizedRequested = _normalizeSingleItemList(requestedItems);

    if (normalizedOffered.length != 1 || normalizedRequested.length != 1) {
      return 'A swap must have exactly one sticker from each side.';
    }

    if (normalizedOffered.first.quantity != 1 ||
        normalizedRequested.first.quantity != 1) {
      return 'Only 1-for-1 swaps are allowed.';
    }

    if (normalizedOffered.first.playerId == normalizedRequested.first.playerId) {
      return 'Choose two different stickers for the swap.';
    }

    return null;
  }

  Future<void> _resetBothAgreements({
    required String senderId,
    required String? receiverId,
  }) async {
    final repo = ref.read(tradeRepositoryProvider);

    if (senderId.isNotEmpty) {
      await repo.updateTradeAgreement(
        widget.tradeId,
        senderId,
        false,
      );
    }

    if (receiverId != null && receiverId.isNotEmpty) {
      await repo.updateTradeAgreement(
        widget.tradeId,
        receiverId,
        false,
      );
    }
  }

  Future<void> _clearTradeSide({
    required bool clearsOfferedItems,
    required List<TradeItemModel> currentOffered,
    required List<TradeItemModel> currentRequested,
    required String senderId,
    required String? receiverId,
  }) async {
    try {
      final repo = ref.read(tradeRepositoryProvider);

      final updatedOffered = clearsOfferedItems
          ? <TradeItemModel>[]
          : _normalizeSingleItemList(currentOffered);

      final updatedRequested = clearsOfferedItems
          ? _normalizeSingleItemList(currentRequested)
          : <TradeItemModel>[];

      await repo.updateTradeItems(
        widget.tradeId,
        updatedOffered,
        updatedRequested,
      );

      await _resetBothAgreements(
        senderId: senderId,
        receiverId: receiverId,
      );

      ref.invalidate(liveTradeStreamProvider(widget.tradeId));
    } catch (e) {
      debugPrint('[LiveTradeRoom] clear side error: $e');

      _showSnack(
        'Could not remove sticker.',
        color: _TradeRoomStyle.error,
      );
    }
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color ?? _TradeRoomStyle.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _showStickerPicker(
    BuildContext context, {
    required bool editsOfferedItems,
    required bool pickerRequiresDuplicate,
    required List<TradeItemModel> currentOffered,
    required List<TradeItemModel> currentRequested,
    required String senderId,
    required String? receiverId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: _TradeRoomStyle.warmBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(
                  color: _TradeRoomStyle.goldBorder,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: StickerPickerSheetContent(
                  scrollController: scrollController,
                  isOffer: pickerRequiresDuplicate,
                  onStickerSelected: (player, qty) async {
                    Navigator.pop(context);

                    final repo = ref.read(tradeRepositoryProvider);

                    final normalizedOffered =
                        _normalizeSingleItemList(currentOffered);
                    final normalizedRequested =
                        _normalizeSingleItemList(currentRequested);

                    final oppositeSide = editsOfferedItems
                        ? normalizedRequested
                        : normalizedOffered;

                    if (oppositeSide.isNotEmpty &&
                        oppositeSide.first.playerId == player.id) {
                      _showSnack(
                        'You cannot swap the same sticker for itself.',
                        color: _TradeRoomStyle.error,
                      );
                      return;
                    }

                    final newItem = _buildSingleTradeItem(
                      player: player,
                      isOffered: editsOfferedItems,
                    );

                    final updatedOffered =
                        editsOfferedItems ? [newItem] : normalizedOffered;

                    final updatedRequested =
                        editsOfferedItems ? normalizedRequested : [newItem];

                    await repo.updateTradeItems(
                      widget.tradeId,
                      updatedOffered,
                      updatedRequested,
                    );

                    await _resetBothAgreements(
                      senderId: senderId,
                      receiverId: receiverId,
                    );

                    ref.invalidate(liveTradeStreamProvider(widget.tradeId));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openChatSheet({
    required AsyncValue<List<TradeChatItemModel>> chatsAsync,
    required UserModel currentUser,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: _TradeRoomStyle.warmBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(
                  color: _TradeRoomStyle.goldBorder,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _TradeRoomStyle.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _TradeChatPanel(
                        chatsAsync: chatsAsync,
                        currentUserId: currentUser.id,
                        chatController: _chatController,
                        chatScrollController: _chatScrollController,
                        onSend: (message) => _sendMessage(message, currentUser),
                        chipBuilder: (text) => _buildNegotiationChip(
                          text,
                          currentUser,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final tradeAsync = ref.watch(liveTradeStreamProvider(widget.tradeId));
    final chatsAsync = ref.watch(liveTradeChatsProvider(widget.tradeId));

    ref.listen(liveTradeChatsProvider(widget.tradeId), (prev, next) {
      if (next.hasValue) _scrollToBottom();
    });

    return authState.when(
      data: (currentUser) {
        if (currentUser == null) {
          return const Scaffold(
            backgroundColor: _TradeRoomStyle.warmBackground,
            body: Center(
              child: _EmptyStateCard(
                icon: Icons.lock_outline,
                title: 'Sign in required',
                message: 'Sign in to negotiate sticker trades.',
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: _TradeRoomStyle.warmBackground,
          appBar: AppBar(
            backgroundColor: _TradeRoomStyle.warmBackground,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: _TradeRoomStyle.navy),
            titleSpacing: 0,
            title: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: _TradeRoomStyle.success,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .fadeIn(duration: 520.ms)
                    .fadeOut(delay: 520.ms),
                const SizedBox(width: 10),
                const Text(
                  'Live Swap Room',
                  style: TextStyle(
                    color: _TradeRoomStyle.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Open chat',
                onPressed: () => _openChatSheet(
                  chatsAsync: chatsAsync,
                  currentUser: currentUser,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  _showSnack(
                    'Each trade must be exactly 1 sticker for 1 sticker. Both collectors must lock agreement.',
                  );
                },
              ),
            ],
          ),
          body: tradeAsync.when(
            data: (trade) {
              if (trade.status == 'accepted' && !_isSuccessOverlayVisible) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _isSuccessOverlayVisible) return;

                  setState(() => _isSuccessOverlayVisible = true);
                  ref.invalidate(collectionProvider);
                });
              }

              final isSender = trade.senderId == currentUser.id;

              final partnerUsername = isSender
                  ? (trade.receiverUsername ?? 'Collector')
                  : (trade.senderUsername ?? 'Collector');

              final partnerAvatar = isSender
                  ? 'https://api.dicebear.com/7.x/pixel-art/png?seed=${trade.receiverId}'
                  : 'https://api.dicebear.com/7.x/pixel-art/png?seed=${trade.senderId}';

              final myOffer = isSender
                  ? _normalizeSingleItemList(trade.offeredItems)
                  : _normalizeSingleItemList(trade.requestedItems);

              final theirOffer = isSender
                  ? _normalizeSingleItemList(trade.requestedItems)
                  : _normalizeSingleItemList(trade.offeredItems);

              final myAgreed =
                  isSender ? trade.senderAgreed : trade.receiverAgreed;

              final theirAgreed =
                  isSender ? trade.receiverAgreed : trade.senderAgreed;

              return Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: _AgreementCard(
                                avatarUrl: currentUser.avatarUrl,
                                title: 'YOU',
                                locked: myAgreed,
                                accentColor: _TradeRoomStyle.navy,
                                trailing: Switch(
                                  value: myAgreed,
                                  activeThumbColor: _TradeRoomStyle.navy,
                                  activeTrackColor: _TradeRoomStyle.navy
                                      .withValues(alpha: 0.32),
                                  inactiveThumbColor: _TradeRoomStyle.muted,
                                  inactiveTrackColor: _TradeRoomStyle.line,
                                  onChanged: trade.status != 'pending'
                                      ? null
                                      : (val) async {
                                          try {
                                            if (val) {
                                              final reason =
                                                  _getAgreementBlockReason(
                                                offeredItems:
                                                    trade.offeredItems,
                                                requestedItems:
                                                    trade.requestedItems,
                                              );

                                              if (reason != null) {
                                                _showSnack(
                                                  reason,
                                                  color: _TradeRoomStyle.error,
                                                );
                                                return;
                                              }
                                            }

                                            await ref
                                                .read(tradeRepositoryProvider)
                                                .updateTradeAgreement(
                                                  trade.id,
                                                  currentUser.id,
                                                  val,
                                                );
                                          } catch (e) {
                                            debugPrint(
                                              'Agreement toggle error: $e',
                                            );

                                            _showSnack(
                                              'Could not update agreement.',
                                              color: _TradeRoomStyle.error,
                                            );
                                          }
                                        },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AgreementCard(
                                avatarUrl: partnerAvatar,
                                title: partnerUsername.toUpperCase(),
                                locked: theirAgreed,
                                accentColor: _TradeRoomStyle.goldDark,
                                trailing: Icon(
                                  theirAgreed ? Icons.lock : Icons.lock_open,
                                  color: theirAgreed
                                      ? _TradeRoomStyle.goldDark
                                      : _TradeRoomStyle.muted,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 540;

                              final yourPanel = _TradeOfferPanel(
                                title: 'Your Offer',
                                count: myOffer.isEmpty ? 0 : 1,
                                accentColor: _TradeRoomStyle.navy,
                                child: _buildTradeCardSlot(
                                  context,
                                  items: myOffer,
                                  editsOfferedItems: isSender,
                                  pickerRequiresDuplicate: true,
                                  locked: myAgreed ||
                                      trade.status != 'pending',
                                  currentOffered: trade.offeredItems,
                                  currentRequested: trade.requestedItems,
                                  senderId: trade.senderId,
                                  receiverId: trade.receiverId,
                                ),
                              );

                              final theirPanel = _TradeOfferPanel(
                                title:
                                    '${partnerUsername.toUpperCase()}\'S OFFER',
                                count: theirOffer.isEmpty ? 0 : 1,
                                accentColor: _TradeRoomStyle.goldDark,
                                child: _buildTradeCardSlot(
                                  context,
                                  items: theirOffer,
                                  editsOfferedItems: !isSender,
                                  pickerRequiresDuplicate: false,
                                  locked: myAgreed ||
                                      trade.status != 'pending',
                                  currentOffered: trade.offeredItems,
                                  currentRequested: trade.requestedItems,
                                  senderId: trade.senderId,
                                  receiverId: trade.receiverId,
                                ),
                              );

                              if (isMobile) {
                                return Column(
                                  children: [
                                    Expanded(child: yourPanel),
                                    const SizedBox(height: 10),
                                    Expanded(child: theirPanel),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: yourPanel),
                                  const SizedBox(width: 10),
                                  Expanded(child: theirPanel),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      _OpenChatBar(
                        chatsAsync: chatsAsync,
                        onOpen: () => _openChatSheet(
                          chatsAsync: chatsAsync,
                          currentUser: currentUser,
                        ),
                      ),
                    ],
                  ),

                  if (_isSuccessOverlayVisible)
                    Positioned.fill(
                      child: _SuccessOverlay(
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _EmptyStateCard(
                  icon: Icons.error_outline,
                  title: 'Could not load trade',
                  message: '$e',
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: _TradeRoomStyle.warmBackground,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _TradeRoomStyle.warmBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _EmptyStateCard(
              icon: Icons.error_outline,
              title: 'Authentication error',
              message: '$e',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTradeCardSlot(
    BuildContext context, {
    required List<TradeItemModel> items,
    required bool editsOfferedItems,
    required bool pickerRequiresDuplicate,
    required bool locked,
    required List<TradeItemModel> currentOffered,
    required List<TradeItemModel> currentRequested,
    required String senderId,
    required String? receiverId,
  }) {
    final accent =
        editsOfferedItems ? _TradeRoomStyle.navy : _TradeRoomStyle.goldDark;

    final visibleItems = _normalizeSingleItemList(items);
    final hasSticker = visibleItems.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final cardHeight = availableHeight < 220
            ? availableHeight.clamp(132.0, 180.0).toDouble()
            : 190.0;

        return ListView(
          padding: const EdgeInsets.all(10),
          children: [
            if (!hasSticker)
              Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _TradeRoomStyle.softBlue.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _TradeRoomStyle.line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.style_outlined,
                      color: accent.withValues(alpha: 0.48),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locked ? 'No sticker selected' : 'Add one sticker',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _TradeRoomStyle.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: cardHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _MiniTradeStickerCard(
                        item: visibleItems.first,
                      ),
                    ),
                    if (!locked)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _clearTradeSide(
                            clearsOfferedItems: editsOfferedItems,
                            currentOffered: currentOffered,
                            currentRequested: currentRequested,
                            senderId: senderId,
                            receiverId: receiverId,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _TradeRoomStyle.error,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _TradeRoomStyle.error.withValues(
                                    alpha: 0.24,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            if (!locked) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent, width: 1.2),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  hasSticker ? Icons.swap_horiz : Icons.add,
                  size: 17,
                ),
                label: Text(
                  hasSticker ? 'CHANGE STICKER' : 'ADD STICKER',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                onPressed: () => _showStickerPicker(
                  context,
                  editsOfferedItems: editsOfferedItems,
                  pickerRequiresDuplicate: pickerRequiresDuplicate,
                  currentOffered: currentOffered,
                  currentRequested: currentRequested,
                  senderId: senderId,
                  receiverId: receiverId,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildNegotiationChip(String text, UserModel user) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        side: const BorderSide(color: _TradeRoomStyle.goldBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        label: Text(
          text,
          style: const TextStyle(
            color: _TradeRoomStyle.inkSoft,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: () => _sendMessage(text, user),
      ),
    );
  }
}

class _OpenChatBar extends StatelessWidget {
  final AsyncValue<List<TradeChatItemModel>> chatsAsync;
  final VoidCallback onOpen;

  const _OpenChatBar({
    required this.chatsAsync,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final count = chatsAsync.valueOrNull?.length ?? 0;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _TradeRoomStyle.goldBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: _TradeRoomStyle.navy,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Negotiation Chat',
                    style: TextStyle(
                      color: _TradeRoomStyle.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'Open chat to negotiate.'
                        : '$count message${count == 1 ? '' : 's'} in this trade.',
                    style: const TextStyle(
                      color: _TradeRoomStyle.inkSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: _TradeRoomStyle.navy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'OPEN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeChatPanel extends StatelessWidget {
  final AsyncValue<List<TradeChatItemModel>> chatsAsync;
  final String currentUserId;
  final TextEditingController chatController;
  final ScrollController chatScrollController;
  final ValueChanged<String> onSend;
  final Widget Function(String text) chipBuilder;

  const _TradeChatPanel({
    required this.chatsAsync,
    required this.currentUserId,
    required this.chatController,
    required this.chatScrollController,
    required this.onSend,
    required this.chipBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _TradeRoomStyle.goldBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: _TradeRoomStyle.navy,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Negotiation Chat',
                        style: TextStyle(
                          color: _TradeRoomStyle.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Send quick offers or custom messages',
                        style: TextStyle(
                          color: _TradeRoomStyle.inkSoft,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                chipBuilder('One for one?'),
                chipBuilder('Can you change yours?'),
                chipBuilder('I can offer this one.'),
                chipBuilder('Deal! Lock in!'),
                chipBuilder('Swap shiny? ✨'),
              ],
            ),
          ),
          const Divider(height: 1, color: _TradeRoomStyle.line),
          Expanded(
            child: _buildChatsList(context),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _TradeRoomStyle.inputBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _TradeRoomStyle.line),
                    ),
                    child: TextField(
                      controller: chatController,
                      onSubmitted: onSend,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _TradeRoomStyle.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(
                          color: _TradeRoomStyle.muted,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _TradeRoomStyle.navy,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _TradeRoomStyle.navy.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => onSend(chatController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsList(BuildContext context) {
    return chatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) {
          return const Center(
            child: _EmptyChatState(),
          );
        }

        return ListView.builder(
          controller: chatScrollController,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          itemCount: chats.length,
          itemBuilder: (context, idx) {
            final chat = chats[idx];
            final isMine = chat.senderId == currentUserId;
            final isBot = chat.senderId.startsWith('mock-bot-');

            return Align(
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                decoration: BoxDecoration(
                  color: isMine ? _TradeRoomStyle.navy : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMine
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                    bottomRight: isMine
                        ? const Radius.circular(4)
                        : const Radius.circular(16),
                  ),
                  border: Border.all(
                    color: isMine
                        ? _TradeRoomStyle.navy
                        : _TradeRoomStyle.goldBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMine) ...[
                      Text(
                        chat.senderUsername,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isBot
                              ? _TradeRoomStyle.goldDark
                              : _TradeRoomStyle.navy,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      chat.message,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isMine ? Colors.white : _TradeRoomStyle.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 1.8),
      ),
      error: (e, _) => Center(
        child: Text(
          'Error loading chats: $e',
          style: const TextStyle(
            color: _TradeRoomStyle.error,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AgreementCard extends StatelessWidget {
  final String avatarUrl;
  final String title;
  final bool locked;
  final Color accentColor;
  final Widget trailing;

  const _AgreementCard({
    required this.avatarUrl,
    required this.title,
    required this.locked,
    required this.accentColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: locked ? accentColor : _TradeRoomStyle.goldBorder,
          width: locked ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: locked ? accentColor : _TradeRoomStyle.line,
              ),
            ),
            child: PlayerAvatar(url: avatarUrl, size: 30),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _TradeRoomStyle.inkSoft,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  locked ? 'LOCKED' : 'NEGOTIATING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: locked ? accentColor : _TradeRoomStyle.muted,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _TradeOfferPanel extends StatelessWidget {
  final String title;
  final int count;
  final Color accentColor;
  final Widget child;

  const _TradeOfferPanel({
    required this.title,
    required this.count,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _TradeRoomStyle.goldBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: accentColor.withValues(alpha: 0.09),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '$count card${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: _TradeRoomStyle.inkSoft,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _MiniTradeStickerCard extends StatelessWidget {
  final TradeItemModel item;

  const _MiniTradeStickerCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final player = item.player!;
    final isGold = player.isShiny;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isGold
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.goldLight,
                  AppTheme.goldMedium,
                  AppTheme.goldDark,
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  _TradeRoomStyle.softBlue,
                ],
              ),
        border: Border.all(
          color: isGold ? _TradeRoomStyle.gold : _TradeRoomStyle.softBlueBorder,
          width: isGold ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -20,
              child: Icon(
                Icons.sports_soccer,
                size: 82,
                color: _TradeRoomStyle.navy.withValues(alpha: 0.045),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _MiniStatBadge(
                      value: '${player.rating}',
                      isGold: isGold,
                    ),
                    const Spacer(),
                    Text(
                      player.position,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isGold
                            ? AppTheme.goldDeep
                            : _TradeRoomStyle.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    child: Center(
                      child: PlayerAvatar(
                        url: player.avatarUrl,
                        size: 72,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  player.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.05,
                    color: isGold
                        ? AppTheme.goldDeep
                        : _TradeRoomStyle.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '#${player.number}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isGold
                        ? AppTheme.goldDeep.withValues(alpha: 0.64)
                        : _TradeRoomStyle.inkSoft,
                  ),
                ),
              ],
            ),
            if (isGold)
              const Positioned(
                right: 0,
                bottom: 0,
                child: Icon(
                  Icons.star,
                  size: 15,
                  color: AppTheme.shinyGold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatBadge extends StatelessWidget {
  final String value;
  final bool isGold;

  const _MiniStatBadge({
    required this.value,
    required this.isGold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isGold ? AppTheme.goldDeep : _TradeRoomStyle.navy,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: _TradeRoomStyle.softBlue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.forum_outlined,
            color: _TradeRoomStyle.navy,
            size: 21,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'No messages yet',
          style: TextStyle(
            color: _TradeRoomStyle.ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Send a message to start negotiating.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _TradeRoomStyle.inkSoft,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _TradeRoomStyle.goldBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: _TradeRoomStyle.softBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: _TradeRoomStyle.navy, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _TradeRoomStyle.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _TradeRoomStyle.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessOverlay extends StatelessWidget {
  final VoidCallback onBack;

  const _SuccessOverlay({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.38),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: _TradeRoomStyle.goldBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 38,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                color: _TradeRoomStyle.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 66,
                color: _TradeRoomStyle.success,
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  duration: 1.seconds,
                  curve: Curves.elasticOut,
                )
                .then()
                .shake(hz: 3, duration: 800.ms),
            const SizedBox(height: 22),
            const Text(
              'Swap Successful!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _TradeRoomStyle.ink,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.25),
            const SizedBox(height: 9),
            const Text(
              'Your sticker collections have been updated.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _TradeRoomStyle.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _TradeRoomStyle.navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text(
                  'Back to Trading',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ).animate().scale(
                  delay: 500.ms,
                  duration: 400.ms,
                  curve: Curves.easeOutBack,
                ),
          ],
        ),
      ),
    );
  }
}

class _TradeRoomStyle {
  static const Color warmBackground = AppTheme.warmBackground;
  static const Color navy = AppTheme.primaryNavy;
  static const Color ink = AppTheme.ink;
  static const Color inkSoft = AppTheme.inkSoft;
  static const Color muted = AppTheme.muted;
  static const Color inputBackground = AppTheme.inputBackground;
  static const Color softBlue = AppTheme.blueTint;
  static const Color softBlueBorder = AppTheme.blueBorder;
  static const Color line = AppTheme.line;
  static const Color gold = AppTheme.gold;
  static const Color goldDark = AppTheme.goldDark;
  static const Color goldBorder = AppTheme.goldBorder;
  static const Color success = AppTheme.success;
  static const Color error = AppTheme.danger;
}