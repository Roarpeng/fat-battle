/// API 配置类
///
/// **正式包（推荐）**：只注入 `API_BASE_URL`，食物识别/搜索走后端代理；
/// 百度/智谱等密钥只存在服务器，不要打进 APK。
///
/// ```bash
/// flutter build apk --release \
///   --dart-define=API_BASE_URL=https://你的服务器:端口
/// ```
///
/// 直连第三方密钥（`BAIDU_*` / `ZHIPU_API_KEY`）仅用于本地调试脚本，正式包不要注入。
class ApiConfig {
  ApiConfig._();

  // ===== 百度菜品识别 API（仅本地调试直连；正式包走后端，勿注入） =====
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

  // ===== GLM 直连（仅本地调试；正式包走后端，勿注入） =====
  static const zhipuApiKey = String.fromEnvironment('ZHIPU_API_KEY');

  /// 可选旧代理根地址；默认空
  static const glmProxyBaseUrl = String.fromEnvironment('GLM_PROXY_BASE_URL');

  static const glmApiUrl =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  static const glmVisionModel = 'glm-4.6v-flash';
  static const glmTextModel = 'glm-4-flash';

  static bool get useGlmProxy => glmProxyBaseUrl.isNotEmpty;

  /// 是否配置了 App 直连智谱 Key（正式包应始终为 false）
  static bool get hasGlmConfig => zhipuApiKey.isNotEmpty;

  // ===== 真实后端（账号 + 食物识别/搜索代理）——正式包唯一需要的配置 =====
  /// 后端基础地址。正式包必须注入；空 = 未连服务器，识别不可用。
  ///
  /// ```bash
  /// flutter build apk --release --dart-define=API_BASE_URL=http://host:8080
  /// ```
  static const backendBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// 是否已配置后端地址
  static bool get isBackendEnabled => backendBaseUrl.isNotEmpty;

  /// 在线识别是否可用：正式路径只看后端；直连密钥仅调试兜底
  static bool get hasAnyFoodVisionConfig =>
      isBackendEnabled || hasGlmConfig || hasBaiduCredentials;

  /// 未配置后端时给用户的提示（不含密钥、不提百度）
  static String get foodVisionConfigHint =>
      '未连接到食物识别服务器。拍照/搜索会发给后端处理，App 只需服务器地址。'
      '请用 scripts/build_apk.ps1 重新打包（自动注入 API_BASE_URL），'
      '并确认手机能访问该服务器。';
}
