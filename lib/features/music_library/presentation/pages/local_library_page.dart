import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../features/player/domain/entities/player_track.dart';
import '../../../../features/player/presentation/providers/player_providers.dart';
import '../../../../shared/widgets/song_list_item.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../domain/entities/local_song.dart';
import '../providers/local_library_providers.dart';

enum _LocalLibraryView { songs, artists, albums }

class LocalLibraryPage extends ConsumerStatefulWidget {
  const LocalLibraryPage({super.key});

  @override
  ConsumerState<LocalLibraryPage> createState() => _LocalLibraryPageState();
}

class _LocalLibraryPageState extends ConsumerState<LocalLibraryPage> {
  _LocalLibraryView _view = _LocalLibraryView.songs;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localLibraryControllerProvider);
    final controller = ref.read(localLibraryControllerProvider.notifier);
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppI18n.t(config, 'local.title')),
        actions: <Widget>[
          IconButton(
            onPressed: controller.scanLibrary,
            tooltip: AppI18n.t(config, 'common.scan'),
            icon: const Icon(Icons.folder_open_rounded),
          ),
          IconButton(
            onPressed: controller.clearLibrary,
            tooltip: AppI18n.t(config, 'common.clear'),
            icon: const Icon(Icons.clear_all_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Expanded(
            child: state.when(
              data: (songs) => _SongList(
                songs: songs,
                view: _view,
                onScan: controller.scanLibrary,
                onClear: controller.clearLibrary,
                localeCode: config.localeCode,
                onViewChanged: (view) => setState(() => _view = view),
                onPlayTap: (index) =>
                    _playLocalSong(context, ref, songs, index),
                onPlayGroupTap: (groupSongs, index) =>
                    _playLocalSong(context, ref, groupSongs, index),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorView(
                message: '$error',
                localeCode: config.localeCode,
                onRetry: controller.scanLibrary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playLocalSong(
    BuildContext context,
    WidgetRef ref,
    List<LocalSong> songs,
    int index,
  ) async {
    if (index < 0 || index >= songs.length) {
      return;
    }
    final track = _toPlayerTrack(songs[index]);
    await ref.read(playerControllerProvider.notifier).insertNextAndPlay(track);
  }

  PlayerTrack _toPlayerTrack(LocalSong song) {
    return PlayerTrack(
      id: 'local-${song.id}',
      title: song.title,
      path: song.filePath,
      artist: song.artist,
      album: song.album,
      url: '',
      artworkUrl: null,
      artworkBytes: song.artworkBytes,
      platform: 'local',
    );
  }
}

class _SongList extends StatelessWidget {
  const _SongList({
    required this.songs,
    required this.view,
    required this.onScan,
    required this.onClear,
    required this.localeCode,
    required this.onViewChanged,
    required this.onPlayTap,
    required this.onPlayGroupTap,
  });

  final List<LocalSong> songs;
  final _LocalLibraryView view;
  final Future<void> Function() onScan;
  final Future<void> Function() onClear;
  final String localeCode;
  final ValueChanged<_LocalLibraryView> onViewChanged;
  final ValueChanged<int> onPlayTap;
  final void Function(List<LocalSong> songs, int index) onPlayGroupTap;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return _EmptyLibrary(onScan: onScan, localeCode: localeCode);
    }
    final artistGroups = _groupSongsByArtist(songs, localeCode);
    final albumGroups = _groupSongsByAlbum(songs, localeCode);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<_LocalLibraryView>(
              segments: <ButtonSegment<_LocalLibraryView>>[
                ButtonSegment<_LocalLibraryView>(
                  value: _LocalLibraryView.songs,
                  label: Text(
                    AppI18n.tByLocaleCode(localeCode, 'local.tab.songs'),
                  ),
                ),
                ButtonSegment<_LocalLibraryView>(
                  value: _LocalLibraryView.artists,
                  label: Text(
                    AppI18n.tByLocaleCode(localeCode, 'local.tab.artists'),
                  ),
                ),
                ButtonSegment<_LocalLibraryView>(
                  value: _LocalLibraryView.albums,
                  label: Text(
                    AppI18n.tByLocaleCode(localeCode, 'local.tab.albums'),
                  ),
                ),
              ],
              selected: <_LocalLibraryView>{view},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }
                onViewChanged(selection.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
        Expanded(
          child: switch (view) {
            _LocalLibraryView.songs => _buildSongList(),
            _LocalLibraryView.artists => _buildGroupList(
              context,
              groups: artistGroups,
              emptyLabel: AppI18n.tByLocaleCode(
                localeCode,
                'local.empty.artist',
              ),
            ),
            _LocalLibraryView.albums => _buildGroupList(
              context,
              groups: albumGroups,
              emptyLabel: AppI18n.tByLocaleCode(
                localeCode,
                'local.empty.album',
              ),
            ),
          },
        ),
      ],
    );
  }

  Widget _buildSongList() {
    return SongListComponent(
      itemCount: songs.length,
      enablePaging: false,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongListItem(
          data: SongListItemData(
            title: song.title,
            artistAlbumText: '${song.artist} - ${song.album}',
            subtitleText: song.filePath,
            coverBytes: song.artworkBytes,
            tags: <String>[
              AppI18n.tByLocaleCode(localeCode, 'local.tag.local'),
              if (song.formatLabel.isNotEmpty) song.formatLabel,
            ],
          ),
          onTap: () => onPlayTap(index),
          onMoreTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppI18n.tByLocaleCode(localeCode, 'local.more_pending'),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupList(
    BuildContext context, {
    required List<_LocalSongGroup> groups,
    required String emptyLabel,
  }) {
    if (groups.isEmpty) {
      return Center(child: Text(emptyLabel));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _LocalGroupListItem(
          group: group,
          onTap: () => _openGroupSongsSheet(context, group),
        );
      },
    );
  }

  void _openGroupSongsSheet(BuildContext context, _LocalSongGroup group) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: <Widget>[
                      if (group.coverBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            group.coverBytes!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) =>
                                _GroupCoverFallback(size: 52, icon: group.icon),
                          ),
                        )
                      else
                        _GroupCoverFallback(size: 52, icon: group.icon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              group.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              group.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SongListComponent(
                    itemCount: group.songs.length,
                    enablePaging: false,
                    itemBuilder: (context, index) {
                      final song = group.songs[index];
                      return SongListItem(
                        data: SongListItemData(
                          title: song.title,
                          artistAlbumText: '${song.artist} - ${song.album}',
                          subtitleText: song.filePath,
                          coverBytes: song.artworkBytes,
                          tags: <String>[
                            AppI18n.tByLocaleCode(
                              localeCode,
                              'local.tag.local',
                            ),
                            if (song.formatLabel.isNotEmpty) song.formatLabel,
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          onPlayGroupTap(group.songs, index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocalGroupListItem extends StatelessWidget {
  const _LocalGroupListItem({required this.group, required this.onTap});

  final _LocalSongGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: <Widget>[
            if (group.coverBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  group.coverBytes!,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      _GroupCoverFallback(size: 58, icon: group.icon),
                ),
              )
            else
              _GroupCoverFallback(size: 58, icon: group.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    group.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCoverFallback extends StatelessWidget {
  const _GroupCoverFallback({required this.size, required this.icon});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Icon(icon, size: size * 0.38),
    );
  }
}

class _LocalSongGroup {
  const _LocalSongGroup({
    required this.title,
    required this.subtitle,
    required this.songs,
    required this.icon,
    this.coverBytes,
  });

  final String title;
  final String subtitle;
  final List<LocalSong> songs;
  final IconData icon;
  final Uint8List? coverBytes;
}

List<_LocalSongGroup> _groupSongsByArtist(
  List<LocalSong> songs,
  String localeCode,
) {
  final grouped = <String, List<LocalSong>>{};
  for (final song in songs) {
    final key = song.artist.trim().isEmpty
        ? AppI18n.tByLocaleCode(localeCode, 'local.unknown_artist')
        : song.artist.trim();
    grouped.putIfAbsent(key, () => <LocalSong>[]).add(song);
  }
  final result = grouped.entries
      .map((entry) {
        final groupSongs = entry.value.toList(growable: false);
        final albumCount = groupSongs
            .map((song) => song.album.trim())
            .where((album) => album.isNotEmpty)
            .toSet()
            .length;
        return _LocalSongGroup(
          title: entry.key,
          subtitle: AppI18n.formatByLocaleCode(
            localeCode,
            'local.group.artist_subtitle',
            <String, String>{
              'songs': '${groupSongs.length}',
              'albums': '$albumCount',
            },
          ),
          songs: groupSongs,
          icon: Icons.person_rounded,
          coverBytes: groupSongs
              .firstWhere(
                (song) => song.artworkBytes != null,
                orElse: () => groupSongs.first,
              )
              .artworkBytes,
        );
      })
      .toList(growable: false);
  result.sort((a, b) => b.songs.length.compareTo(a.songs.length));
  return result;
}

List<_LocalSongGroup> _groupSongsByAlbum(
  List<LocalSong> songs,
  String localeCode,
) {
  final grouped = <String, List<LocalSong>>{};
  for (final song in songs) {
    final key = song.album.trim().isEmpty
        ? AppI18n.tByLocaleCode(localeCode, 'local.unknown_album')
        : song.album.trim();
    grouped.putIfAbsent(key, () => <LocalSong>[]).add(song);
  }
  final result = grouped.entries
      .map((entry) {
        final groupSongs = entry.value.toList(growable: false)
          ..sort((a, b) => a.title.compareTo(b.title));
        final artistNames = groupSongs
            .map((song) => song.artist.trim())
            .where((artist) => artist.isNotEmpty)
            .toSet()
            .toList(growable: false);
        return _LocalSongGroup(
          title: entry.key,
          subtitle: AppI18n.formatByLocaleCode(
            localeCode,
            'local.group.album_subtitle',
            <String, String>{
              'songs': '${groupSongs.length}',
              'artists':
                  '${artistNames.take(2).join(' / ')}${artistNames.length > 2 ? '…' : ''}',
            },
          ),
          songs: groupSongs,
          icon: Icons.album_rounded,
          coverBytes: groupSongs
              .firstWhere(
                (song) => song.artworkBytes != null,
                orElse: () => groupSongs.first,
              )
              .artworkBytes,
        );
      })
      .toList(growable: false);
  result.sort((a, b) => b.songs.length.compareTo(a.songs.length));
  return result;
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onScan, required this.localeCode});

  final Future<void> Function() onScan;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.library_music_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              AppI18n.tByLocaleCode(localeCode, 'local.empty'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(AppI18n.tByLocaleCode(localeCode, 'local.scan')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.localeCode,
    required this.onRetry,
  });

  final String message;
  final String localeCode;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppI18n.tByLocaleCode(localeCode, 'local.rescan')),
            ),
          ],
        ),
      ),
    );
  }
}
