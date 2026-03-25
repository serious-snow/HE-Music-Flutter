import '../../../../shared/models/he_music_models.dart';

class ArtistPlazaState {
  const ArtistPlazaState({
    required this.selectedPlatformId,
    required this.filtersLoading,
    required this.artistsLoading,
    required this.loadingMore,
    required this.filterGroups,
    required this.selectedFilters,
    required this.artists,
    required this.hasMore,
    required this.pageIndex,
    this.filtersErrorMessage,
    this.artistsErrorMessage,
  });

  final String? selectedPlatformId;
  final bool filtersLoading;
  final bool artistsLoading;
  final bool loadingMore;
  final List<FilterInfo> filterGroups;
  final Map<String, String> selectedFilters;
  final List<ArtistInfo> artists;
  final bool hasMore;
  final int pageIndex;
  final String? filtersErrorMessage;
  final String? artistsErrorMessage;

  ArtistPlazaState copyWith({
    String? selectedPlatformId,
    bool? filtersLoading,
    bool? artistsLoading,
    bool? loadingMore,
    List<FilterInfo>? filterGroups,
    Map<String, String>? selectedFilters,
    List<ArtistInfo>? artists,
    bool? hasMore,
    int? pageIndex,
    String? filtersErrorMessage,
    String? artistsErrorMessage,
    bool clearFiltersError = false,
    bool clearArtistsError = false,
  }) {
    return ArtistPlazaState(
      selectedPlatformId: selectedPlatformId ?? this.selectedPlatformId,
      filtersLoading: filtersLoading ?? this.filtersLoading,
      artistsLoading: artistsLoading ?? this.artistsLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      filterGroups: filterGroups ?? this.filterGroups,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      artists: artists ?? this.artists,
      hasMore: hasMore ?? this.hasMore,
      pageIndex: pageIndex ?? this.pageIndex,
      filtersErrorMessage: clearFiltersError
          ? null
          : filtersErrorMessage ?? this.filtersErrorMessage,
      artistsErrorMessage: clearArtistsError
          ? null
          : artistsErrorMessage ?? this.artistsErrorMessage,
    );
  }

  static const initial = ArtistPlazaState(
    selectedPlatformId: null,
    filtersLoading: false,
    artistsLoading: false,
    loadingMore: false,
    filterGroups: <FilterInfo>[],
    selectedFilters: <String, String>{},
    artists: <ArtistInfo>[],
    hasMore: false,
    pageIndex: 1,
  );
}
