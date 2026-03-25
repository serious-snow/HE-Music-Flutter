import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/domain/repositories/my_collection_repository.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_collection_providers.dart';

void main() {
  test('initialize should load all favorite types', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        myCollectionRepositoryProvider.overrideWithValue(
          _FakeMyCollectionRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(myCollectionControllerProvider.notifier).initialize();
    final state = container.read(myCollectionControllerProvider);

    expect(state.loading, false);
    expect(state.errorMessage, isNull);
    expect(state.songs.length, 2);
    expect(state.playlists.length, 1);
    expect(state.artists.length, 1);
    expect(state.albums.length, 1);
  });

  test('removeFavorite should remove item from selected list', () async {
    final repository = _FakeMyCollectionRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        myCollectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(myCollectionControllerProvider.notifier).refreshAll();
    final firstSong = container
        .read(myCollectionControllerProvider)
        .songs
        .first;

    await container
        .read(myCollectionControllerProvider.notifier)
        .removeFavorite(firstSong);
    final state = container.read(myCollectionControllerProvider);

    expect(state.songs.length, 1);
    expect(state.songs.first.id, 'song-2');
  });
}

class _FakeMyCollectionRepository implements MyCollectionRepository {
  final Map<MyFavoriteType, List<MyFavoriteItem>> _itemsByType =
      <MyFavoriteType, List<MyFavoriteItem>>{
        MyFavoriteType.songs: <MyFavoriteItem>[
          const MyFavoriteItem(
            id: 'song-1',
            platform: 'kuwo',
            type: MyFavoriteType.songs,
            title: 'ID: song-1',
            subtitle: 'kuwo',
            coverUrl: '',
          ),
          const MyFavoriteItem(
            id: 'song-2',
            platform: 'kuwo',
            type: MyFavoriteType.songs,
            title: 'ID: song-2',
            subtitle: 'kuwo',
            coverUrl: '',
          ),
        ],
        MyFavoriteType.playlists: <MyFavoriteItem>[
          const MyFavoriteItem(
            id: 'playlist-1',
            platform: 'kuwo',
            type: MyFavoriteType.playlists,
            title: 'Playlist',
            subtitle: 'kuwo',
            coverUrl: '',
          ),
        ],
        MyFavoriteType.artists: <MyFavoriteItem>[
          const MyFavoriteItem(
            id: 'artist-1',
            platform: 'kuwo',
            type: MyFavoriteType.artists,
            title: 'Artist',
            subtitle: 'kuwo',
            coverUrl: '',
          ),
        ],
        MyFavoriteType.albums: <MyFavoriteItem>[
          const MyFavoriteItem(
            id: 'album-1',
            platform: 'kuwo',
            type: MyFavoriteType.albums,
            title: 'Album',
            subtitle: 'kuwo',
            coverUrl: '',
          ),
        ],
      };

  @override
  Future<List<MyFavoriteItem>> fetchFavorites(MyFavoriteType type) async {
    return _itemsByType[type]!.toList(growable: false);
  }

  @override
  Future<void> removeFavorite({
    required MyFavoriteType type,
    required String id,
    required String platform,
  }) async {
    final list = _itemsByType[type]!;
    list.removeWhere((item) => item.id == id && item.platform == platform);
  }
}
