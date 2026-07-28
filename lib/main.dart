import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/game_provider.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/setup_page.dart';
import 'pages/stats_page.dart';
import 'theme/forge_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const BodyStudioApp(),
  ));
}

class BodyStudioApp extends ConsumerWidget {
  const BodyStudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);

    return MaterialApp(
      title: '塑身工坊',
      debugShowCheckedModeBanner: false,
      theme: buildForgeTheme(),
      home: gameState.hasGame
          ? const MainPage()
          : gameState.user.height > 0
              ? const SetupPage()
              : const WelcomePage(),
    );
  }
}

/// 方案 A：舞台 + 进度
class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        onTabSwitch: (index) {
          // 兼容旧回调：1 饮食 / 2 锤炼已改为 push；3→进度 Tab
          if (index == 3 || index == 1) {
            setState(() => _currentIndex = 1);
          }
        },
      ),
      const StatsPage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: '舞台',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '进度',
          ),
        ],
      ),
    );
  }
}
