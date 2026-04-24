import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/song_detail_request.dart';
import '../../domain/entities/song_detail_state.dart';
import '../../domain/repositories/song_detail_repository.dart';
import '../providers/song_detail_providers.dart';

class SongDetailController extends AutoDisposeNotifier<SongDetailState> {
  String _lastRequestKey = '';

  @override
  SongDetailState build() {
    return SongDetailState.initial;
  }

  Future<void> initialize(SongDetailRequest request) async {
    if (_lastRequestKey == request.cacheKey && state.content != null) {
      return;
    }
    _lastRequestKey = request.cacheKey;
    await _load(request);
  }

  Future<void> retry(SongDetailRequest request) async {
    await _load(request);
  }

  Future<void> _load(SongDetailRequest request) async {
    state = state.copyWith(
      loading: true,
      relationsLoading: false,
      clearContent: true,
      clearError: true,
      clearRelationsError: true,
      clearRelations: true,
    );
    try {
      final content = await _repository.fetchDetail(request);
      state = state.copyWith(
        loading: false,
        content: content,
        relationsLoading: true,
        clearError: true,
        clearRelationsError: true,
      );
      try {
        final relations = await _repository.fetchRelations(request);
        state = state.copyWith(
          relationsLoading: false,
          relations: relations,
          clearRelationsError: true,
        );
      } catch (error) {
        state = state.copyWith(
          relationsLoading: false,
          relationsErrorMessage: '$error',
        );
      }
    } catch (error) {
      state = state.copyWith(
        loading: false,
        relationsLoading: false,
        errorMessage: '$error',
      );
    }
  }

  SongDetailRepository get _repository {
    return ref.read(songDetailRepositoryProvider);
  }
}
