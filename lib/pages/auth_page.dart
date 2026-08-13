import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/forge_theme.dart';
import '../theme/forge_routes.dart';
import '../theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/progress_sync_service.dart';
import '../providers/game_provider.dart';
import '../widgets/home/forge_background.dart';
import '../main.dart';
import 'setup_page.dart';
import 'privacy_page.dart';

/// 塑身工坊 - 身份认证（注册 / 登录）页面
///
/// 锻造工坊品牌首屏：炉火背景 + 铁砧之锤 + 铜金描边工坊卡
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _agreedPolicy = false;

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

  /// 登录/注册成功后的统一跳转：
  /// 有存档 → 主舞台；无存档（新用户）→ 直接进入角色创建，不再出现“请先创建角色”断链
  void _navigateAfterAuth() {
    final hasGame = ref.read(gameStateProvider).hasGame;
    Navigator.of(context).pushReplacement(
      forgePageRoute(
        builder: (_) => hasGame ? const MainPage() : const SetupPage(),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // 上架合规：未勾选协议时阻断并提示
    if (!_agreedPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请先阅读并勾选《用户协议与隐私政策》'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final isRegister = _tabController.index == 1;

    // 已配置真实后端（API_BASE_URL）：注册/登录走后端接口
    if (AuthService().isBackendConfigured) {
      await _handleBackendAuth(isRegister);
      return;
    }

    // 离线模拟模式：本地假 token（向后兼容，未配置后端时保持原样）
    await Future.delayed(const Duration(milliseconds: 900));

    final prefs = await SharedPreferences.getInstance();

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

    // 登录成功跳转（有存档进舞台，无存档进角色创建）
    _navigateAfterAuth();
  }

  /// 真实后端注册/登录（成功存 token 后跳转，失败提示 SnackBar）
  Future<void> _handleBackendAuth(bool isRegister) async {
    final auth = AuthService();
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final AuthUser user;
      if (isRegister) {
        user = await auth.register(
          email: email,
          password: password,
          nickname: _usernameController.text.trim(),
        );
      } else {
        user = await auth.login(email: email, password: password);
      }

      // 记录本地展示账号（昵称优先，兼容旧 user_account 键）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'user_account',
        user.nickname.isNotEmpty ? user.nickname : email,
      );
      await prefs.setString('user_email', user.email.isNotEmpty ? user.email : email);
      await prefs.setString(
        'user_nickname',
        user.nickname.isNotEmpty ? user.nickname : email.split('@').first,
      );

      // 登录后云同步：云端空则推本地；双边按 updatedAt 合并（不擦首次登录本地档）
      final local = ref.read(gameStateProvider);
      await ProgressSyncService.instance.syncAfterLogin(
        localJson: local.toJson(),
        localHasGame: local.hasGame,
        applyRemote: (json) async {
          await ref.read(gameStateProvider.notifier).replaceState(
                GameState.fromJson(json),
              );
        },
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRegister ? '🎉 注册成功！欢迎加入塑身工坊' : '⚡ 登录成功！欢迎回来'),
          backgroundColor: AppColors.green,
        ),
      );

      // 登录成功跳转（有存档进舞台，无存档进角色创建）
      _navigateAfterAuth();
    } on AuthException catch (e) {
      _showBackendError(e.message);
    } catch (e) {
      _showBackendError('网络异常，请确认后端服务已启动（$e）');
    }
  }

  /// 后端错误提示（保持与现有 SnackBar 风格一致）
  void _showBackendError(String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: AppColors.red,
      ),
    );
  }

  Future<void> _handleGuestLogin() async {
    if (!_agreedPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('试用前请先阅读并勾选《用户协议与隐私政策》'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_account', '离线体验勇士');
    await prefs.remove('user_email');
    await prefs.setString('user_nickname', '离线体验勇士');

    if (!mounted) return;
    _navigateAfterAuth();
  }

  @override
  Widget build(BuildContext context) {
    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xxl,
                vertical: AppSpace.xl,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 品牌 Header：铁砧之锤（锻造工坊徽记）
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.bg3,
                          AppColors.ember.withValues(alpha: 0.4),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.copper.withValues(alpha: 0.6),
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
                    child: const Text('🔨', style: TextStyle(fontSize: 44)),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Text(
                    '塑身工坊',
                    style: AppFonts.display(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      letterSpacing: 1.2,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    '锻造你的身体',
                    style: AppFonts.display(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.copper,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    '你的身体，是你精心雕琢的作品',
                    style: AppFonts.body(
                      fontSize: 13,
                      color: AppColors.text2,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxxl),

                  // 工坊卡容器
                  ForgeSurface(
                    borderColor: AppColors.copper.withValues(alpha: 0.4),
                    padding: const EdgeInsets.all(AppSpace.xl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
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
                              borderRadius: AppRadii.smAll,
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
                              labelColor: AppColors.onEmber,
                              unselectedLabelColor: AppColors.text2,
                              labelStyle: AppFonts.body(
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
                          const SizedBox(height: AppSpace.xl),

                          // 如果是注册页，显示用户名输入框
                          if (_tabController.index == 1) ...[
                            TextFormField(
                              controller: _usernameController,
                              style: TextStyle(color: AppColors.text),
                              decoration: InputDecoration(
                                labelText: '用户昵称',
                                prefixIcon: Icon(Icons.person_outline, color: AppColors.copper),
                                border: OutlineInputBorder(borderRadius: AppRadii.smAll),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().length < 2) {
                                  return '请输入至少2个字符的昵称';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpace.lg - 2),
                          ],

                          // 账号/邮箱输入框
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: AppColors.text),
                            decoration: InputDecoration(
                              labelText: '邮箱',
                              helperText: '仅支持邮箱登录，手机号暂不支持',
                              helperMaxLines: 2,
                              prefixIcon: Icon(Icons.email_outlined, color: AppColors.copper),
                              border: OutlineInputBorder(borderRadius: AppRadii.smAll),
                            ),
                            validator: (val) {
                              final v = val?.trim() ?? '';
                              if (v.isEmpty) {
                                return '请输入邮箱';
                              }
                              final isEmail =
                                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
                              if (!isEmail) {
                                return '请输入正确的邮箱地址';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpace.lg - 2),

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
                              border: OutlineInputBorder(borderRadius: AppRadii.smAll),
                            ),
                            validator: (val) {
                              if (val == null || val.length < 6) {
                                return '密码长度不能少于6位';
                              }
                              if (val.length > 32) {
                                return '密码长度不能超过32位';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpace.xxl),

                          // 提交按钮（炉火赤红主行动）
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.ember,
                                foregroundColor: AppColors.onEmber,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadii.mdAll,
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
                                        color: AppColors.onEmber,
                                      ),
                                    )
                                  : Text(
                                      _tabController.index == 0 ? '安全登录' : '立即注册',
                                      style: AppFonts.body(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.md),

                          // 协议勾选（商店上架合规要求）
                          Row(
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: Checkbox(
                                  value: _agreedPolicy,
                                  onChanged: (v) =>
                                      setState(() => _agreedPolicy = v ?? false),
                                  activeColor: AppColors.ember,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: AppSpace.xs),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _agreedPolicy = !_agreedPolicy),
                                  child: Text.rich(
                                    TextSpan(
                                      text: '我已阅读并同意 ',
                                      style: AppFonts.body(
                                        fontSize: 12,
                                        color: AppColors.text2,
                                      ),
                                      children: [
                                        WidgetSpan(
                                          child: GestureDetector(
                                            onTap: () => Navigator.of(context)
                                                .push(forgePageRoute(
                                                    builder: (_) =>
                                                        const PrivacyPolicyPage())),
                                            child: Text(
                                              '《用户协议与隐私政策》',
                                              style: AppFonts.body(
                                                fontSize: 12,
                                                color: AppColors.copper,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),

                  // 离线游客模式按钮（与账号登录同样需要同意隐私政策）
                  TextButton.icon(
                    onPressed: _handleGuestLogin,
                    icon: Icon(Icons.bolt_outlined, color: AppColors.ember, size: 18),
                    label: Text(
                      '免登录离线试用模式',
                      style: AppFonts.body(
                        color: AppColors.text2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '离线试用同样适用隐私政策，数据仅保存在本机',
                    style: AppFonts.body(fontSize: 11, color: AppColors.text2),
                    textAlign: TextAlign.center,
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
