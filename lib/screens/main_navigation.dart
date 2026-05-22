import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/app_providers.dart';
import '../widgets/player_avatar.dart';
import 'album_screen.dart';
import 'pack_opener_screen.dart';
import 'trading_screen.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AlbumScreen(),
    PackOpenerScreen(),
    TradingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: userAsync.when(
            data: (user) => CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.2),
              child: ClipOval(
                child: PlayerAvatar(
                  url: user?.avatarUrl ?? 'https://api.dicebear.com/7.x/bottts/svg?seed=Collector',
                  size: 32,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            loading: () => const CircleAvatar(radius: 16, child: CircularProgressIndicator(strokeWidth: 1.5)),
            error: (err, stack) => const CircleAvatar(radius: 16, child: Icon(Icons.error)),
          ),
        ),
        title: userAsync.when(
          data: (user) => Text(user?.username.toUpperCase() ?? 'COLLECTOR'),
          loading: () => const Text('LOADING...'),
          error: (err, stack) => const Text('ERROR'),
        ),
        actions: [
          // Coins indicator badge
          userAsync.when(
            data: (user) => Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${user?.coins ?? 0}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(),
            error: (err, stack) => const SizedBox(),
          ),
          
          // Sign Out Action button
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: AppTheme.neonPink),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.darkCard,
                  title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                  content: const Text('Are you sure you want to log out of Sticker Swap?', style: TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    TextButton(
                      child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: const Text('SIGN OUT', style: TextStyle(color: AppTheme.neonPink)),
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(authRepositoryProvider).signOut();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) => _screens[_currentIndex],
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            activeIcon: Icon(Icons.menu_book, color: AppTheme.neonCyan),
            label: 'Album',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            activeIcon: Icon(Icons.explore, color: AppTheme.neonCyan),
            label: 'Get Packs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horizontal_circle),
            activeIcon: Icon(Icons.swap_horizontal_circle, color: AppTheme.neonCyan),
            label: 'Trading Desk',
          ),
        ],
      ),
    );
  }
}
