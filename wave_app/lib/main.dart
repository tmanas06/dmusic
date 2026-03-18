import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'services/audio_service.dart';

import 'theme/app_theme.dart';
import 'models/track.dart';
import 'providers/player_provider.dart';
import 'providers/library_provider.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/equalizer_screen.dart';
import 'widgets/mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // System UI styling
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(TrackAdapter());

  try {
    // Initialize Audio
    await AudioPlayerService.init();
  } catch (e) {
    debugPrint('Audio initialization failed: $e');
  }

  // Initialize library
  final libraryProvider = LibraryProvider();
  try {
    await libraryProvider.init();
  } catch (e) {
    debugPrint('Library initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider.value(value: libraryProvider),
      ],
      child: const WaveApp(),
    ),
  );
}

class WaveApp extends StatelessWidget {
  const WaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wave.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const WaveShell(),
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
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    EqualizerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
              key: ValueKey(_currentIndex),
              child: _screens[_currentIndex],
            ),
          ),

          // Mini player (above bottom nav)
          Positioned(
            left: 0,
            right: 0,
            bottom: 72,
            child: const MiniPlayer(),
          ),

          // Bottom navigation bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bg.withValues(alpha: 0.85),
                    border: const Border(
                      top: BorderSide(color: AppTheme.border, width: 0.5),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(0, Icons.home_rounded, 'home'),
                          _buildNavItem(1, Icons.search_rounded, 'search'),
                          _buildNavItem(
                              2, Icons.library_music_rounded, 'library'),
                          _buildNavItem(
                              3, Icons.equalizer_rounded, 'eq'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
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
                  ? AppTheme.textPrimary
                  : AppTheme.textMuted.withValues(alpha: 0.5),
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
