import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/startup/app_startup_provider.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_collection_status_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_collection_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
  setUp(() {
    _CountingFavoriteSongStatusController.reset();
    _CountingFavoriteCollectionStatusController.reset();
  });

  test(
    'app startup refreshes favorite states when auth token exists',
    () async {
      final container = ProviderContainer(
        overrides: <Override>[
          appConfigProvider.overrideWith(
            () => _TestAppConfigController(authToken: 'token'),
          ),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          favoriteSongStatusProvider.overrideWith(
            _CountingFavoriteSongStatusController.new,
          ),
          favoriteCollectionStatusProvider.overrideWith(
            _CountingFavoriteCollectionStatusController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appStartupProvider.future);

      expect(_CountingFavoriteSongStatusController.refreshCallCount, 1);
      expect(_CountingFavoriteCollectionStatusController.refreshCallCount, 1);
    },
  );

  test('app startup ignores favorite state preload failures', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        appConfigProvider.overrideWith(
          () => _TestAppConfigController(authToken: 'token'),
        ),
        onlinePlatformsProvider.overrideWith(
          _TestOnlinePlatformsController.new,
        ),
        favoriteSongStatusProvider.overrideWith(
          _ThrowingFavoriteSongStatusController.new,
        ),
        favoriteCollectionStatusProvider.overrideWith(
          _ThrowingFavoriteCollectionStatusController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(container.read(appStartupProvider.future), completes);
  });
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({required this.authToken});

  final String authToken;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      apiBaseUrl: 'https://example.com',
      authToken: authToken,
    );
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];
  }
}

class _CountingFavoriteSongStatusController
    extends FavoriteSongStatusController {
  static int refreshCallCount = 0;

  static void reset() {
    refreshCallCount = 0;
  }

  @override
  FavoriteSongStatusState build() {
    return FavoriteSongStatusState.initial;
  }

  @override
  Future<void> refresh() async {
    refreshCallCount += 1;
  }
}

class _CountingFavoriteCollectionStatusController
    extends FavoriteCollectionStatusController {
  static int refreshCallCount = 0;

  static void reset() {
    refreshCallCount = 0;
  }

  @override
  FavoriteCollectionStatusState build() {
    return FavoriteCollectionStatusState.initial;
  }

  @override
  Future<void> refresh() async {
    refreshCallCount += 1;
  }
}

class _ThrowingFavoriteSongStatusController
    extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() {
    return FavoriteSongStatusState.initial;
  }

  @override
  Future<void> refresh() async {
    throw Exception('favorite songs preload failed');
  }
}

class _ThrowingFavoriteCollectionStatusController
    extends FavoriteCollectionStatusController {
  @override
  FavoriteCollectionStatusState build() {
    return FavoriteCollectionStatusState.initial;
  }

  @override
  Future<void> refresh() async {
    throw Exception('favorite collections preload failed');
  }
}
