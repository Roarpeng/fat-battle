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
}
