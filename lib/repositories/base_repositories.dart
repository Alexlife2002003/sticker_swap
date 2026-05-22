import '../models/user_model.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/trade_model.dart';

abstract class AuthRepository {
  Stream<UserModel?> get onAuthStateChanged;
  UserModel? get currentUser;
  Future<UserModel> signIn(String email, String password);
  Future<UserModel> signUp(String email, String password, String username);
  Future<void> signOut();
  Future<List<UserModel>> getAllUsers();
}

abstract class StickerRepository {
  Future<List<TeamModel>> getTeams();
  Future<List<PlayerModel>> getPlayers();
  Future<Map<int, int>> getUserCollection(); // Maps playerId -> quantity owned
  Future<List<PlayerModel>> openPack(String userId); // Claims & rolls a 7-sticker pack
  Future<void> addStickerToCollection(String userId, int playerId, int quantity);
}

abstract class TradeRepository {
  Future<List<TradeModel>> getOpenTrades();
  Future<List<TradeModel>> getUserTrades(String userId);
  Future<TradeModel> createTradeOffer({
    required String senderId,
    required List<TradeItemModel> offeredItems,
    required List<TradeItemModel> requestedItems,
    String? receiverId,
  });
  Future<void> acceptTrade(String tradeId, String receiverId);
  Future<void> rejectOrCancelTrade(String tradeId, String userId);
  
  // Real-time & Live Friend Interactions
  Stream<TradeModel> streamTrade(String tradeId);
  Stream<List<TradeChatItemModel>> streamChats(String tradeId);
  Future<void> sendChatMessage(String tradeId, String senderId, String senderUsername, String message);
  Future<void> updateTradeAgreement(String tradeId, String userId, bool agreed);
  Future<void> updateTradeItems(String tradeId, List<TradeItemModel> offeredItems, List<TradeItemModel> requestedItems);
}
