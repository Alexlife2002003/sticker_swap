import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env asset file
  await dotenv.load(fileName: 'assets/app.env');

  // DYNAMIC SUPABASE INITIALIZATION
  // Only tries to initialize if set to true by developer.
  // Otherwise, fallback MockRepository enables immediate play!
  if (SupabaseConfig.useSupabase) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase connection failed: $e');
    }
  }

  runApp(
    // Wire up Riverpod ProviderScope at root level
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticker Swap',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

/// Listens to authStateProvider to direct user to the login gateway
/// or straight into their sticker booklet upon session verification.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider);

    return session.when(
      data: (user) {
        if (user != null) {
          return const MainNavigation();
        } else {
          return const AuthScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.neonCyan,
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Text(
            'Initialization Error: $e',
            style: const TextStyle(color: AppTheme.neonPink),
          ),
        ),
      ),
    );
  }
}
