import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart'; // Added Firebase
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'services/audio_service.dart';
import 'theme/app_theme.dart';
import 'models/track.dart';
import 'providers/player_provider.dart';
import 'providers/library_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/auth_provider.dart'; // Added AuthProvider
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/playlist_import_screen.dart'; 
import 'screens/prediction_screen.dart';
import 'screens/login_screen.dart'; 
import 'widgets/mini_player.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[wave] Firebase initialization error: $e');
    }

    // System UI styling
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Initialize Hive
    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(TrackAdapter());
      }
    } catch (e) {
      debugPrint('[wave] Hive initialization error: $e');
    }

    // Initialize Audio
    try {
      await AudioPlayerService.init();
    } catch (e) {
      debugPrint('[wave] Audio service initialization error: $e');
    }

    // Initialize Library
    final libraryProvider = LibraryProvider();
    try {
      await libraryProvider.init();
    } catch (e) {
      debugPrint('[wave] Library initialization error: $e');
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()), // New Auth Provider
          ChangeNotifierProvider(create: (_) => PlayerProvider()),
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ChangeNotifierProvider.value(value: libraryProvider),
        ],
        child: const WaveApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('[wave] Global error: $error');
    // We catch exceptions like font loading failures here to prevent the app from hanging or being killed.
  });
}

class WaveApp extends StatelessWidget {
  const WaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'wave.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: auth.isAuthenticated
            ? const WaveShell(key: ValueKey('shell'))
            : const LoginScreen(key: ValueKey('login')),
      ),
    );
  }
}

/// Main shell — bottom nav + mini player overlay.
class WaveShell extends StatefulWidget {
  const WaveShell({super.key});

  @override
  State<WaveShell> createState() => _WaveShellState();
}

class _WaveShellState extends State<WaveShell> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const PredictionScreen(),
    const LibraryScreen(),
    const PlaylistImportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    final currentIndex = navigation.currentIndex;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Current screen
          AnimatedSwitcher(
            duration: AppTheme.pageTransition,
            switchInCurve: AppTheme.defaultCurve,
            switchOutCurve: AppTheme.defaultCurve,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(currentIndex),
              child: _screens[currentIndex],
            ),
          ),

          // Layer (Mini player + Bottom Navigation)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mini player
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: MiniPlayer(),
                ),
                const SizedBox(height: 8),

                // Navigation Bar with backdrop blur
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bg.withOpacity(0.8),
                        border: const Border(
                          top: BorderSide(color: AppTheme.border, width: 0.5),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          height: 60,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildNavItem(0, Icons.home_rounded, 'home'),
                              _buildNavItem(1, Icons.search_rounded, 'search'),
                              _buildNavItem(2, Icons.auto_awesome_rounded, 'prediction', color: Colors.blueAccent.shade200),
                              _buildNavItem(3, Icons.library_music_rounded, 'library'),
                              _buildNavItem(4, Icons.share_rounded, 'import'),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildNavItem(int index, IconData icon, String label, {Color? color}) {
    final navigation = context.read<NavigationProvider>();
    final isActive = navigation.currentIndex == index;

    return GestureDetector(
      onTap: () => navigation.setTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive
                  ? (color ?? AppTheme.textPrimary)
                  : AppTheme.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 4),
            // Active dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 4 : 0,
              height: 4,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
