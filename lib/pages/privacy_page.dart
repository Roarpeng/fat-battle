import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../constants/app_constants.dart';
import '../theme/forge_theme.dart';
import '../theme/tokens.dart';
import '../widgets/home/forge_background.dart';

/// 隐私政策与用户协议页（上架合规）
///
/// 内容覆盖：信息收集范围、权限用途说明、第三方服务、
/// 数据存储与安全、用户权利（注销账号）、联系方式。
/// 文案与 AndroidManifest 声明的权限、后端 API 能力保持一致。
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  String get _transportLine {
    if (!ApiConfig.isBackendEnabled) {
      return '当前构建未连接后端。本地调试可能使用 HTTP；'
          '正式环境请通过反向代理（如 Caddy）启用 HTTPS，切勿在明文 HTTP 下传输账号密码。';
    }
    if (ApiConfig.isHttps) {
      return '当前已配置 HTTPS 后端（${ApiConfig.backendBaseUrl}），账号与识别请求走加密传输。';
    }
    return '当前后端地址为 HTTP（${ApiConfig.backendBaseUrl}），并非全程 HTTPS。'
        '正式上架请改用 HTTPS 反代，避免在公共网络传输登录凭证。';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        title: Text(
          '隐私政策与用户协议',
          style: AppFonts.display(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: ForgeBackground(
        child: ListView(
          padding: AppSpace.page.copyWith(bottom: AppSpace.xxxl),
          children: [
            Text(
              '生效日期：2026 年 8 月 1 日',
              style: AppFonts.body(fontSize: 12, color: AppColors.text2),
            ),
            const SizedBox(height: AppSpace.lg),
            _section('一、我们是谁', [
              '「塑身工坊」（下称"本应用"）是一款游戏化体重管理应用，'
                  '通过"击败脂肪怪"的玩法帮助你记录饮食、坚持锻炼。',
            ]),
            _section('二、我们收集哪些信息', [
              '1. 账号信息：注册时提供的邮箱与密码（密码加密存储，任何人无法查看明文）。当前不支持手机号登录。',
              '2. 健康记录：你主动填写的体重、饮食、运动记录，用于游戏数值与统计图表。',
              '3. 食物图片：使用"拍照识别"且你已开启该功能时，图片会上传到我们的服务器进行 AI 识别，识别完成后不做其他用途。',
              '4. 大致位置：城市美食推荐会使用 GPS 解析所在城市（见《权限用途》），不会持续追踪轨迹。',
              '5. 设备信息：仅用于维持登录状态与安全校验，不包含通讯录等无关数据。',
            ]),
            _section('三、权限用途说明', [
              '相机：拍摄食物照片进行 AI 识别、扫描包装条形码；锻炼时用于姿态检测（可在设置中关闭）。',
              '蓝牙：连接 ESP32 腰部 IMU Hub，接收运动传感器数据。本应用不连接体脂秤。',
              '位置：用于城市美食推荐（CityLocationService 解析所在城市）。可拒绝授权，此时回退到全国菜谱。',
              '存储（相册）：读取你主动选择的食物照片用于识别。',
              '通知 / 闹钟：在你开启提醒功能后，发送饮食与锻炼提醒。',
              '以上权限均可在使用对应功能时单独授权或拒绝，不影响其他功能使用。',
            ]),
            _section('四、第三方服务', [
              '食物 AI 识别由大语言模型服务商（如智谱 GLM、百度 AI）提供技术支持。'
                  '你的图片经由我们的服务器转发给上述服务商，'
                  '我们不会把图片用于识别以外的任何场景，也不会长期留存。',
              '条码查询可能使用公开的 Open Food Facts 数据库。',
              '除此之外，本应用不接入广告平台，不与任何第三方共享你的账号与健康数据。',
            ]),
            _section('五、数据存储与安全', [
              '登录凭证采用加密方式存储在你的设备中。',
              _transportLine,
              '你可以随时在"设置"中退出登录；注销账号后进入 30 天软删除期，期满后服务端数据将被物理清除。',
            ]),
            _section('六、你的权利', [
              '1. 查询与导出：你的全部记录可在应用内查看与分享。',
              '2. 注销账号：通过“设置 → 注销账号并抹除个人数据”提交（符合应用商店应用内删除要求）。'
                  '账号立即停用，云端数据在 30 天后彻底删除。网页说明见仓库 docs/account-deletion.html。',
              '3. 撤回同意：可在设置中关闭云同步、食物视觉识别、摄像头姿态检测，或关闭相应系统权限。',
            ]),
            _section('七、未成年人保护', [
              '本应用主要面向 16 周岁以上用户。未成年人请在监护人指导下使用，'
                  '若监护人发现未成年人未经同意提供了个人信息，可联系我们删除。',
            ]),
            _section('八、政策更新', [
              '如隐私政策发生重大变化，我们会在应用内显著位置通知。继续使用即视为接受更新后的政策。',
            ]),
            _section('九、联系我们', [
              '如有任何隐私相关问题，请联系：support@bodystudio.app',
            ]),
            const SizedBox(height: AppSpace.xxl),
            Text(
              '使用本应用即表示你已阅读并同意以上内容。',
              style: AppFonts.body(
                fontSize: 12,
                color: AppColors.text2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<String> paragraphs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: ForgeSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppFonts.display(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.copper,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            ...paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm - 2),
                child: Text(
                  p,
                  style: AppFonts.body(
                    fontSize: 13,
                    color: AppColors.text,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
