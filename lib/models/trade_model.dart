import 'player_model.dart';

class TradeItemModel {
  final String id;
  final String tradeId;
  final int playerId;
  final bool isOffered; // True: Offered by sender, False: Requested by sender
  final int quantity;
  
  // Optional client-side hydration
  final PlayerModel? player;

  TradeItemModel({
    required this.id,
    required this.tradeId,
    required this.playerId,
    required this.isOffered,
    this.quantity = 1,
    this.player,
  });

  TradeItemModel copyWith({
    String? id,
    String? tradeId,
    int? playerId,
    bool? isOffered,
    int? quantity,
    PlayerModel? player,
  }) {
    return TradeItemModel(
      id: id ?? this.id,
      tradeId: tradeId ?? this.tradeId,
      playerId: playerId ?? this.playerId,
      isOffered: isOffered ?? this.isOffered,
      quantity: quantity ?? this.quantity,
      player: player ?? this.player,
    );
  }

  factory TradeItemModel.fromJson(Map<String, dynamic> json, {PlayerModel? player}) {
    return TradeItemModel(
      id: json['id'] as String,
      tradeId: json['trade_id'] as String,
      playerId: json['player_id'] as int,
      isOffered: json['is_offered'] as bool,
      quantity: json['quantity'] as int? ?? 1,
      player: player,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trade_id': tradeId,
      'player_id': playerId,
      'is_offered': isOffered,
      'quantity': quantity,
    };
  }
}

class TradeModel {
  final String id;
  final String senderId;
  final String? senderUsername;
  final String? receiverId; // Null indicates "Open to anyone"
  final String? receiverUsername;
  final String status; // 'pending', 'accepted', 'rejected', 'cancelled'
  final DateTime createdAt;
  final List<TradeItemModel> items;
  final bool senderAgreed;
  final bool receiverAgreed;

  TradeModel({
    required this.id,
    required this.senderId,
    this.senderUsername,
    this.receiverId,
    this.receiverUsername,
    required this.status,
    required this.createdAt,
    required this.items,
    this.senderAgreed = false,
    this.receiverAgreed = false,
  });

  // Getters to easily filter offered vs requested items
  List<TradeItemModel> get offeredItems => items.where((item) => item.isOffered).toList();
  List<TradeItemModel> get requestedItems => items.where((item) => !item.isOffered).toList();

  TradeModel copyWith({
    String? id,
    String? senderId,
    String? senderUsername,
    String? receiverId,
    String? receiverUsername,
    String? status,
    DateTime? createdAt,
    List<TradeItemModel>? items,
    bool? senderAgreed,
    bool? receiverAgreed,
  }) {
    return TradeModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      receiverId: receiverId ?? this.receiverId,
      receiverUsername: receiverUsername ?? this.receiverUsername,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      senderAgreed: senderAgreed ?? this.senderAgreed,
      receiverAgreed: receiverAgreed ?? this.receiverAgreed,
    );
  }

  factory TradeModel.fromJson(Map<String, dynamic> json, {List<TradeItemModel>? items}) {
    return TradeModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      senderUsername: json['sender_username'] as String?,
      receiverId: json['receiver_id'] as String?,
      receiverUsername: json['receiver_username'] as String?,
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      items: items ?? [],
      senderAgreed: json['sender_agreed'] as bool? ?? false,
      receiverAgreed: json['receiver_agreed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'sender_agreed': senderAgreed,
      'receiver_agreed': receiverAgreed,
    };
  }
}

class TradeChatItemModel {
  final String id;
  final String tradeId;
  final String senderId;
  final String senderUsername;
  final String message;
  final DateTime createdAt;

  TradeChatItemModel({
    required this.id,
    required this.tradeId,
    required this.senderId,
    required this.senderUsername,
    required this.message,
    required this.createdAt,
  });

  factory TradeChatItemModel.fromJson(Map<String, dynamic> json) {
    return TradeChatItemModel(
      id: json['id'] as String,
      tradeId: json['trade_id'] as String,
      senderId: json['sender_id'] as String,
      senderUsername: json['sender_username'] as String? ?? 'Collector',
      message: json['message'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  TradeChatItemModel copyWith({
    String? id,
    String? tradeId,
    String? senderId,
    String? senderUsername,
    String? message,
    DateTime? createdAt,
  }) {
    return TradeChatItemModel(
      id: id ?? this.id,
      tradeId: tradeId ?? this.tradeId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trade_id': tradeId,
      'sender_id': senderId,
      'message': message,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
