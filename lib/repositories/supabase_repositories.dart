import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/trade_model.dart';
import 'base_repositories.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final _controller = StreamController<UserModel?>.broadcast();
  UserModel? _currentUser;

  SupabaseAuthRepository() {
    _client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user != null) {
        final profile = await _fetchProfile(user.id, user.email ?? '');
        _currentUser = profile;
        _controller.add(profile);
      } else {
        _currentUser = null;
        _controller.add(null);
      }
    });
  }

  Future<UserModel> _fetchProfile(String id, String email) async {
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .single();
      final map = Map<String, dynamic>.from(res);
      map['email'] = email;
      return UserModel.fromJson(map);
    } catch (e) {
      // Return a basic profile if loading errors or trigger hasn't finished yet
      return UserModel(
        id: id,
        username: email.split('@')[0],
        email: email,
        avatarUrl: 'https://api.dicebear.com/7.x/bottts/svg?seed=$id',
      );
    }
  }

  @override
  Stream<UserModel?> get onAuthStateChanged => _controller.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<UserModel> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (response.user == null) {
      throw Exception('Authentication failed.');
    }
    final profile = await _fetchProfile(response.user!.id, response.user!.email ?? '');
    _currentUser = profile;
    _controller.add(profile);
    return profile;
  }

  @override
  Future<UserModel> signUp(String email, String password, String username) async {
    final response = await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {'username': username.trim()},
    );
    if (response.user == null) {
      throw Exception('Sign up failed.');
    }
    // We add a tiny delay to ensure Postgres trigger on_auth_user_created completes
    await Future.delayed(const Duration(milliseconds: 500));
    final profile = await _fetchProfile(response.user!.id, response.user!.email ?? '');
    _currentUser = profile;
    _controller.add(profile);
    return profile;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    try {
      final res = await _client.from('profiles').select();
      return (res as List).map((p) {
        final map = Map<String, dynamic>.from(p);
        map['email'] = ''; // keep private
        return UserModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseRepo] getAllUsers ERROR: $e');
      return [];
    }
  }
}

class SupabaseStickerRepository implements StickerRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<TeamModel>> getTeams() async {
    try {
      final List res = await _client.from('teams').select().order('name');
      debugPrint('[SupabaseRepo] getTeams: loaded ${res.length} teams');
      return res.map((item) => TeamModel.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e, s) {
      debugPrint('[SupabaseRepo] getTeams ERROR: $e\n$s');
      rethrow;
    }
  }

  @override
  Future<List<PlayerModel>> getPlayers() async {
    try {
      final List res = await _client.from('players').select().order('id');
      debugPrint('[SupabaseRepo] getPlayers: loaded ${res.length} players');
      return res.map((item) => PlayerModel.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e, s) {
      debugPrint('[SupabaseRepo] getPlayers ERROR: $e\n$s');
      rethrow;
    }
  }

  @override
  Future<Map<int, int>> getUserCollection() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};
    try {
      final List res = await _client
          .from('user_collection')
          .select()
          .eq('user_id', user.id);
      debugPrint('[SupabaseRepo] getUserCollection: ${res.length} sticker rows');
      final Map<int, int> collection = {};
      for (var item in res) {
        final pId = item['player_id'] as int;
        final qty = item['quantity'] as int;
        if (qty > 0) collection[pId] = qty;
      }
      return collection;
    } catch (e, s) {
      debugPrint('[SupabaseRepo] getUserCollection ERROR: $e\n$s');
      rethrow;
    }
  }

  @override
  Future<List<PlayerModel>> openPack(String userId) async {
    // 1. FETCH PROFILE TO CHECK DAILY COUNTS
    final profileRes = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
        
    final now = DateTime.now().toUtc();
    final claimedToday = profileRes['free_packs_claimed_today'] as int? ?? 0;
    final lastClaimStr = profileRes['last_free_pack_claimed_at'] as String?;
    
    bool isNewDay = true;
    if (lastClaimStr != null) {
      final lastClaim = DateTime.parse(lastClaimStr).toLocal();
      final localNow = now.toLocal();
      if (lastClaim.year == localNow.year &&
          lastClaim.month == localNow.month &&
          lastClaim.day == localNow.day) {
        isNewDay = false;
      }
    }

    int currentClaimCount = isNewDay ? 0 : claimedToday;
    if (currentClaimCount >= 10) {
      final localNow = now.toLocal();
      final tomorrow = DateTime(localNow.year, localNow.month, localNow.day + 1);
      final waitDuration = tomorrow.difference(localNow);
      throw Exception(
        'Daily Free Limit Reached (10/10 packs opened).\n'
        'Reset unlocks in ${waitDuration.inHours}h ${waitDuration.inMinutes % 60}m.'
      );
    }

    // 2. ROLL 7 RANDOM PLAYERS FROM DB
    final List playersRes = await _client.from('players').select('id');
    if (playersRes.isEmpty) throw Exception('Player roster is empty. Run seed SQL first!');

    final random = Random();
    final randomIds = List.generate(7, (_) => playersRes[random.nextInt(playersRes.length)]['id'] as int);

    // 3. FETCH FULL PLAYER ENTRIES
    final uniqueIds = randomIds.toSet().toList();
    final List fullPlayersRes = await _client
        .from('players')
        .select()
        .inFilter('id', uniqueIds);
        
    final Map<int, PlayerModel> playerMap = {
      for (var p in fullPlayersRes)
        p['id'] as int: PlayerModel.fromJson(Map<String, dynamic>.from(p))
    };

    final List<PlayerModel> rolledStickers = randomIds
        .map((id) => playerMap[id])
        .whereType<PlayerModel>()
        .toList();

    // 4. WRITE COLLECTIONS TO DATABASE IN UPSERT LOOP
    for (var sticker in rolledStickers) {
      try {
        await _client.rpc('increment_sticker_inventory', params: {
          'p_user_id': userId,
          'p_player_id': sticker.id,
          'p_qty': 1
        });
        debugPrint('[SupabaseRepo] openPack: added sticker id=${sticker.id} (${sticker.name})');
      } catch (e, s) {
        debugPrint('[SupabaseRepo] openPack ERROR adding sticker ${sticker.id}: $e\n$s');
        rethrow;
      }
    }

    // 5. UPDATE PROFILE
    await _client.from('profiles').update({
      'free_packs_claimed_today': currentClaimCount + 1,
      'last_free_pack_claimed_at': now.toIso8601String(),
    }).eq('id', userId);

    return rolledStickers;
  }

  @override
  Future<void> addStickerToCollection(String userId, int playerId, int quantity) async {
    await _client.rpc('increment_sticker_inventory', params: {
      'p_user_id': userId,
      'p_player_id': playerId,
      'p_qty': quantity
    });
  }
}

class SupabaseTradeRepository implements TradeRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<TradeModel>> getOpenTrades() async {
    try {
      final List res = await _client
          .from('trades')
          .select('*, profiles!trades_sender_id_fkey(username), trade_items(*, players(*))')
          .eq('status', 'pending')
          .isFilter('receiver_id', null)
          .order('created_at', ascending: false);
      debugPrint('[SupabaseRepo] getOpenTrades: ${res.length} open trades');
      return _parseTrades(res);
    } catch (e, s) {
      debugPrint('[SupabaseRepo] getOpenTrades ERROR: $e\n$s');
      rethrow;
    }
  }

  @override
  Future<List<TradeModel>> getUserTrades(String userId) async {
    try {
      final List res = await _client
          .from('trades')
          .select('*, profiles!trades_sender_id_fkey(username), trade_items(*, players(*))')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);
      debugPrint('[SupabaseRepo] getUserTrades: ${res.length} user trades');
      return _parseTrades(res);
    } catch (e, s) {
      debugPrint('[SupabaseRepo] getUserTrades ERROR: $e\n$s');
      rethrow;
    }
  }

  List<TradeModel> _parseTrades(List raw) {
    return raw.map((t) {
      final tItemsRaw = t['trade_items'] as List? ?? [];
      // Key matches the explicit FK alias used in the select query
      final senderProfile = t['profiles!trades_sender_id_fkey'] as Map? ?? {};

      final items = tItemsRaw.map((ti) {
        final playerRaw = ti['players'] as Map<String, dynamic>?;
        return TradeItemModel.fromJson(
          Map<String, dynamic>.from(ti),
          player: playerRaw != null ? PlayerModel.fromJson(playerRaw) : null,
        );
      }).toList();

      return TradeModel.fromJson(
        Map<String, dynamic>.from(t),
        items: items,
      ).copyWith(
        senderUsername: senderProfile['username'],
      );
    }).toList();
  }

  @override
  Future<TradeModel> createTradeOffer({
    required String senderId,
    required List<TradeItemModel> offeredItems,
    required List<TradeItemModel> requestedItems,
    String? receiverId,
  }) async {
    // 1. INSERT THE HEADER
    final tradeRes = await _client.from('trades').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': 'pending',
    }).select().single();

    final tradeId = tradeRes['id'] as String;

    // 2. INSERT THE ITEMS
    final List<Map<String, dynamic>> itemsToInsert = [];
    for (var item in offeredItems) {
      itemsToInsert.add({
        'trade_id': tradeId,
        'player_id': item.playerId,
        'is_offered': true,
        'quantity': item.quantity,
      });
    }
    for (var item in requestedItems) {
      itemsToInsert.add({
        'trade_id': tradeId,
        'player_id': item.playerId,
        'is_offered': false,
        'quantity': item.quantity,
      });
    }

    if (itemsToInsert.isNotEmpty) {
      await _client.from('trade_items').insert(itemsToInsert);
    }

    // Return header
    return TradeModel.fromJson(Map<String, dynamic>.from(tradeRes), items: []);
  }

  @override
  Future<void> acceptTrade(String tradeId, String receiverId) async {
    // Performs live transacting via direct Postgres RPC function
    await _client.rpc('execute_sticker_trade', params: {
      'p_trade_id': tradeId,
      'p_receiver_id': receiverId,
    });
  }

  @override
  Future<void> rejectOrCancelTrade(String tradeId, String userId) async {
    final tradeRes = await _client.from('trades').select().eq('id', tradeId).single();
    final senderId = tradeRes['sender_id'] as String;
    
    if (senderId == userId) {
      await _client.from('trades').update({'status': 'cancelled'}).eq('id', tradeId);
    } else {
      await _client.from('trades').update({'status': 'rejected'}).eq('id', tradeId);
    }
  }

  @override
  Stream<TradeModel> streamTrade(String tradeId) {
    return _client
        .from('trades')
        .stream(primaryKey: ['id'])
        .eq('id', tradeId)
        .asyncMap((event) async {
          if (event.isEmpty) throw Exception('Trade not found');
          final t = event.first;
          
          final tItemsRaw = await _client
              .from('trade_items')
              .select('*, players(*)')
              .eq('trade_id', tradeId);
              
          final senderProfile = await _client
              .from('profiles')
              .select('username')
              .eq('id', t['sender_id'] as String)
              .maybeSingle();

          final receiverProfile = t['receiver_id'] != null
              ? await _client
                  .from('profiles')
                  .select('username')
                  .eq('id', t['receiver_id'] as String)
                  .maybeSingle()
              : null;

          final items = (tItemsRaw as List).map((ti) {
            final playerRaw = ti['players'] as Map<String, dynamic>?;
            return TradeItemModel.fromJson(
              Map<String, dynamic>.from(ti),
              player: playerRaw != null ? PlayerModel.fromJson(playerRaw) : null,
            );
          }).toList();

          return TradeModel.fromJson(
            Map<String, dynamic>.from(t),
            items: items,
          ).copyWith(
            senderUsername: senderProfile?['username'],
            receiverUsername: receiverProfile?['username'],
          );
        });
  }

  @override
  Stream<List<TradeChatItemModel>> streamChats(String tradeId) {
    return _client
        .from('trade_chats')
        .stream(primaryKey: ['id'])
        .eq('trade_id', tradeId)
        .order('created_at', ascending: true)
        .asyncMap((event) async {
          final List<TradeChatItemModel> list = [];
          for (var item in event) {
            final senderId = item['sender_id'] as String;
            final senderProfile = await _client
                .from('profiles')
                .select('username')
                .eq('id', senderId)
                .maybeSingle();
            list.add(TradeChatItemModel.fromJson(item).copyWith(
              senderUsername: senderProfile?['username'] ?? 'Collector',
            ));
          }
          return list;
        });
  }

  @override
  Future<void> sendChatMessage(String tradeId, String senderId, String senderUsername, String message) async {
    await _client.from('trade_chats').insert({
      'trade_id': tradeId,
      'sender_id': senderId,
      'message': message.trim(),
    });
  }

  @override
  Future<void> updateTradeAgreement(String tradeId, String userId, bool agreed) async {
    final tradeRes = await _client.from('trades').select().eq('id', tradeId).single();
    final isSender = tradeRes['sender_id'] == userId;
    
    Map<String, dynamic> updateData = {};
    if (isSender) {
      updateData['sender_agreed'] = agreed;
    } else {
      updateData['receiver_agreed'] = agreed;
    }
    
    final updatedRes = await _client
        .from('trades')
        .update(updateData)
        .eq('id', tradeId)
        .select()
        .single();
        
    final senderAgreed = updatedRes['sender_agreed'] as bool? ?? false;
    final receiverAgreed = updatedRes['receiver_agreed'] as bool? ?? false;
    final status = updatedRes['status'] as String? ?? 'pending';
    final receiverId = updatedRes['receiver_id'] as String?;
    
    if (senderAgreed && receiverAgreed && status == 'pending') {
      final rId = receiverId ?? (!isSender ? userId : null);
      if (rId != null) {
        await acceptTrade(tradeId, rId);
      }
    }
  }

  @override
  Future<void> updateTradeItems(String tradeId, List<TradeItemModel> offeredItems, List<TradeItemModel> requestedItems) async {
    await _client.from('trade_items').delete().eq('trade_id', tradeId);
    
    final List<Map<String, dynamic>> itemsToInsert = [];
    for (var item in offeredItems) {
      itemsToInsert.add({
        'trade_id': tradeId,
        'player_id': item.playerId,
        'is_offered': true,
        'quantity': item.quantity,
      });
    }
    for (var item in requestedItems) {
      itemsToInsert.add({
        'trade_id': tradeId,
        'player_id': item.playerId,
        'is_offered': false,
        'quantity': item.quantity,
      });
    }

    if (itemsToInsert.isNotEmpty) {
      await _client.from('trade_items').insert(itemsToInsert);
    }

    await _client.from('trades').update({
      'sender_agreed': false,
      'receiver_agreed': false,
    }).eq('id', tradeId);
  }
}
