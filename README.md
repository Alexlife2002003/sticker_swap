# ⚽ Sticker Swap — Digital Sticker Collecting & Trading Hub

[![Flutter Version](https://img.shields.io/badge/flutter-v3.11+-blue.svg?logo=flutter&style=flat-square)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/state--management-riverpod-lightgrey.svg?style=flat-square)](https://riverpod.dev)
[![License: None](https://img.shields.io/badge/license-private-red.svg?style=flat-square)](#)
[![Status: Work In Progress](https://img.shields.io/badge/status-work--in--progress-orange?style=flat-square)](#)

Sticker Swap is a premium, high-fidelity digital sticker booklet and trading marketplace built with Flutter. Users can earn coins, purchase and rip open premium foil packs, organize their player collections in interactive pages, propose swaps with global collectors, and execute real-time negotiations in dedicated swap rooms.

---

> [!IMPORTANT]
> 🚧 **PROJECT STATUS: WORK IN PROGRESS**
> This application is actively being developed. Core gameplay flows, interactive animations, and visual theme systems are fully constructed. Integration with Supabase backend tables is available, and an automatic **Mock Data Repository fallback** is active out-of-the-box so you can run the app instantly without any configuration!

---

## ✨ Features Highlight

### 📱 Premium Interactive Screen Layouts

1. **🔒 Sleek Gateway Gate (`auth_screen.dart`)**
   - High-fidelity form handling and premium dynamic animations utilizing `flutter_animate`.
   - Visual toggle between **Sign-In** and **Register** panels with custom form validators.

2. **📖 Digital Sticker Booklet (`album_screen.dart`)**
   - Implements a gorgeous paper-textured sticker album view.
   - Live completion gauges showing real-time statistics (total collection completion, country/group breakdowns).
   - Differentiates beautifully between Standard, Shiny, and coveted Gold Foil player cards.

3. **✨ Premium Pack Opener (`pack_opener_screen.dart`)**
   - Implements a stunning card pack ripping animation built using custom canvas shapes and gradients.
   - Earn, manage, and consume golden coins to rip packs and reveal rare player card pulls with calculated odds.

4. **💼 Master Trading Desk (`trading_screen.dart`)**
   - A central station showing all active, pending, accepted, and declined trade offers.
   - Searchable and categorized filters to view outgoing and incoming proposals.

5. **💬 Real-Time Live Swap Room (`live_trade_room_screen.dart`)**
   - Dedicate multiplayer sandbox rooms supporting real-time chat, synchronized player offers, and live lock/ready states.
   - Fully-fledged messaging interface and automatic card validation safeguards.

---

## 🛠️ Technological Architecture

Sticker Swap uses a state-of-the-art Flutter architecture:

- **State Management**: `flutter_riverpod` handles granular reactivity and state propagation, decoupled from widgets.
- **Backend / Authentication**: `supabase_flutter` for secure user sessions, account syncing, and live database tables.
- **Styling & Color Palette**: Centralized `AppTheme` token system located inside [theme.dart](file:///Users/alexia/Downloads/projects/sticker_swap/lib/core/theme.dart) for seamless theme token lookup.
- **Animations**: `flutter_animate` provides buttery smooth 60 FPS transitions and hover highlights.
- **Asset Handling**: `flutter_svg` for crisp, vector-based player avatars generated on-the-fly.
- **Device Support**: Optimized for iOS, Android, and Web platforms.

---

## 📂 Project Structure

```text
lib/
├── core/
│   ├── supabase_config.dart   # Backend integration toggle and environment keys
│   └── theme.dart             # Central AppTheme palette, shadows, & premium decoration builders
├── models/
│   ├── user.dart              # User model with coins, username, and avatar properties
│   ├── sticker.dart           # Sticker structure supporting standard, foil, and shiny attributes
│   └── trade.dart             # Trade transactions, message models, and swap state definitions
├── providers/
│   └── app_providers.dart     # Riverpod state nodes for authentication, albums, and swaps
├── repositories/
│   ├── auth_repository.dart   # Session controller (Mock API fallback / Supabase Client)
│   ├── album_repository.dart  # Sticker book collection actions (Mock / Supabase API)
│   └── trade_repository.dart  # Active offers, messaging, and chatrooms (Mock / Supabase API)
├── screens/
│   ├── auth_screen.dart       # Authentication panel gateway
│   ├── album_screen.dart      # Paper-themed digital sticker book
│   ├── pack_opener_screen.dart# Custom animated pack opener
│   ├── trading_screen.dart    # Transaction list and master trading desk
│   ├── live_trade_room_screen.dart # Interactive real-time trade room
│   └── main_navigation.dart   # Bottom navigation shell controller
└── widgets/
    └── player_avatar.dart     # Adaptive SVG/PNG network render widget
```

---

## 🚀 Getting Started

Follow these quick steps to get the project building and running locally.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`v3.11` or higher recommended)
- [Dart SDK](https://dart.dev/get-started)
- iOS Simulator, Android Emulator, or a Chrome browser target

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/sticker_swap.git
   cd sticker_swap
   ```

2. **Retrieve all packages and assets:**
   ```bash
   flutter pub get
   ```

3. **Configure the Environment:**
   A template environment file `assets/app.env` is loaded automatically at startup. The app uses it to decide whether to connect to a live Supabase project or use local Mock data.
   
   To use mock data, keep `USE_SUPABASE=false` in `assets/app.env`.

4. **Verify Code Health:**
   Ensure everything is perfectly formatted and passes all static checks:
   ```bash
   flutter analyze
   ```

5. **Run the Application:**
   ```bash
   flutter run
   ```

### 🌐 Deploying to Firebase Hosting

To compile and deploy the web application:

1. **Compile the web release build:**
   ```bash
   flutter build web --release
   ```

   > [!TIP]
   > To optimize rendering performance on desktop and mobile browsers, use the CanvasKit renderer explicitly:
   > ```bash
   > flutter build web --release --web-renderer canvaskit
   > ```

2. **Deploy to Firebase Hosting:**
   Upload your compiled static assets directly to Firebase servers:
   ```bash
   firebase deploy --only hosting
   ```

---

## 🚧 Active Roadmap & Milestones

Here are the upcoming developments planned for the Sticker Swap app:

- [x] Unify the color theme system across all screens into `AppTheme`.
- [ ] Implement push notifications for newly received global trade requests.
- [ ] Incorporate interactive sound effects on pack tearing and shiny gold pulls.
- [ ] Develop multiplayer matchmaking queues to connect users seeking complementary sticker duplicates.
- [ ] Integrate full Supabase real-time channels for live trades.
- [ ] Implement custom sticker-swapping animations inside the Live Trade Room.
