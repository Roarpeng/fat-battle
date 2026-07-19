/// API 配置类
///
/// 当前阶段：**App 直连第三方 API**，不依赖本机后端。
/// 密钥通过 `--dart-define` 在编译时注入（不要提交到仓库）。
///
/// 构建示例：
/// ```bash
/// flutter build apk --release \
///   --dart-define=ZHIPU_API_KEY=... \
///   --dart-define=BAIDU_API_KEY=... \
///   --dart-define=BAIDU_SECRET_KEY=...
/// ```
///
/// 后续若做后端分离，可再通过 dart-define 显式传入：
/// `BAIDU_PROXY_URL` / `GLM_PROXY_BASE_URL`（默认均为空 = 不走代理）。
class ApiConfig {
  ApiConfig._();

  // ===== 百度菜品识别 API（直连） =====
  static const baiduApiKey = String.fromEnvironment('BAIDU_API_KEY');
  static const baiduSecretKey = String.fromEnvironment('BAIDU_SECRET_KEY');

  static const baiduTokenUrl =
      'https://aip.baidubce.com/oauth/2.0/token';
  static const baiduDishUrl =
      'https://aip.baidubce.com/rest/2.0/image-classify/v2/dish';
  static const baiduIngredientUrl =
      'https://aip.baidubce.com/rest/2.0/image-classify/v1/classify/ingredient';

  static bool get hasBaiduCredentials =>
      baiduApiKey.isNotEmpty && baiduSecretKey.isNotEmpty;

  /// 可选代理；默认空字符串 = 不走代理
  static const baiduProxyUrl = String.fromEnvironment('BAIDU_PROXY_URL');

  static bool get useBaiduProxy => baiduProxyUrl.isNotEmpty;

  // ===== 薄荷健康 API =====
  static const booheeAppId = String.fromEnvironment('BOOHEE_APP_ID');
  static const booheeAppKey = String.fromEnvironment('BOOHEE_APP_KEY');
  static const booheeBaseUrl = 'https://api.boohee.com';

  static bool get hasBooheeCredentials =>
      booheeAppId.isNotEmpty && booheeAppKey.isNotEmpty;

  // ===== FatSecret API =====
  static const fatsecretTokenUrl =
      'https://oauth.fatsecret.com/connect/token';
  static const fatsecretBaseUrl =
      'https://platform.fatsecret.com/rest/server.api';

  // ===== MiniCPM-V（可选；默认关闭，避免误连本机后端） =====
  static const minicpmBaseUrl = String.fromEnvironment('MINICPM_BASE_URL');
  static const minicpmApiKey = String.fromEnvironment('MINICPM_API_KEY');

  static bool get hasMiniCPMConfig => minicpmBaseUrl.isNotEmpty;

  // ===== GLM 食物识别（直连智谱） =====
  static const zhipuApiKey = String.fromEnvironment('ZHIPU_API_KEY');

  /// 可选代理根地址；默认空 = 直连 open.bigmodel.cn
  static const glmProxyBaseUrl = String.fromEnvironment('GLM_PROXY_BASE_URL');

  static const glmApiUrl =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  static const glmVisionModel = 'glm-4.6v-flash';
  static const glmTextModel = 'glm-4-flash';

  static bool get useGlmProxy => glmProxyBaseUrl.isNotEmpty;

  /// GLM 可用：必须有直连 Key（代理仅作可选增强，当前阶段不依赖）
  static bool get hasGlmConfig => zhipuApiKey.isNotEmpty;
}
