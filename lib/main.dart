import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/game_provider.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/setup_page.dart';
import 'pages/food_page.dart';
import 'pages/exercise_page.dart';
import 'pages/stats_page.dart';
import 'pages/settings_page.dart';
import 'constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化SharedPreferences
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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.bg2,
          foregroundColor: AppColors.text,
        ),
        cardTheme: CardThemeData(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bg2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.red),
          ),
        ),
      ),
      home: gameState.hasGame 
          ? const MainPage() 
          : gameState.user.height > 0 
              ? const SetupPage() 
              : const WelcomePage(),
    );
  }
}

/// 主页面（带底部导航）
class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});
  
  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    HomePage(onTabSwitch: (index) {
      setState(() => _currentIndex = index);
    }),
    const FoodPage(),
    const ExercisePage(),
    const StatsPage(),
    const SettingsPage(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppColors.bg2,
        indicatorColor: AppColors.red.withOpacity(0.3),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '工坊',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: '饮食',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: '锤炼',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '进度',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '更多',
          ),
        ],
      ),
    );
  }
}