import 'dart:io';

import 'package:fat_battle/config/api_config.dart';
import 'package:fat_battle/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default dart-defines do not ship third-party food API secrets', () {
    expect(ApiConfig.booheeAppId, isEmpty);
    expect(ApiConfig.booheeAppKey, isEmpty);
    expect(ApiConfig.fatsecretClientId, isEmpty);
    expect(ApiConfig.fatsecretClientSecret, isEmpty);
    expect(ApiConfig.hasBooheeCredentials, isFalse);
    expect(ApiConfig.hasFatSecretCredentials, isFalse);
  });

  test('food_recognition_service.dart has no hardcoded Boohee/FatSecret secrets', () {
    final src = File('lib/services/food_recognition_service.dart').readAsStringSync();
    expect(src.contains('nwkbeuvbdb'), isFalse);
    expect(src.contains('4rwwjrns5jyhbyptcdswsb5fyhavqa9b'), isFalse);
    expect(src.contains('7f138fe9fc194ed9a41e71ac2390abac'), isFalse);
    expect(src.contains('6424bd4ca42444e7b495557c569b6deb'), isFalse);
  });

  test('GameState privacy flags persist through JSON', () {
    const original = GameState(
      cloudSyncEnabled: false,
      foodVisionEnabled: false,
      cameraPoseEnabled: true,
    );
    final roundtrip = GameState.fromJson(original.toJson());
    expect(roundtrip.cloudSyncEnabled, isFalse);
    expect(roundtrip.foodVisionEnabled, isFalse);
    expect(roundtrip.cameraPoseEnabled, isTrue);
  });
}
