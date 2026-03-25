import '../../../../shared/models/he_music_models.dart';

class VideoPlazaState {
  const VideoPlazaState({
    required this.selectedPlatformId,
    required this.filtersLoading,
    required this.videosLoading,
    required this.loadingMore,
    required this.filterGroups,
    required this.selectedFilters,
    required this.videos,
    required this.hasMore,
    required this.pageIndex,
    this.filtersErrorMessage,
    this.videosErrorMessage,
  });

  final String? selectedPlatformId;
  final bool filtersLoading;
  final bool videosLoading;
  final bool loadingMore;
  final List<FilterInfo> filterGroups;
  final Map<String, String> selectedFilters;
  final List<MvInfo> videos;
  final bool hasMore;
  final int pageIndex;
  final String? filtersErrorMessage;
  final String? videosErrorMessage;

  VideoPlazaState copyWith({
    String? selectedPlatformId,
    bool? filtersLoading,
    bool? videosLoading,
    bool? loadingMore,
    List<FilterInfo>? filterGroups,
    Map<String, String>? selectedFilters,
    List<MvInfo>? videos,
    bool? hasMore,
    int? pageIndex,
    String? filtersErrorMessage,
    String? videosErrorMessage,
    bool clearFiltersError = false,
    bool clearVideosError = false,
  }) {
    return VideoPlazaState(
      selectedPlatformId: selectedPlatformId ?? this.selectedPlatformId,
      filtersLoading: filtersLoading ?? this.filtersLoading,
      videosLoading: videosLoading ?? this.videosLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      filterGroups: filterGroups ?? this.filterGroups,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      videos: videos ?? this.videos,
      hasMore: hasMore ?? this.hasMore,
      pageIndex: pageIndex ?? this.pageIndex,
      filtersErrorMessage: clearFiltersError
          ? null
          : filtersErrorMessage ?? this.filtersErrorMessage,
      videosErrorMessage: clearVideosError
          ? null
          : videosErrorMessage ?? this.videosErrorMessage,
    );
  }

  static const initial = VideoPlazaState(
    selectedPlatformId: null,
    filtersLoading: false,
    videosLoading: false,
    loadingMore: false,
    filterGroups: <FilterInfo>[],
    selectedFilters: <String, String>{},
    videos: <MvInfo>[],
    hasMore: false,
    pageIndex: 1,
  );
}
