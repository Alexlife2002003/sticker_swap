import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration settings for Supabase.
/// Values are automatically loaded from the `.env` file at runtime.
/// 
/// To switch between mock/offline mode and live Supabase, set:
///   USE_SUPABASE=true   → connects to Supabase
///   USE_SUPABASE=false  → uses local mock (SharedPreferences)
class SupabaseConfig {
  static bool get useSupabase =>
      dotenv.get('USE_SUPABASE', fallback: 'false').toLowerCase() == 'true';

  static String get supabaseUrl =>
      dotenv.get('SUPABASE_URL', fallback: '');

  static String get supabaseAnonKey =>
      dotenv.get('SUPABASE_ANON_KEY', fallback: '');
}
