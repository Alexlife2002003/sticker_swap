import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/trade_model.dart';
import '../utils/generator.dart';
import 'base_repositories.dart';

class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<UserModel?>.broadcast();
  UserModel? _currentUser;
  
  static const String _usersKey = 'mock_registered_users';
  static const String _currentSessionKey = 'mock_current_session';

  MockAuthRepository() {
    _initSession();
  }

  Future<void> _initSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionData = prefs.getString(_currentSessionKey);
    if (sessionData != null) {
      _currentUser = UserModel.fromJson(jsonDecode(sessionData));
      _controller.add(_currentUser);
    } else {
      _controller.add(null);
    }
  }

  @override
  Stream<UserModel?> get onAuthStateChanged => _controller.stream;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<UserModel> signIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulating network latency
    final prefs = await SharedPreferences.getInstance();
    final usersData = prefs.getStringList(_usersKey) ?? [];

    for (var uStr in usersData) {
      final json = jsonDecode(uStr);
      if (json['email'] == email.trim().toLowerCase()) {
        if (json['password'] == password) {
          final user = UserModel.fromJson(json);
          _currentUser = user;
          await prefs.setString(_currentSessionKey, jsonEncode(user.toJson()));
          _controller.add(user);
          return user;
        } else {
          throw Exception('Incorrect password. Please try again.');
        }
      }
    }
    throw Exception('No account found with this email. Please sign up!');
  }

  @override
  Future<UserModel> signUp(String email, String password, String username) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final prefs = await SharedPreferences.getInstance();
    final usersData = prefs.getStringList(_usersKey) ?? [];

    final cleanEmail = email.trim().toLowerCase();

    // 1. UNIQUE EMAIL CHECK
    for (var uStr in usersData) {
      final json = jsonDecode(uStr);
      if (json['email'] == cleanEmail) {
        throw Exception('This email is already taken. Please sign in or use another.');
      }
      if (json['username'] == username.trim()) {
        throw Exception('Username is already taken.');
      }
    }

    // 2. CREATE NEW USER IN MOCK STORAGE
    final id = const Uuid().v4();
    final newUser = UserModel(
      id: id,
      username: username.trim(),
      email: cleanEmail,
      avatarUrl: 'https://api.dicebear.com/7.x/bottts/svg?seed=$username',
      coins: 100,
      freePacksClaimedToday: 0,
      lastFreePackClaimedAt: null,
    );

    // Save with mock password included
    final userJson = newUser.toJson();
    userJson['password'] = password;

    usersData.add(jsonEncode(userJson));
    await prefs.setStringList(_usersKey, usersData);

    // Auto sign-in
    _currentUser = newUser;
    await prefs.setString(_currentSessionKey, jsonEncode(newUser.toJson()));
    _controller.add(newUser);

    return newUser;
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    final List<UserModel> list = [
      UserModel(
        id: 'mock-bot-1',
        username: 'StickerGuru99',
        email: 'guru@swap.com',
        avatarUrl: 'https://api.dicebear.com/7.x/pixel-art/png?seed=guru',
        coins: 500,
      ),
      UserModel(
        id: 'mock-bot-2',
        username: 'SwapLegend',
        email: 'legend@swap.com',
        avatarUrl: 'https://api.dicebear.com/7.x/pixel-art/png?seed=legend',
        coins: 750,
      ),
      UserModel(
        id: 'mock-bot-3',
        username: 'ShinyHunter',
        email: 'hunter@swap.com',
        avatarUrl: 'https://api.dicebear.com/7.x/pixel-art/png?seed=hunter',
        coins: 200,
      ),
      UserModel(
        id: 'mock-bot-4',
        username: 'PaniniKing',
        email: 'panini@swap.com',
        avatarUrl: 'https://api.dicebear.com/7.x/pixel-art/png?seed=panini',
        coins: 1000,
      ),
    ];

    try {
      final prefs = await SharedPreferences.getInstance();
      final usersData = prefs.getStringList(_usersKey) ?? [];
      for (var uStr in usersData) {
        final json = jsonDecode(uStr);
        if (json['id'] != _currentUser?.id) {
          list.add(UserModel.fromJson(json));
        }
      }
    } catch (_) {}
    return list;
  }

  // Helper to update mock user coins and stats locally
  Future<void> updateMockUser(UserModel updatedUser) async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = updatedUser;
    await prefs.setString(_currentSessionKey, jsonEncode(updatedUser.toJson()));
    
    // Update in registered accounts too
    final usersData = prefs.getStringList(_usersKey) ?? [];
    final updatedList = usersData.map((uStr) {
      final json = jsonDecode(uStr);
      if (json['id'] == updatedUser.id) {
        final newJson = updatedUser.toJson();
        newJson['password'] = json['password']; // Preserve password
        return jsonEncode(newJson);
      }
      return uStr;
    }).toList();
    await prefs.setStringList(_usersKey, updatedList);
    
    _controller.add(updatedUser);
  }
}

class MockStickerRepository implements StickerRepository {
  final List<TeamModel> _teams = StickerGenerator.generateTeams();
  late final List<PlayerModel> _players = StickerGenerator.generatePlayers(_teams);
  final MockAuthRepository _authRepo;

  MockStickerRepository(this._authRepo);

  @override
  Future<List<TeamModel>> getTeams() async {
    return _teams;
  }

  @override
  Future<List<PlayerModel>> getPlayers() async {
    return _players;
  }

  @override
  Future<Map<int, int>> getUserCollection() async {
    final user = _authRepo.currentUser;
    if (user == null) return {};

    final prefs = await SharedPreferences.getInstance();
    final collectionStr = prefs.getString('mock_collection_${user.id}');
    if (collectionStr == null) return {};

    final Map<String, dynamic> rawMap = jsonDecode(collectionStr);
    return rawMap.map((key, value) => MapEntry(int.parse(key), value as int));
  }

  @override
  Future<List<PlayerModel>> openPack(String userId) async {
    final user = _authRepo.currentUser;
    if (user == null || user.id != userId) {
      throw Exception('Session mismatch. Please sign in again.');
    }

    final now = DateTime.now();

    // 1. CALCULATE IF CLAIMS RESET (MIDNIGHT CHECK)
    bool isNewDay = true;
    if (user.lastFreePackClaimedAt != null) {
      final lastClaim = user.lastFreePackClaimedAt!;
      if (lastClaim.year == now.year &&
          lastClaim.month == now.month &&
          lastClaim.day == now.day) {
        isNewDay = false;
      }
    }

    int currentClaimCount = isNewDay ? 0 : user.freePacksClaimedToday;

    // 2. CHECK PACK CLAIM BOUNDARY (10 PER DAY)
    if (currentClaimCount >= 10) {
      // Calculate countdown to next midnight
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final waitDuration = tomorrow.difference(now);
      final hours = waitDuration.inHours;
      final minutes = waitDuration.inMinutes % 60;
      throw Exception(
        'Daily Free Limit Reached (10/10 packs opened today).\n'
        'Next claim unlocks in ${hours}h ${minutes}m (at midnight).'
      );
    }

    await Future.delayed(const Duration(milliseconds: 1500)); // Pack opening suspense delay!

    // 3. ROLL 7 RANDOM PLAYERS
    final random = Random();
    final List<PlayerModel> rolledStickers = [];
    
    for (int i = 0; i < 7; i++) {
      // 10% chance of pulling a high-rated shiny global superstar
      if (random.nextDouble() < 0.12) {
        final superstars = _players.where((p) => p.isShiny && p.rating >= 90).toList();
        if (superstars.isNotEmpty) {
          rolledStickers.add(superstars[random.nextInt(superstars.length)]);
          continue;
        }
      }
      
      // Otherwise, standard random sticker pull
      rolledStickers.add(_players[random.nextInt(_players.length)]);
    }

    // 4. UPDATE LOCAL COLLECTION IN PREFERENCES
    final prefs = await SharedPreferences.getInstance();
    final collectionStr = prefs.getString('mock_collection_${user.id}');
    final Map<int, int> collectionMap = {};
    if (collectionStr != null) {
      final Map<String, dynamic> rawMap = jsonDecode(collectionStr);
      rawMap.forEach((key, value) {
        collectionMap[int.parse(key)] = value as int;
      });
    }

    for (var sticker in rolledStickers) {
      collectionMap[sticker.id] = (collectionMap[sticker.id] ?? 0) + 1;
    }

    // Save back collection
    final savedMap = collectionMap.map((key, value) => MapEntry(key.toString(), value));
    await prefs.setString('mock_collection_${user.id}', jsonEncode(savedMap));

    // 5. UPDATE DAILY CLAIM STATS IN PROFILE
    final updatedUser = user.copyWith(
      freePacksClaimedToday: currentClaimCount + 1,
      lastFreePackClaimedAt: now,
    );
    await _authRepo.updateMockUser(updatedUser);

    return rolledStickers;
  }

  @override
  Future<void> addStickerToCollection(String userId, int playerId, int quantity) async {
    final prefs = await SharedPreferences.getInstance();
    final collectionStr = prefs.getString('mock_collection_$userId');
    final Map<int, int> collectionMap = {};
    
    if (collectionStr != null) {
      final Map<String, dynamic> rawMap = jsonDecode(collectionStr);
      rawMap.forEach((key, value) {
        collectionMap[int.parse(key)] = value as int;
      });
    }

    collectionMap[playerId] = (collectionMap[playerId] ?? 0) + quantity;
    if (collectionMap[playerId]! <= 0) {
      collectionMap.remove(playerId);
    }

    final savedMap = collectionMap.map((key, value) => MapEntry(key.toString(), value));
    await prefs.setString('mock_collection_$userId', jsonEncode(savedMap));
  }
}

class MockTradeRepository implements TradeRepository {
  final List<TradeModel> _tradesMemory = [];
  final MockStickerRepository _stickerRepo;

  MockTradeRepository(this._stickerRepo) {
    _populateSeedTrades();
  }

  // Pre-populates mock offers from other virtual players to look populated
  void _populateSeedTrades() {
    final random = Random();
    final now = DateTime.now();
    
    // Select a few superstars to trade
    final mesy = _stickerRepo._players.firstWhere((p) => p.name.contains('Mesi'));
    final ronalzo = _stickerRepo._players.firstWhere((p) => p.name.contains('Ronalzo'));
    final mpap = _stickerRepo._players.firstWhere((p) => p.name.contains('Mpap'));
    final random1 = _stickerRepo._players[random.nextInt(100)];
    final random2 = _stickerRepo._players[random.nextInt(100) + 100];

    // Trade 1: GoalStriker99 wants Mpap, offers Ronalzo
    final t1Id = const Uuid().v4();
    _tradesMemory.add(TradeModel(
      id: t1Id,
      senderId: 'v-trader-1',
      senderUsername: 'GoalStriker99',
      receiverId: null,
      status: 'pending',
      createdAt: now.subtract(const Duration(hours: 2)),
      items: [
        TradeItemModel(id: 'ti-1', tradeId: t1Id, playerId: ronalzo.id, isOffered: true, player: ronalzo),
        TradeItemModel(id: 'ti-2', tradeId: t1Id, playerId: mpap.id, isOffered: false, player: mpap),
      ],
    ));

    // Trade 2: FifaFanatic offers random stickers, wants Leonel Mesi
    final t2Id = const Uuid().v4();
    _tradesMemory.add(TradeModel(
      id: t2Id,
      senderId: 'v-trader-2',
      senderUsername: 'FifaFanatic',
      receiverId: null,
      status: 'pending',
      createdAt: now.subtract(const Duration(minutes: 45)),
      items: [
        TradeItemModel(id: 'ti-3', tradeId: t2Id, playerId: random1.id, isOffered: true, player: random1),
        TradeItemModel(id: 'ti-4', tradeId: t2Id, playerId: random2.id, isOffered: true, player: random2),
        TradeItemModel(id: 'ti-5', tradeId: t2Id, playerId: mesy.id, isOffered: false, player: mesy),
      ],
    ));
  }

  @override
  Future<List<TradeModel>> getOpenTrades() async {
    // Open trades are pending and not directed to a specific different user
    return _tradesMemory.where((t) => t.status == 'pending').toList();
  }

  @override
  Future<List<TradeModel>> getUserTrades(String userId) async {
    return _tradesMemory.where((t) => t.senderId == userId || t.receiverId == userId).toList();
  }

  @override
  Future<TradeModel> createTradeOffer({
    required String senderId,
    required List<TradeItemModel> offeredItems,
    required List<TradeItemModel> requestedItems,
    String? receiverId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final tradeId = const Uuid().v4();

    final user = _stickerRepo._authRepo.currentUser;
    final username = user?.username ?? 'Collector';

    // Verify collector actually owns the offered stickers
    final collection = await _stickerRepo.getUserCollection();
    for (var offer in offeredItems) {
      final ownedQty = collection[offer.playerId] ?? 0;
      if (ownedQty < offer.quantity) {
        final p = _stickerRepo._players.firstWhere((p) => p.id == offer.playerId);
        throw Exception("Insufficient duplicates of ${p.name} (have: $ownedQty, offering: ${offer.quantity})");
      }
    }

    final List<TradeItemModel> fullyHydratedItems = [];

    for (var item in offeredItems) {
      fullyHydratedItems.add(item.copyWith(
        id: const Uuid().v4(),
        tradeId: tradeId,
        player: _stickerRepo._players.firstWhere((p) => p.id == item.playerId),
      ));
    }

    for (var item in requestedItems) {
      fullyHydratedItems.add(item.copyWith(
        id: const Uuid().v4(),
        tradeId: tradeId,
        player: _stickerRepo._players.firstWhere((p) => p.id == item.playerId),
      ));
    }

    final newTrade = TradeModel(
      id: tradeId,
      senderId: senderId,
      senderUsername: username,
      receiverId: receiverId,
      status: 'pending',
      createdAt: DateTime.now(),
      items: fullyHydratedItems,
    );

    _tradesMemory.insert(0, newTrade);
    return newTrade;
  }

  @override
  Future<void> acceptTrade(String tradeId, String receiverId) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final idx = _tradesMemory.indexWhere((t) => t.id == tradeId);
    if (idx == -1) throw Exception('Trade offer no longer exists.');

    final trade = _tradesMemory[idx];
    if (trade.status != 'pending') throw Exception('Trade is no longer active.');
    if (trade.senderId == receiverId) throw Exception('You cannot accept your own trade!');

    // But since it's mock, let's verify both collections
    final prefs = await SharedPreferences.getInstance();
    
    final senderCollStr = prefs.getString('mock_collection_${trade.senderId}');
    final Map<int, int> senderCollection = {};
    if (senderCollStr != null) {
      final Map<String, dynamic> rawMap = jsonDecode(senderCollStr);
      rawMap.forEach((key, value) {
        senderCollection[int.parse(key)] = value as int;
      });
    }

    final receiverCollStr = prefs.getString('mock_collection_$receiverId');
    final Map<int, int> receiverCollection = {};
    if (receiverCollStr != null) {
      final Map<String, dynamic> rawMap = jsonDecode(receiverCollStr);
      rawMap.forEach((key, value) {
        receiverCollection[int.parse(key)] = value as int;
      });
    }

    // Check sender has offered items
    for (var off in trade.offeredItems) {
      final ownedQty = senderCollection[off.playerId] ?? 0;
      if (ownedQty < off.quantity) {
        final p = _stickerRepo._players.firstWhere((p) => p.id == off.playerId);
        throw Exception("Sender does not have enough copies of ${p.name} to complete this trade.");
      }
    }

    // Check receiver has requested items
    for (var req in trade.requestedItems) {
      final ownedQty = receiverCollection[req.playerId] ?? 0;
      if (ownedQty < req.quantity) {
        final p = _stickerRepo._players.firstWhere((p) => p.id == req.playerId);
        throw Exception("You do not have enough copies of ${p.name} to complete this trade.");
      }
    }

    // 2. APPLY SWAP - ATOMIC TRANSACTION SIMULATION
    // receiver gains offered, loses requested
    for (var off in trade.offeredItems) {
      // deduct from sender, add to receiver
      await _stickerRepo.addStickerToCollection(trade.senderId, off.playerId, -off.quantity);
      await _stickerRepo.addStickerToCollection(receiverId, off.playerId, off.quantity);
    }

    for (var req in trade.requestedItems) {
      // deduct from receiver, add to sender
      await _stickerRepo.addStickerToCollection(receiverId, req.playerId, -req.quantity);
      await _stickerRepo.addStickerToCollection(trade.senderId, req.playerId, req.quantity);
    }

    // Update trade status
    final receiverProfileStr = prefs.getString('mock_current_session');
    String rUsername = 'Acceptor';
    if (receiverProfileStr != null) {
      final profileJson = jsonDecode(receiverProfileStr);
      if (profileJson['id'] == receiverId) {
        rUsername = profileJson['username'] ?? 'Acceptor';
      }
    }

    _tradesMemory[idx] = trade.copyWith(
      status: 'accepted',
      receiverId: receiverId,
      receiverUsername: rUsername,
    );
  }

  @override
  Future<void> rejectOrCancelTrade(String tradeId, String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final idx = _tradesMemory.indexWhere((t) => t.id == tradeId);
    if (idx == -1) throw Exception('Trade offer no longer exists.');

    final trade = _tradesMemory[idx];
    if (trade.senderId == userId) {
      _tradesMemory[idx] = trade.copyWith(status: 'cancelled');
    } else if (trade.receiverId == userId) {
      _tradesMemory[idx] = trade.copyWith(status: 'rejected');
    } else {
      throw Exception('Unauthorized trade action.');
    }
  }

  // --- Real-time & Live Friend Interactions ---
  final Map<String, List<TradeChatItemModel>> _chatsMemory = {};
  final Map<String, StreamController<TradeModel>> _tradeStreams = {};
  final Map<String, StreamController<List<TradeChatItemModel>>> _chatStreams = {};

  @override
  Stream<TradeModel> streamTrade(String tradeId) {
    final controller = _tradeStreams.putIfAbsent(tradeId, () => StreamController<TradeModel>.broadcast());
    
    final idx = _tradesMemory.indexWhere((t) => t.id == tradeId);
    if (idx != -1) {
      Timer(const Duration(milliseconds: 100), () {
        if (!controller.isClosed) controller.add(_tradesMemory[idx]);
      });
    }
    
    return controller.stream;
  }

  @override
  Stream<List<TradeChatItemModel>> streamChats(String tradeId) {
    final controller = _chatStreams.putIfAbsent(tradeId, () => StreamController<List<TradeChatItemModel>>.broadcast());
    
    final chats = _chatsMemory.putIfAbsent(tradeId, () {
      final tradeIdx = _tradesMemory.indexWhere((t) => t.id == tradeId);
      if (tradeIdx != -1) {
        final trade = _tradesMemory[tradeIdx];
        final isBot = trade.receiverId?.startsWith('mock-bot-') ?? false;
        if (isBot) {
          final botUsername = trade.receiverUsername ?? 'Collector';
          return [
            TradeChatItemModel(
              id: const Uuid().v4(),
              tradeId: tradeId,
              senderId: trade.receiverId!,
              senderUsername: botUsername,
              message: "Hey! Let's negotiate in real-time. Add some stickers you want to swap, or ask me for what you need! ⚽",
              createdAt: DateTime.now(),
            )
          ];
        }
      }
      return [];
    });
    
    Timer(const Duration(milliseconds: 100), () {
      if (!controller.isClosed) controller.add(List.from(chats));
    });
    
    return controller.stream;
  }

  @override
  Future<void> sendChatMessage(String tradeId, String senderId, String senderUsername, String message) async {
    final chatMsg = TradeChatItemModel(
      id: const Uuid().v4(),
      tradeId: tradeId,
      senderId: senderId,
      senderUsername: senderUsername,
      message: message,
      createdAt: DateTime.now(),
    );
    
    final chats = _chatsMemory[tradeId] ?? [];
    chats.add(chatMsg);
    _chatsMemory[tradeId] = chats;
    
    _chatStreams[tradeId]?.add(List.from(chats));
    
    final tradeIdx = _tradesMemory.indexWhere((t) => t.id == tradeId);
    if (tradeIdx != -1) {
      final trade = _tradesMemory[tradeIdx];
      final isBot = trade.receiverId?.startsWith('mock-bot-') ?? false;
      if (isBot && senderId != trade.receiverId) {
        _handleBotChatResponse(tradeId, message);
      }
    }
  }

  void _handleBotChatResponse(String tradeId, String userMessage) {
    final tradeIdx = _tradesMemory.indexWhere((t) => t.id == tradeId);
    if (tradeIdx == -1) return;
    final trade = _tradesMemory[tradeIdx];
    final botId = trade.receiverId!;
    final botName = trade.receiverUsername ?? 'StickerGuru99';
    
    String responseText = "";
    final cleanMsg = userMessage.toLowerCase();
    
    if (cleanMsg.contains('hello') || cleanMsg.contains('hey') || cleanMsg.contains('hi')) {
      responseText = "Hey there! Looking to complete your album? Let me know what you want to swap.";
    } else if (cleanMsg.contains('messi') || cleanMsg.contains('ronaldo') || cleanMsg.contains('shiny') || cleanMsg.contains('superstar')) {
      responseText = "I love shiny superstar stickers! If you put one on the table, I'll definitely give you a premium trade! ✨";
    } else if (cleanMsg.contains('agree') || cleanMsg.contains('ready') || cleanMsg.contains('lock') || cleanMsg.contains('done')) {
      if (trade.senderAgreed) {
        responseText = "Awesome, you've agreed! I'll review our swap and lock in too!";
        Timer(const Duration(milliseconds: 1500), () {
          updateTradeAgreement(tradeId, botId, true);
        });
      } else {
        responseText = "Make sure you toggle your Agreement lock first so I can see you're ready!";
      }
    } else if (cleanMsg.contains('please') || cleanMsg.contains('more') || cleanMsg.contains('help')) {
      responseText = "Let me see if I can add another sticker to balance our swap. One sec!";
      Timer(const Duration(milliseconds: 2000), () {
        _addRandomBotOffer(tradeId);
      });
    } else {
      responseText = "Sounds like a plan! Check out our active cards and toggle your Agreement when you're happy with the swap! 🤝";
    }
    
    Timer(const Duration(milliseconds: 1500), () {
      final chats = _chatsMemory[tradeId] ?? [];
      chats.add(TradeChatItemModel(
        id: const Uuid().v4(),
        tradeId: tradeId,
        senderId: botId,
        senderUsername: botName,
        message: responseText,
        createdAt: DateTime.now(),
      ));
      _chatsMemory[tradeId] = chats;
      _chatStreams[tradeId]?.add(List.from(chats));
    });
  }

  void _addRandomBotOffer(String tradeId) {
    final idx = _tradesMemory.indexWhere((t) => t.id == tradeId);
    if (idx == -1) return;
    final trade = _tradesMemory[idx];
    
    final randomPlayer = _stickerRepo._players[Random().nextInt(_stickerRepo._players.length)];
    
    final newItem = TradeItemModel(
      id: const Uuid().v4(),
      tradeId: tradeId,
      playerId: randomPlayer.id,
      isOffered: false, 
      quantity: 1,
      player: randomPlayer,
    );
    
    final updatedItems = List<TradeItemModel>.from(trade.items)..add(newItem);
    final updated = trade.copyWith(
      items: updatedItems,
      senderAgreed: false,
      receiverAgreed: false,
    );
    
    _tradesMemory[idx] = updated;
    _tradeStreams[tradeId]?.add(updated);
    
    final chats = _chatsMemory[tradeId] ?? [];
    chats.add(TradeChatItemModel(
      id: const Uuid().v4(),
      tradeId: tradeId,
      senderId: trade.receiverId!,
      senderUsername: trade.receiverUsername ?? 'Collector',
      message: "Proposing to add ${randomPlayer.name} (#${randomPlayer.number}) from ${randomPlayer.position}! What do you think?",
      createdAt: DateTime.now(),
    ));
    _chatsMemory[tradeId] = chats;
    _chatStreams[tradeId]?.add(List.from(chats));
  }

  void _addHighRatedBotOffer(String tradeId) {
    final idx = _tradesMemory.indexWhere((t) => t.id == tradeId);
    if (idx == -1) return;
    final trade = _tradesMemory[idx];
    
    final stars = _stickerRepo._players.where((p) => p.isShiny && p.rating >= 92).toList();
    final starPlayer = stars.isNotEmpty ? stars[Random().nextInt(stars.length)] : _stickerRepo._players[0];
    
    final newItem = TradeItemModel(
      id: const Uuid().v4(),
      tradeId: tradeId,
      playerId: starPlayer.id,
      isOffered: false, 
      quantity: 1,
      player: starPlayer,
    );
    
    final updatedItems = List<TradeItemModel>.from(trade.items)..add(newItem);
    final updated = trade.copyWith(
      items: updatedItems,
      senderAgreed: false,
      receiverAgreed: false,
    );
    
    _tradesMemory[idx] = updated;
    _tradeStreams[tradeId]?.add(updated);
    
    final chats = _chatsMemory[tradeId] ?? [];
    chats.add(TradeChatItemModel(
      id: const Uuid().v4(),
      tradeId: tradeId,
      senderId: trade.receiverId!,
      senderUsername: trade.receiverUsername ?? 'Collector',
      message: "I've added the superstar ${starPlayer.name} (Rating: ${starPlayer.rating}! ✨) to my side. Check it out!",
      createdAt: DateTime.now(),
    ));
    _chatsMemory[tradeId] = chats;
    _chatStreams[tradeId]?.add(List.from(chats));
  }

  void _handleBotItemEvaluation(String tradeId, List<TradeItemModel> offered, List<TradeItemModel> requested) {
    final tradeIdx = _tradesMemory.indexWhere((t) => t.id == tradeId);
    if (tradeIdx == -1) return;
    final trade = _tradesMemory[tradeIdx];
    final botId = trade.receiverId!;
    final botName = trade.receiverUsername ?? 'Collector';
    
    bool userOffersSuperstar = false;
    String superstarName = "";
    for (var item in offered) {
      final p = _stickerRepo._players.firstWhere((p) => p.id == item.playerId);
      if (p.isShiny && p.rating >= 90) {
        userOffersSuperstar = true;
        superstarName = p.name;
        break;
      }
    }
    
    String text = "";
    if (offered.isEmpty && requested.isEmpty) {
      text = "We have an empty table now! Add some stickers to get this trade rolling.";
    } else if (offered.isEmpty) {
      text = "You are requesting my stickers, but you haven't offered anything yet! Propose some stickers on your side.";
    } else if (userOffersSuperstar) {
      text = "WHOA! You are offering the legendary shiny $superstarName?! 🌟 That is incredibly generous! Let me add my best star player to balance this out!";
      Timer(const Duration(milliseconds: 2000), () {
        _addHighRatedBotOffer(tradeId);
      });
    } else {
      text = "I see your proposed swap! Let me look at the ratings... It looks fair. Toggle your Agreement lock when you're ready!";
    }
    
    Timer(const Duration(milliseconds: 1000), () {
      final chats = _chatsMemory[tradeId] ?? [];
      chats.add(TradeChatItemModel(
        id: const Uuid().v4(),
        tradeId: tradeId,
        senderId: botId,
        senderUsername: botName,
        message: text,
        createdAt: DateTime.now(),
      ));
      _chatsMemory[tradeId] = chats;
      _chatStreams[tradeId]?.add(List.from(chats));
    });
  }

  @override
  Future<void> updateTradeAgreement(String tradeId, String userId, bool agreed) async {
    final idx = _tradesMemory.indexWhere((t) => t.id == tradeId);
    if (idx == -1) return;
    final trade = _tradesMemory[idx];
    
    final isSender = trade.senderId == userId;
    final updated = trade.copyWith(
      senderAgreed: isSender ? agreed : trade.senderAgreed,
      receiverAgreed: !isSender ? agreed : trade.receiverAgreed,
    );
    
    _tradesMemory[idx] = updated;
    _tradeStreams[tradeId]?.add(updated);
    
    if (updated.senderAgreed && updated.receiverAgreed) {
      Timer(const Duration(milliseconds: 1000), () async {
        try {
          await acceptTrade(tradeId, trade.receiverId ?? 'mock-bot-1');
          
          final acceptedIdx = _tradesMemory.indexWhere((t) => t.id == tradeId);
          if (acceptedIdx != -1) {
            _tradeStreams[tradeId]?.add(_tradesMemory[acceptedIdx]);
          }
          
          final chats = _chatsMemory[tradeId] ?? [];
          chats.add(TradeChatItemModel(
            id: const Uuid().v4(),
            tradeId: tradeId,
            senderId: trade.receiverId ?? 'mock-bot-1',
            senderUsername: trade.receiverUsername ?? 'Collector',
            message: "SWAP SUCCESSFUL! Both parties locked agreements and inventory was exchanged. It was a pleasure swapping with you! 🤝⚽🎉",
            createdAt: DateTime.now(),
          ));
          _chatsMemory[tradeId] = chats;
          _chatStreams[tradeId]?.add(List.from(chats));
        } catch (e) {
          debugPrint('[MockRepo] agreement auto-execute error: $e');
        }
      });
    } else {
      final isBot = trade.receiverId?.startsWith('mock-bot-') ?? false;
      if (isBot && isSender && agreed) {
        Timer(const Duration(milliseconds: 1500), () {
          updateTradeAgreement(tradeId, trade.receiverId!, true);
        });
      }
    }
  }

  @override
  Future<void> updateTradeItems(String tradeId, List<TradeItemModel> offeredItems, List<TradeItemModel> requestedItems) async {
    final idx = _tradesMemory.indexWhere((t) => t.id == tradeId);
    if (idx == -1) return;
    
    final trade = _tradesMemory[idx];
    
    final List<TradeItemModel> hydratedItems = [];
    for (var item in offeredItems) {
      hydratedItems.add(item.copyWith(
        player: item.player ?? _stickerRepo._players.firstWhere((p) => p.id == item.playerId),
      ));
    }
    for (var item in requestedItems) {
      hydratedItems.add(item.copyWith(
        player: item.player ?? _stickerRepo._players.firstWhere((p) => p.id == item.playerId),
      ));
    }
    
    final updated = trade.copyWith(
      items: hydratedItems,
      senderAgreed: false,
      receiverAgreed: false,
    );
    
    _tradesMemory[idx] = updated;
    _tradeStreams[tradeId]?.add(updated);
    
    final isBot = trade.receiverId?.startsWith('mock-bot-') ?? false;
    if (isBot) {
      _handleBotItemEvaluation(tradeId, offeredItems, requestedItems);
    }
  }
}
