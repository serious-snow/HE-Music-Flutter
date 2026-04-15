import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/config/app_config_controller.dart';
import '../../../../../app/router/app_routes.dart';
import '../../../../../shared/layout/adaptive_media_grid_spec.dart';
import '../../../../../shared/widgets/detail_page_shell.dart';
import '../../../../../shared/widgets/media_grid_card.dart';
import '../../../../../shared/widgets/online_platform_tabs.dart';
import '../../../../online/domain/entities/online_platform.dart';
import '../../../../../shared/widgets/underline_tab.dart';
import '../../domain/entities/new_album_page_state.dart';
import '../providers/new_album_page_providers.dart';

class NewAlbumPage extends ConsumerStatefulWidget {
  const NewAlbumPage({this.initialPlatform, this.initialTabId, super.key});

  final String? initialPlatform;
  final String? initialTabId;

  @override
  ConsumerState<NewAlbumPage> createState() => _NewAlbumPageState();
}

class _NewAlbumPageState extends ConsumerState<NewAlbumPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    Future.microtask(() {
      ref
          .read(newAlbumPageControllerProvider.notifier)
          .initialize(
            preferredPlatformId: widget.initialPlatform,
            preferredTabId: widget.initialTabId,
          );
    });
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
    final state = ref.watch(newAlbumPageControllerProvider);
    final controller = ref.read(newAlbumPageControllerProvider.notifier);
    final localeCode = ref.watch(appConfigProvider).localeCode;

    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(title: const Text('新碟')),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: OnlinePlatformTabs(
                platforms: state.platforms,
                selectedId: state.selectedPlatformId,
                requiredFeatureFlag: PlatformFeatureSupportFlag.getNewAlbumList,
                onSelected: controller.selectPlatform,
              ),
            ),
            const Divider(height: 1),
            _ReleaseTabBar(
              labels: state.tabs
                  .map((item) => _ReleaseTabData(id: item.id, name: item.name))
                  .toList(growable: false),
              selectedId: state.selectedTabId,
              onSelected: controller.selectTab,
            ),
            const Divider(height: 1),
            Expanded(
              child: _NewAlbumBody(
                localeCode: localeCode,
                scrollController: _scrollController,
                state: state,
                onRetry: controller.retry,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 160) {
      return;
    }
    ref.read(newAlbumPageControllerProvider.notifier).loadMore();
  }
}

class _NewAlbumBody extends StatelessWidget {
  const _NewAlbumBody({
    required this.localeCode,
    required this.scrollController,
    required this.state,
    required this.onRetry,
  });

  final String localeCode;
  final ScrollController scrollController;
  final NewAlbumPageState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.tabsLoading && state.tabs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.albumsErrorMessage != null && state.albums.isEmpty) {
      return _RetryBody(message: state.albumsErrorMessage!, onRetry: onRetry);
    }
    if (state.albumsLoading && state.albums.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.albums.isEmpty) {
      return const Center(child: Text('暂无新碟'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = resolveAdaptiveMediaGridSpec(
          maxWidth: constraints.maxWidth - 24,
        );
        final showFooter = state.loadingMore || !state.hasMore;
        return GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(12),
          gridDelegate: spec.sliverDelegate,
          itemCount: state.albums.length + (showFooter ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.albums.length) {
              if (state.loadingMore) {
                return const Center(child: CircularProgressIndicator());
              }
              return Center(
                child: Text(
                  '没有更多了',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            final album = state.albums[index];
            return MediaGridCard(
              kind: MediaGridCardKind.album,
              title: album.name,
              subtitle: album.artistText,
              coverUrl: album.cover,
              caption: '${album.songCount} 首',
              playCount: album.playCount,
              onTap: () => context.push(
                Uri(
                  path: AppRoutes.albumDetail,
                  queryParameters: <String, String>{
                    'id': album.id,
                    'platform': album.platform,
                    'title': album.name,
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

class _ReleaseTabData {
  const _ReleaseTabData({required this.id, required this.name});

  final String id;
  final String name;
}

class _ReleaseTabBar extends StatelessWidget {
  const _ReleaseTabBar({
    required this.labels,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_ReleaseTabData> labels;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: labels
            .map(
              (item) => UnderlineTab(
                label: item.name,
                selected: item.id == selectedId,
                enabled: true,
                onTap: () => onSelected(item.id),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _RetryBody extends StatelessWidget {
  const _RetryBody({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => onRetry(), child: const Text('重试')),
        ],
      ),
    );
  }
}
