import 'package:flutter/material.dart';

import 'online_search_bars.dart';
import 'online_search_models.dart';
import 'online_search_result_list.dart';

class OnlineSearchResultPage extends StatelessWidget {
  const OnlineSearchResultPage({
    required this.selectedType,
    required this.onTypeChanged,
    required this.loadingPlatforms,
    required this.platforms,
    required this.selectedPlatformId,
    required this.onPlatformChanged,
    required this.loading,
    required this.results,
    required this.error,
    required this.initialLoading,
    required this.likedSongKeys,
    required this.onTapItem,
    required this.onLikeSongItem,
    required this.onMoreSongItem,
    required this.onLoadMore,
    required this.loadingMore,
    required this.hasMore,
    super.key,
  });

  final SearchType selectedType;
  final ValueChanged<SearchType> onTypeChanged;
  final bool loadingPlatforms;
  final List<SearchPlatform> platforms;
  final String selectedPlatformId;
  final ValueChanged<String> onPlatformChanged;
  final bool loading;
  final List<Map<String, dynamic>> results;
  final String? error;
  final bool initialLoading;
  final Set<String> likedSongKeys;
  final ValueChanged<Map<String, dynamic>> onTapItem;
  final Future<void> Function(Map<String, dynamic>) onLikeSongItem;
  final ValueChanged<Map<String, dynamic>> onMoreSongItem;
  final Future<void> Function() onLoadMore;
  final bool loadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SearchTypeBar(selectedType: selectedType, onChanged: onTypeChanged),
        const SizedBox(height: 10),
        SearchPlatformBar(
          loading: loadingPlatforms,
          platforms: platforms,
          requiredFeatureFlag: selectedType.requiredPlatformFeatureFlag,
          selectedPlatformId: selectedPlatformId,
          onChanged: onPlatformChanged,
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 2),
        Expanded(
          child: OnlineSearchResultList(
            type: selectedType,
            results: results,
            error: error,
            initialLoading: initialLoading,
            likedSongKeys: likedSongKeys,
            onTapItem: onTapItem,
            onLikeSongItem: onLikeSongItem,
            onMoreSongItem: onMoreSongItem,
            onLoadMore: onLoadMore,
            loadingMore: loadingMore,
            hasMore: hasMore,
          ),
        ),
      ],
    );
  }
}
