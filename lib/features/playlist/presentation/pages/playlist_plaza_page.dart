import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/layout/adaptive_media_grid_spec.dart';
import '../../../../shared/widgets/media_grid_card.dart';
import '../../../../shared/widgets/online_platform_tabs.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../player/presentation/widgets/mini_player_bar.dart';
import '../../domain/entities/playlist_category_group.dart';
import '../../domain/entities/playlist_plaza_state.dart';
import '../providers/playlist_plaza_providers.dart';

class PlaylistPlazaPage extends ConsumerStatefulWidget {
  const PlaylistPlazaPage({this.initialPlatform, super.key});

  final String? initialPlatform;

  @override
  ConsumerState<PlaylistPlazaPage> createState() => _PlaylistPlazaPageState();
}

class _PlaylistPlazaPageState extends ConsumerState<PlaylistPlazaPage> {
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
    final state = ref.watch(playlistPlazaControllerProvider);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: AppI18n.t(config, 'common.back'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(AppI18n.t(config, 'playlist.plaza.title')),
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
                  requiredFeatureFlag: PlatformFeatureSupportFlag.getTagList,
                  onSelected: (id) => ref
                      .read(playlistPlazaControllerProvider.notifier)
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
                    label: AppI18n.t(config, 'playlist.plaza.empty'),
                  );
                }
                return _PlaylistPlazaBody(
                  scrollController: _scrollController,
                  state: state,
                  onRetry: () => ref
                      .read(playlistPlazaControllerProvider.notifier)
                      .retry(),
                  onLoadMoreRetry: () => ref
                      .read(playlistPlazaControllerProvider.notifier)
                      .loadMore(),
                  onCategorySelected: (id) => ref
                      .read(playlistPlazaControllerProvider.notifier)
                      .selectCategory(id),
                  onShowAllCategories: () => _showAllCategoriesSheet(
                    context,
                    state,
                    supportedPlatforms,
                  ),
                );
              },
              loading: () => const _PlaylistPlazaLoadingView(),
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
              platform.supports(PlatformFeatureSupportFlag.getTagList) &&
              platform.supports(PlatformFeatureSupportFlag.getTagPlaylist),
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
          .read(playlistPlazaControllerProvider.notifier)
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
    ref.read(playlistPlazaControllerProvider.notifier).loadMore();
  }

  Future<void> _showAllCategoriesSheet(
    BuildContext context,
    PlaylistPlazaState state,
    List<OnlinePlatform> platforms,
  ) {
    final selectedPlatformId = state.selectedPlatformId?.trim() ?? '';
    final currentPlatform = platforms
        .where((platform) => platform.id == selectedPlatformId)
        .firstOrNull;
    final totalCategories = state.allCategories.length;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '全部分类',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      if (currentPlatform != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            currentPlatform.name,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (currentPlatform != null) const SizedBox(width: 8),
                      Text(
                        '$totalCategories 个分类',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: state.categoryGroups
                            .map(
                              (group) => _CategoryGroupSection(
                                group: group,
                                selectedCategoryId: state.selectedCategoryId,
                                onSelected: (id) {
                                  Navigator.of(context).pop();
                                  ref
                                      .read(
                                        playlistPlazaControllerProvider
                                            .notifier,
                                      )
                                      .selectCategory(id);
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaylistPlazaBody extends StatelessWidget {
  const _PlaylistPlazaBody({
    required this.scrollController,
    required this.state,
    required this.onRetry,
    required this.onLoadMoreRetry,
    required this.onCategorySelected,
    required this.onShowAllCategories,
  });

  final ScrollController scrollController;
  final PlaylistPlazaState state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMoreRetry;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onShowAllCategories;

  @override
  Widget build(BuildContext context) {
    if (state.categoriesLoading && state.categoryGroups.isEmpty) {
      return const _PlaylistPlazaLoadingView();
    }
    if (state.categoriesErrorMessage != null && state.categoryGroups.isEmpty) {
      return _ErrorView(
        message: state.categoriesErrorMessage!,
        onRetry: onRetry,
      );
    }
    return Column(
      children: <Widget>[
        _CategoryBar(
          categories: state.allCategories,
          selectedCategoryId: state.selectedCategoryId,
          onSelected: onCategorySelected,
          onShowAll: onShowAllCategories,
        ),
        const Divider(height: 1, indent: 12, endIndent: 12),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final showTail = state.loadingMore || state.playlistsErrorMessage != null;
    if (state.playlistsLoading && state.playlists.isEmpty) {
      return const PlazaGridSkeleton();
    }
    if (state.playlistsErrorMessage != null && state.playlists.isEmpty) {
      return _ErrorView(
        message: state.playlistsErrorMessage!,
        onRetry: onRetry,
      );
    }
    if (state.playlists.isEmpty) {
      return const _EmptyState(label: '当前分类下暂无歌单');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = resolveAdaptiveMediaGridSpec(
          maxWidth: constraints.maxWidth,
        );
        return GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          gridDelegate: spec.sliverDelegate,
          itemCount: state.playlists.length + (showTail ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.playlists.length) {
              if (state.loadingMore) {
                return const Center(child: CircularProgressIndicator());
              }
              return _LoadMoreRetryCard(
                message: state.playlistsErrorMessage,
                onRetry: onLoadMoreRetry,
              );
            }
            final playlist = state.playlists[index];
            return MediaGridCard(
              kind: MediaGridCardKind.playlist,
              title: playlist.name,
              subtitle: playlist.creator,
              coverUrl: playlist.cover,
              playCount: playlist.playCount,
              onTap: () => context.push(
                Uri(
                  path: AppRoutes.playlistDetail,
                  queryParameters: <String, String>{
                    'id': playlist.id,
                    'platform': playlist.platform,
                    'title': playlist.name,
                  },
                ).toString(),
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoryBar extends StatefulWidget {
  const _CategoryBar({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
    required this.onShowAll,
  });

  final List<CategoryInfo> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelected;
  final VoidCallback onShowAll;

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _chipKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _ensureSelectedChipVisible();
    });
  }

  @override
  void didUpdateWidget(covariant _CategoryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId ||
        oldWidget.categories != widget.categories) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _ensureSelectedChipVisible();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleCategories = _resolveVisibleCategories(
      categories: widget.categories,
      selectedCategoryId: widget.selectedCategoryId,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: visibleCategories
                    .map(
                      (category) => Padding(
                        key: _keyForCategory(category.id),
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category.name),
                          showCheckmark: false,
                          selectedColor: colorScheme.primary.withValues(
                            alpha: 0.10,
                          ),
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          side: BorderSide(
                            color: category.id == widget.selectedCategoryId
                                ? colorScheme.primary.withValues(alpha: 0.30)
                                : colorScheme.outlineVariant,
                          ),
                          labelStyle: theme.textTheme.labelLarge?.copyWith(
                            color: category.id == widget.selectedCategoryId
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                          visualDensity: VisualDensity.compact,
                          selected: category.id == widget.selectedCategoryId,
                          onSelected: (_) => widget.onSelected(category.id),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: widget.onShowAll,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.apps_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  GlobalKey _keyForCategory(String categoryId) {
    return _chipKeys.putIfAbsent(categoryId, () => GlobalKey());
  }

  void _ensureSelectedChipVisible() {
    final selectedId = widget.selectedCategoryId?.trim() ?? '';
    if (selectedId.isEmpty) {
      return;
    }
    final targetContext = _chipKeys[selectedId]?.currentContext;
    if (targetContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  List<CategoryInfo> _resolveVisibleCategories({
    required List<CategoryInfo> categories,
    required String? selectedCategoryId,
  }) {
    const visibleLimit = 10;
    if (categories.length <= visibleLimit) {
      return categories;
    }
    final currentId = selectedCategoryId?.trim() ?? '';
    if (currentId.isEmpty) {
      return categories.take(visibleLimit).toList(growable: false);
    }
    final selectedIndex = categories.indexWhere(
      (category) => category.id.trim() == currentId,
    );
    if (selectedIndex < 0 || selectedIndex < visibleLimit) {
      return categories.take(visibleLimit).toList(growable: false);
    }
    return <CategoryInfo>[
      ...categories.take(visibleLimit - 1),
      categories[selectedIndex],
    ];
  }
}

class _CategoryGroupSection extends StatelessWidget {
  const _CategoryGroupSection({
    required this.group,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final PlaylistCategoryGroup group;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (group.categories.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            group.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.categories
                .map(
                  (category) => ChoiceChip(
                    label: Text(category.name),
                    showCheckmark: false,
                    selectedColor: colorScheme.primary.withValues(alpha: 0.10),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    side: BorderSide(
                      color: category.id == selectedCategoryId
                          ? colorScheme.primary.withValues(alpha: 0.30)
                          : colorScheme.outlineVariant,
                    ),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: category.id == selectedCategoryId
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                    visualDensity: VisualDensity.compact,
                    selected: category.id == selectedCategoryId,
                    onSelected: (_) => onSelected(category.id),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _PlaylistPlazaLoadingView extends StatelessWidget {
  const _PlaylistPlazaLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        PlazaFilterPanelSkeleton(rowCount: 1, trailingButton: true),
        Divider(height: 1, indent: 12, endIndent: 12),
        Expanded(child: PlazaGridSkeleton()),
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

class _LoadMoreRetryCard extends StatelessWidget {
  const _LoadMoreRetryCard({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = (message ?? '').trim().isNotEmpty;
    return Center(
      child: hasError
          ? TextButton(onPressed: onRetry, child: const Text('加载更多失败，点击重试'))
          : const SizedBox.shrink(),
    );
  }
}
