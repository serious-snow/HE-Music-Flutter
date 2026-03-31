import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_item.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_state.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_platform.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/discover_sections.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/layout/adaptive_media_grid_spec.dart';

void main() {
  testWidgets('album section title does not use bold font weight', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscoverSections(
            loadingText: 'loading',
            emptyText: 'empty',
            retryText: 'retry',
            titleOf: (section) => section.titleKey,
            state: HomeDiscoverState(
              loading: false,
              platforms: const <HomePlatform>[],
              selectedPlatformId: 'qq',
              sections: <HomeDiscoverSection>[
                HomeDiscoverSection(
                  key: 'album',
                  titleKey: '新碟上架',
                  type: HomeDiscoverItemType.album,
                  albums: <AlbumInfo>[_buildAlbum()],
                ),
              ],
            ),
            onRetry: () {},
            onTapSong: (songs, index) {},
            onTapAlbum: (_) {},
            onTapPlaylist: (_) {},
            onTapVideo: (_) {},
            onMoreSong: (_) {},
            isSongLiked: (_) => false,
            onLikeSong: (_) async {},
            isCurrentSong: (_) => false,
            config: AppConfigState.initial,
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('新碟上架'));

    expect(
      title.style?.fontWeight,
      isNot(anyOf(FontWeight.w600, FontWeight.w700, FontWeight.w800)),
    );
  });

  testWidgets('album section stays left aligned on wide layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 840,
            child: DiscoverSections(
              loadingText: 'loading',
              emptyText: 'empty',
              retryText: 'retry',
              titleOf: (section) => section.titleKey,
              state: HomeDiscoverState(
                loading: false,
                platforms: const <HomePlatform>[],
                selectedPlatformId: 'qq',
                sections: <HomeDiscoverSection>[
                  HomeDiscoverSection(
                    key: 'album',
                    titleKey: '新碟上架',
                    type: HomeDiscoverItemType.album,
                    albums: <AlbumInfo>[_buildAlbum()],
                  ),
                ],
              ),
              onRetry: () {},
              onTapSong: (songs, index) {},
              onTapAlbum: (_) {},
              onTapPlaylist: (_) {},
              onTapVideo: (_) {},
              onMoreSong: (_) {},
              isSongLiked: (_) => false,
              onLikeSong: (_) async {},
              isCurrentSong: (_) => false,
              config: AppConfigState.initial,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final titleLeft = tester.getTopLeft(find.text('新碟上架')).dx;

    expect(titleLeft, lessThan(10));
  });

  test('discover slivers do not use scroll-time sliver layout builders', () {
    final slivers = buildDiscoverSectionSlivers(
      loadingText: 'loading',
      emptyText: 'empty',
      retryText: 'retry',
      titleOf: (section) => section.titleKey,
      state: HomeDiscoverState(
        loading: false,
        platforms: const <HomePlatform>[],
        selectedPlatformId: 'qq',
        sections: <HomeDiscoverSection>[
          HomeDiscoverSection(
            key: 'album',
            titleKey: '新碟上架',
            type: HomeDiscoverItemType.album,
            albums: <AlbumInfo>[_buildAlbum()],
          ),
        ],
      ),
      gridSpec: resolveAdaptiveMediaGridSpec(maxWidth: 320),
      onRetry: () {},
      onTapSong: (songs, index) {},
      onTapAlbum: (_) {},
      onTapPlaylist: (_) {},
      onTapVideo: (_) {},
      onMoreSong: (_) {},
      isSongLiked: (_) => false,
      onLikeSong: (_) async {},
      isCurrentSong: (_) => false,
      config: AppConfigState.initial,
    );

    expect(slivers.whereType<SliverLayoutBuilder>(), isEmpty);
  });
}

AlbumInfo _buildAlbum() {
  return const AlbumInfo(
    name: 'American Heart',
    id: 'album-1',
    cover: '',
    artists: <SongInfoArtistInfo>[
      SongInfoArtistInfo(id: 'artist-1', name: 'Benson Boone'),
    ],
    songCount: '10',
    publishTime: '2026-03-30',
    songs: <SongInfo>[],
    description: '',
    platform: 'qq',
    language: '',
    genre: '',
    type: 0,
    isFinished: true,
    playCount: '1234',
  );
}
