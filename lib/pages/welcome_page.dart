import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import 'setup_page.dart';

/// 欢迎页面
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bg, AppColors.bg2],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            const Text(
              '⚔️',
              style: TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 20),
            
            // 标题
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.red, AppColors.gold],
              ).createShader(bounds),
              child: const Text(
                '减肥大作战',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // 副标题
            Text(
              '用游戏的方式，打赢这场脂肪战争',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.text2,
              ),
            ),
            const SizedBox(height: 40),
            
            // 开始按钮
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const SetupPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '开始冒险 🚀',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}