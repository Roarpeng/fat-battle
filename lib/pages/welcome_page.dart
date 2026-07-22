import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import 'setup_page.dart';

/// 欢迎页面 — 塑身工坊
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
            // Logo — 雕刻锤，象征精雕细琢
            const Text(
              '🔨',
              style: TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 20),

            // 标题
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.red, AppColors.gold],
              ).createShader(bounds),
              child: const Text(
                '塑身工坊',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 副标题 — 核心概念
            Text(
              '你的身体，是你精心雕琢的作品',
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