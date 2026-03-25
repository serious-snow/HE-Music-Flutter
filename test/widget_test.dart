import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_song_source.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_platform.dart';
import 'package:he_music_flutter/features/home/domain/repositories/home_discover_repository.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_discover_providers.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_profile.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_summary.dart';
import 'package:he_music_flutter/features/my/domain/repositories/my_overview_repository.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_overview_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
  testWidgets('home shell renders with two tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onlinePlatformsProvider.overrideWith(
            (ref) async => _fakeOnlinePlatforms,
          ),
          homeDiscoverRepositoryProvider.overrideWithValue(
            const _FakeHomeDiscoverRepository(),
          ),
          myOverviewRepositoryProvider.overrideWithValue(
            const _FakeMyOverviewRepository(),
          ),
        ],
        child: const HeMusicApp(),
      ),
    );

    expect(find.text('首页'), findsWidgets);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('搜索歌曲/歌手/歌单'), findsOneWidget);
    expect(find.text('排行榜'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('home discover uses preloaded global platforms', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onlinePlatformsProvider.overrideWith(
            (ref) async => _fakeOnlinePlatforms,
          ),
          homeDiscoverRepositoryProvider.overrideWithValue(
            const _GlobalPlatformFirstRepository(),
          ),
          myOverviewRepositoryProvider.overrideWithValue(
            const _FakeMyOverviewRepository(),
          ),
        ],
        child: const HeMusicApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('QQ'), findsWidgets);
    expect(find.text('OFF'), findsNothing);
    expect(find.text('搜索歌曲/歌手/歌单'), findsOneWidget);
  });
}

final List<OnlinePlatform> _fakeOnlinePlatforms = <OnlinePlatform>[
  OnlinePlatform(
    id: 'qq',
    name: 'QQ音乐',
    shortName: 'QQ',
    status: 1,
    featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
  ),
  OnlinePlatform(
    id: 'disabled',
    name: 'Disabled',
    shortName: 'OFF',
    status: 2,
    featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
  ),
];

class _FakeHomeDiscoverRepository implements HomeDiscoverRepository {
  const _FakeHomeDiscoverRepository();

  @override
  Future<List<HomePlatform>> fetchPlatforms() async {
    return <HomePlatform>[
      HomePlatform(
        id: 'qq',
        name: 'QQ',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
      ),
    ];
  }

  @override
  Future<List<HomeDiscoverSection>> fetchDiscoverSections(
    String platformId,
  ) async {
    return const <HomeDiscoverSection>[];
  }

  @override
  Future<HomeSongSource> fetchSongSource({
    required String songId,
    required String platformId,
  }) async {
    return const HomeSongSource(
      url: 'https://example.com/test.mp3',
      format: 'mp3',
    );
  }
}

class _GlobalPlatformFirstRepository implements HomeDiscoverRepository {
  const _GlobalPlatformFirstRepository();

  @override
  Future<List<HomePlatform>> fetchPlatforms() async {
    throw StateError(
      'fetchPlatforms should not be called when global platform cache exists',
    );
  }

  @override
  Future<List<HomeDiscoverSection>> fetchDiscoverSections(
    String platformId,
  ) async {
    return const <HomeDiscoverSection>[];
  }

  @override
  Future<HomeSongSource> fetchSongSource({
    required String songId,
    required String platformId,
  }) async {
    return const HomeSongSource(
      url: 'https://example.com/test.mp3',
      format: 'mp3',
    );
  }
}

class _FakeMyOverviewRepository implements MyOverviewRepository {
  const _FakeMyOverviewRepository();

  @override
  Future<MyOverview> fetchOverview() async {
    return const MyOverview(
      profile: MyProfile(
        id: '1',
        username: 'tester',
        nickname: 'Tester',
        email: '',
        status: 1,
        avatarUrl: '',
      ),
      summary: MySummary(
        favoriteSongCount: 1,
        favoritePlaylistCount: 1,
        favoriteArtistCount: 1,
        favoriteAlbumCount: 1,
        createdPlaylistCount: 1,
      ),
    );
  }
}
