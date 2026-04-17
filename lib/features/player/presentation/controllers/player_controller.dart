import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_online_audio_quality.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../core/audio/audio_handler_player_adapter.dart';
import '../../../../core/audio/audio_player_port.dart';
import '../../../../core/audio/audio_track.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../../shared/utils/audio_quality_selector.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../radio/presentation/providers/radio_providers.dart';
import '../../data/datasources/player_history_data_source.dart';
import '../../data/datasources/player_progress_data_source.dart';
import '../../data/datasources/player_queue_data_source.dart';
import '../../domain/entities/player_history_item.dart';
import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_playback_state.dart';
import '../../domain/entities/player_quality_option.dart';
import '../../domain/entities/player_queue_snapshot.dart';
import '../../domain/entities/player_queue_source.dart';
import '../../domain/entities/player_track.dart';
import '../providers/player_audio_provider.dart';
import '../providers/player_history_provider.dart';
import '../providers/player_progress_provider.dart';
import '../providers/player_queue_provider.dart';

class PlayerController extends Notifier<PlayerPlaybackState> {
  static const _defaultQueueIndex = 0;
  static const _positionUpdateMinDeltaMs = 16;
  static const _freshPositionAcceptMaxMs = 800;
  static const _progressPersistMinGapMs = 5000;
  static const _progressPersistMinDeltaMs = 4000;
  static const _progressPersistMinPositionMs = 3000;
  static const _progressPersistTailBufferMs = 2000;

  final Random _random = Random();

  late AudioPlayerPort _audioPlayer;
  late PlayerHistoryDataSource _historyDataSource;
  late PlayerProgressDataSource _progressDataSource;
  late PlayerQueueDataSource _queueDataSource;

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _loadingSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _completedSubscription;

  bool _initialized = false;
  bool _isLoadingRadioNextPage = false;
  String? _lastHistoryTrackKey;
  DateTime? _lastProgressPersistAt;
  int _lastPersistedPositionMs = 0;
  String? _lastPersistTrackKey;
  int? _suppressedCurrentIndexEvent;
  bool _awaitingFreshPosition = false;
  int _trackSwitchRequestId = 0;

  @override
  PlayerPlaybackState build() {
    _audioPlayer = ref.read(audioPlayerPortProvider);
    if (_audioPlayer case final AudioHandlerPlayerAdapter adapter) {
      unawaited(adapter.syncConfig(ref.read(appConfigProvider)));
    }
    _historyDataSource = ref.read(playerHistoryDataSourceProvider);
    _progressDataSource = ref.read(playerProgressDataSourceProvider);
    _queueDataSource = ref.read(playerQueueDataSourceProvider);
    ref.listen<AppConfigState>(appConfigProvider, (previous, next) {
      if (_audioPlayer case final AudioHandlerPlayerAdapter adapter) {
        unawaited(adapter.syncConfig(next));
      }
    });
    ref.onDispose(_disposeSubscriptions);
    return const PlayerPlaybackState(
      queue: <PlayerTrack>[],
      currentIndex: 0,
      historyCount: 0,
      isPlaying: false,
      isLoading: false,
      position: Duration.zero,
      duration: Duration.zero,
      volume: defaultPlayerVolume,
      speed: defaultPlayerSpeed,
      playMode: PlayerPlayMode.sequence,
      currentAvailableQualities: <PlayerQualityOption>[],
      isRadioMode: false,
      previousPlayModeBeforeRadio: null,
    );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _bindStreams();
    await _hydrateHistoryCount();
    await _applyPlayMode(state.playMode);
    await _hydrateQueue();
    _initialized = true;
  }

  Future<void> replaceQueue(
    List<PlayerTrack> queue, {
    int startIndex = _defaultQueueIndex,
    bool autoplay = true,
    PlayerQueueSource? queueSource,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {
    _validateQueueInput(queue, startIndex);
    await _ensureInitialized();
    if (_isSameQueueContext(queue, queueSource) &&
        _isSameRadioContext(
          isRadioMode: isRadioMode,
          currentRadioId: currentRadioId,
          currentRadioPlatform: currentRadioPlatform,
          currentRadioPageIndex: currentRadioPageIndex,
        )) {
      await playAt(startIndex);
      return;
    }
    final previousSnapshot = _buildCurrentQueueSnapshot();
    final nextPlayMode = _resolveNextPlayMode(isRadioMode: isRadioMode);
    final nextPreviousPlayModeBeforeRadio = _resolvePreviousPlayModeBeforeRadio(
      isRadioMode: isRadioMode,
    );
    await _switchCurrentPlaybackContext(
      queue: queue,
      targetIndex: startIndex,
      autoplay: autoplay,
      buildState:
          ({
            required List<PlayerQualityOption> availableQualities,
            required String? selectedQualityName,
          }) {
            return state.copyWith(
              queue: queue,
              currentIndex: startIndex,
              position: Duration.zero,
              duration: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              playMode: nextPlayMode,
              queueSource: queueSource,
              previousQueueSnapshot: previousSnapshot,
              isRadioMode: isRadioMode,
              currentRadioId: isRadioMode
                  ? _normalizeRadioValue(currentRadioId)
                  : null,
              clearCurrentRadioId: !isRadioMode,
              currentRadioPlatform: isRadioMode
                  ? _normalizeRadioValue(currentRadioPlatform)
                  : null,
              clearCurrentRadioPlatform: !isRadioMode,
              currentRadioPageIndex: isRadioMode
                  ? _normalizeRadioPageIndex(currentRadioPageIndex)
                  : null,
              clearCurrentRadioPageIndex: !isRadioMode,
              previousPlayModeBeforeRadio: nextPreviousPlayModeBeforeRadio,
              clearPreviousPlayModeBeforeRadio: !isRadioMode,
              clearError: true,
            );
          },
      applyResolvedState: (_TrackPlaybackResolution resolution) {
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          clearError: true,
        );
      },
    );
  }

  bool get hasPreviousQueue =>
      state.previousQueueSnapshot != null &&
      state.previousQueueSnapshot!.queue.isNotEmpty;

  Future<void> swapToPreviousQueue({
    int? startIndex,
    bool autoplay = true,
  }) async {
    await _ensureInitialized();
    final snapshot = state.previousQueueSnapshot;
    if (snapshot == null || snapshot.queue.isEmpty) {
      return;
    }
    final targetIndex = (startIndex ?? snapshot.currentIndex).clamp(
      0,
      snapshot.queue.length - 1,
    );
    final currentSnapshot = _buildCurrentQueueSnapshot();
    await _switchCurrentPlaybackContext(
      queue: snapshot.queue,
      targetIndex: targetIndex,
      autoplay: autoplay,
      buildState:
          ({
            required List<PlayerQualityOption> availableQualities,
            required String? selectedQualityName,
          }) {
            return state.copyWith(
              queue: snapshot.queue,
              currentIndex: targetIndex,
              playMode: snapshot.playMode,
              position: Duration.zero,
              duration: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              queueSource: snapshot.source,
              previousQueueSnapshot: currentSnapshot,
              isRadioMode: snapshot.isRadioMode,
              currentRadioId: snapshot.currentRadioId,
              clearCurrentRadioId: snapshot.currentRadioId == null,
              currentRadioPlatform: snapshot.currentRadioPlatform,
              clearCurrentRadioPlatform: snapshot.currentRadioPlatform == null,
              currentRadioPageIndex: snapshot.currentRadioPageIndex,
              clearCurrentRadioPageIndex:
                  snapshot.currentRadioPageIndex == null,
              previousPlayModeBeforeRadio: snapshot.previousPlayModeBeforeRadio,
              clearPreviousPlayModeBeforeRadio:
                  snapshot.previousPlayModeBeforeRadio == null,
              clearError: true,
            );
          },
      applyResolvedState: (_TrackPlaybackResolution resolution) {
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          clearError: true,
        );
      },
    );
  }

  Future<void> togglePlayPause() async {
    await _ensureInitialized();
    if (state.isPlaying) {
      await _execute(() async {
        await _audioPlayer.pause();
        await _persistTrackProgress(
          track: state.currentTrack,
          position: state.position,
          force: true,
        );
      });
      return;
    }
    final currentTrack = state.currentTrack;
    if (currentTrack == null) {
      return;
    }
    final currentIndex = _safeCurrentIndex(state.queue.length);
    if (!_hasReadyPlaybackSource(currentTrack)) {
      await _execute(() async {
        final resolution = await _resolveTrackForPlayback(currentIndex);
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          clearError: true,
        );
        await _persistQueueState();
        await _audioPlayer.setSource(_toAudioTrack(resolution.track));
        await _audioPlayer.play();
        await _recordCurrentTrackHistory(index: currentIndex);
      });
      return;
    }
    await _execute(() async {
      await _audioPlayer.play();
      await _recordCurrentTrackHistory();
    });
  }

  Future<void> playAt(int index) async {
    await _ensureInitialized();
    _validateQueueInput(state.queue, index);
    await _switchCurrentPlaybackContext(
      queue: state.queue,
      targetIndex: index,
      autoplay: true,
      buildState:
          ({
            required List<PlayerQualityOption> availableQualities,
            required String? selectedQualityName,
          }) {
            return state.copyWith(
              currentIndex: index,
              position: Duration.zero,
              duration: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              clearError: true,
            );
          },
      applyResolvedState: (_TrackPlaybackResolution resolution) {
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          clearError: true,
        );
      },
    );
  }

  Future<void> playNext() async {
    await _ensureInitialized();
    final queue = state.queue;
    if (queue.isEmpty) {
      return;
    }
    final currentIndex = _safeCurrentIndex(queue.length);
    if (state.isRadioMode && currentIndex == queue.length - 1) {
      final appended = await _ensureRadioNextPageAppended();
      if (appended && state.queue.length > currentIndex + 1) {
        await playAt(currentIndex + 1);
      }
      return;
    }
    final targetIndex = switch (state.playMode) {
      PlayerPlayMode.shuffle => _randomNextIndex(
        queue.length,
        excluding: currentIndex,
      ),
      _ => (currentIndex + 1) % queue.length,
    };
    await playAt(targetIndex);
  }

  Future<void> playPrevious() async {
    await _ensureInitialized();
    final queue = state.queue;
    if (queue.isEmpty) {
      return;
    }
    final currentIndex = _safeCurrentIndex(queue.length);
    final targetIndex = switch (state.playMode) {
      PlayerPlayMode.shuffle => _randomNextIndex(
        queue.length,
        excluding: currentIndex,
      ),
      _ => (currentIndex - 1 + queue.length) % queue.length,
    };
    await playAt(targetIndex);
  }

  Future<void> insertNextAndPlay(PlayerTrack track) async {
    await _ensureInitialized();
    final currentQueue = state.queue;
    if (currentQueue.isEmpty) {
      await replaceQueue(<PlayerTrack>[track]);
      return;
    }
    final currentIndex = _safeCurrentIndex(currentQueue.length);
    final targetIndex = currentIndex + 1;
    final nextQueue = <PlayerTrack>[...currentQueue];
    nextQueue.insert(targetIndex, track);
    final nextPlayMode = _resolveNextPlayMode(isRadioMode: false);
    await _switchCurrentPlaybackContext(
      queue: nextQueue,
      targetIndex: targetIndex,
      autoplay: true,
      buildState:
          ({
            required List<PlayerQualityOption> availableQualities,
            required String? selectedQualityName,
          }) {
            return state.copyWith(
              queue: nextQueue,
              currentIndex: targetIndex,
              position: Duration.zero,
              duration: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              playMode: nextPlayMode,
              clearQueueSource: true,
              clearPreviousPlayModeBeforeRadio: true,
              clearError: true,
            );
          },
      applyResolvedState: (_TrackPlaybackResolution resolution) {
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          isRadioMode: false,
          clearCurrentRadioId: true,
          clearCurrentRadioPlatform: true,
          clearCurrentRadioPageIndex: true,
          clearError: true,
        );
      },
    );
  }

  Future<void> insertNextTrack(PlayerTrack track) async {
    await _upsertQueueTrack(
      track: track,
      insertNext: true,
      autoplayWhenQueueEmpty: true,
    );
  }

  Future<void> appendTrack(PlayerTrack track) async {
    await _upsertQueueTrack(
      track: track,
      insertNext: false,
      autoplayWhenQueueEmpty: false,
    );
  }

  Future<void> removeTrackAt(int index) async {
    await _ensureInitialized();
    final queue = state.queue;
    if (index < 0 || index >= queue.length) {
      return;
    }
    if (queue.length == 1) {
      await clearQueue();
      return;
    }
    final currentIndex = _safeCurrentIndex(queue.length);
    final wasPlaying = state.isPlaying;
    final nextQueue = <PlayerTrack>[...queue]..removeAt(index);
    if (index != currentIndex) {
      final nextCurrentIndex = index < currentIndex
          ? currentIndex - 1
          : currentIndex;
      state = state.copyWith(
        queue: nextQueue,
        currentIndex: nextCurrentIndex,
        playMode: _resolveNextPlayMode(isRadioMode: false),
        isRadioMode: false,
        clearQueueSource: true,
        clearCurrentRadioId: true,
        clearCurrentRadioPlatform: true,
        clearCurrentRadioPageIndex: true,
        clearPreviousPlayModeBeforeRadio: true,
        clearError: true,
      );
      await _execute(() async {
        _suppressNextCurrentIndexEvent(nextCurrentIndex);
        await _audioPlayer.setQueue(
          nextQueue.map(_toAudioTrack).toList(growable: false),
          initialIndex: nextCurrentIndex,
          forceReloadCurrent: false,
        );
        await _applyPlayMode(state.playMode);
      });
      await _persistQueueState();
      return;
    }
    final targetIndex = index >= nextQueue.length
        ? nextQueue.length - 1
        : index;
    final nextPlayMode = _resolveNextPlayMode(isRadioMode: false);
    await _switchCurrentPlaybackContext(
      queue: nextQueue,
      targetIndex: targetIndex,
      autoplay: wasPlaying,
      buildState:
          ({
            required List<PlayerQualityOption> availableQualities,
            required String? selectedQualityName,
          }) {
            return state.copyWith(
              queue: nextQueue,
              currentIndex: targetIndex,
              position: Duration.zero,
              duration: Duration.zero,
              currentAvailableQualities: availableQualities,
              currentSelectedQualityName: selectedQualityName,
              playMode: nextPlayMode,
              clearQueueSource: true,
              clearPreviousPlayModeBeforeRadio: true,
              clearError: true,
            );
          },
      applyResolvedState: (_TrackPlaybackResolution resolution) {
        state = state.copyWith(
          queue: resolution.updatedQueue,
          currentAvailableQualities: resolution.availableQualities,
          currentSelectedQualityName: resolution.selectedQualityName,
          isRadioMode: false,
          clearCurrentRadioId: true,
          clearCurrentRadioPlatform: true,
          clearCurrentRadioPageIndex: true,
          clearError: true,
        );
      },
    );
  }

  Future<void> clearQueue() async {
    await _ensureInitialized();
    await _persistTrackProgress(
      track: state.currentTrack,
      position: state.position,
      force: true,
    );
    await _execute(() async {
      await _audioPlayer.stop();
      state = state.copyWith(
        queue: const <PlayerTrack>[],
        currentIndex: 0,
        isPlaying: false,
        isLoading: false,
        position: Duration.zero,
        duration: Duration.zero,
        currentAvailableQualities: const <PlayerQualityOption>[],
        isRadioMode: false,
        playMode: _resolveNextPlayMode(isRadioMode: false),
        clearQueueSource: true,
        clearCurrentSelectedQuality: true,
        clearCurrentRadioId: true,
        clearCurrentRadioPlatform: true,
        clearCurrentRadioPageIndex: true,
        clearPreviousPlayModeBeforeRadio: true,
        clearError: true,
      );
    });
    await _persistQueueState();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    await _ensureInitialized();
    final queue = state.queue;
    if (oldIndex < 0 ||
        oldIndex >= queue.length ||
        newIndex < 0 ||
        newIndex > queue.length ||
        oldIndex == newIndex) {
      return;
    }
    final normalizedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    if (oldIndex == normalizedNewIndex) {
      return;
    }
    final currentTrack = state.currentTrack;
    final currentTrackKey = currentTrack == null
        ? null
        : _trackKey(currentTrack);
    final nextQueue = <PlayerTrack>[...queue];
    final moved = nextQueue.removeAt(oldIndex);
    nextQueue.insert(normalizedNewIndex, moved);
    final nextCurrentIndex = currentTrackKey == null
        ? _defaultQueueIndex
        : nextQueue.indexWhere((track) => _trackKey(track) == currentTrackKey);
    state = state.copyWith(
      queue: nextQueue,
      currentIndex: nextCurrentIndex < 0
          ? _defaultQueueIndex
          : nextCurrentIndex,
      playMode: _resolveNextPlayMode(isRadioMode: false),
      isRadioMode: false,
      clearQueueSource: true,
      clearCurrentRadioId: true,
      clearCurrentRadioPlatform: true,
      clearCurrentRadioPageIndex: true,
      clearPreviousPlayModeBeforeRadio: true,
      clearError: true,
    );
    await _execute(() async {
      _suppressNextCurrentIndexEvent(
        nextCurrentIndex < 0 ? _defaultQueueIndex : nextCurrentIndex,
      );
      await _audioPlayer.setQueue(
        nextQueue.map(_toAudioTrack).toList(growable: false),
        initialIndex: nextCurrentIndex < 0
            ? _defaultQueueIndex
            : nextCurrentIndex,
        forceReloadCurrent: false,
      );
      await _applyPlayMode(state.playMode);
    });
    await _persistQueueState();
  }

  Future<void> seek(Duration position) async {
    await _ensureInitialized();
    await _execute(() => _audioPlayer.seek(position));
  }

  Future<void> setVolume(double volume) async {
    await _ensureInitialized();
    state = state.copyWith(volume: volume, clearError: true);
    await _execute(() => _audioPlayer.setVolume(volume));
  }

  Future<void> setSpeed(double speed) async {
    await _ensureInitialized();
    state = state.copyWith(speed: speed, clearError: true);
    await _execute(() => _audioPlayer.setSpeed(speed));
  }

  Future<void> cyclePlayMode() async {
    await _ensureInitialized();
    if (state.isRadioMode) {
      return;
    }
    final nextMode = switch (state.playMode) {
      PlayerPlayMode.sequence => PlayerPlayMode.shuffle,
      PlayerPlayMode.shuffle => PlayerPlayMode.single,
      PlayerPlayMode.single => PlayerPlayMode.sequence,
    };
    await setPlayMode(nextMode);
  }

  Future<void> setPlayMode(PlayerPlayMode mode) async {
    await _ensureInitialized();
    if (state.isRadioMode) {
      return;
    }
    state = state.copyWith(playMode: mode, clearError: true);
    await _execute(() => _applyPlayMode(mode));
    await _persistQueueState();
  }

  Future<void> switchCurrentQualityByName(String qualityName) async {
    await _ensureInitialized();
    final track = state.currentTrack;
    final normalized = qualityName.trim();
    if (track == null || normalized.isEmpty) {
      return;
    }
    final matchedOption = _findQualityOptionByName(
      state.currentAvailableQualities,
      normalized,
    );
    if (matchedOption == null) {
      return;
    }
    final index = _safeCurrentIndex(state.queue.length);
    final wasPlaying = state.isPlaying;
    final resumePosition = state.position;
    await _persistTrackProgress(
      track: track,
      position: resumePosition,
      force: true,
    );
    state = state.copyWith(
      position: Duration.zero,
      duration: Duration.zero,
      currentSelectedQualityName: matchedOption.name,
      clearError: true,
    );
    final requestId = _beginTrackSwitchRequest();
    await _execute(() async {
      _guardTrackSwitchRequest(requestId);
      final resolution = await _resolveTrackForPlayback(
        index,
        forcedQualityName: matchedOption.name,
      );
      _guardTrackSwitchRequest(requestId);
      state = state.copyWith(
        queue: resolution.updatedQueue,
        currentAvailableQualities: resolution.availableQualities,
        currentSelectedQualityName: resolution.selectedQualityName,
        clearError: true,
      );
      ref
          .read(appConfigProvider.notifier)
          .setLastSelectedOnlineAudioQualityName(matchedOption.name);
      await _syncAudioHandlerConfigFromState();
      _guardTrackSwitchRequest(requestId);
      await _persistQueueState();
      _guardTrackSwitchRequest(requestId);
      await _audioPlayer.setSource(_toAudioTrack(resolution.track));
      _guardTrackSwitchRequest(requestId);
      if (resumePosition > Duration.zero) {
        await _audioPlayer.seek(resumePosition);
        state = state.copyWith(position: resumePosition, clearError: true);
      }
      if (wasPlaying) {
        await _audioPlayer.play();
      }
    }, trackSwitchRequestId: requestId);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await initialize();
  }

  Future<void> _interruptPlaybackForTrackSwitch() async {
    await _execute(() async {
      await _audioPlayer.stop();
      state = state.copyWith(
        isPlaying: false,
        isLoading: false,
        position: Duration.zero,
        duration: Duration.zero,
        clearError: true,
      );
    });
  }

  Future<void> _execute(
    Future<void> Function() action, {
    int? trackSwitchRequestId,
  }) async {
    try {
      state = state.copyWith(clearError: true);
      await action();
    } on _StaleTrackSwitchException {
      return;
    } catch (error) {
      if (trackSwitchRequestId != null &&
          trackSwitchRequestId != _trackSwitchRequestId) {
        return;
      }
      state = state.copyWith(errorMessage: _userFacingPlaybackError(error));
      rethrow;
    }
  }

  Future<void> _reloadQueueAt({
    required List<PlayerTrack> queue,
    required int index,
    required bool autoplay,
    required void Function(_TrackPlaybackResolution resolution)
    applyResolvedState,
    String? forcedQualityName,
  }) async {
    final requestId = _beginTrackSwitchRequest();
    await _execute(() async {
      _guardTrackSwitchRequest(requestId);
      final resolution = await _resolveQueueTrackForPlayback(
        queue,
        index,
        forcedQualityName: forcedQualityName,
      );
      _guardTrackSwitchRequest(requestId);
      applyResolvedState(resolution);
      _guardTrackSwitchRequest(requestId);
      await _syncQueueToAudioPlayer(
        queue: resolution.updatedQueue,
        currentIndex: index,
        autoplay: autoplay,
        restoreProgress: false,
      );
    }, trackSwitchRequestId: requestId);
  }

  Future<void> _switchCurrentPlaybackContext({
    required List<PlayerTrack> queue,
    required int targetIndex,
    required bool autoplay,
    required PlayerPlaybackState Function({
      required List<PlayerQualityOption> availableQualities,
      required String? selectedQualityName,
    })
    buildState,
    required void Function(_TrackPlaybackResolution resolution)
    applyResolvedState,
  }) async {
    await _persistTrackProgress(
      track: state.currentTrack,
      position: state.position,
      force: true,
    );
    await _interruptPlaybackForTrackSwitch();
    final currentTrack = queue[targetIndex];
    final availableQualities = _availableQualities(currentTrack);
    final selectedQualityName = _resolveSelectedQualityName(
      availableQualities: availableQualities,
    );
    state = buildState(
      availableQualities: availableQualities,
      selectedQualityName: selectedQualityName,
    );
    _markFreshPositionPending();
    await _reloadQueueAt(
      queue: queue,
      index: targetIndex,
      autoplay: autoplay,
      applyResolvedState: applyResolvedState,
    );
    await _persistQueueState();
  }

  int _beginTrackSwitchRequest() {
    _trackSwitchRequestId += 1;
    return _trackSwitchRequestId;
  }

  void _guardTrackSwitchRequest(int requestId) {
    if (requestId != _trackSwitchRequestId) {
      throw const _StaleTrackSwitchException();
    }
  }

  void _bindStreams() {
    _playingSubscription = _audioPlayer.playingStream.listen((isPlaying) {
      state = state.copyWith(isPlaying: isPlaying);
    }, onError: _onStreamError);

    _loadingSubscription = _audioPlayer.loadingStream.listen((isLoading) {
      state = state.copyWith(isLoading: isLoading);
    }, onError: _onStreamError);

    _currentIndexSubscription = _audioPlayer.currentIndexStream.listen((
      nextIndex,
    ) {
      unawaited(_handleCurrentIndexChanged(nextIndex));
    }, onError: _onStreamError);

    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      if (_awaitingFreshPosition) {
        if (position.inMilliseconds > _freshPositionAcceptMaxMs) {
          return;
        }
        _awaitingFreshPosition = false;
      }
      final deltaMs = (position.inMilliseconds - state.position.inMilliseconds)
          .abs();
      if (deltaMs < _positionUpdateMinDeltaMs && position > Duration.zero) {
        return;
      }
      state = state.copyWith(position: position);
      _persistProgressFromStream(position);
    }, onError: _onStreamError);

    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      final normalized = duration ?? Duration.zero;
      state = state.copyWith(duration: normalized);
      if (normalized > Duration.zero) {
        _syncCurrentTrackDuration(normalized);
      }
    }, onError: _onStreamError);

    _completedSubscription = _audioPlayer.completedStream.listen((completed) {
      if (!completed) {
        return;
      }
      unawaited(_handlePlaybackCompleted());
    }, onError: _onStreamError);
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    state = state.copyWith(errorMessage: _userFacingPlaybackError(error));
  }

  void _disposeSubscriptions() {
    _playingSubscription?.cancel();
    _loadingSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completedSubscription?.cancel();
  }

  void _markFreshPositionPending() {
    _awaitingFreshPosition = true;
  }

  void _syncCurrentTrackDuration(Duration duration) {
    final queue = state.queue;
    if (queue.isEmpty) {
      return;
    }
    final index = _safeCurrentIndex(queue.length);
    final current = queue[index];
    if (current.duration == duration) {
      return;
    }
    final nextQueue = <PlayerTrack>[...queue];
    nextQueue[index] = current.copyWith(duration: duration);
    state = state.copyWith(queue: nextQueue);
    unawaited(_persistQueueState());
  }

  AudioTrack _toAudioTrack(PlayerTrack track) {
    return AudioTrack(
      id: track.id,
      title: track.title,
      duration: track.duration,
      links: track.links,
      artist: track.artist,
      album: track.album,
      url: track.url,
      path: track.path,
      artworkUrl: track.artworkUrl,
      platform: track.platform,
    );
  }

  bool _hasReadyPlaybackSource(PlayerTrack track) {
    final localPath = track.path?.trim() ?? '';
    if (localPath.isNotEmpty) {
      return true;
    }
    final platform = track.platform?.trim() ?? '';
    if (platform.isNotEmpty) {
      return false;
    }
    return track.url.trim().isNotEmpty;
  }

  Future<void> _syncAudioHandlerConfigFromState() async {
    if (_audioPlayer case final AudioHandlerPlayerAdapter adapter) {
      await adapter.syncConfig(ref.read(appConfigProvider));
    }
  }

  Future<void> _applyPlayMode(PlayerPlayMode mode) async {
    if (mode == PlayerPlayMode.single) {
      await _audioPlayer.setSingleLoop(true);
      await _audioPlayer.setShuffle(false);
      return;
    }
    await _audioPlayer.setSingleLoop(false);
    await _audioPlayer.setShuffle(mode == PlayerPlayMode.shuffle);
  }

  Future<void> _syncQueueToAudioPlayer({
    required List<PlayerTrack> queue,
    required int currentIndex,
    required bool autoplay,
    required bool restoreProgress,
  }) async {
    _suppressNextCurrentIndexEvent(currentIndex);
    await _audioPlayer.setQueue(
      queue.map(_toAudioTrack).toList(growable: false),
      initialIndex: currentIndex,
      forceReloadCurrent: true,
    );
    await _applyPlayMode(state.playMode);
    if (restoreProgress) {
      await _restoreTrackProgress(currentIndex);
    }
    if (autoplay) {
      await _audioPlayer.play();
      await _recordCurrentTrackHistory(index: currentIndex);
    }
  }

  void _persistProgressFromStream(Duration position) {
    if (!state.isPlaying) {
      return;
    }
    unawaited(
      _persistTrackProgress(track: state.currentTrack, position: position),
    );
  }

  Future<void> _handleCurrentIndexChanged(int? nextIndex) async {
    if (nextIndex == null || state.queue.isEmpty) {
      return;
    }
    final safeIndex = nextIndex.clamp(0, state.queue.length - 1);
    if (_suppressedCurrentIndexEvent == safeIndex) {
      _suppressedCurrentIndexEvent = null;
      return;
    }
    _suppressedCurrentIndexEvent = null;
    final previousTrack = state.currentTrack;
    final previousTrackKey = previousTrack == null
        ? null
        : _trackKey(previousTrack);
    final previousPosition = state.position;
    final previousDuration = state.duration;
    final track = _resolveTrack(safeIndex);
    if (track == null) {
      return;
    }
    final nextTrackKey = _trackKey(track);
    if (previousTrackKey != null && previousTrackKey != nextTrackKey) {
      await _persistTrackProgress(
        track: previousTrack,
        position: previousPosition,
        durationOverride: previousDuration,
        force: true,
      );
    }
    final availableQualities = _availableQualities(track);
    final selectedQualityName = _resolveSelectedQualityName(
      availableQualities: availableQualities,
    );
    state = state.copyWith(
      currentIndex: safeIndex,
      position: Duration.zero,
      duration: Duration.zero,
      currentAvailableQualities: availableQualities,
      currentSelectedQualityName: selectedQualityName,
      clearError: true,
    );
    _markFreshPositionPending();
    await _persistQueueState();
    await _recordCurrentTrackHistory(index: safeIndex);
  }

  Future<_TrackPlaybackResolution> _resolveTrackForPlayback(
    int index, {
    String? forcedQualityName,
  }) async {
    return _resolveQueueTrackForPlayback(
      state.queue,
      index,
      forcedQualityName: forcedQualityName,
    );
  }

  Future<_TrackPlaybackResolution> _resolveQueueTrackForPlayback(
    List<PlayerTrack> queue,
    int index, {
    String? forcedQualityName,
  }) async {
    if (index < 0 || index >= queue.length) {
      throw const AppException(ValidationFailure('Player track is missing.'));
    }
    final track = queue[index];
    final availableQualities = _availableQualities(track);
    final selectedQualityName = _resolveSelectedQualityName(
      availableQualities: availableQualities,
      forcedQualityName: forcedQualityName,
    );
    final localPath = track.path?.trim() ?? '';
    if (localPath.isNotEmpty) {
      final localUrl = _localPathToUrl(localPath);
      final updatedTrack = track.copyWith(url: localUrl);
      return _TrackPlaybackResolution(
        track: updatedTrack,
        updatedQueue: <PlayerTrack>[
          ...queue.take(index),
          updatedTrack,
          ...queue.skip(index + 1),
        ],
        availableQualities: availableQualities,
        selectedQualityName: selectedQualityName,
      );
    }
    final platform = (track.platform ?? '').trim();
    var resolvedTrack = track;
    if (platform.isNotEmpty) {
      resolvedTrack = track.copyWith(url: '');
    }
    if (resolvedTrack.url.trim().isEmpty && platform.isEmpty) {
      throw const AppException(
        ValidationFailure('Player track url is missing.'),
      );
    }
    final nextQueue = <PlayerTrack>[...queue];
    nextQueue[index] = resolvedTrack;
    return _TrackPlaybackResolution(
      track: resolvedTrack,
      updatedQueue: nextQueue,
      availableQualities: availableQualities,
      selectedQualityName: selectedQualityName,
    );
  }

  List<PlayerQualityOption> _availableQualities(PlayerTrack track) {
    if (track.links.isEmpty) {
      return const <PlayerQualityOption>[];
    }
    final descriptions = _platformQualityDescriptions(
      (track.platform ?? '').trim(),
    );
    final available = <PlayerQualityOption>[];
    final seenNames = <String>{};
    for (final link in track.links) {
      final name = link.name.trim();
      if (name.isEmpty || !seenNames.add(name)) {
        continue;
      }
      final description = (descriptions[name] ?? '').trim();
      available.add(
        PlayerQualityOption(
          name: name,
          description: description.isEmpty ? null : description,
          quality: link.quality,
          format: link.format,
          url: link.url,
          sizeBytes: _parseLinkSizeBytes(link.size),
        ),
      );
    }
    return List<PlayerQualityOption>.unmodifiable(available.reversed);
  }

  Map<String, String> _platformQualityDescriptions(String platformId) {
    if (platformId.isEmpty) {
      return const <String, String>{};
    }
    final platforms = ref.read(onlinePlatformsProvider).valueOrNull;
    if (platforms == null || platforms.isEmpty) {
      return const <String, String>{};
    }
    for (final platform in platforms) {
      if (platform.id == platformId) {
        return platform.qualities;
      }
    }
    return const <String, String>{};
  }

  int? _parseLinkSizeBytes(String rawSize) {
    final normalized = rawSize.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  String _localPathToUrl(String localPath) {
    final normalized = localPath.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final parsed = Uri.tryParse(normalized);
    if (parsed != null && parsed.hasScheme) {
      return parsed.toString();
    }
    return Uri.file(normalized).toString();
  }

  String? _resolveSelectedQualityName({
    required List<PlayerQualityOption> availableQualities,
    String? forcedQualityName,
  }) {
    if (availableQualities.isEmpty) {
      return null;
    }
    final forced = forcedQualityName?.trim() ?? '';
    if (forced.isNotEmpty &&
        _findQualityOptionByName(availableQualities, forced) != null) {
      return forced;
    }
    final config = ref.read(appConfigProvider);
    final matched = selectPreferredAudioQuality(
      availableQualities,
      preference: config.onlineAudioQualityPreference,
      lastSelectedQualityName: config.lastSelectedOnlineAudioQualityName,
      nameOf: (PlayerQualityOption option) => option.name,
      formatOf: (PlayerQualityOption option) => option.format,
      bitrateOf: (PlayerQualityOption option) => option.quality,
    );
    if (matched != null) {
      return matched.name;
    }
    return availableQualities.first.name;
  }

  PlayerQualityOption? _findQualityOptionByName(
    List<PlayerQualityOption> options,
    String qualityName,
  ) {
    for (final option in options) {
      if (option.name == qualityName) {
        return option;
      }
    }
    return null;
  }

  Future<void> _persistTrackProgress({
    required PlayerTrack? track,
    required Duration position,
    Duration? durationOverride,
    bool force = false,
  }) async {
    if (track == null) {
      return;
    }
    final positionMs = position.inMilliseconds;
    if (!force && positionMs < _progressPersistMinPositionMs) {
      return;
    }
    final durationMs = (durationOverride ?? state.duration).inMilliseconds;
    if (durationMs > _progressPersistMinPositionMs &&
        positionMs >= durationMs - _progressPersistTailBufferMs) {
      await _progressDataSource.clearProgress(track);
      return;
    }
    final trackKey = _trackKey(track);
    final now = DateTime.now();
    if (!force && _lastPersistTrackKey == trackKey) {
      final lastAt = _lastProgressPersistAt;
      final gapMs = lastAt == null
          ? _progressPersistMinGapMs
          : now.difference(lastAt).inMilliseconds;
      final deltaMs = (positionMs - _lastPersistedPositionMs).abs();
      if (gapMs < _progressPersistMinGapMs &&
          deltaMs < _progressPersistMinDeltaMs) {
        return;
      }
    }
    try {
      await _progressDataSource.saveProgress(
        track: track,
        positionMs: positionMs,
      );
      _lastProgressPersistAt = now;
      _lastPersistedPositionMs = positionMs;
      _lastPersistTrackKey = trackKey;
    } catch (_) {
      // 忽略进度持久化失败，避免影响主播放链路。
    }
  }

  Future<void> _restoreTrackProgress(int index) async {
    final track = _resolveTrack(index);
    if (track == null) {
      return;
    }
    try {
      final savedMs = await _progressDataSource.readProgress(track);
      if (savedMs == null || savedMs < _progressPersistMinPositionMs) {
        return;
      }
      final durationMs = state.duration.inMilliseconds;
      if (durationMs > _progressPersistMinPositionMs &&
          savedMs >= durationMs - _progressPersistTailBufferMs) {
        await _progressDataSource.clearProgress(track);
        return;
      }
      final safePosition = Duration(milliseconds: savedMs);
      await _audioPlayer.seek(safePosition);
      state = state.copyWith(position: safePosition, clearError: true);
      _lastPersistTrackKey = _trackKey(track);
      _lastPersistedPositionMs = savedMs;
      _lastProgressPersistAt = DateTime.now();
    } catch (_) {
      // 恢复失败时保持从头播放。
    }
  }

  void _suppressNextCurrentIndexEvent(int index) {
    _suppressedCurrentIndexEvent = index;
  }

  Future<void> _hydrateHistoryCount() async {
    try {
      final count = await _historyDataSource.getCount();
      state = state.copyWith(historyCount: count, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: _userFacingPlaybackError(error));
    }
  }

  Future<void> _hydrateQueue() async {
    try {
      final snapshot = await _queueDataSource.readQueue();
      if (snapshot == null) {
        return;
      }
      if (snapshot.queue.isEmpty) {
        state = state.copyWith(
          playMode: snapshot.playMode,
          isRadioMode: snapshot.isRadioMode,
          currentRadioId: snapshot.currentRadioId,
          clearCurrentRadioId: snapshot.currentRadioId == null,
          currentRadioPlatform: snapshot.currentRadioPlatform,
          clearCurrentRadioPlatform: snapshot.currentRadioPlatform == null,
          currentRadioPageIndex: snapshot.currentRadioPageIndex,
          clearCurrentRadioPageIndex: snapshot.currentRadioPageIndex == null,
          previousPlayModeBeforeRadio: snapshot.previousPlayModeBeforeRadio,
          clearPreviousPlayModeBeforeRadio:
              snapshot.previousPlayModeBeforeRadio == null,
          clearQueueSource: true,
          previousQueueSnapshot: snapshot.previousSnapshot,
          clearError: true,
        );
        await _applyPlayMode(snapshot.playMode);
        return;
      }
      final currentTrack = snapshot.queue[snapshot.currentIndex];
      final availableQualities = _availableQualities(currentTrack);
      final selectedQualityName = _resolveSelectedQualityName(
        availableQualities: availableQualities,
      );
      state = state.copyWith(
        queue: snapshot.queue,
        currentIndex: snapshot.currentIndex,
        playMode: snapshot.playMode,
        position: Duration.zero,
        duration: Duration.zero,
        currentAvailableQualities: availableQualities,
        currentSelectedQualityName: selectedQualityName,
        queueSource: snapshot.source,
        previousQueueSnapshot: snapshot.previousSnapshot,
        isRadioMode: snapshot.isRadioMode,
        currentRadioId: snapshot.currentRadioId,
        clearCurrentRadioId: snapshot.currentRadioId == null,
        currentRadioPlatform: snapshot.currentRadioPlatform,
        clearCurrentRadioPlatform: snapshot.currentRadioPlatform == null,
        currentRadioPageIndex: snapshot.currentRadioPageIndex,
        clearCurrentRadioPageIndex: snapshot.currentRadioPageIndex == null,
        previousPlayModeBeforeRadio: snapshot.previousPlayModeBeforeRadio,
        clearPreviousPlayModeBeforeRadio:
            snapshot.previousPlayModeBeforeRadio == null,
        clearError: true,
      );
      await _applyPlayMode(snapshot.playMode);
      final resolution = await _resolveQueueTrackForPlayback(
        snapshot.queue,
        snapshot.currentIndex,
      );
      state = state.copyWith(
        queue: resolution.updatedQueue,
        currentAvailableQualities: resolution.availableQualities,
        currentSelectedQualityName: resolution.selectedQualityName,
        clearError: true,
      );
      await _syncQueueToAudioPlayer(
        queue: resolution.updatedQueue,
        currentIndex: snapshot.currentIndex,
        autoplay: false,
        restoreProgress: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _userFacingPlaybackError(error));
    }
  }

  Future<void> _persistQueueState() async {
    final queue = state.queue;
    final previousSnapshot = state.previousQueueSnapshot;
    final hasPreviousSnapshot =
        previousSnapshot != null && previousSnapshot.queue.isNotEmpty;
    if (queue.isEmpty && !hasPreviousSnapshot) {
      await _queueDataSource.clearQueue();
      return;
    }
    await _queueDataSource.saveQueue(
      queue: queue,
      currentIndex: queue.isEmpty ? 0 : _safeCurrentIndex(queue.length),
      playMode: state.playMode,
      isRadioMode: state.isRadioMode,
      currentRadioId: state.currentRadioId,
      currentRadioPlatform: state.currentRadioPlatform,
      currentRadioPageIndex: state.currentRadioPageIndex,
      previousPlayModeBeforeRadio: state.previousPlayModeBeforeRadio,
      source: state.queueSource,
      previousSnapshot: previousSnapshot,
    );
  }

  Future<void> _recordCurrentTrackHistory({int? index}) async {
    final track = _resolveTrack(index ?? state.currentIndex);
    if (track == null) {
      return;
    }
    final historyKey = _trackKey(track);
    if (_lastHistoryTrackKey == historyKey) {
      return;
    }
    try {
      final count = await _historyDataSource.appendTrack(
        track,
        isRadioMode: state.isRadioMode,
        currentRadioId: state.currentRadioId,
        currentRadioPlatform: state.currentRadioPlatform,
        currentRadioPageIndex: state.currentRadioPageIndex,
        previousPlayModeBeforeRadio: state.previousPlayModeBeforeRadio,
      );
      _lastHistoryTrackKey = historyKey;
      state = state.copyWith(historyCount: count, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: _userFacingPlaybackError(error));
    }
  }

  String _userFacingPlaybackError(Object error) {
    final resolved = NetworkErrorMessage.resolve(error)?.trim() ?? '';
    if (resolved.isEmpty) {
      return '播放失败，请稍后重试';
    }
    final lower = resolved.toLowerCase();
    if (lower.contains('invalid /v1/song/url response') ||
        lower.contains('missing url')) {
      return '播放失败，暂时无法获取歌曲链接';
    }
    if (lower.contains('player track is missing') ||
        lower.contains('player queue cannot be empty') ||
        lower.contains('start index is out of range') ||
        lower.contains('initial index is out of range')) {
      return '播放失败，请稍后重试';
    }
    if (lower.contains('status code of 404') ||
        lower == '请求的内容不存在' ||
        lower.contains('not found')) {
      return '播放失败，当前资源不存在';
    }
    if (lower.contains('dioexception') ||
        lower.contains('source error') ||
        lower.contains('platformexception') ||
        lower.contains('failed to load') ||
        lower.contains('exception')) {
      return '播放失败，请稍后重试';
    }
    return resolved;
  }

  PlayerTrack? _resolveTrack(int index) {
    final queue = state.queue;
    if (index < 0 || index >= queue.length) {
      return null;
    }
    return queue[index];
  }

  String _trackKey(PlayerTrack track) {
    final id = track.id.trim();
    if (id.isEmpty) {
      return '';
    }
    final platform = (track.platform ?? '').trim();
    if (platform == 'local') {
      return id;
    }
    if (platform.isNotEmpty) {
      return '$id|$platform';
    }
    return id;
  }

  PlayerQueueSnapshot? _buildCurrentQueueSnapshot() {
    final queue = state.queue;
    if (queue.isEmpty) {
      return null;
    }
    return PlayerQueueSnapshot(
      queue: List<PlayerTrack>.unmodifiable(queue),
      currentIndex: _safeCurrentIndex(queue.length),
      playMode: state.playMode,
      isRadioMode: state.isRadioMode,
      source: state.queueSource,
      previousSnapshot: state.previousQueueSnapshot,
      currentRadioId: state.currentRadioId,
      currentRadioPlatform: state.currentRadioPlatform,
      currentRadioPageIndex: state.currentRadioPageIndex,
      previousPlayModeBeforeRadio: state.previousPlayModeBeforeRadio,
    );
  }

  bool _isSameQueueContext(
    List<PlayerTrack> nextQueue,
    PlayerQueueSource? nextSource,
  ) {
    final currentQueue = state.queue;
    if (currentQueue.length != nextQueue.length) {
      return false;
    }
    if (!_isSameQueueSource(state.queueSource, nextSource)) {
      return false;
    }
    for (var index = 0; index < currentQueue.length; index++) {
      if (_trackKey(currentQueue[index]) != _trackKey(nextQueue[index])) {
        return false;
      }
    }
    return currentQueue.isNotEmpty;
  }

  bool _isSameRadioContext({
    required bool isRadioMode,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) {
    if (state.isRadioMode != isRadioMode) {
      return false;
    }
    if (!isRadioMode) {
      return true;
    }
    return state.currentRadioId == _normalizeRadioValue(currentRadioId) &&
        state.currentRadioPlatform ==
            _normalizeRadioValue(currentRadioPlatform) &&
        state.currentRadioPageIndex ==
            _normalizeRadioPageIndex(currentRadioPageIndex);
  }

  String? _normalizeRadioValue(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  int? _normalizeRadioPageIndex(int? pageIndex) {
    if (pageIndex == null || pageIndex <= 0) {
      return null;
    }
    return pageIndex;
  }

  bool _isSameQueueSource(PlayerQueueSource? current, PlayerQueueSource? next) {
    if (current == null || next == null) {
      return false;
    }
    if (current.routePath != next.routePath) {
      return false;
    }
    if (current.queryParameters.length != next.queryParameters.length) {
      return false;
    }
    for (final entry in current.queryParameters.entries) {
      if (next.queryParameters[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  Future<void> _upsertQueueTrack({
    required PlayerTrack track,
    required bool insertNext,
    required bool autoplayWhenQueueEmpty,
  }) async {
    await _ensureInitialized();
    final currentQueue = state.queue;
    if (currentQueue.isEmpty) {
      await replaceQueue(
        <PlayerTrack>[track],
        startIndex: _defaultQueueIndex,
        autoplay: autoplayWhenQueueEmpty,
      );
      return;
    }
    final currentIndex = _safeCurrentIndex(currentQueue.length);
    final nextQueue = <PlayerTrack>[...currentQueue];
    if (insertNext) {
      final targetIndex = (currentIndex + 1).clamp(0, nextQueue.length);
      nextQueue.insert(targetIndex, track);
    } else {
      nextQueue.add(track);
    }
    state = state.copyWith(
      queue: nextQueue,
      currentIndex: currentIndex,
      playMode: _resolveNextPlayMode(isRadioMode: false),
      isRadioMode: false,
      clearQueueSource: true,
      clearCurrentRadioId: true,
      clearCurrentRadioPlatform: true,
      clearCurrentRadioPageIndex: true,
      clearPreviousPlayModeBeforeRadio: true,
      clearError: true,
    );
    await _execute(() async {
      await _audioPlayer.setQueue(
        nextQueue.map(_toAudioTrack).toList(growable: false),
        initialIndex: currentIndex,
        forceReloadCurrent: false,
      );
      await _applyPlayMode(state.playMode);
    });
    await _persistQueueState();
  }

  Future<void> playHistoryItem(PlayerHistoryItem item) async {
    await _ensureInitialized();
    if (!item.isRadioMode) {
      await insertNextAndPlay(_historyItemToTrack(item));
      return;
    }
    final radioId = _normalizeRadioValue(item.currentRadioId);
    final radioPlatform = _normalizeRadioValue(item.currentRadioPlatform);
    final radioPageIndex = _normalizeRadioPageIndex(item.currentRadioPageIndex);
    if (radioId == null || radioPlatform == null || radioPageIndex == null) {
      await insertNextAndPlay(_historyItemToTrack(item));
      return;
    }
    final songs = await ref
        .read(radioApiClientProvider)
        .fetchSongs(
          id: radioId,
          platform: radioPlatform,
          pageIndex: radioPageIndex,
        );
    if (songs.isEmpty) {
      await insertNextAndPlay(_historyItemToTrack(item));
      return;
    }
    final tracks = songs.map(_buildRadioTrack).toList(growable: false);
    final targetTrack = _historyItemToTrack(item);
    var startIndex = tracks.indexWhere(
      (track) => _trackKey(track) == _trackKey(targetTrack),
    );
    if (startIndex < 0) {
      startIndex = 0;
    }
    await replaceQueue(
      tracks,
      startIndex: startIndex,
      isRadioMode: true,
      currentRadioId: radioId,
      currentRadioPlatform: radioPlatform,
      currentRadioPageIndex: radioPageIndex,
    );
  }

  Future<void> _handlePlaybackCompleted() async {
    if (!state.isRadioMode) {
      return;
    }
    final queue = state.queue;
    if (queue.isEmpty) {
      return;
    }
    final currentIndex = _safeCurrentIndex(queue.length);
    if (currentIndex != queue.length - 1) {
      return;
    }
    final appended = await _ensureRadioNextPageAppended();
    if (appended && state.queue.length > currentIndex + 1) {
      await playAt(currentIndex + 1);
    }
  }

  Future<bool> _ensureRadioNextPageAppended() async {
    if (_isLoadingRadioNextPage) {
      return false;
    }
    final radioId = _normalizeRadioValue(state.currentRadioId);
    final radioPlatform = _normalizeRadioValue(state.currentRadioPlatform);
    final currentPageIndex = _normalizeRadioPageIndex(
      state.currentRadioPageIndex,
    );
    if (!state.isRadioMode ||
        radioId == null ||
        radioPlatform == null ||
        currentPageIndex == null) {
      return false;
    }
    _isLoadingRadioNextPage = true;
    try {
      final nextPageIndex = currentPageIndex + 1;
      final songs = await ref
          .read(radioApiClientProvider)
          .fetchSongs(
            id: radioId,
            platform: radioPlatform,
            pageIndex: nextPageIndex,
          );
      if (songs.isEmpty) {
        return false;
      }
      final currentQueue = state.queue;
      final existingKeys = currentQueue.map(_trackKey).toSet();
      final appendedTracks = songs
          .map(_buildRadioTrack)
          .where((track) => !existingKeys.contains(_trackKey(track)))
          .toList(growable: false);
      if (appendedTracks.isEmpty) {
        state = state.copyWith(
          currentRadioPageIndex: nextPageIndex,
          clearError: true,
        );
        await _persistQueueState();
        return false;
      }
      state = state.copyWith(
        queue: <PlayerTrack>[...currentQueue, ...appendedTracks],
        currentRadioPageIndex: nextPageIndex,
        clearError: true,
      );
      await _execute(() async {
        await _audioPlayer.setQueue(
          state.queue.map(_toAudioTrack).toList(growable: false),
          initialIndex: _safeCurrentIndex(state.queue.length),
          forceReloadCurrent: false,
        );
        await _applyPlayMode(state.playMode);
      });
      await _persistQueueState();
      return true;
    } finally {
      _isLoadingRadioNextPage = false;
    }
  }

  PlayerPlayMode _resolveNextPlayMode({required bool isRadioMode}) {
    if (isRadioMode) {
      return PlayerPlayMode.sequence;
    }
    if (state.isRadioMode) {
      return state.previousPlayModeBeforeRadio ?? state.playMode;
    }
    return state.playMode;
  }

  PlayerPlayMode? _resolvePreviousPlayModeBeforeRadio({
    required bool isRadioMode,
  }) {
    if (!isRadioMode) {
      return null;
    }
    if (state.isRadioMode) {
      return state.previousPlayModeBeforeRadio;
    }
    return state.playMode;
  }

  PlayerTrack _historyItemToTrack(PlayerHistoryItem item) {
    final platform = item.platform?.trim() ?? '';
    return PlayerTrack(
      id: item.id,
      title: item.title.isEmpty ? item.id : item.title,
      artist: item.artist,
      album: item.album.isEmpty ? null : item.album,
      url: platform == 'local' ? item.url : '',
      artworkUrl: item.artworkUrl.isEmpty ? null : item.artworkUrl,
      platform: platform.isEmpty ? null : platform,
    );
  }

  PlayerTrack _buildRadioTrack(SongInfo song) {
    final platformId = song.platform.trim();
    final config = ref.read(appConfigProvider);
    final platforms =
        ref.read(onlinePlatformsProvider).valueOrNull ??
        const <OnlinePlatform>[];
    final coverUrl = resolveSongCoverUrl(
      baseUrl: config.apiBaseUrl,
      token: config.authToken ?? '',
      platforms: platforms,
      platformId: platformId,
      songId: song.id,
      cover: song.cover,
      size: 300,
    );
    final localPath = song.path?.trim();
    return PlayerTrack(
      id: song.id,
      title: song.title,
      path: localPath == null || localPath.isEmpty ? null : localPath,
      duration: song.duration > 0
          ? Duration(milliseconds: song.duration)
          : null,
      links: song.links,
      artist: song.artist,
      albumId: song.album?.id,
      album: song.album?.name,
      artists: song.artists,
      mvId: song.mvId,
      artworkUrl: coverUrl.isEmpty ? null : coverUrl,
      platform: platformId,
    );
  }

  int _randomNextIndex(int queueLength, {required int excluding}) {
    if (queueLength <= 1) {
      return _defaultQueueIndex;
    }
    var nextIndex = excluding;
    while (nextIndex == excluding) {
      nextIndex = _random.nextInt(queueLength);
    }
    return nextIndex;
  }

  int _safeCurrentIndex(int queueLength) {
    if (queueLength <= 0) {
      return _defaultQueueIndex;
    }
    final index = state.currentIndex;
    if (index < 0 || index >= queueLength) {
      return _defaultQueueIndex;
    }
    return index;
  }

  void _validateQueueInput(List<PlayerTrack> queue, int startIndex) {
    if (queue.isEmpty) {
      throw const AppException(
        ValidationFailure('Player queue cannot be empty.'),
      );
    }
    final maxIndex = queue.length - 1;
    if (startIndex < 0 || startIndex > maxIndex) {
      throw const AppException(
        ValidationFailure('Start index is out of range for the player queue.'),
      );
    }
  }
}

class _TrackPlaybackResolution {
  const _TrackPlaybackResolution({
    required this.track,
    required this.updatedQueue,
    required this.availableQualities,
    required this.selectedQualityName,
  });

  final PlayerTrack track;
  final List<PlayerTrack> updatedQueue;
  final List<PlayerQualityOption> availableQualities;
  final String? selectedQualityName;
}

class _StaleTrackSwitchException implements Exception {
  const _StaleTrackSwitchException();
}
