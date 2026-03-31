import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/widgets/online_platform_tabs.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../../shared/widgets/video_list_card.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../player/presentation/widgets/mini_player_bar.dart';
import '../../domain/entities/video_plaza_state.dart';
import '../providers/video_plaza_providers.dart';

class VideoPlazaPage extends ConsumerStatefulWidget {
  const VideoPlazaPage({this.initialPlatform, super.key});

  final String? initialPlatform;

  @override
  ConsumerState<VideoPlazaPage> createState() => _VideoPlazaPageState();
}

class _VideoPlazaPageState extends ConsumerState<VideoPlazaPage> {
  late final ScrollController _scrollController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformsAsync = ref.watch(onlinePlatformsProvider);
    final state = ref.watch(videoPlazaControllerProvider);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: AppI18n.t(config, 'common.back'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(AppI18n.t(config, 'video.plaza.title')),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: platformsAsync.when(
              data: (platforms) {
                final supportedPlatforms = _supportedPlatforms(platforms);
                _initializeIfNeeded(supportedPlatforms);
                return OnlinePlatformTabs(
                  platforms: supportedPlatforms,
                  selectedId: state.selectedPlatformId,
                  requiredFeatureFlag: PlatformFeatureSupportFlag.getMvInfo,
                  onSelected: (id) => ref
                      .read(videoPlazaControllerProvider.notifier)
                      .selectPlatform(id),
                );
              },
              loading: () => const PlazaPlatformTabsSkeleton(),
              error: (error, _) => _PlatformsErrorView(
                onRetry: () =>
                    ref.read(onlinePlatformsProvider.notifier).refresh(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: platformsAsync.when(
              data: (platforms) {
                final supportedPlatforms = _supportedPlatforms(platforms);
                if (supportedPlatforms.isEmpty) {
                  return _EmptyState(
                    label: AppI18n.t(config, 'video.plaza.empty'),
                  );
                }
                return _VideoPlazaBody(
                  scrollController: _scrollController,
                  state: state,
                  onRetry: () =>
                      ref.read(videoPlazaControllerProvider.notifier).retry(),
                  onSelectFilter: (groupId, value) => ref
                      .read(videoPlazaControllerProvider.notifier)
                      .selectFilter(groupId: groupId, value: value),
                  onLoadMoreRetry: () => ref
                      .read(videoPlazaControllerProvider.notifier)
                      .loadMore(),
                );
              },
              loading: () => const _VideoPlazaLoadingView(),
              error: (error, _) => _ErrorView(
                message: '$error',
                onRetry: () =>
                    ref.read(onlinePlatformsProvider.notifier).refresh(),
              ),
            ),
          ),
          MiniPlayerBar(onOpenFullPlayer: () => context.push(AppRoutes.player)),
        ],
      ),
    );
  }

  List<OnlinePlatform> _supportedPlatforms(List<OnlinePlatform> platforms) {
    return platforms
        .where(
          (platform) =>
              platform.available &&
              platform.supports(PlatformFeatureSupportFlag.getMvInfo) &&
              platform.supports(PlatformFeatureSupportFlag.getMvUrl) &&
              platform.supports(PlatformFeatureSupportFlag.listMvFilters) &&
              platform.supports(PlatformFeatureSupportFlag.listFilterMvs),
        )
        .toList(growable: false);
  }

  void _initializeIfNeeded(List<OnlinePlatform> platforms) {
    if (_initialized || platforms.isEmpty) {
      return;
    }
    _initialized = true;
    final initialPlatformId = _resolveInitialPlatform(platforms);
    if (initialPlatformId == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(videoPlazaControllerProvider.notifier)
          .initialize(initialPlatformId);
    });
  }

  String? _resolveInitialPlatform(List<OnlinePlatform> platforms) {
    final preferred = widget.initialPlatform?.trim() ?? '';
    if (preferred.isNotEmpty) {
      for (final platform in platforms) {
        if (platform.id == preferred) {
          return preferred;
        }
      }
    }
    if (platforms.isEmpty) {
      return null;
    }
    return platforms.first.id;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 240) {
      return;
    }
    ref.read(videoPlazaControllerProvider.notifier).loadMore();
  }
}

class _VideoPlazaBody extends StatelessWidget {
  const _VideoPlazaBody({
    required this.scrollController,
    required this.state,
    required this.onRetry,
    required this.onSelectFilter,
    required this.onLoadMoreRetry,
  });

  final ScrollController scrollController;
  final VideoPlazaState state;
  final VoidCallback onRetry;
  final void Function(String groupId, String value) onSelectFilter;
  final VoidCallback onLoadMoreRetry;

  @override
  Widget build(BuildContext context) {
    if (state.filtersLoading && state.filterGroups.isEmpty) {
      return const _VideoPlazaLoadingView();
    }
    if (state.filtersErrorMessage != null && state.filterGroups.isEmpty) {
      return _ErrorView(message: state.filtersErrorMessage!, onRetry: onRetry);
    }
    return Column(
      children: <Widget>[
        _VideoFiltersPanel(
          filterGroups: state.filterGroups,
          selectedFilters: state.selectedFilters,
          onSelectFilter: onSelectFilter,
        ),
        const Divider(height: 1, indent: 12, endIndent: 12),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (state.videosLoading && state.videos.isEmpty) {
      return const PlazaVideoListSkeleton();
    }
    if (state.videosErrorMessage != null && state.videos.isEmpty) {
      return _ErrorView(message: state.videosErrorMessage!, onRetry: onRetry);
    }
    if (state.videos.isEmpty) {
      return const _EmptyState(label: '当前筛选下暂无视频');
    }
    final showTail = state.loadingMore || state.videosErrorMessage != null;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      itemCount: state.videos.length + (showTail ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.videos.length) {
          if (state.loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _LoadMoreRetryCard(
            message: state.videosErrorMessage,
            onRetry: onLoadMoreRetry,
          );
        }
        final video = state.videos[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: VideoListCard(
            title: video.name,
            creator: video.creator,
            duration: '${video.duration}',
            coverUrl: video.cover,
            playCount: video.playCount,
            onTap: () => context.push(
              Uri(
                path: AppRoutes.videoDetail,
                queryParameters: <String, String>{
                  'id': video.id,
                  'platform': video.platform,
                  'title': video.name,
                },
              ).toString(),
            ),
          ),
        );
      },
    );
  }
}

class _VideoFiltersPanel extends StatelessWidget {
  const _VideoFiltersPanel({
    required this.filterGroups,
    required this.selectedFilters,
    required this.onSelectFilter,
  });

  final List<FilterInfo> filterGroups;
  final Map<String, String> selectedFilters;
  final void Function(String groupId, String value) onSelectFilter;

  @override
  Widget build(BuildContext context) {
    if (filterGroups.isEmpty) {
      return const SizedBox.shrink();
    }
    final visibleGroups = filterGroups
        .where((group) => group.options.isNotEmpty)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: visibleGroups
              .asMap()
              .entries
              .map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == visibleGroups.length - 1 ? 0 : 6,
                  ),
                  child: _VideoFilterRow(
                    group: entry.value,
                    selectedValue: selectedFilters[entry.value.id],
                    onSelect: (value) => onSelectFilter(entry.value.id, value),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _VideoFilterRow extends StatelessWidget {
  const _VideoFilterRow({
    required this.group,
    required this.selectedValue,
    required this.onSelect,
  });

  final FilterInfo group;
  final String? selectedValue;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: group.options
              .map((option) {
                final selected = option.value == selectedValue;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(option.label),
                    showCheckmark: false,
                    selected: selected,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selectedColor: colorScheme.primary.withValues(alpha: 0.10),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    side: BorderSide(
                      width: 0.9,
                      color: selected
                          ? colorScheme.primary.withValues(alpha: 0.30)
                          : colorScheme.outlineVariant,
                    ),
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 0,
                    ),
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -3,
                    ),
                    onSelected: (_) => onSelect(option.value),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _VideoPlazaLoadingView extends StatelessWidget {
  const _VideoPlazaLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        PlazaFilterPanelSkeleton(rowCount: 2),
        Divider(height: 1, indent: 12, endIndent: 12),
        Expanded(child: PlazaVideoListSkeleton()),
      ],
    );
  }
}

class _PlatformsErrorView extends StatelessWidget {
  const _PlatformsErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '平台加载失败',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreRetryCard extends StatelessWidget {
  const _LoadMoreRetryCard({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: <Widget>[
          Text(
            message?.trim().isNotEmpty == true ? message!.trim() : '加载失败',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
