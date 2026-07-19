/// API 配置类
///
/// 所有第三方 API 密钥均通过 `--dart-define` 在编译时注入，
/// 不硬编码到源码中。运行时通过 [String.fromEnvironment] 读取。
///
/// 构建示例：
/// ```bash
/// flutter run --release \
///   --dart-define=BAIDU_API_KEY=your_baidu_api_key \
///   --dart-define=BAIDU_SECRET_KEY=your_baidu_secret_key \
///   --dart-define=BOOHEE_APP_ID=your_boohee_app_id \
///   --dart-define=BOOHEE_APP_KEY=your_boohee_app_key
/// ```
class ApiConfig {
  ApiConfig._();

  // ===== 百度菜品识别 API =====
  /// 百度 AI 平台的 API Key
  static const baiduApiKey = String.fromEnvironment('BAIDU_API_KEY');

  /// 百度 AI 平台的 Secret Key
  static const baiduSecretKey = String.fromEnvironment('BAIDU_SECRET_KEY');

  /// 百度 Token 接口
  static const baiduTokenUrl =
      'https://aip.baidubce.com/oauth/2.0/token';

  /// 百度菜品识别接口（v2）
  static const baiduDishUrl =
      'https://aip.baidubce.com/rest/2.0/image-classify/v2/dish';

  /// 百度果蔬识别接口（v1）
  static const baiduIngredientUrl =
      'https://aip.baidubce.com/rest/2.0/image-classify/v1/classify/ingredient';

  /// 是否已配置百度凭据
  static bool get hasBaiduCredentials =>
      baiduApiKey.isNotEmpty && baiduSecretKey.isNotEmpty;

  /// 百度后端代理地址（推荐方式：API Key 保存在后端 .env 中）
  /// 真机调试用电脑局域网 IP，模拟器用 10.0.2.2
  static const baiduProxyUrl = String.fromEnvironment(
    'BAIDU_PROXY_URL',
    defaultValue: 'http://192.168.50.195:7860/api/food-recognize',
  );

  /// 是否走后端代理（优先于直连）
  static bool get useBaiduProxy => baiduProxyUrl.isNotEmpty;

  // ===== 薄荷健康 API =====
  /// 薄荷健康 App ID
  static const booheeAppId = String.fromEnvironment('BOOHEE_APP_ID');

  /// 薄荷健康 App Key
  static const booheeAppKey = String.fromEnvironment('BOOHEE_APP_KEY');

  /// 薄荷健康 API 基础地址
  static const booheeBaseUrl = 'https://api.boohee.com';

  /// 是否已配置薄荷健康凭据
  static bool get hasBooheeCredentials =>
      booheeAppId.isNotEmpty && booheeAppKey.isNotEmpty;

  // ===== FatSecret API（沿用旧版 FoodRecognitionService 的实现） =====
  /// FatSecret OAuth Token 接口
  static const fatsecretTokenUrl =
      'https://oauth.fatsecret.com/connect/token';

  /// FatSecret REST API 基础地址
  static const fatsecretBaseUrl =
      'https://platform.fatsecret.com/rest/server.api';

  // ===== MiniCPM-V 食物识别 API =====
  /// MiniCPM-V 后端代理地址
  static const minicpmBaseUrl = String.fromEnvironment(
    'MINICPM_BASE_URL',
    defaultValue: 'http://192.168.50.195:7860/api/minicpm',
  );

  /// MiniCPM-V API Key（可选，后端代理时使用）
  static const minicpmApiKey = String.fromEnvironment('MINICPM_API_KEY');

  /// 是否已配置 MiniCPM
  static bool get hasMiniCPMConfig => minicpmBaseUrl.isNotEmpty;

  // ===== GLM 食物识别 API =====
  /// 智谱 AI API Key（通过 --dart-define 注入）
  static const zhipuApiKey = String.fromEnvironment('ZHIPU_API_KEY');

  /// 智谱 AI API 端点
  static const glmApiUrl = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  /// GLM 视觉模型（图片识别用）
  static const glmVisionModel = 'glm-4.6v-flash';

  /// GLM 纯文本模型（文本搜索用）
  static const glmTextModel = 'glm-4-flash';

  /// 是否已配置 GLM（只需配置 API Key）
  static bool get hasGlmConfig => zhipuApiKey.isNotEmpty;
}
