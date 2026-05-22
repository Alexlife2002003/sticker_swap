import 'dart:math';
import '../models/team_model.dart';
import '../models/player_model.dart';

class StickerGenerator {
  // Static lists for culturally appropriate phonetic name pieces
  static const Map<String, List<String>> _firstNames = {
    'lat': ['Leonel', 'Angel', 'Roderigo', 'Emiliano', 'Gonzalo', 'Lautaro', 'Alexis', 'Federico', 'Lucas', 'Mateo', 'Neymar', 'Vinicius', 'Gabriel', 'Casemiro', 'Marquinhos', 'Alisson', 'Ederson', 'Cristiano', 'Bruno', 'Bernardo', 'Joao', 'Diogo', 'Ruben', 'Luis', 'Alvaro', 'Gavi', 'Pedri', 'Rodri', 'Sergio', 'Hector', 'Keylor', 'Guillermo', 'Hirving', 'Raul', 'Edinson', 'Darwin', 'Jose', 'Piero', 'Moises', 'Enner'],
    'fre': ['Kylian', 'Antoine', 'Kareem', 'Nogolo', 'Hugo', 'Olivier', 'Ousmane', 'Kingsley', 'Adrien', 'Raphael', 'Eden', 'Romelu', 'Youri', 'Thibaut', 'Yannick', 'Michy', 'Sadio', 'Kalidou', 'Edouard', 'Ismaila', 'Idrissa', 'Achraf', 'Yassine', 'Hakim', 'Sofyan', 'Samuel', 'Eric', 'Karl', 'Andre', 'Granit', 'Breel', 'Xherdan', 'Manuel', 'Yann'],
    'ang': ['Harry', 'Jude', 'Bukayo', 'Marcus', 'Declan', 'Kyle', 'Jordan', 'Jack', 'Mason', 'Phil', 'Christian', 'Weston', 'Tyler', 'Timothy', 'Sergino', 'Alphonso', 'Jonathan', 'Cyle', 'Tajon', 'Mathew', 'Aaron', 'Mitchell', 'Jackson', 'Craig', 'Gareth', 'Daniel', 'Connor', 'Joe'],
    'ger': ['Thomas', 'Manuel', 'Kai', 'Toni', 'Joshua', 'Serge', 'Leroy', 'Marc', 'Ilkay', 'Niklas', 'Virgil', 'Frenkie', 'Memphis', 'Matthijs', 'Denzel', 'Cody', 'Christian', 'Kasper', 'Simon', 'Pierre', 'Robert', 'Wojciech', 'Piotr', 'Arkadiusz', 'Kamil'],
    'esc': ['Luka', 'Mateo', 'Ivan', 'Marcelo', 'Andrej', 'Josko', 'Dejan', 'Nikola', 'Dusan', 'Aleksandar', 'Sergej', 'Filip', 'Strahinja', 'Nemanja'],
    'asi': ['Takumi', 'Kaoru', 'Wataru', 'Ritsu', 'Maya', 'Daichi', 'Junya', 'Heung', 'Min', 'Dae', 'Jae', 'Hwang', 'Salem', 'Yasir', 'Firas', 'Salman', 'Mehdi', 'Sardar', 'Alireza', 'Ehsan'],
  };

  static const Map<String, List<String>> _lastNames = {
    'lat': ['Mesi', 'Di Mariao', 'De Paul', 'Martines', 'Montiel', 'Alvares', 'Gomes', 'Jnr', 'Silva', 'Casemiroo', 'Militao', 'Beker', 'Ederso', 'Ronalzo', 'Fernanz', 'Silvo', 'Feliks', 'Jotaa', 'Dias', 'Sanches', 'Morataa', 'Torres', 'Busquetz', 'Pedree', 'Navass', 'Ochoaa', 'Lozanoo', 'Jimenes', 'Suares', 'Nunezz', 'Cavanee', 'Hincapye', 'Caicedoo', 'Valencya'],
    'fre': ['Mpap', 'Grizman', 'Benzama', 'Kante', 'Loris', 'Dembelee', 'Comann', 'Rabiot', 'Varanee', 'Azard', 'Lucaku', 'Tielmans', 'Cortua', 'Carasco', 'Mane', 'Coulibaly', 'Mendy', 'Sarr', 'Gueye', 'Hakimee', 'Bonoo', 'Ziyech', 'Amrabat', 'Umtitee', 'Chopo-Moting', 'Onanaa', 'Xhaka', 'Emboloo', 'Shaqiree', 'Akanjee', 'Sommerr'],
    'ang': ['Kan', 'Belingam', 'Sako', 'Rashfor', 'Rice', 'Walkere', 'Picford', 'Grealish', 'Mount', 'Fodenn', 'Pulisicc', 'Mckennie', 'Adams', 'Weah', 'Destt', 'Davies', 'David', 'Larin', 'Buchanan', 'Ryan', 'Mooy', 'Duke', 'Irvine', 'Bale', 'James', 'Ramsy', 'Rodonn'],
    'ger': ['Muler', 'Nuer', 'Havertz', 'Kroos', 'Kimich', 'Gnabry', 'Sane', 'Terstegn', 'Gundogann', 'Sule', 'Diyk', 'De Jong', 'Depay', 'Deligt', 'Dumfries', 'Gakpo', 'Eriksen', 'Schmeichel', 'Kjaer', 'Hojbjerg', 'Lewandowskee', 'Szczesny', 'Zielinskee', 'Milik', 'Glik'],
    'esc': ['Modricc', 'Kovacicc', 'Perisicc', 'Brozovicc', 'Kramaricc', 'Gvardiol', 'Lovren', 'Vlasicc', 'Vlahovicc', 'Mitrovicc', 'Milinkovicc', 'Kosticc', 'Tadicc', 'Gudelj'],
    'asi': ['Minaminoo', 'Mitomah', 'Endo', 'Doan', 'Yoshida', 'Kamada', 'Ito', 'Son', 'Kim', 'Hwang', 'Cho', 'Al-Dawsaree', 'Al-Shahranee', 'Al-Brikan', 'Al-Faraj', 'Al-Shehri', 'Taremee', 'Azmoun', 'Jahanbakhsh', 'Hajsafi'],
  };

  // Helper mapping country code to linguistic style
  static String _getLinguisticStyle(String code) {
    switch (code) {
      case 'ARG':
      case 'BRA':
      case 'POR':
      case 'ESP':
      case 'URU':
      case 'MEX':
      case 'ECU':
      case 'CRC':
        return 'lat';
      case 'FRA':
      case 'BEL':
      case 'SEN':
      case 'MAR':
      case 'CMR':
      case 'SUI':
        return 'fre';
      case 'ENG':
      case 'USA':
      case 'CAN':
      case 'AUS':
        return 'ang';
      case 'GER':
      case 'NED':
      case 'DEN':
      case 'POL':
        return 'ger';
      case 'CRO':
      case 'SRB':
        return 'esc';
      case 'JPN':
      case 'KOR':
      case 'KSA':
      case 'IRN':
        return 'asi';
      case 'NOR':
      default:
        // Norway uses a mix of ger/ang style or default
        return 'ger';
    }
  }

  // 32 National Teams representing Groups A-H
  static List<TeamModel> generateTeams() {
    final List<Map<String, dynamic>> rawTeams = [
      // Group A
      {'id': 1, 'name': 'Netherlanz', 'country_code': 'NED', 'group': 'A', 'primary': '#FF4F00', 'secondary': '#FFFFFF'},
      {'id': 2, 'name': 'Senegall', 'country_code': 'SEN', 'group': 'A', 'primary': '#00853F', 'secondary': '#FDEF42'},
      {'id': 3, 'name': 'Ecuadore', 'country_code': 'ECU', 'group': 'A', 'primary': '#FFDD00', 'secondary': '#0033A0'},
      {'id': 4, 'name': 'Moroccoh', 'country_code': 'MAR', 'group': 'A', 'primary': '#C1272D', 'secondary': '#006233'},
      
      // Group B
      {'id': 5, 'name': 'Ingland', 'country_code': 'ENG', 'group': 'B', 'primary': '#FFFFFF', 'secondary': '#CF081F'},
      {'id': 6, 'name': 'USA', 'country_code': 'USA', 'group': 'B', 'primary': '#0A3161', 'secondary': '#B31942'},
      {'id': 7, 'name': 'Iran', 'country_code': 'IRN', 'group': 'B', 'primary': '#239F40', 'secondary': '#DA251D'},
      {'id': 8, 'name': 'Ostralia', 'country_code': 'AUS', 'group': 'B', 'primary': '#000031', 'secondary': '#FFCD00'},

      // Group C
      {'id': 9, 'name': 'Argintina', 'country_code': 'ARG', 'group': 'C', 'primary': '#75AADB', 'secondary': '#FFFFFF'},
      {'id': 10, 'name': 'Polan', 'country_code': 'POL', 'group': 'C', 'primary': '#DC143C', 'secondary': '#FFFFFF'},
      {'id': 11, 'name': 'Mexicoh', 'country_code': 'MEX', 'group': 'C', 'primary': '#006847', 'secondary': '#FFFFFF'},
      {'id': 12, 'name': 'Saudi Arabya', 'country_code': 'KSA', 'group': 'C', 'primary': '#006C35', 'secondary': '#FFFFFF'},

      // Group D
      {'id': 13, 'name': 'Franse', 'country_code': 'FRA', 'group': 'D', 'primary': '#002395', 'secondary': '#ED2939'},
      {'id': 14, 'name': 'Switzerlanz', 'country_code': 'SUI', 'group': 'D', 'primary': '#D52B1E', 'secondary': '#FFFFFF'},
      {'id': 15, 'name': 'Demarc', 'country_code': 'DEN', 'group': 'D', 'primary': '#C60C30', 'secondary': '#FFFFFF'},
      {'id': 16, 'name': 'Tunisya', 'country_code': 'TUN', 'group': 'D', 'primary': '#E70013', 'secondary': '#FFFFFF'},

      // Group E
      {'id': 17, 'name': 'Spayn', 'country_code': 'ESP', 'group': 'E', 'primary': '#C60B1E', 'secondary': '#FFC400'},
      {'id': 18, 'name': 'Germani', 'country_code': 'GER', 'group': 'E', 'primary': '#FFFFFF', 'secondary': '#000000'},
      {'id': 19, 'name': 'Japanne', 'country_code': 'JPN', 'group': 'E', 'primary': '#00008F', 'secondary': '#FFFFFF'},
      {'id': 20, 'name': 'Costa Rycah', 'country_code': 'CRC', 'group': 'E', 'primary': '#002B7F', 'secondary': '#CE1126'},

      // Group F
      {'id': 21, 'name': 'Croashea', 'country_code': 'CRO', 'group': 'F', 'primary': '#C60C30', 'secondary': '#FFFFFF'},
      {'id': 22, 'name': 'Belgim', 'country_code': 'BEL', 'group': 'F', 'primary': '#ED2939', 'secondary': '#FFD100'},
      {'id': 23, 'name': 'Canadah', 'country_code': 'CAN', 'group': 'F', 'primary': '#FF0000', 'secondary': '#FFFFFF'},
      {'id': 24, 'name': 'Norwey', 'country_code': 'NOR', 'group': 'F', 'primary': '#EF2B2D', 'secondary': '#002868'},

      // Group G
      {'id': 25, 'name': 'Brazyl', 'country_code': 'BRA', 'group': 'G', 'primary': '#FEE227', 'secondary': '#009B3A'},
      {'id': 26, 'name': 'Serbya', 'country_code': 'SRB', 'group': 'G', 'primary': '#C60C30', 'secondary': '#003893'},
      {'id': 27, 'name': 'Cameroon', 'country_code': 'CMR', 'group': 'G', 'primary': '#007A5E', 'secondary': '#CE1126'},
      {'id': 28, 'name': 'Italee', 'country_code': 'ITA', 'group': 'G', 'primary': '#004B87', 'secondary': '#FFFFFF'},

      // Group H
      {'id': 29, 'name': 'Portugual', 'country_code': 'POR', 'group': 'H', 'primary': '#C60C30', 'secondary': '#114524'},
      {'id': 30, 'name': 'Sout Korea', 'country_code': 'KOR', 'group': 'H', 'primary': '#CD113B', 'secondary': '#112F77'},
      {'id': 31, 'name': 'Urugway', 'country_code': 'URU', 'group': 'H', 'primary': '#84BEE7', 'secondary': '#FEE227'},
      {'id': 32, 'name': 'Ghanah', 'country_code': 'GHA', 'group': 'H', 'primary': '#FCD116', 'secondary': '#006B3F'},
    ];

    return rawTeams.map((t) => TeamModel(
      id: t['id'],
      name: t['name'],
      countryCode: t['country_code'],
      group: t['group'],
      primaryColor: t['primary'],
      secondaryColor: t['secondary'],
      flagUrl: 'https://flagsapi.com/${t['country_code'] == 'ENG' ? 'GB' : t['country_code'] == 'KOR' ? 'KR' : t['country_code'] == 'NOR' ? 'NO' : t['country_code'].toString().substring(0, 2)}/flat/64.png',
    )).toList();
  }

  // Programmatic generation of 18 players per team (Total = 576 players)
  static List<PlayerModel> generatePlayers(List<TeamModel> teams) {
    final List<PlayerModel> players = [];
    final Random random = Random(42); // Pin seed for deterministic loading
    int globalPlayerId = 1;

    for (var team in teams) {
      final String style = _getLinguisticStyle(team.countryCode);
      final List<String> firstNamesPool = _firstNames[style] ?? _firstNames['lat']!;
      final List<String> lastNamesPool = _lastNames[style] ?? _lastNames['lat']!;

      final Set<String> createdNames = {};

      for (int number = 1; number <= 18; number++) {
        // Determine position based on card number within team roster
        String position = 'MF';
        int baseRating = 72;
        if (number == 1) {
          position = 'GK';
          baseRating = 74;
        } else if (number >= 2 && number <= 6) {
          position = 'DF';
          baseRating = 71;
        } else if (number >= 7 && number <= 12) {
          position = 'MF';
          baseRating = 73;
        } else {
          position = 'FW';
          baseRating = 75;
        }

        // Generate unique pseudo-national name
        String name = '';
        int attempts = 0;
        do {
          final fn = firstNamesPool[random.nextInt(firstNamesPool.length)];
          final ln = lastNamesPool[random.nextInt(lastNamesPool.length)];
          name = '$fn $ln';
          attempts++;
        } while (createdNames.contains(name) && attempts < 100);
        createdNames.add(name);

        // Adjust rating slightly
        int rating = baseRating + random.nextInt(12); // add random 0-11
        if (rating > 95) rating = 95;

        // Shiny status
        bool isShiny = random.nextDouble() < 0.08; // 8% generic shiny rate

        final player = PlayerModel(
          id: globalPlayerId,
          teamId: team.id,
          name: name,
          position: position,
          number: number,
          rating: rating,
          isShiny: isShiny,
          avatarUrl: 'https://api.dicebear.com/7.x/adventurer/svg?seed=$name',
        );

        players.add(player);
        globalPlayerId++;
      }
    }

    // APPLY MANUAL SUPERSTAR OVERRIDES
    // Hardcode legendary parodies with high stats and shiny properties
    _applySuperstarOverride(players, teamId: 9, number: 10, name: 'Leonel Mesi', rating: 99, isShiny: true);
    _applySuperstarOverride(players, teamId: 9, number: 11, name: 'Angel Di Mariao', rating: 88, isShiny: false);
    _applySuperstarOverride(players, teamId: 9, number: 1, name: 'Emiliano Martines', rating: 89, isShiny: true);
    _applySuperstarOverride(players, teamId: 25, number: 10, name: 'Neymar Jnr', rating: 94, isShiny: true);
    _applySuperstarOverride(players, teamId: 25, number: 11, name: 'Vinicius Jnr', rating: 93, isShiny: true);
    _applySuperstarOverride(players, teamId: 25, number: 1, name: 'Alisson Beker', rating: 89, isShiny: false);
    _applySuperstarOverride(players, teamId: 29, number: 7, name: 'Crisalno Ronalzo', rating: 98, isShiny: true);
    _applySuperstarOverride(players, teamId: 29, number: 8, name: 'Bruno Fernanz', rating: 91, isShiny: true);
    _applySuperstarOverride(players, teamId: 29, number: 10, name: 'Bernardo Silvo', rating: 90, isShiny: false);
    _applySuperstarOverride(players, teamId: 13, number: 10, name: 'Kylian Mpap', rating: 97, isShiny: true);
    _applySuperstarOverride(players, teamId: 13, number: 7, name: 'Antoine Grizman', rating: 90, isShiny: true);
    _applySuperstarOverride(players, teamId: 18, number: 1, name: 'Manuel Nuer', rating: 91, isShiny: true);
    _applySuperstarOverride(players, teamId: 18, number: 13, name: 'Thomas Muler', rating: 88, isShiny: false);
    _applySuperstarOverride(players, teamId: 5, number: 9, name: 'Harry Kan', rating: 93, isShiny: true);
    _applySuperstarOverride(players, teamId: 5, number: 10, name: 'Jude Belingam', rating: 95, isShiny: true);
    _applySuperstarOverride(players, teamId: 5, number: 17, name: 'Bukayo Sako', rating: 89, isShiny: false);
    _applySuperstarOverride(players, teamId: 22, number: 7, name: 'Kevin De Bruyn', rating: 94, isShiny: true);
    _applySuperstarOverride(players, teamId: 21, number: 10, name: 'Luka Modricc', rating: 93, isShiny: true);
    _applySuperstarOverride(players, teamId: 24, number: 9, name: 'Erling Haalan', rating: 96, isShiny: true);
    _applySuperstarOverride(players, teamId: 24, number: 10, name: 'Martin Odergard', rating: 91, isShiny: true);
    _applySuperstarOverride(players, teamId: 10, number: 9, name: 'Robert Lewandowskee', rating: 92, isShiny: true);
    _applySuperstarOverride(players, teamId: 4, number: 2, name: 'Achraf Hakimee', rating: 88, isShiny: false);
    _applySuperstarOverride(players, teamId: 4, number: 1, name: 'Yassine Bonoo', rating: 88, isShiny: true);
    _applySuperstarOverride(players, teamId: 30, number: 7, name: 'Heung Min Son', rating: 90, isShiny: true);
    _applySuperstarOverride(players, teamId: 1, number: 4, name: 'Virgil Diyk', rating: 92, isShiny: true);
    _applySuperstarOverride(players, teamId: 1, number: 10, name: 'Memphis Depay', rating: 86, isShiny: false);
    _applySuperstarOverride(players, teamId: 17, number: 16, name: 'Rodree', rating: 93, isShiny: true);
    _applySuperstarOverride(players, teamId: 28, number: 1, name: 'Gianluigee Donaruma', rating: 88, isShiny: true);
    _applySuperstarOverride(players, teamId: 28, number: 10, name: 'Federico Ciesa', rating: 86, isShiny: false);
    _applySuperstarOverride(players, teamId: 6, number: 10, name: 'Christian Pulisicc', rating: 86, isShiny: true);

    return players;
  }

  static void _applySuperstarOverride(
    List<PlayerModel> players, {
    required int teamId,
    required int number,
    required String name,
    required int rating,
    required bool isShiny,
  }) {
    final idx = players.indexWhere((p) => p.teamId == teamId && p.number == number);
    if (idx != -1) {
      players[idx] = PlayerModel(
        id: players[idx].id,
        teamId: teamId,
        name: name,
        position: players[idx].position,
        number: number,
        rating: rating,
        isShiny: isShiny,
        avatarUrl: 'https://api.dicebear.com/7.x/adventurer/svg?seed=$name',
      );
    }
  }

  // Generates massive SQL scripts for users to run on Supabase console!
  static String generateSQLSeed() {
    final StringBuffer sb = StringBuffer();
    sb.writeln('-- ==========================================================');
    sb.writeln('-- STICKER SWAP - SEED DATA FOR TEAMS & PLAYERS');
    sb.writeln('-- ==========================================================');
    sb.writeln();

    // 1. INSERT TEAMS
    sb.writeln('-- 1. SEEDING 32 WORLD CUP TEAMS');
    final teams = generateTeams();
    for (var team in teams) {
      // Escape single quotes in names
      final cleanName = team.name.replaceAll("'", "''");
      sb.writeln(
        "INSERT INTO public.teams (id, name, country_code, primary_color, secondary_color, flag_url) "
        "OVERRIDING SYSTEM VALUE VALUES (${team.id}, '$cleanName', '${team.countryCode}', '${team.primaryColor}', '${team.secondaryColor}', '${team.flagUrl}') "
        "ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, country_code = EXCLUDED.country_code, primary_color = EXCLUDED.primary_color, secondary_color = EXCLUDED.secondary_color, flag_url = EXCLUDED.flag_url;"
      );
    }
    sb.writeln();

    // 2. INSERT PLAYERS
    sb.writeln('-- 2. SEEDING 576 PARODY PLAYERS');
    final players = generatePlayers(teams);
    for (var player in players) {
      final cleanName = player.name.replaceAll("'", "''");
      sb.writeln(
        "INSERT INTO public.players (id, team_id, name, position, number, rating, is_shiny, avatar_url) "
        "OVERRIDING SYSTEM VALUE VALUES (${player.id}, ${player.teamId}, '$cleanName', '${player.position}', ${player.number}, ${player.rating}, ${player.isShiny}, '${player.avatarUrl}') "
        "ON CONFLICT (id) DO UPDATE SET team_id = EXCLUDED.team_id, name = EXCLUDED.name, position = EXCLUDED.position, number = EXCLUDED.number, rating = EXCLUDED.rating, is_shiny = EXCLUDED.is_shiny, avatar_url = EXCLUDED.avatar_url;"
      );
    }

    return sb.toString();
  }
}
