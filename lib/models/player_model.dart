class PlayerModel {
  final int id;
  final int teamId;
  final String name;
  final String position; // 'GK', 'DF', 'MF', 'FW'
  final int number;      // 1 to 18
  final int rating;      // 70 to 99
  final bool isShiny;    // Shiny/special card
  final String avatarUrl;

  PlayerModel({
    required this.id,
    required this.teamId,
    required this.name,
    required this.position,
    required this.number,
    this.rating = 80,
    this.isShiny = false,
    required this.avatarUrl,
  });

  PlayerModel copyWith({
    int? id,
    int? teamId,
    String? name,
    String? position,
    int? number,
    int? rating,
    bool? isShiny,
    String? avatarUrl,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      position: position ?? this.position,
      number: number ?? this.number,
      rating: rating ?? this.rating,
      isShiny: isShiny ?? this.isShiny,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as int,
      teamId: json['team_id'] as int,
      name: json['name'] as String,
      position: json['position'] ?? 'MF',
      number: json['number'] as int? ?? 1,
      rating: json['rating'] as int? ?? 80,
      isShiny: json['is_shiny'] as bool? ?? false,
      avatarUrl: json['avatar_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'name': name,
      'position': position,
      'number': number,
      'rating': rating,
      'is_shiny': isShiny,
      'avatar_url': avatarUrl,
    };
  }
}
