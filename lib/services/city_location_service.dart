import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food_recommend_models.dart';

/// GPS / 缓存 / 锁定城市解析服务
class CityLocationService {
  static const cacheKey = 'food_recommend_last_city';
  static const cachePlaceKey = 'food_recommend_last_place';

  /// 解析城市。顺序：锁定 → GPS → 缓存 → national
  Future<CityResolveResult> resolve({FoodPreference? preference}) async {
    final locked = preference?.lockedCity;
    if (locked != null) {
      return CityResolveResult(
        city: locked,
        source: 'locked',
        rawPlaceName: locked.displayName,
      );
    }

    final gps = await resolveFromGps();
    // GPS 成功且匹配到支持城市
    if (gps.fromGps && gps.city != SupportedCity.national) {
      await cacheCity(gps.city, placeName: gps.rawPlaceName);
      return gps;
    }

    final cached = await loadCachedCity();
    if (cached != null) {
      final prefs = await SharedPreferences.getInstance();
      return CityResolveResult(
        city: cached,
        source: 'cache',
        rawPlaceName: prefs.getString(cachePlaceKey),
      );
    }

    // GPS 成功但未匹配支持城市
    if (gps.fromGps) {
      return gps;
    }

    return const CityResolveResult(
      city: SupportedCity.national,
      source: 'fallback',
    );
  }

  /// 仅尝试 GPS（供手动「重新定位」）
  Future<CityResolveResult> resolveFromGps({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final permission = await Permission.locationWhenInUse.request();
      if (!permission.isGranted) {
        return const CityResolveResult(
          city: SupportedCity.national,
          source: 'fallback',
        );
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const CityResolveResult(
          city: SupportedCity.national,
          source: 'fallback',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        return const CityResolveResult(
          city: SupportedCity.national,
          source: 'gps',
          fromGps: true,
        );
      }

      final p = placemarks.first;
      final place = [
        p.locality,
        p.subAdministrativeArea,
        p.administrativeArea,
      ].where((e) => e != null && e.trim().isNotEmpty).join(' ');

      final matched = matchCity(place);
      return CityResolveResult(
        city: matched ?? SupportedCity.national,
        source: 'gps',
        rawPlaceName: place.isEmpty ? null : place,
        fromGps: true,
      );
    } catch (_) {
      // 拒权 / 超时 / 服务关闭等：降级，不抛致命异常
      return const CityResolveResult(
        city: SupportedCity.national,
        source: 'fallback',
      );
    }
  }

  Future<void> cacheCity(SupportedCity city, {String? placeName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, city.name);
    if (placeName != null) {
      await prefs.setString(cachePlaceKey, placeName);
    }
  }

  Future<SupportedCity?> loadCachedCity() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(cacheKey);
    if (name == null) return null;
    for (final c in SupportedCity.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// 从地名字符串匹配 SupportedCity（含「杭州市」「西安市」等）
  static SupportedCity? matchCity(String? place) {
    if (place == null || place.trim().isEmpty) return null;
    final lower = place.toLowerCase();

    if (place.contains('杭州') || lower.contains('hangzhou')) {
      return SupportedCity.hangzhou;
    }
    if (place.contains('西安') ||
        lower.contains("xi'an") ||
        RegExp(r'(^|[^a-z])xian([^a-z]|$)').hasMatch(lower)) {
      return SupportedCity.xian;
    }
    if (place.contains('成都') || lower.contains('chengdu')) {
      return SupportedCity.chengdu;
    }
    if (place.contains('宁波') || lower.contains('ningbo')) {
      return SupportedCity.ningbo;
    }
    return null;
  }
}
