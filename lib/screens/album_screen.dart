import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../providers/app_providers.dart';
import '../widgets/player_avatar.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  String _selectedGroup = 'A';
  TeamModel? _selectedTeam;
  String _searchQuery = '';
  bool _searchActive = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchActive = false;
      _searchController.clear();
    });
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsProvider);
    final playersAsync = ref.watch(playersProvider);
    final collectionAsync = ref.watch(collectionProvider);

    return Container(
      color: _AlbumUi.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(),

            if (_searchQuery.isNotEmpty)
              Expanded(
                child: playersAsync.when(
                  data: (players) => collectionAsync.when(
                    data: (coll) => teamsAsync.when(
                      data: (teams) => _buildSearchResults(players, coll, teams),
                      loading: _buildLoading,
                      error: (e, s) {
                        debugPrint('[AlbumScreen] Teams load error: $e\n$s');
                        return _buildError('Error loading teams: $e');
                      },
                    ),
                    loading: _buildLoading,
                    error: (e, s) {
                      debugPrint('[AlbumScreen] Collection load error: $e\n$s');
                      return _buildError('Error loading collection: $e');
                    },
                  ),
                  loading: _buildLoading,
                  error: (e, s) {
                    debugPrint('[AlbumScreen] Players load error: $e\n$s');
                    return _buildError('Error loading players: $e');
                  },
                ),
              )
            else ...[
              _buildAlbumProgressHeader(collectionAsync),
              _buildGroupTabs(),

              Expanded(
                child: teamsAsync.when(
                  data: (teams) {
                    final groupTeams = teams
                        .where((team) => team.group == _selectedGroup)
                        .toList();

                    if (_selectedTeam == null && groupTeams.isNotEmpty) {
                      _selectedTeam = groupTeams.first;
                    }

                    if (_selectedTeam != null &&
                        !groupTeams.any((team) => team.id == _selectedTeam!.id)) {
                      _selectedTeam = groupTeams.isEmpty ? null : groupTeams.first;
                    }

                    if (groupTeams.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.public_off,
                        title: 'No teams in this group',
                        message: 'Try another group to continue filling your album.',
                      );
                    }

                    return Column(
                      children: [
                        _buildTeamSelector(groupTeams),
                        Expanded(
                          child: playersAsync.when(
                            data: (players) {
                              final teamPlayers = players
                                  .where((player) => player.teamId == _selectedTeam?.id)
                                  .toList()
                                ..sort((a, b) => a.number.compareTo(b.number));

                              return collectionAsync.when(
                                data: (coll) => _buildStickersGrid(teamPlayers, coll),
                                loading: _buildLoading,
                                error: (e, s) {
                                  debugPrint('[AlbumScreen] Collection error: $e\n$s');
                                  return _buildError('Error loading collection: $e');
                                },
                              );
                            },
                            loading: _buildLoading,
                            error: (e, s) {
                              debugPrint('[AlbumScreen] Players error: $e\n$s');
                              return _buildError('Error loading players: $e');
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: _buildLoading,
                  error: (e, s) {
                    debugPrint('[AlbumScreen] Teams error: $e\n$s');
                    return _buildError('Error loading teams: $e');
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEARCH BAR
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _searchActive ? _AlbumUi.navy : _AlbumUi.goldBorder,
          width: _searchActive ? 1.5 : 1,
        ),
        boxShadow: _AlbumUi.softShadow,
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onTap: () => setState(() => _searchActive = true),
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
        onSubmitted: (_) {
          setState(() => _searchActive = false);
          _searchFocus.unfocus();
        },
        style: const TextStyle(
          color: _AlbumUi.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Search stickers by player name…',
          hintStyle: const TextStyle(
            color: _AlbumUi.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: _AlbumUi.softBlue,
            size: 21,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: _AlbumUi.muted,
                    size: 18,
                  ),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEARCH RESULTS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSearchResults(
    List<PlayerModel> allPlayers,
    Map<int, int> coll,
    List<TeamModel> teams,
  ) {
    final query = _searchQuery.toLowerCase();
    final matches = allPlayers
        .where((player) => player.name.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) {
        final aOwned = (coll[a.id] ?? 0) > 0 ? 0 : 1;
        final bOwned = (coll[b.id] ?? 0) > 0 ? 0 : 1;

        if (aOwned != bOwned) return aOwned - bOwned;
        return a.name.compareTo(b.name);
      });

    if (matches.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        title: 'No stickers found',
        message: 'No results for "$_searchQuery". Try another player name.',
      );
    }

    final teamMap = {for (final team in teams) team.id: team};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 18, 8),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: _AlbumUi.gold,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${matches.length} result${matches.length == 1 ? '' : 's'} for "$_searchQuery"',
                  style: const TextStyle(
                    color: _AlbumUi.subtext,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final player = matches[index];
              final quantity = coll[player.id] ?? 0;
              final isCollected = quantity > 0;
              final team = teamMap[player.teamId];

              return _buildStickerSlotWithTeamBadge(
                player,
                quantity,
                isCollected,
                team,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStickerSlotWithTeamBadge(
    PlayerModel player,
    int quantity,
    bool isCollected,
    TeamModel? team,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildStickerSlot(player, quantity, isCollected),
        ),
        if (team != null)
          Positioned(
            top: 7,
            left: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _AlbumUi.goldBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                team.flagEmoji,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ALBUM HEADER
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildAlbumProgressHeader(AsyncValue<Map<int, int>> collectionAsync) {
    return collectionAsync.when(
      data: (coll) {
        final totalCollected = coll.keys.length;
        const totalCapacity = 576;
        final ratio = (totalCollected / totalCapacity).clamp(0.0, 1.0).toDouble();

        return Container(
          margin: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _AlbumUi.goldBorder),
            boxShadow: _AlbumUi.softShadow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 58,
                        width: 58,
                        child: CircularProgressIndicator(
                          value: ratio,
                          strokeWidth: 6,
                          color: _AlbumUi.navy,
                          backgroundColor: _AlbumUi.blueTint,
                        ),
                      ),
                      Text(
                        '${(ratio * 100).toInt()}%',
                        style: const TextStyle(
                          color: _AlbumUi.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Album Progress',
                          style: TextStyle(
                            color: _AlbumUi.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$totalCollected / $totalCapacity stickers collected',
                          style: const TextStyle(
                            color: _AlbumUi.subtext,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: _AlbumUi.navy,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.collections_bookmark,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: _AlbumUi.blueTint,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    _AlbumUi.navy,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 112,
        child: Center(
          child: CircularProgressIndicator(color: _AlbumUi.navy),
        ),
      ),
      error: (e, s) {
        debugPrint('[AlbumScreen] Progress header error: $e\n$s');
        return const SizedBox();
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FILTERS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildGroupTabs() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemBuilder: (context, index) {
          final group = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'][index];
          final active = _selectedGroup == group;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedGroup = group;
                _selectedTeam = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active ? _AlbumUi.navy : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? _AlbumUi.navy : _AlbumUi.goldBorder,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _AlbumUi.navy.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  'GROUP $group',
                  style: TextStyle(
                    color: active ? Colors.white : _AlbumUi.subtext,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemCount: 8,
      ),
    );
  }

  Widget _buildTeamSelector(List<TeamModel> groupTeams) {
    return Container(
      height: 62,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: groupTeams.length,
        itemBuilder: (context, index) {
          final team = groupTeams[index];
          final selected = _selectedTeam?.id == team.id;
          final teamColor = _parseHexColor(team.primaryColor);
          final selectedTextColor =
              teamColor.computeLuminance() > 0.52 ? _AlbumUi.text : Colors.white;

          return GestureDetector(
            onTap: () => setState(() => _selectedTeam = team),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 190),
              margin: const EdgeInsets.only(right: 12, top: 7, bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: selected ? teamColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? Colors.white : teamColor.withValues(alpha: 0.45),
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: teamColor.withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      team.flagEmoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      team.name.toUpperCase(),
                      style: TextStyle(
                        color: selected ? selectedTextColor : _AlbumUi.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STICKER GRID
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildStickersGrid(List<PlayerModel> roster, Map<int, int> coll) {
    if (roster.isEmpty) {
      return _buildEmptyState(
        icon: Icons.style,
        title: 'No players generated',
        message: 'This team does not have stickers yet.',
      );
    }

    final playerByNumber = {
      for (final player in roster) player.number: player,
    };

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: 18,
      itemBuilder: (context, index) {
        final slotNumber = index + 1;
        final player = playerByNumber[slotNumber];

        if (player == null) {
          return _buildEmptySlot(slotNumber);
        }

        final quantity = coll[player.id] ?? 0;
        final isCollected = quantity > 0;

        return _buildStickerSlot(player, quantity, isCollected);
      },
    );
  }

  Widget _buildEmptySlot(int slotNumber) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AlbumUi.goldBorder),
      ),
      child: Center(
        child: Text(
          '#$slotNumber',
          style: const TextStyle(
            color: _AlbumUi.muted,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildStickerSlot(PlayerModel player, int quantity, bool isCollected) {
    if (!isCollected) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _AlbumUi.goldBorder),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -20,
              child: Icon(
                Icons.sports_soccer,
                size: 82,
                color: _AlbumUi.navy.withValues(alpha: 0.04),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${player.number}',
                    style: const TextStyle(
                      color: _AlbumUi.muted,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _AlbumUi.blueTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      player.position,
                      style: const TextStyle(
                        color: _AlbumUi.softBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showStickerDetails(player, quantity),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: player.isShiny
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
                    _AlbumUi.blueTint,
                  ],
                ),
          border: Border.all(
            color: player.isShiny ? _AlbumUi.gold : AppTheme.blueBorder,
            width: player.isShiny ? 2 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (player.isShiny)
              Positioned.fill(
                child: CustomPaint(
                  painter: _AlbumShimmerPainter(),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _MiniStatPill(
                      text: '${player.rating}',
                      isGold: player.isShiny,
                    ),
                    const Spacer(),
                    _MiniStatPill(
                      text: player.position,
                      isGold: player.isShiny,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: PlayerAvatar(
                        url: player.avatarUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: player.isShiny
                        ? AppTheme.goldDeep.withValues(alpha: 0.88)
                        : _AlbumUi.navy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    player.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                       color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 1,
              bottom: 31,
              child: Container(
                height: 19,
                width: 19,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  border: Border.all(color: _AlbumUi.goldBorder),
                ),
                child: Center(
                  child: Text(
                    '${player.number}',
                    style: TextStyle(
                      color: player.isShiny
                          ? AppTheme.goldDeep
                          : _AlbumUi.text,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            if (player.isShiny)
              const Positioned(
                top: 2,
                right: 2,
                child: Icon(
                  Icons.star,
                  size: 13,
                  color: AppTheme.shinyGold,
                ),
              ),
            if (quantity > 1)
              Positioned(
                right: 1,
                bottom: 31,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _AlbumUi.navy,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: _AlbumUi.navy.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '+${quantity - 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DETAIL DIALOG
  // ───────────────────────────────────────────────────────────────────────────

  void _showStickerDetails(PlayerModel player, int quantity) {
    showDialog(
      context: context,
      builder: (context) {
        final teamFlag = _selectedTeam?.flagEmoji ?? '⚽';

        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(
              color: player.isShiny ? _AlbumUi.gold : _AlbumUi.goldBorder,
              width: player.isShiny ? 2 : 1,
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 20, 18, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          title: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: _AlbumUi.blueTint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    teamFlag,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  player.name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AlbumUi.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 212,
                width: 152,
                child: _buildStickerSlot(player, quantity, true),
              ),
              const SizedBox(height: 18),
              _DetailRow(
                label: 'Position',
                value: player.position,
              ),
              _DetailRow(
                label: 'Slot',
                value: '#${player.number}',
              ),
              _DetailRow(
                label: 'Card Type',
                value: player.isShiny ? 'Gold Foil Shiny' : 'Standard Classic',
                highlight: player.isShiny,
              ),
              _DetailRow(
                label: 'Total Owned',
                value: '$quantity (${quantity - 1} duplicates)',
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AlbumUi.navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SMALL STATES / HELPERS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: _AlbumUi.navy),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _AlbumUi.danger,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _AlbumUi.goldBorder),
          boxShadow: _AlbumUi.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: _AlbumUi.blueTint,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                icon,
                color: _AlbumUi.navy,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _AlbumUi.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _AlbumUi.subtext,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseHexColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '').trim();

      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }

      if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }

      return _AlbumUi.navy;
    } catch (_) {
      return _AlbumUi.navy;
    }
  }
}

class _MiniStatPill extends StatelessWidget {
  final String text;
  final bool isGold;

  const _MiniStatPill({
    required this.text,
    required this.isGold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isGold
            ? AppTheme.goldDeep.withValues(alpha: 0.90)
            : _AlbumUi.navy,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _DetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _AlbumUi.blueTint.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AlbumUi.goldBorder.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _AlbumUi.subtext,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: highlight ? AppTheme.goldDark : _AlbumUi.text,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumShimmerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..strokeWidth = 11;

    for (int i = -6; i < 18; i++) {
      final x = i * 28.0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AlbumUi {
  static const Color background = AppTheme.warmBackground;
  static const Color navy = AppTheme.primaryNavy;
  static const Color text = AppTheme.ink;
  static const Color subtext = AppTheme.inkSoft;
  static const Color muted = AppTheme.muted;
  static const Color softBlue = AppTheme.subtext;
  static const Color blueTint = AppTheme.blueTint;
  static const Color gold = AppTheme.gold;
  static const Color goldBorder = AppTheme.goldBorder;
  static const Color danger = AppTheme.danger;

  static List<BoxShadow> get softShadow => AppTheme.premiumSoftShadow;
}