class TeamModel {
  final int id;
  final String name;
  final String countryCode; // 3 characters, e.g. 'ARG', 'BRA'
  final String group;       // 'A' to 'H'
  final String primaryColor;   // Hex color, e.g. '#75AADB'
  final String secondaryColor; // Hex color, e.g. '#FFFFFF'
  final String flagUrl;

  TeamModel({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.group,
    required this.primaryColor,
    required this.secondaryColor,
    required this.flagUrl,
  });

  // Unique utility to turn a standard country code to a flag emoji (e.g. 'ARG' -> 🇦🇷)
  // Highly reliable offline rendering
  String get flagEmoji {
    final code = countryCode.toUpperCase();
    
    // Custom mapping for our 3 letter tournament codes to standard 2 letter ISO codes
    final map = {
      'ARG': 'AR', 'BRA': 'BR', 'POR': 'PT', 'FRA': 'FR', 'GER': 'DE', 
      'ENG': 'GB', 'BEL': 'BE', 'NED': 'NL', 'ESP': 'ES', 'ITA': 'IT', 
      'URU': 'UY', 'CRO': 'HR', 'SEN': 'SN', 'MEX': 'MX', 'JPN': 'JP', 
      'KOR': 'KR', 'MAR': 'MA', 'CMR': 'CM', 'GHA': 'GH', 'CAN': 'CA', 
      'USA': 'US', 'ECU': 'EC', 'SUI': 'CH', 'DEN': 'DK', 'POL': 'PL', 
      'KSA': 'SA', 'AUS': 'AU', 'TUN': 'TN', 'NOR': 'NO', 'CRC': 'CR', 
      'SRB': 'RS', 'IRN': 'IR'
    };
    
    final isoCode = map[code] ?? 'UN'; // UN flag as fallback
    
    int firstChar = isoCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    int secondChar = isoCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    
    return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
  }

  TeamModel copyWith({
    int? id,
    String? name,
    String? countryCode,
    String? group,
    String? primaryColor,
    String? secondaryColor,
    String? flagUrl,
  }) {
    return TeamModel(
      id: id ?? this.id,
      name: name ?? this.name,
      countryCode: countryCode ?? this.countryCode,
      group: group ?? this.group,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      flagUrl: flagUrl ?? this.flagUrl,
    );
  }

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'] as int,
      name: json['name'] as String,
      countryCode: json['country_code'] as String,
      group: json['group'] ?? 'A',
      primaryColor: json['primary_color'] ?? '#FFFFFF',
      secondaryColor: json['secondary_color'] ?? '#000000',
      flagUrl: json['flag_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country_code': countryCode,
      'group': group,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'flag_url': flagUrl,
    };
  }
}
