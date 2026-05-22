class UserModel {
  final String id;
  final String username;
  final String email;
  final String avatarUrl;
  final int freePacksClaimedToday;
  final DateTime? lastFreePackClaimedAt;
  final int coins;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.avatarUrl,
    this.freePacksClaimedToday = 0,
    this.lastFreePackClaimedAt,
    this.coins = 100,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    int? freePacksClaimedToday,
    DateTime? lastFreePackClaimedAt,
    int? coins,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      freePacksClaimedToday: freePacksClaimedToday ?? this.freePacksClaimedToday,
      lastFreePackClaimedAt: lastFreePackClaimedAt ?? this.lastFreePackClaimedAt,
      coins: coins ?? this.coins,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'] ?? 'https://api.dicebear.com/7.x/bottts/svg?seed=${json['id']}',
      freePacksClaimedToday: json['free_packs_claimed_today'] as int? ?? 0,
      lastFreePackClaimedAt: json['last_free_pack_claimed_at'] != null
          ? DateTime.parse(json['last_free_pack_claimed_at'] as String).toLocal()
          : null,
      coins: json['coins'] as int? ?? 100,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'free_packs_claimed_today': freePacksClaimedToday,
      'last_free_pack_claimed_at': lastFreePackClaimedAt?.toUtc().toIso8601String(),
      'coins': coins,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
