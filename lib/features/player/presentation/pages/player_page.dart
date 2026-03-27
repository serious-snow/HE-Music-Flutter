import 'dart:ui';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/helpers/album_id_helper.dart';
import '../../../../shared/helpers/platform_label_helper.dart';
import '../../../../shared/helpers/song_artist_navigation_helper.dart';
import '../../../download/presentation/providers/download_providers.dart';
import '../../../lyrics/domain/entities/lyric_document.dart';
import '../../../lyrics/domain/entities/lyric_line.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';
import '../../../lyrics/presentation/widgets/lyric_panel.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/player_quality_option.dart';
import '../controllers/player_controller.dart';
import '../providers/player_providers.dart';
import '../widgets/player_control_bar.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/player_queue_sheet.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  static const _pageCount = 2;
  late final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(playerControllerProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      playerControllerProvider.select((state) => state.errorMessage),
      (previous, next) {
        final message = next?.trim() ?? '';
        if (message.isEmpty || message == previous?.trim()) {
          return;
        }
        AppMessageService.showError(message);
      },
    );
    final config = ref.watch(appConfigProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _PlayerBackdrop(
              artworkUrl: track?.artworkUrl,
              artworkBytes: track?.artworkBytes,
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: Column(
                  children: <Widget>[
                    _PlayerTopBar(
                      currentPage: _currentPage,
                      total: _pageCount,
                      onTapDot: _animateToPage,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          if (_currentPage == index) {
                            return;
                          }
                          setState(() => _currentPage = index);
                        },
                        children: <Widget>[
                          _PlayerMetaControlPage(
                            noTrackText: AppI18n.t(config, 'player.noTrack'),
                            controller: controller,
                            onOpenQueue: _openQueueSheet,
                            onOpenMore: _openMoreSheet,
                            onOpenLyrics: () => _animateToPage(1),
                            onOpenQuality: () {
                              final currentAvailableQualities = ref.read(
                                playerControllerProvider.select(
                                  (s) => s.currentAvailableQualities,
                                ),
                              );
                              final currentSelectedQuality = ref.read(
                                playerControllerProvider.select(
                                  (s) => s.currentSelectedQualityName,
                                ),
                              );
                              if (currentAvailableQualities.isEmpty) {
                                return;
                              }
                              _openQualitySheet(
                                context,
                                controller,
                                currentAvailableQualities,
                                currentSelectedQuality,
                              );
                            },
                            onOpenSpeed: () {
                              final speed = ref.read(
                                playerControllerProvider.select((s) => s.speed),
                              );
                              _openSpeedSheet(context, controller, speed);
                            },
                          ),
                          _PlayerLyricPage(
                            emptyText: AppI18n.t(config, 'player.lyrics.empty'),
                            onSeek: (position) {
                              controller.seek(position);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _animateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _openQueueSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const PlayerQueueSheet(),
    );
  }

  void _openMoreSheet() {
    final rootContext = context;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final controller = ref.read(playerControllerProvider.notifier);
          final track = ref.watch(
            playerControllerProvider.select((s) => s.currentTrack),
          );
          final speed = ref.watch(
            playerControllerProvider.select((s) => s.speed),
          );
          final volume = ref.watch(
            playerControllerProvider.select((s) => s.volume),
          );
          final currentAvailableQualities = ref.watch(
            playerControllerProvider.select((s) => s.currentAvailableQualities),
          );
          final currentSelectedQuality = ref.watch(
            playerControllerProvider.select(
              (s) => s.currentSelectedQualityName,
            ),
          );
          final currentSelectedQualityOption = _findQualityOptionByName(
            currentAvailableQualities,
            currentSelectedQuality,
          );
          final onlinePlatformId = (track?.platform ?? '').trim();
          final canOnline =
              onlinePlatformId.isNotEmpty && onlinePlatformId != 'local';
          final searchPlatformId = _resolveSearchPlatformId(
            ref,
            preferredPlatformId: canOnline ? onlinePlatformId : null,
          );
          final canSearchSameName =
              track != null &&
              track.title.trim().isNotEmpty &&
              searchPlatformId != null;
          final canViewAlbum = canOnline && hasValidAlbumId(track?.albumId);
          final canViewArtists =
              canOnline && track != null && track.artists.isNotEmpty;
          final canWatchMv =
              canOnline &&
              ((track?.mvId?.trim().isNotEmpty ?? false) &&
                  (track?.mvId?.trim() != '0'));
          final onlineKeyword = track?.title.trim() ?? '';
          final onlineId = track?.id ?? '';
          final onlineTitle = track?.title.trim() ?? '';
          final config = ref.read(appConfigProvider);
          final platforms = ref.read(onlinePlatformsProvider).valueOrNull;
          final sourcePlatformLabel = canOnline
              ? resolvePlatformLabel(
                  onlinePlatformId,
                  platforms: platforms ?? const <OnlinePlatform>[],
                )
              : 'LOCAL';

          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              children: <Widget>[
                if (track != null)
                  _PlayerSheetHero(
                    coverUrl: track.artworkUrl,
                    title: track.title,
                    subtitle: (track.artist ?? '-').trim().isEmpty
                        ? '-'
                        : (track.artist ?? '-'),
                  ),
                _PlayerSheetActionTile(
                  icon: Icons.speed_rounded,
                  title: AppI18n.t(config, 'player.action.speed'),
                  subtitle: '${speed.toStringAsFixed(2)}x',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openSpeedSheet(rootContext, controller, speed);
                  },
                ),
                _PlayerSheetActionTile(
                  icon: Icons.volume_up_rounded,
                  title: AppI18n.t(config, 'player.action.volume'),
                  subtitle: '${(volume * 100).round()}%',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openVolumeSheet(rootContext, controller, volume);
                  },
                ),
                _PlayerSheetActionTile(
                  icon: Icons.search_rounded,
                  title: AppI18n.t(config, 'player.action.search_same'),
                  enabled: canSearchSameName,
                  onTap: canSearchSameName
                      ? () {
                          Navigator.of(sheetContext).pop();
                          rootContext.push(
                            Uri(
                              path: AppRoutes.onlineSearch,
                              queryParameters: <String, String>{
                                'platform': searchPlatformId,
                                'keyword': onlineKeyword,
                              },
                            ).toString(),
                          );
                        }
                      : null,
                ),
                _PlayerSheetActionTile(
                  icon: Icons.high_quality_rounded,
                  title: AppI18n.t(config, 'player.action.quality'),
                  subtitle: currentSelectedQualityOption?.name,
                  enabled: canOnline && currentAvailableQualities.isNotEmpty,
                  onTap: canOnline && currentAvailableQualities.isNotEmpty
                      ? () {
                          Navigator.of(sheetContext).pop();
                          _openQualitySheet(
                            rootContext,
                            controller,
                            currentAvailableQualities,
                            currentSelectedQuality,
                          );
                        }
                      : null,
                ),
                if (canOnline)
                  _PlayerSheetActionTile(
                    icon: Icons.album_outlined,
                    title: AppI18n.t(config, 'player.action.view_album'),
                    subtitle: track?.album?.trim() ?? '',
                    enabled: canViewAlbum,
                    onTap: canViewAlbum
                        ? () {
                            Navigator.of(sheetContext).pop();
                            rootContext.push(
                              Uri(
                                path: AppRoutes.albumDetail,
                                queryParameters: <String, String>{
                                  'id': track!.albumId!.trim(),
                                  'platform': onlinePlatformId,
                                  if ((track.album ?? '').trim().isNotEmpty)
                                    'title': track.album!.trim(),
                                },
                              ).toString(),
                            );
                          }
                        : null,
                  ),
                if (canOnline)
                  _PlayerSheetActionTile(
                    icon: Icons.person_outline_rounded,
                    title: canViewArtists && track.artists.length > 1
                        ? AppI18n.format(
                            config,
                            'player.action.view_artists_count',
                            <String, String>{
                              'count': '${track.artists.length}',
                            },
                          )
                        : AppI18n.t(config, 'player.action.view_artists'),
                    subtitle: track?.artist ?? '',
                    enabled: canViewArtists,
                    onTap: canViewArtists
                        ? () {
                            Navigator.of(sheetContext).pop();
                            openSongArtistSelection(
                              context: rootContext,
                              platformId: onlinePlatformId,
                              artists: track.artists,
                              onError: _showMessage,
                            );
                          }
                        : null,
                  ),
                if (canOnline)
                  _PlayerSheetActionTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: AppI18n.t(config, 'player.action.comments'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      rootContext.push(
                        Uri(
                          path: AppRoutes.onlineComments,
                          queryParameters: <String, String>{
                            'id': onlineId,
                            'platform': onlinePlatformId,
                            'resource_type': 'song',
                            if (onlineTitle.isNotEmpty) 'title': onlineTitle,
                          },
                        ).toString(),
                      );
                    },
                  ),
                if (canOnline)
                  _PlayerSheetActionTile(
                    icon: Icons.share_rounded,
                    title: AppI18n.t(config, 'player.action.copy_share'),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              'https://y.wjhe.top/song/$onlinePlatformId/${track!.id}',
                        ),
                      );
                      if (!mounted) return;
                      _showMessage(AppI18n.t(config, 'player.copy.share_done'));
                    },
                  ),
                if (canOnline)
                  _PlayerSheetActionTile(
                    icon: Icons.ondemand_video_rounded,
                    title: AppI18n.t(config, 'player.action.watch_mv'),
                    enabled: canWatchMv,
                    onTap: canWatchMv
                        ? () {
                            Navigator.of(sheetContext).pop();
                            rootContext.push(
                              Uri(
                                path: AppRoutes.videoDetail,
                                queryParameters: <String, String>{
                                  'id': track!.mvId!.trim(),
                                  'platform': onlinePlatformId,
                                  if (onlineTitle.isNotEmpty)
                                    'title': onlineTitle,
                                },
                              ).toString(),
                            );
                          }
                        : null,
                  ),
                if (canOnline)
                  _PlayerSheetActionTile(
                    icon: Icons.download_rounded,
                    title: AppI18n.t(config, 'player.action.download'),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        final url = await ref
                            .read(onlineControllerProvider.notifier)
                            .fetchSongUrl(
                              songId: track!.id,
                              platform: onlinePlatformId,
                            );
                        await ref
                            .read(downloadControllerProvider.notifier)
                            .enqueue(title: track.title, url: url);
                        if (!mounted) return;
                        _showMessage(
                          AppI18n.format(
                            config,
                            'player.download.added',
                            <String, String>{'title': track.title},
                          ),
                        );
                      } catch (_) {
                        if (!mounted) return;
                        _showMessage(
                          AppI18n.t(config, 'player.download.failed'),
                        );
                      }
                    },
                  ),
                _PlayerSheetActionTile(
                  icon: Icons.copy_rounded,
                  title: AppI18n.t(config, 'player.action.copy_name'),
                  enabled: track != null && track.title.trim().isNotEmpty,
                  onTap: track == null || track.title.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          await Clipboard.setData(
                            ClipboardData(text: track.title),
                          );
                          if (!mounted) return;
                          _showMessage(
                            AppI18n.t(config, 'player.copy.name_done'),
                          );
                        },
                ),
                _PlayerSheetActionTile(
                  icon: Icons.copy_rounded,
                  title: AppI18n.t(config, 'player.action.copy_id'),
                  enabled: track != null && track.id.trim().isNotEmpty,
                  onTap: track == null || track.id.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          await Clipboard.setData(
                            ClipboardData(text: track.id),
                          );
                          if (!mounted) return;
                          _showMessage(
                            AppI18n.t(config, 'player.copy.id_done'),
                          );
                        },
                ),
                _PlayerSourceInfoRow(
                  label: AppI18n.format(config, 'song.source', <String, String>{
                    'platform': sourcePlatformLabel,
                  }),
                ),
                const SizedBox(height: 4),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openSpeedSheet(
    BuildContext context,
    PlayerController controller,
    double current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        var value = current.clamp(0.5, 2.0);
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            AppI18n.t(
                              ref.read(appConfigProvider),
                              'player.action.speed',
                            ),
                          ),
                        ),
                        Text('${value.toStringAsFixed(2)}x'),
                      ],
                    ),
                    Slider(
                      value: value,
                      min: 0.5,
                      max: 2.0,
                      divisions: 30,
                      label: '${value.toStringAsFixed(2)}x',
                      onChanged: (next) {
                        setState(() => value = next);
                      },
                      onChangeEnd: (next) {
                        controller.setSpeed(next);
                      },
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: () {
                        controller.setSpeed(1.0);
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        AppI18n.t(
                          ref.read(appConfigProvider),
                          'player.reset.speed',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openVolumeSheet(
    BuildContext context,
    PlayerController controller,
    double current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        var value = current.clamp(0.0, 1.0);
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            AppI18n.t(
                              ref.read(appConfigProvider),
                              'player.action.volume',
                            ),
                          ),
                        ),
                        Text('${(value * 100).round()}%'),
                      ],
                    ),
                    Slider(
                      value: value,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: '${(value * 100).round()}%',
                      onChanged: (next) {
                        setState(() => value = next);
                      },
                      onChangeEnd: (next) {
                        controller.setVolume(next);
                      },
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: () {
                        controller.setVolume(1.0);
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        AppI18n.t(
                          ref.read(appConfigProvider),
                          'player.reset.volume',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openQualitySheet(
    BuildContext context,
    PlayerController controller,
    List<PlayerQualityOption> availableQualities,
    String? current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final quality in availableQualities)
                ListTile(
                  leading: const Icon(Icons.graphic_eq_rounded),
                  title: Text(quality.name),
                  subtitle: _buildQualitySubtitle(quality),
                  trailing: current == quality.name
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.switchCurrentQualityByName(quality.name);
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _resolveSearchPlatformId(
    WidgetRef ref, {
    String? preferredPlatformId,
  }) {
    final preferred = preferredPlatformId?.trim() ?? '';
    if (preferred.isNotEmpty && preferred != 'local') {
      return preferred;
    }
    final platforms = ref.read(onlinePlatformsProvider).valueOrNull;
    if (platforms == null || platforms.isEmpty) {
      return null;
    }
    for (final platform in platforms) {
      if (platform.available) {
        return platform.id;
      }
    }
    return null;
  }

  PlayerQualityOption? _findQualityOptionByName(
    List<PlayerQualityOption> options,
    String? name,
  ) {
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    for (final option in options) {
      if (option.name == name) {
        return option;
      }
    }
    return null;
  }

  Widget? _buildQualitySubtitle(PlayerQualityOption quality) {
    final parts = <String>[
      if ((quality.description ?? '').trim().isNotEmpty)
        quality.description!.trim(),
      if (quality.sizeLabel.isNotEmpty) quality.sizeLabel,
    ];
    if (parts.isEmpty) {
      return null;
    }
    return Text(parts.join(' · '));
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.currentPage,
    required this.total,
    required this.onTapDot,
  });

  final int currentPage;
  final int total;
  final ValueChanged<int> onTapDot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: Navigator.of(context).pop,
              style: IconButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(total, (index) {
              final active = index == currentPage;
              return GestureDetector(
                onTap: () => onTapDot(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: active ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PlayerInfoPage extends ConsumerWidget {
  const _PlayerInfoPage({
    required this.noTrackText,
    required this.onOpenLyrics,
    required this.onOpenQuality,
    required this.onOpenSpeed,
  });

  final String noTrackText;
  final VoidCallback onOpenLyrics;
  final VoidCallback onOpenQuality;
  final VoidCallback onOpenSpeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final currentAvailableQualities = ref.watch(
      playerControllerProvider.select(
        (state) => state.currentAvailableQualities,
      ),
    );
    final currentSelectedQualityName = ref.watch(
      playerControllerProvider.select(
        (state) => state.currentSelectedQualityName,
      ),
    );
    final speed = ref.watch(
      playerControllerProvider.select((state) => state.speed),
    );
    final currentQuality = _findQualityByName(
      currentAvailableQualities,
      currentSelectedQualityName,
    );
    final title = track?.title ?? noTrackText;
    final artist = _fallbackText(track?.artist);
    final album = _fallbackText(track?.album);
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = math
            .min(constraints.maxWidth * 0.72, constraints.maxHeight * 0.40)
            .clamp(190.0, 320.0);
        final topSpacing = (constraints.maxHeight * 0.01).clamp(4.0, 10.0);
        final coverBottomSpacing = (constraints.maxHeight * 0.035).clamp(
          14.0,
          24.0,
        );
        final lyricBottomSpacing = (constraints.maxHeight * 0.012).clamp(
          4.0,
          8.0,
        );
        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            children: <Widget>[
              SizedBox(height: topSpacing),
              _PlayerCoverHero(
                artworkUrl: track?.artworkUrl,
                artworkBytes: track?.artworkBytes,
                size: coverSize,
              ),
              SizedBox(height: coverBottomSpacing),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Colors.white,
                  ),
                ),
              ),
              if (currentQuality != null) ...<Widget>[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _PlayerMiniBadge(
                        label: currentQuality.name,
                        onTap: onOpenQuality,
                      ),
                      _PlayerMiniBadge(
                        label: '${speed.toStringAsFixed(speed == 1 ? 0 : 2)}x',
                        onTap: onOpenSpeed,
                      ),
                    ],
                  ),
                ),
              ],
              if (currentQuality == null) ...<Widget>[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _PlayerMiniBadge(
                    label: '${speed.toStringAsFixed(speed == 1 ? 0 : 2)}x',
                    onTap: onOpenSpeed,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _PlayerMetaLine(value: artist),
              const SizedBox(height: 8),
              _PlayerMetaLine(value: album),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: _PlayerCompactLyricSection(onTap: onOpenLyrics),
              ),
              SizedBox(height: lyricBottomSpacing),
            ],
          ),
        );
      },
    );
  }

  String _fallbackText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }
    return value;
  }

  PlayerQualityOption? _findQualityByName(
    List<PlayerQualityOption> options,
    String? name,
  ) {
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    for (final option in options) {
      if (option.name == name) {
        return option;
      }
    }
    return null;
  }
}

class _PlayerStageCard extends StatelessWidget {
  const _PlayerStageCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: child,
    );
  }
}

class _PlayerMiniBadge extends StatelessWidget {
  const _PlayerMiniBadge({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 0.7,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
              fontSize: 10,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerMetaControlPage extends StatelessWidget {
  const _PlayerMetaControlPage({
    required this.noTrackText,
    required this.controller,
    required this.onOpenQueue,
    required this.onOpenMore,
    required this.onOpenLyrics,
    required this.onOpenQuality,
    required this.onOpenSpeed,
  });

  final String noTrackText;
  final PlayerController controller;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenMore;
  final VoidCallback onOpenLyrics;
  final VoidCallback onOpenQuality;
  final VoidCallback onOpenSpeed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: _PlayerInfoPage(
            noTrackText: noTrackText,
            onOpenLyrics: onOpenLyrics,
            onOpenQuality: onOpenQuality,
            onOpenSpeed: onOpenSpeed,
          ),
        ),
        const SizedBox(height: 8),
        _PlayerStageCard(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Spacer(),
                  _PlayerUtilityRow(onOpenMore: onOpenMore),
                ],
              ),
              const SizedBox(height: 10),
              _PlayerProgressSection(onSeek: controller.seek),
              const SizedBox(height: 18),
              _PlayerControlSection(
                controller: controller,
                onOpenQueue: onOpenQueue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerCoverHero extends StatelessWidget {
  const _PlayerCoverHero({
    required this.artworkUrl,
    required this.artworkBytes,
    required this.size,
  });

  final String? artworkUrl;
  final Uint8List? artworkBytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageProvider = _artworkProvider(artworkUrl, artworkBytes);
    final glowColor = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.16);
    return SizedBox(
      width: size + 56,
      height: size + 56,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  glowColor,
                  glowColor.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, 6),
            child: Opacity(
              opacity: 0.18,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: imageProvider == null
                    ? Container(
                        width: size * 0.88,
                        height: size * 0.88,
                        color: glowColor,
                      )
                    : Image(
                        image: imageProvider,
                        width: size * 0.88,
                        height: size * 0.88,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: size * 0.88,
                          height: size * 0.88,
                          color: glowColor,
                        ),
                      ),
              ),
            ),
          ),
          _PlayerCover(
            artworkUrl: artworkUrl,
            artworkBytes: artworkBytes,
            size: size,
          ),
        ],
      ),
    );
  }
}

class _PlayerLyricPage extends StatelessWidget {
  const _PlayerLyricPage({required this.emptyText, required this.onSeek});

  final String emptyText;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: LyricPanel(emptyText: emptyText, onSeek: onSeek),
    );
  }
}

class _PlayerUtilityRow extends StatelessWidget {
  const _PlayerUtilityRow({required this.onOpenMore});

  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PlayerUtilityButton(
          icon: Icons.more_horiz_rounded,
          color: Colors.white.withValues(alpha: 0.82),
          onTap: onOpenMore,
        ),
      ],
    );
  }
}

class _PlayerProgressSection extends ConsumerWidget {
  const _PlayerProgressSection({required this.onSeek});

  final Future<void> Function(Duration) onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(
      playerControllerProvider.select((state) => state.position),
    );
    final duration = ref.watch(
      playerControllerProvider.select((state) => state.duration),
    );
    return PlayerProgressBar(
      position: position,
      duration: duration,
      onSeek: onSeek,
    );
  }
}

class _PlayerCompactLyricSection extends ConsumerWidget {
  const _PlayerCompactLyricSection({required this.onTap});

  static const double _compactLyricHeight = 40;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack != null),
    );
    if (!hasTrack) {
      return const SizedBox(height: _compactLyricHeight);
    }
    final position = ref.watch(lyricPositionProvider);
    final documentAsync = ref.watch(currentLyricDocumentProvider);
    final text = documentAsync.when(
      data: (document) => _resolveCompactLyricText(document, position),
      loading: () => '',
      error: (_, _) => '',
    );
    final theme = Theme.of(context);
    return SizedBox(
      height: _compactLyricHeight,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  text,
                  key: ValueKey<String>(text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white.withValues(
                      alpha: text.isEmpty ? 0.56 : 0.92,
                    ),
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveCompactLyricText(LyricDocument document, Duration position) {
    if (document.lines.isEmpty) {
      return '';
    }
    final index = _findCurrentLineIndex(document.lines, position);
    if (index < 0 || index >= document.lines.length) {
      return '';
    }
    return document.lines[index].text.trim();
  }

  int _findCurrentLineIndex(List<LyricLine> lines, Duration position) {
    for (var index = lines.length - 1; index >= 0; index--) {
      final line = lines[index];
      if (position < line.start) {
        continue;
      }
      final nextStart = index + 1 < lines.length
          ? lines[index + 1].start
          : null;
      final lineEnd = line.end ?? nextStart;
      if (lineEnd == null || position < lineEnd) {
        return index;
      }
    }
    return -1;
  }
}

class _PlayerControlSection extends ConsumerWidget {
  const _PlayerControlSection({
    required this.controller,
    required this.onOpenQueue,
  });

  final PlayerController controller;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final isPlaying = ref.watch(
      playerControllerProvider.select((state) => state.isPlaying),
    );
    final playMode = ref.watch(
      playerControllerProvider.select((state) => state.playMode),
    );
    return PlayerControlBar(
      config: config,
      isPlaying: isPlaying,
      playMode: playMode,
      onOpenQueue: onOpenQueue,
      onCyclePlayMode: controller.cyclePlayMode,
      onPrevious: controller.playPrevious,
      onPlayPause: controller.togglePlayPause,
      onNext: controller.playNext,
    );
  }
}

class _PlayerSheetHero extends StatelessWidget {
  const _PlayerSheetHero({
    required this.coverUrl,
    required this.title,
    required this.subtitle,
  });

  final String? coverUrl;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: coverUrl == null || coverUrl!.trim().isEmpty
                ? Container(
                    width: 48,
                    height: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.music_note_rounded),
                  )
                : Image.network(
                    coverUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 48,
                      height: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.music_note_rounded),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerSheetActionTile extends StatelessWidget {
  const _PlayerSheetActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, size: 22),
      title: Text(title),
      subtitle: (subtitle ?? '').trim().isEmpty ? null : Text(subtitle!.trim()),
      trailing: enabled ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: enabled ? onTap : null,
    );
  }
}

class _PlayerSourceInfoRow extends StatelessWidget {
  const _PlayerSourceInfoRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      enabled: false,
      minTileHeight: 40,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        Icons.info_outline_rounded,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PlayerCover extends StatelessWidget {
  const _PlayerCover({
    required this.artworkUrl,
    required this.artworkBytes,
    required this.size,
  });

  final String? artworkUrl;
  final Uint8List? artworkBytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageProvider = _artworkProvider(artworkUrl, artworkBytes);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: const Icon(Icons.music_note_rounded, size: 96),
    );
    if (imageProvider == null) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: Image(
        image: imageProvider,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => placeholder,
      ),
    );
  }
}

class _PlayerMetaLine extends StatelessWidget {
  const _PlayerMetaLine({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: 14,
          color: Colors.white.withValues(alpha: 0.7),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _PlayerUtilityButton extends StatelessWidget {
  const _PlayerUtilityButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _PlayerBackdrop extends StatelessWidget {
  const _PlayerBackdrop({required this.artworkUrl, required this.artworkBytes});

  final String? artworkUrl;
  final Uint8List? artworkBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final imageProvider = _artworkProvider(artworkUrl, artworkBytes);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                primary.withValues(alpha: 0.16),
                secondary.withValues(alpha: 0.16),
                const Color(0xFF0E1715),
                theme.colorScheme.surface.withValues(alpha: 0.96),
              ],
            ),
          ),
        ),
        if (imageProvider != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: Transform.scale(
              scale: 1.18,
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.30),
                theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
              ],
              stops: const <double>[0, 0.42, 1],
            ),
          ),
        ),
      ],
    );
  }
}

ImageProvider<Object>? _artworkProvider(
  String? artworkUrl,
  Uint8List? artworkBytes,
) {
  if (artworkBytes != null && artworkBytes.isNotEmpty) {
    return MemoryImage(artworkBytes);
  }
  final value = artworkUrl?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  return CachedNetworkImageProvider(value);
}
