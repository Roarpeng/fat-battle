import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../widgets/home/forge_background.dart';
import 'auth_page.dart';

/// 欢迎页 — 锻造工坊开场
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.bg3,
                        AppColors.ember.withValues(alpha: 0.35),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.copper.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ember.withValues(alpha: 0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('🔨', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 28),
                Text(
                  '塑身工坊',
                  style: GoogleFonts.fraunces(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '你的身体，是你精心雕琢的作品',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(
                    fontSize: 16,
                    color: AppColors.text2,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '吃得清醒 · 练得扎实 · 看着怪物倒下',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    color: AppColors.copper.withValues(alpha: 0.9),
                  ),
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const AuthPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      '注册 / 登录进入工坊',
                      style: GoogleFonts.figtree(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
