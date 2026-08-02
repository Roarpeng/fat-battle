import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../widgets/home/forge_background.dart';
import 'home_page.dart';

/// 塑身工坊 - 身份认证（注册 / 登录）页面
///
/// 锻造工坊品牌首屏：炉火背景 + 铁砧之锤 + 铜金描边工坊卡
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // 模拟注册/登录认证延迟与网络请求
    await Future.delayed(const Duration(milliseconds: 900));

    final prefs = await SharedPreferences.getInstance();
    final isRegister = _tabController.index == 1;

    final accountName = isRegister
        ? _usernameController.text.trim()
        : _emailController.text.trim().split('@').first;

    // 存储用户认证 Session
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_account', accountName);
    await prefs.setString('auth_token', 'token_demo_${DateTime.now().millisecondsSinceEpoch}');

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isRegister ? '🎉 注册成功！欢迎加入塑身工坊' : '⚡ 登录成功！欢迎回来'),
        backgroundColor: AppColors.green,
      ),
    );

    // 登录成功跳转主界面
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  Future<void> _handleGuestLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_account', '离线体验勇士');

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 品牌 Header：铁砧之锤（锻造工坊徽记）
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.bg3,
                          AppColors.ember.withValues(alpha: 0.35),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.copper.withValues(alpha: 0.55),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ember.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('🔨', style: TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '塑身工坊',
                    style: GoogleFonts.fraunces(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      letterSpacing: 1.0,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '你的身体，是你精心雕琢的作品',
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      color: AppColors.text2,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 工坊卡容器
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.copper.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tab 切换（登录 / 注册）— 锻造铆钉分段
                          Container(
                            height: 42,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                color: AppColors.ember,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: const Color(0xFFFFF8F5),
                              unselectedLabelColor: AppColors.text2,
                              labelStyle: GoogleFonts.figtree(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              tabs: const [
                                Tab(text: '密码登录'),
                                Tab(text: '注册新账号'),
                              ],
                              onTap: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 如果是注册页，显示用户名输入框
                          if (_tabController.index == 1) ...[
                            TextFormField(
                              controller: _usernameController,
                              style: TextStyle(color: AppColors.text),
                              decoration: InputDecoration(
                                labelText: '用户昵称',
                                prefixIcon: Icon(Icons.person_outline, color: AppColors.copper),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().length < 2) {
                                  return '请输入至少2个字符的昵称';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 账号/邮箱输入框
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: AppColors.text),
                            decoration: InputDecoration(
                              labelText: '手机号 / 邮箱',
                              prefixIcon: Icon(Icons.email_outlined, color: AppColors.copper),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return '请输入登录账号/邮箱';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // 密码输入框
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: AppColors.text),
                            decoration: InputDecoration(
                              labelText: '密码',
                              prefixIcon: Icon(Icons.lock_outline, color: AppColors.copper),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.text2,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.length < 6) {
                                return '密码长度不能少于6位';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // 提交按钮（炉火赤红主行动）
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.ember,
                                foregroundColor: const Color(0xFFFFF8F5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                                shadowColor: AppColors.ember,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFFFF8F5),
                                      ),
                                    )
                                  : Text(
                                      _tabController.index == 0 ? '安全登录' : '立即注册',
                                      style: GoogleFonts.figtree(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 离线游客模式按钮
                  TextButton.icon(
                    onPressed: _handleGuestLogin,
                    icon: Icon(Icons.bolt_outlined, color: AppColors.ember, size: 18),
                    label: Text(
                      '免登录离线试用模式',
                      style: GoogleFonts.figtree(
                        color: AppColors.text2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
