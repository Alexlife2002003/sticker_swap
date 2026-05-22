import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/supabase_config.dart';
import '../models/user_model.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/trade_model.dart';
import '../repositories/base_repositories.dart';
import '../repositories/mock_repositories.dart';
import '../repositories/supabase_repositories.dart';

// 1. REPOSITORY PROVIDERS
// Conditionally load Mock or Live Supabase repos based on config
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseConfig.useSupabase) {
    return SupabaseAuthRepository();
  } else {
    return MockAuthRepository();
  }
});

final stickerRepositoryProvider = Provider<StickerRepository>((ref) {
  if (SupabaseConfig.useSupabase) {
    return SupabaseStickerRepository();
  } else {
    // Inject MockAuthRepository for session states
    final auth = ref.watch(authRepositoryProvider) as MockAuthRepository;
    return MockStickerRepository(auth);
  }
});

final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  if (SupabaseConfig.useSupabase) {
    return SupabaseTradeRepository();
  } else {
    final sticker = ref.watch(stickerRepositoryProvider) as MockStickerRepository;
    return MockTradeRepository(sticker);
  }
});

// 2. AUTH STATE PROVIDER
// Listens to stream of current user profiles
final authStateProvider = StreamProvider<UserModel?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.onAuthStateChanged;
});

// 3. STATICS PROVIDERS
final teamsProvider = FutureProvider<List<TeamModel>>((ref) async {
  final repo = ref.watch(stickerRepositoryProvider);
  return repo.getTeams();
});

final playersProvider = FutureProvider<List<PlayerModel>>((ref) async {
  final repo = ref.watch(stickerRepositoryProvider);
  return repo.getPlayers();
});

// 4. USER COLLECTION NOTIFIER (Holds Map<playerId, Quantity>)
class UserCollectionNotifier extends StateNotifier<AsyncValue<Map<int, int>>> {
  final StickerRepository _repo;
  final Ref _ref;

  UserCollectionNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    state = const AsyncValue.loading();
    try {
      // Monitor authState to reload collection upon user switching
      final auth = _ref.watch(authStateProvider).value;
      if (auth == null) {
        state = const AsyncValue.data({});
        return;
      }
      final coll = await _repo.getUserCollection();
      state = AsyncValue.data(coll);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    try {
      final coll = await _repo.getUserCollection();
      state = AsyncValue.data(coll);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // Local optimization after opening packs
  void addStickers(List<PlayerModel> items) {
    state.whenData((currentMap) {
      final updated = Map<int, int>.from(currentMap);
      for (var p in items) {
        updated[p.id] = (updated[p.id] ?? 0) + 1;
      }
      state = AsyncValue.data(updated);
    });
  }
}

final collectionProvider = StateNotifierProvider<UserCollectionNotifier, AsyncValue<Map<int, int>>>((ref) {
  final repo = ref.watch(stickerRepositoryProvider);
  return UserCollectionNotifier(repo, ref);
});

// 5. TRADING NOTIFIERS
class OpenTradesNotifier extends StateNotifier<AsyncValue<List<TradeModel>>> {
  final TradeRepository _repo;

  OpenTradesNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.getOpenTrades();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<TradeModel> createTrade({
    required String senderId,
    required List<TradeItemModel> offeredItems,
    required List<TradeItemModel> requestedItems,
    String? receiverId,
  }) async {
    try {
      final trade = await _repo.createTradeOffer(
        senderId: senderId,
        offeredItems: offeredItems,
        requestedItems: requestedItems,
        receiverId: receiverId,
      );
      await refresh();
      return trade;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> acceptTrade(String tradeId, String receiverId) async {
    try {
      await _repo.acceptTrade(tradeId, receiverId);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelTrade(String tradeId, String userId) async {
    try {
      await _repo.rejectOrCancelTrade(tradeId, userId);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}

final openTradesProvider = StateNotifierProvider<OpenTradesNotifier, AsyncValue<List<TradeModel>>>((ref) {
  final repo = ref.watch(tradeRepositoryProvider);
  return OpenTradesNotifier(repo);
});

class UserTradesNotifier extends StateNotifier<AsyncValue<List<TradeModel>>> {
  final TradeRepository _repo;
  final String _userId;

  UserTradesNotifier(this._repo, this._userId) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.getUserTrades(_userId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<TradeModel> createTrade({
    required String senderId,
    required List<TradeItemModel> offeredItems,
    required List<TradeItemModel> requestedItems,
    String? receiverId,
  }) async {
    try {
      final trade = await _repo.createTradeOffer(
        senderId: senderId,
        offeredItems: offeredItems,
        requestedItems: requestedItems,
        receiverId: receiverId,
      );
      await refresh();
      return trade;
    } catch (e) {
      rethrow;
    }
  }
}

final userTradesProvider = StateNotifierProvider.family<UserTradesNotifier, AsyncValue<List<TradeModel>>, String>((ref, userId) {
  final repo = ref.watch(tradeRepositoryProvider);
  return UserTradesNotifier(repo, userId);
});

// 6. LIVE FRIEND TRADING PROVIDERS
final allUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getAllUsers();
});

final liveTradeStreamProvider = StreamProvider.family<TradeModel, String>((ref, tradeId) {
  final repo = ref.watch(tradeRepositoryProvider);
  return repo.streamTrade(tradeId);
});

final liveTradeChatsProvider = StreamProvider.family<List<TradeChatItemModel>, String>((ref, tradeId) {
  final repo = ref.watch(tradeRepositoryProvider);
  return repo.streamChats(tradeId);
});

// 7. POKEMON GO STYLE FRIENDS & CODES
String getFriendCodeForUser(UserModel user) {
  if (user.id == 'mock-bot-1') return 'SWAP-GURU-99';
  if (user.id == 'mock-bot-2') return 'SWAP-SWAP-LE';
  if (user.id == 'mock-bot-3') return 'SWAP-SHIN-HU';
  if (user.id == 'mock-bot-4') return 'SWAP-PANI-KI';
  
  final clean = user.id.replaceAll('-', '').toUpperCase();
  if (clean.length >= 8) {
    return 'SWAP-${clean.substring(0, 4)}-${clean.substring(4, 8)}';
  }
  return 'SWAP-${clean.padRight(8, '0')}';
}

class AddedFriendsNotifier extends StateNotifier<Set<String>> {
  AddedFriendsNotifier() : super({'mock-bot-1', 'mock-bot-2'}) {
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('added_friend_ids');
      if (list != null) {
        state = list.toSet();
      } else {
        // Pre-populate with our bots by default
        state = {'mock-bot-1', 'mock-bot-2'};
      }
    } catch (_) {}
  }

  Future<bool> addFriendByCode(String code, List<UserModel> allUsers) async {
    final cleanCode = code.trim().replaceAll(' ', '').replaceAll('-', '').toUpperCase();
    
    UserModel? foundUser;
    for (var u in allUsers) {
      final uCode = getFriendCodeForUser(u).replaceAll('-', '').toUpperCase();
      if (uCode == cleanCode) {
        foundUser = u;
        break;
      }
    }

    if (foundUser != null) {
      if (state.contains(foundUser.id)) {
        return true; // Already exists
      }
      final newState = {...state, foundUser.id};
      state = newState;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('added_friend_ids', newState.toList());
      } catch (_) {}
      return true;
    }
    return false;
  }

  Future<void> addFriendById(String friendId) async {
    if (state.contains(friendId)) return;
    final newState = {...state, friendId};
    state = newState;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('added_friend_ids', newState.toList());
    } catch (_) {}
  }

  Future<void> removeFriend(String friendId) async {
    if (state.contains(friendId)) {
      final newState = Set<String>.from(state)..remove(friendId);
      state = newState;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('added_friend_ids', newState.toList());
      } catch (_) {}
    }
  }
}

final addedFriendsProvider = StateNotifierProvider<AddedFriendsNotifier, Set<String>>((ref) {
  return AddedFriendsNotifier();
});
