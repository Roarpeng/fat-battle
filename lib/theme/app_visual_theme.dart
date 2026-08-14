/// 塑身工坊可切换视觉风格。
///
/// 默认 [forge] 保持现有熔炉暗色；[sketch] 为浅色铅笔手账；
/// [ink] 为深色墨稿。选择写入 GameState，并额外备份到
/// SharedPreferences 键 [kAppVisualThemePrefKey]，以便重启后仍在。
enum AppVisualTheme {
  forge,
  sketch,
  ink;

  String get label {
    switch (this) {
      case AppVisualTheme.forge:
        return '熔炉';
      case AppVisualTheme.sketch:
        return '铅笔手账';
      case AppVisualTheme.ink:
        return '墨稿';
    }
  }

  String get subtitle {
    switch (this) {
      case AppVisualTheme.forge:
        return '炉火与铜金';
      case AppVisualTheme.sketch:
        return '纸面与石墨';
      case AppVisualTheme.ink:
        return '夜读墨色';
    }
  }

  static AppVisualTheme fromId(String? raw) {
    switch (raw) {
      case 'sketch':
        return AppVisualTheme.sketch;
      case 'ink':
        return AppVisualTheme.ink;
      case 'forge':
      default:
        return AppVisualTheme.forge;
    }
  }
}

/// SharedPreferences 备份键（GameState JSON 为主，此键用于空档/重置后回退）。
const String kAppVisualThemePrefKey = 'app_visual_theme';
