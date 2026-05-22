import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Color Palette (Original Dark Theme)
  static const Color darkBackground = Color(0xFF050814); // Deep space navy
  static const Color darkCard = Color(0xFF0E1630);       // Glassmorphic navy card
  static const Color neonCyan = Color(0xFF00E5FF);       // Electric cyan accent
  static const Color neonPink = Color(0xFFFF2A6D);       // Electric pink/red for alerts/errors
  static const Color shinyGold = Color(0xFFFFD700);      // Shiny sticker classic gold
  static const Color textPrimary = Color(0xFFF5F6FA);    // Clean off-white text
  static const Color textSecondary = Color(0xFF8B9CB6);  // Cool slate secondary text

  // Light/Warm Theme Color Palette (Shared across screens)
  static const Color warmBackground = Color(0xFFF6F2E8); // Warm cream background
  static const Color cardWhite = Colors.white;            // Standard white card background
  static const Color primaryNavy = Color(0xFF123C69);     // Primary header/button navy
  static const Color navyDark = Color(0xFF0B2545);        // Dark navy accent
  static const Color navyMid = Color(0xFF1D4E89);         // Mid navy (gradient step)
  static const Color ink = Color(0xFF102A43);             // Deep slate text primary
  static const Color inkSoft = Color(0xFF486581);         // Slate text secondary
  static const Color subtext = Color(0xFF627D98);         // Muted subtext
  static const Color muted = Color(0xFF9FB3C8);           // Gray muted elements
  static const Color mutedDisabled = Color(0xFFBCCCDC);  // Disabled/outline button muted
  static const Color slateGray = Color(0xFF829AB1);       // Slate gray muted elements
  static const Color line = Color(0xFFD9E2EC);            // Light gray lines
  static const Color inputBackground = Color(0xFFF8FAFC); // Very light input fill
  static const Color progressTrack = Color(0xFFEAF0F6);   // Track background for progress bars
  static const Color progressBackground = Color(0xFFF2F6FA); // Progress track secondary
  static const Color nearWhite = Color(0xFFFDFEFE);       // Near-white pack card gradient start
  static const Color warmCream = Color(0xFFFFF1C7);       // Warm cream yellow (pack gradient end)
  static const Color gold = Color(0xFFD4AF37);            // Standard gold/shiny color
  static const Color goldDark = Color(0xFFB7791F);        // Dark gold for outline/shadow
  static const Color goldDeepDark = Color(0xFF8A6A16);    // Darkest gold gradient end
  static const Color goldDeep = Color(0xFF4A3410);        // Deep gold for foil text contrast
  static const Color goldBorder = Color(0xFFE5D8B8);      // Light gold border
  static const Color goldMuted = Color(0xFFE0C56E);       // Muted pack-border gold
  static const Color goldLight = Color(0xFFFFF8D6);       // Shiny gold start gradient
  static const Color goldMedium = Color(0xFFE9C46A);      // Shiny gold mid gradient
  static const Color blueTint = Color(0xFFEAF4FF);        // Soft blue tint for sticker card backgrounds
  static const Color blueBorder = Color(0xFFBFD7EA);      // Border color for regular sticker cards
  static const Color success = Color(0xFF0B6B3A);         // Deep green for success/accepted
  static const Color danger = Color(0xFFB42318);          // Deep red for warning/error/danger
  static const Color dangerLight = Color(0xFFFFF1F0);     // Very light red for error backgrounds
  static const Color info = Color(0xFF627D98);            // Info icons / badges
  
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      primaryColor: neonCyan,
      colorScheme: const ColorScheme.dark().copyWith(
        primary: neonCyan,
        secondary: neonCyan,
        surface: darkCard,
        error: neonPink,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.copyWith(
          titleLarge: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          bodyLarge: const TextStyle(color: textPrimary),
          bodyMedium: const TextStyle(color: textSecondary),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        selectedItemColor: neonCyan,
        unselectedItemColor: textSecondary,
      ),
    );
  }

  // Neon Outer Glow decoration helper
  static BoxDecoration neonBox({
    Color glowColor = neonCyan,
    double blurRadius = 8.0,
    double borderRadius = 12.0,
    Color bgColor = darkCard,
  }) {
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: glowColor.withValues(alpha: 0.5), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.15),
          blurRadius: blurRadius,
          spreadRadius: 1,
        ),
      ],
    );
  }

  // Card background for stickers
  static BoxDecoration stickerBox({required bool isShiny}) {
    if (isShiny) {
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF099), shinyGold, Color(0xFFC79E00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: shinyGold.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      );
    } else {
      return BoxDecoration(
        color: const Color(0xFF1B2440),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: neonCyan.withValues(alpha: 0.2), width: 1.5),
      );
    }
  }

  // Premium Light/Warm Neon Outer Glow decoration helper
  static BoxDecoration premiumNeonBox({
    required Color glowColor,
    required double borderRadius,
    Color bgColor = Colors.white,
  }) {
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: glowColor == danger
            ? danger.withValues(alpha: 0.30)
            : goldBorder,
        width: 1.1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  // Premium Card background for stickers
  static BoxDecoration premiumStickerBox({required bool isShiny}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      gradient: isShiny
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                goldLight,
                goldMedium,
                goldDark,
              ],
            )
          : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, blueTint],
            ),
      border: Border.all(
        color: isShiny ? gold : blueBorder,
        width: isShiny ? 1.8 : 1.1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // Premium soft shadow list
  static List<BoxShadow> get premiumSoftShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}
