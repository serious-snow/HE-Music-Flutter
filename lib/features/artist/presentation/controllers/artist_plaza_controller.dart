import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/he_music_models.dart';
import '../../data/datasources/artist_plaza_api_client.dart';
import '../../domain/entities/artist_plaza_state.dart';
import '../providers/artist_plaza_providers.dart';

class ArtistPlazaController extends AutoDisposeNotifier<ArtistPlazaState> {
  final Map<String, List<FilterInfo>> _filterCache =
      <String, List<FilterInfo>>{};
  final Map<String, Map<String, String>> _selectedFilterCache =
      <String, Map<String, String>>{};

  @override
  ArtistPlazaState build() {
    return ArtistPlazaState.initial;
  }

  Future<void> initialize(String platformId) async {
    final currentPlatform = state.selectedPlatformId?.trim() ?? '';
    if (currentPlatform == platformId.trim() && state.filterGroups.isNotEmpty) {
      return;
    }
    await selectPlatform(platformId);
  }

  Future<void> selectPlatform(String platformId) async {
    final normalizedPlatformId = platformId.trim();
    if (normalizedPlatformId.isEmpty) {
      return;
    }
    state = state.copyWith(
      selectedPlatformId: normalizedPlatformId,
      filtersLoading: true,
      artistsLoading: true,
      filterGroups: const <FilterInfo>[],
      selectedFilters: const <String, String>{},
      artists: const <ArtistInfo>[],
      hasMore: false,
      pageIndex: 1,
      clearFiltersError: true,
      clearArtistsError: true,
    );
    try {
      final filterGroups = await _loadFilters(normalizedPlatformId);
      final selectedFilters = _resolveSelectedFilters(
        platformId: normalizedPlatformId,
        filterGroups: filterGroups,
      );
      _selectedFilterCache[normalizedPlatformId] = selectedFilters;
      state = state.copyWith(
        filtersLoading: false,
        filterGroups: filterGroups,
        selectedFilters: selectedFilters,
      );
      await _loadFirstPage(
        platformId: normalizedPlatformId,
        selectedFilters: selectedFilters,
      );
    } catch (error) {
      state = state.copyWith(
        filtersLoading: false,
        artistsLoading: false,
        filtersErrorMessage: '$error',
        artistsErrorMessage: '$error',
      );
    }
  }

  Future<void> selectFilter({
    required String groupId,
    required String value,
  }) async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    final normalizedGroupId = groupId.trim();
    final normalizedValue = value.trim();
    if (platformId.isEmpty || normalizedGroupId.isEmpty) {
      return;
    }
    if (state.selectedFilters[normalizedGroupId] == normalizedValue &&
        state.artists.isNotEmpty) {
      return;
    }
    final nextFilters = <String, String>{
      ...state.selectedFilters,
      normalizedGroupId: normalizedValue,
    };
    _selectedFilterCache[platformId] = nextFilters;
    state = state.copyWith(
      selectedFilters: nextFilters,
      artistsLoading: true,
      artists: const <ArtistInfo>[],
      hasMore: false,
      pageIndex: 1,
      clearArtistsError: true,
    );
    try {
      await _loadFirstPage(
        platformId: platformId,
        selectedFilters: nextFilters,
      );
    } catch (error) {
      state = state.copyWith(
        artistsLoading: false,
        artistsErrorMessage: '$error',
      );
    }
  }

  Future<void> retry() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    if (platformId.isEmpty) {
      return;
    }
    if (state.filterGroups.isEmpty || state.filtersErrorMessage != null) {
      await selectPlatform(platformId);
      return;
    }
    state = state.copyWith(
      artistsLoading: true,
      artists: const <ArtistInfo>[],
      hasMore: false,
      pageIndex: 1,
      clearArtistsError: true,
    );
    try {
      await _loadFirstPage(
        platformId: platformId,
        selectedFilters: state.selectedFilters,
      );
    } catch (error) {
      state = state.copyWith(
        artistsLoading: false,
        artistsErrorMessage: '$error',
      );
    }
  }

  Future<void> loadMore() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    if (platformId.isEmpty ||
        state.loadingMore ||
        state.artistsLoading ||
        !state.hasMore) {
      return;
    }
    state = state.copyWith(loadingMore: true, clearArtistsError: true);
    try {
      final currentPageIndex = state.pageIndex;
      final currentArtists = state.artists;
      final result = await _apiClient.fetchArtists(
        platform: platformId,
        filters: state.selectedFilters,
        pageIndex: currentPageIndex,
      );
      state = state.copyWith(
        loadingMore: false,
        artists: <ArtistInfo>[...currentArtists, ...result.list],
        hasMore: result.hasMore,
        pageIndex: currentPageIndex + 1,
      );
    } catch (error) {
      state = state.copyWith(loadingMore: false, artistsErrorMessage: '$error');
    }
  }

  Future<List<FilterInfo>> _loadFilters(String platformId) async {
    final cached = _filterCache[platformId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final groups = await _apiClient.fetchFilters(platform: platformId);
    _filterCache[platformId] = groups;
    return groups;
  }

  Map<String, String> _resolveSelectedFilters({
    required String platformId,
    required List<FilterInfo> filterGroups,
  }) {
    final cached = _selectedFilterCache[platformId] ?? const <String, String>{};
    final result = <String, String>{};
    for (final group in filterGroups) {
      final groupId = group.id.trim();
      if (groupId.isEmpty || group.options.isEmpty) {
        continue;
      }
      final cachedValue = cached[groupId]?.trim() ?? '';
      final matched = group.options.any(
        (option) => option.value.trim() == cachedValue,
      );
      result[groupId] = matched ? cachedValue : group.options.first.value;
    }
    return result;
  }

  Future<void> _loadFirstPage({
    required String platformId,
    required Map<String, String> selectedFilters,
  }) async {
    final result = await _apiClient.fetchArtists(
      platform: platformId,
      filters: selectedFilters,
      pageIndex: 1,
    );
    state = state.copyWith(
      artistsLoading: false,
      artists: result.list,
      hasMore: result.hasMore,
      pageIndex: 2,
      clearArtistsError: true,
    );
  }

  ArtistPlazaApiClient get _apiClient {
    return ref.read(artistPlazaApiClientProvider);
  }
}
