import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/online_platform_tabs.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../online/presentation/widgets/search_artist_list_item.dart';
import '../../domain/entities/artist_plaza_state.dart';
import '../providers/artist_plaza_providers.dart';

class ArtistPlazaPage extends ConsumerStatefulWidget {
  const ArtistPlazaPage({this.initialPlatform, super.key});

  final String? initialPlatform;

  @override
  ConsumerState<ArtistPlazaPage> createState() => _ArtistPlazaPageState();
}

class _ArtistPlazaPageState extends ConsumerState<ArtistPlazaPage> {
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
    final state = ref.watch(artistPlazaControllerProvider);
    final config = ref.watch(appConfigProvider);

    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            tooltip: AppI18n.t(config, 'common.back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(AppI18n.t(config, 'artist.plaza.title')),
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
                    requiredFeatureFlag:
                        PlatformFeatureSupportFlag.searchSinger,
                    onSelected: (id) => ref
                        .read(artistPlazaControllerProvider.notifier)
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
                      label: AppI18n.t(config, 'artist.plaza.empty'),
                    );
                  }
                  return _ArtistPlazaBody(
                    localeCode: config.localeCode,
                    scrollController: _scrollController,
                    state: state,
                    onRetry: () => ref
                        .read(artistPlazaControllerProvider.notifier)
                        .retry(),
                    onSelectFilter: (groupId, value) => ref
                        .read(artistPlazaControllerProvider.notifier)
                        .selectFilter(groupId: groupId, value: value),
                    onLoadMoreRetry: () => ref
                        .read(artistPlazaControllerProvider.notifier)
                        .loadMore(),
                  );
                },
                loading: () => const _ArtistPlazaLoadingView(),
                error: (error, _) => _ErrorView(
                  message: '$error',
                  onRetry: () =>
                      ref.read(onlinePlatformsProvider.notifier).refresh(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<OnlinePlatform> _supportedPlatforms(List<OnlinePlatform> platforms) {
    return platforms
        .where(
          (platform) =>
              platform.available &&
              platform.supports(PlatformFeatureSupportFlag.searchSinger),
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
          .read(artistPlazaControllerProvider.notifier)
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
    ref.read(artistPlazaControllerProvider.notifier).loadMore();
  }
}

class _ArtistPlazaBody extends StatelessWidget {
  const _ArtistPlazaBody({
    required this.localeCode,
    required this.scrollController,
    required this.state,
    required this.onRetry,
    required this.onSelectFilter,
    required this.onLoadMoreRetry,
  });

  final String localeCode;
  final ScrollController scrollController;
  final ArtistPlazaState state;
  final VoidCallback onRetry;
  final void Function(String groupId, String value) onSelectFilter;
  final VoidCallback onLoadMoreRetry;

  @override
  Widget build(BuildContext context) {
    if (state.filtersLoading && state.filterGroups.isEmpty) {
      return const _ArtistPlazaLoadingView();
    }
    if (state.filtersErrorMessage != null && state.filterGroups.isEmpty) {
      return _ErrorView(message: state.filtersErrorMessage!, onRetry: onRetry);
    }
    return Column(
      children: <Widget>[
        _ArtistFiltersPanel(
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
    if (state.artistsLoading && state.artists.isEmpty) {
      return const PlazaArtistListSkeleton();
    }
    if (state.artistsErrorMessage != null && state.artists.isEmpty) {
      return _ErrorView(message: state.artistsErrorMessage!, onRetry: onRetry);
    }
    if (state.artists.isEmpty) {
      return const _EmptyState(label: '当前筛选下暂无歌手');
    }
    final showTail = state.loadingMore || state.artistsErrorMessage != null;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      itemCount: state.artists.length + (showTail ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.artists.length) {
          if (state.loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _LoadMoreRetryCard(
            message: state.artistsErrorMessage,
            onRetry: onLoadMoreRetry,
          );
        }
        final artist = state.artists[index];
        return SearchArtistListItem(
          localeCode: localeCode,
          title: artist.name,
          coverUrl: artist.cover,
          songCount: artist.songCount,
          albumCount: artist.albumCount,
          videoCount: artist.mvCount,
          onTap: () => context.push(
            Uri(
              path: AppRoutes.artistDetail,
              queryParameters: <String, String>{
                'id': artist.id,
                'platform': artist.platform,
                'title': artist.name,
              },
            ).toString(),
          ),
        );
      },
    );
  }
}

class _ArtistFiltersPanel extends StatelessWidget {
  const _ArtistFiltersPanel({
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
                  child: _ArtistFilterRow(
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

class _ArtistFilterRow extends StatelessWidget {
  const _ArtistFilterRow({
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

class _ArtistPlazaLoadingView extends StatelessWidget {
  const _ArtistPlazaLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        PlazaFilterPanelSkeleton(rowCount: 2),
        Divider(height: 1, indent: 12, endIndent: 12),
        Expanded(child: PlazaArtistListSkeleton()),
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
