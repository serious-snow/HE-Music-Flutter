import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../shared/utils/compact_number_formatter.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/video_detail_content.dart';
import '../../domain/entities/video_detail_link.dart';
import '../../domain/entities/video_detail_request.dart';
import '../providers/video_detail_providers.dart';

class VideoDetailPage extends ConsumerStatefulWidget {
  const VideoDetailPage({
    required this.id,
    required this.platform,
    required this.title,
    super.key,
  });

  final String id;
  final String platform;
  final String title;

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends ConsumerState<VideoDetailPage> {
  static const Duration _controlsAutoHideDelay = Duration(seconds: 3);
  static const Duration _gestureHudAutoHideDelay = Duration(milliseconds: 900);

  late final VideoDetailRequest _request;
  final ScreenBrightness _screenBrightness = ScreenBrightness.instance;
  final VolumeController _volumeController = VolumeController.instance;
  VideoPlayerController? _videoController;
  String? _activeSourceKey;
  bool _playerLoading = false;
  String? _playerError;
  bool _isFullscreen = false;
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  Timer? _gestureHudTimer;
  double? _initialApplicationBrightness;
  double? _currentApplicationBrightness;
  double? _currentSystemVolume;
  _FullscreenGestureHud? _gestureHud;

  @override
  void initState() {
    super.initState();
    _volumeController.showSystemUI = false;
    _request = VideoDetailRequest(
      id: widget.id,
      platform: widget.platform,
      title: widget.title,
    );
    Future.microtask(() async {
      final playerState = ref.read(playerControllerProvider);
      if (playerState.isPlaying) {
        await ref.read(playerControllerProvider.notifier).togglePlayPause();
      }
      await ref
          .read(videoDetailControllerProvider.notifier)
          .initialize(_request);
    });
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _gestureHudTimer?.cancel();
    final controller = _videoController;
    _videoController = null;
    controller?.dispose();
    unawaited(_restoreWindowModeAndBrightness());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoDetailControllerProvider);
    final controller = ref.read(videoDetailControllerProvider.notifier);
    final content = state.content;

    if (content != null) {
      _maybePreparePlayer(content);
    }

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_isFullscreen) {
          return;
        }
        unawaited(_exitFullscreen());
      },
      child: Scaffold(
        body: Column(
          children: <Widget>[
            Expanded(
              child: state.loading && content == null
                  ? _LoadingView(title: widget.title)
                  : state.errorMessage != null && content == null
                  ? _ErrorView(
                      title: widget.title,
                      message: state.errorMessage!,
                      onRetry: () => controller.retry(_request),
                    )
                  : _buildBody(context, content),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, VideoDetailContent? content) {
    if (content == null) {
      return _ErrorView(
        title: widget.title,
        message: '暂无视频详情',
        onRetry: () =>
            ref.read(videoDetailControllerProvider.notifier).retry(_request),
      );
    }
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final selectedLink = _selectedLink(content);
    final videoController = _videoController;
    final title = content.title.isEmpty ? widget.title : content.title;
    final topInset = MediaQuery.paddingOf(context).top;

    if (_isFullscreen) {
      return ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Center(
                child: _VideoStage(
                  controller: videoController,
                  loading: _playerLoading,
                  errorText: _playerError,
                  coverUrl: content.coverUrl,
                  onTogglePlay: _toggleVideoPlayPause,
                  onToggleFullscreen: _toggleFullscreen,
                  onSurfaceTap: _toggleControlsVisibility,
                  onBrightnessDragStart: _handleBrightnessDragStart,
                  onBrightnessDragUpdate: _handleBrightnessDragUpdate,
                  onVolumeDragStart: _handleVolumeDragStart,
                  onVolumeDragUpdate: _handleVolumeDragUpdate,
                  onGestureDragEnd: _handleGestureDragEnd,
                  isFullscreen: _isFullscreen,
                  controlsVisible: _controlsVisible,
                ),
              ),
              if (_gestureHud != null)
                Center(child: _FullscreenGestureHudView(hud: _gestureHud!)),
              if (_controlsVisible)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _TopOverlayButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: _handleBack,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFFF2F5F3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 0),
              child: Row(
                children: <Widget>[
                  Material(
                    color: const Color(0xFFE8EEEB),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _handleBack,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF243231),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF101615),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: <Widget>[
                    _VideoStage(
                      controller: videoController,
                      loading: _playerLoading,
                      errorText: _playerError,
                      coverUrl: content.coverUrl,
                      onTogglePlay: _toggleVideoPlayPause,
                      onToggleFullscreen: _toggleFullscreen,
                      onSurfaceTap: _toggleControlsVisibility,
                      onBrightnessDragStart: null,
                      onBrightnessDragUpdate: null,
                      onVolumeDragStart: null,
                      onVolumeDragUpdate: null,
                      onGestureDragEnd: null,
                      isFullscreen: _isFullscreen,
                      controlsVisible: _controlsVisible,
                    ),
                    if (!_controlsVisible && !_playerLoading)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.34),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _currentTimeLabel(videoController),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFDFC),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF0E1715).withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '视频信息',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF101615),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _VideoInfoRow(label: '标题', value: title),
                      if (content.creator.trim().isNotEmpty)
                        _VideoInfoRow(
                          label: '作者',
                          value: content.creator.trim(),
                        ),
                      _VideoInfoRow(
                        label: '播放量',
                        value: content.playCount.isEmpty
                            ? '0'
                            : formatCompactPlayCount(content.playCount, locale),
                      ),
                      _VideoInfoRow(
                        label: '时长',
                        value: content.duration > 0
                            ? formatDurationSecondsLabel('${content.duration}')
                            : '--:--',
                      ),
                      if (selectedLink != null)
                        _VideoInfoRow(
                          label: '清晰度',
                          value: selectedLink.qualityLabel,
                        ),
                      if (content.links.length > 1) ...<Widget>[
                        const SizedBox(height: 18),
                        Text(
                          '清晰度切换',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '切换时保留当前进度',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF7A8585),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: content.links
                              .map((link) {
                                final selected =
                                    selectedLink?.cacheKey == link.cacheKey;
                                return ChoiceChip(
                                  label: Text(link.qualityLabel),
                                  showCheckmark: false,
                                  selected: selected,
                                  backgroundColor: const Color(0xFFF6F7F7),
                                  selectedColor: const Color(0xFFECEFF0),
                                  side: BorderSide(
                                    color: selected
                                        ? const Color(0xFFCFD6D7)
                                        : const Color(0xFFE3E7E7),
                                  ),
                                  labelStyle: theme.textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: const Color(0xFF222222),
                                      ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  onSelected: _playerLoading
                                      ? null
                                      : (_) => unawaited(
                                          _selectSource(content, link),
                                        ),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ],
                      if (content.description.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 18),
                        _VideoInfoRow(
                          label: '简介',
                          value: content.description.trim(),
                          multiline: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _maybePreparePlayer(VideoDetailContent content) {
    final selectedLink = _selectedLink(content);
    if (selectedLink == null) {
      return;
    }
    if (_activeSourceKey == selectedLink.cacheKey || _playerLoading) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_selectSource(content, selectedLink));
    });
  }

  VideoDetailLink? _selectedLink(VideoDetailContent content) {
    if (content.links.isEmpty) {
      return null;
    }
    for (final link in content.links) {
      if (link.cacheKey == _activeSourceKey) {
        return link;
      }
    }
    final sorted = <VideoDetailLink>[...content.links]
      ..sort((a, b) => b.quality.compareTo(a.quality));
    return sorted.first;
  }

  Future<void> _selectSource(
    VideoDetailContent content,
    VideoDetailLink link,
  ) async {
    final previousController = _videoController;
    final snapshot = _capturePlaybackSnapshot(previousController);

    setState(() {
      _playerLoading = true;
      _playerError = null;
    });

    try {
      final uri = _buildVideoUri(content, link);
      final nextController = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: const <String, String>{
          'User-Agent': 'Mozilla/5.0 HE-Music-Flutter VideoPlayer',
        },
      );
      await nextController.initialize();
      if (snapshot.position > Duration.zero) {
        await nextController.seekTo(snapshot.position);
      }
      if (snapshot.wasPlaying || previousController == null) {
        await nextController.play();
      }
      nextController.addListener(_onVideoTick);
      if (!mounted) {
        await nextController.dispose();
        return;
      }
      setState(() {
        _videoController = nextController;
        _activeSourceKey = link.cacheKey;
        _playerLoading = false;
      });
      if (previousController != null) {
        previousController.removeListener(_onVideoTick);
        await previousController.dispose();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playerLoading = false;
        _playerError = '$error';
      });
    }
  }

  Uri _buildVideoUri(VideoDetailContent content, VideoDetailLink link) {
    if (link.url.trim().isNotEmpty) {
      return Uri.parse(link.url.trim());
    }
    final config = ref.read(appConfigProvider);
    final baseUri = Uri.parse(config.apiBaseUrl.trim());
    return baseUri.replace(
      path: '/v1/mv/url',
      queryParameters: <String, String>{
        'id': content.id,
        'platform': content.platform,
        'quality': '${link.quality}',
        'format': link.format.isEmpty ? 'mp4' : link.format,
        'redirect': 'true',
        'token': config.authToken ?? '',
      },
    );
  }

  void _toggleVideoPlayPause() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      unawaited(controller.pause());
    } else {
      unawaited(controller.play());
    }
    _showControlsTemporarily();
    setState(() {});
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      await _exitFullscreen();
      return;
    }
    await _enterFullscreen();
  }

  Future<void> _enterFullscreen() async {
    setState(() => _isFullscreen = true);
    await _primeFullscreenGestureValues();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _showControlsTemporarily();
  }

  Future<void> _exitFullscreen() async {
    await _restoreWindowModeAndBrightness();
    if (mounted) {
      setState(() {
        _isFullscreen = false;
        _gestureHud = null;
      });
    }
    _showControlsTemporarily();
  }

  Future<void> _restoreWindowModeAndBrightness() async {
    await _restoreApplicationBrightness();
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _primeFullscreenGestureValues() async {
    try {
      final brightness = await _screenBrightness.application;
      _initialApplicationBrightness ??= brightness;
      _currentApplicationBrightness = brightness;
    } catch (_) {}
    try {
      _currentSystemVolume = await _volumeController.getVolume();
    } catch (_) {}
  }

  Future<void> _restoreApplicationBrightness() async {
    final initialBrightness = _initialApplicationBrightness;
    _initialApplicationBrightness = null;
    if (initialBrightness == null) {
      return;
    }
    try {
      await _screenBrightness.setApplicationScreenBrightness(initialBrightness);
      _currentApplicationBrightness = initialBrightness;
    } catch (_) {}
  }

  Future<void> _handleBack() async {
    if (_isFullscreen) {
      await _exitFullscreen();
      return;
    }
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  _PlaybackSnapshot _capturePlaybackSnapshot(
    VideoPlayerController? controller,
  ) {
    if (controller == null || !controller.value.isInitialized) {
      return const _PlaybackSnapshot();
    }
    return _PlaybackSnapshot(
      position: controller.value.position,
      wasPlaying: controller.value.isPlaying,
    );
  }

  void _onVideoTick() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleControlsVisibility() {
    final controller = _videoController;
    final isPlaying = controller?.value.isPlaying ?? false;
    if (_controlsVisible) {
      _controlsTimer?.cancel();
      setState(() => _controlsVisible = false);
      return;
    }
    setState(() => _controlsVisible = true);
    if (isPlaying) {
      _scheduleControlsHide();
    }
  }

  void _handleBrightnessDragStart() {
    final value =
        _currentApplicationBrightness ?? _initialApplicationBrightness ?? 0.5;
    _showGestureHud(type: _FullscreenGestureHudType.brightness, value: value);
  }

  void _handleBrightnessDragUpdate(double delta) {
    final currentValue =
        _currentApplicationBrightness ?? _initialApplicationBrightness ?? 0.5;
    final nextValue = (currentValue + delta).clamp(0.02, 1.0).toDouble();
    if ((nextValue - currentValue).abs() < 0.005) {
      return;
    }
    _currentApplicationBrightness = nextValue;
    _showGestureHud(
      type: _FullscreenGestureHudType.brightness,
      value: nextValue,
    );
    unawaited(_screenBrightness.setApplicationScreenBrightness(nextValue));
  }

  void _handleVolumeDragStart() {
    final value = _currentSystemVolume ?? 0.5;
    _showGestureHud(type: _FullscreenGestureHudType.volume, value: value);
  }

  void _handleVolumeDragUpdate(double delta) {
    final currentValue = _currentSystemVolume ?? 0.5;
    final nextValue = (currentValue + delta).clamp(0.0, 1.0).toDouble();
    if ((nextValue - currentValue).abs() < 0.005) {
      return;
    }
    _currentSystemVolume = nextValue;
    _showGestureHud(type: _FullscreenGestureHudType.volume, value: nextValue);
    unawaited(_volumeController.setVolume(nextValue));
  }

  void _handleGestureDragEnd() {
    _gestureHudTimer?.cancel();
    _gestureHudTimer = Timer(_gestureHudAutoHideDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _gestureHud = null);
    });
  }

  void _showGestureHud({
    required _FullscreenGestureHudType type,
    double? value,
  }) {
    _gestureHudTimer?.cancel();
    setState(() {
      _gestureHud = _FullscreenGestureHud(type: type, value: value);
    });
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    final controller = _videoController;
    if (controller?.value.isPlaying ?? false) {
      _scheduleControlsHide();
    }
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(_controlsAutoHideDelay, () {
      if (!mounted) {
        return;
      }
      final controller = _videoController;
      if (controller == null || !controller.value.isPlaying) {
        return;
      }
      setState(() => _controlsVisible = false);
    });
  }

  String _currentTimeLabel(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return '00:00 / 00:00';
    }
    final position = _formatVideoDuration(controller.value.position);
    final duration = _formatVideoDuration(controller.value.duration);
    return '$position / $duration';
  }

  String _formatVideoDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    if (totalSeconds <= 0) {
      return '00:00';
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({
    required this.controller,
    required this.loading,
    required this.errorText,
    required this.coverUrl,
    required this.onTogglePlay,
    required this.onToggleFullscreen,
    required this.onSurfaceTap,
    required this.onBrightnessDragStart,
    required this.onBrightnessDragUpdate,
    required this.onVolumeDragStart,
    required this.onVolumeDragUpdate,
    required this.onGestureDragEnd,
    required this.isFullscreen,
    required this.controlsVisible,
  });

  final VideoPlayerController? controller;
  final bool loading;
  final String? errorText;
  final String coverUrl;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onSurfaceTap;
  final VoidCallback? onBrightnessDragStart;
  final ValueChanged<double>? onBrightnessDragUpdate;
  final VoidCallback? onVolumeDragStart;
  final ValueChanged<double>? onVolumeDragUpdate;
  final VoidCallback? onGestureDragEnd;
  final bool isFullscreen;
  final bool controlsVisible;

  @override
  Widget build(BuildContext context) {
    final player = controller;
    final isReady = player != null && player.value.isInitialized;

    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: isReady ? player.value.aspectRatio : 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (coverUrl.trim().isNotEmpty && !isReady)
              Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            if (isReady) VideoPlayer(player),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.34),
                  ],
                  stops: const <double>[0, 0.48, 1],
                ),
              ),
            ),
            if (loading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (!loading && errorText != null && errorText!.trim().isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    errorText!,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onSurfaceTap),
              ),
            ),
            if (isFullscreen)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight <= 0
                        ? 1.0
                        : constraints.maxHeight;
                    return Row(
                      children: <Widget>[
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: onSurfaceTap,
                            onVerticalDragStart: onBrightnessDragStart == null
                                ? null
                                : (_) => onBrightnessDragStart!.call(),
                            onVerticalDragUpdate: onBrightnessDragUpdate == null
                                ? null
                                : (details) => onBrightnessDragUpdate!.call(
                                    -((details.primaryDelta ?? 0) / height),
                                  ),
                            onVerticalDragEnd: onGestureDragEnd == null
                                ? null
                                : (_) => onGestureDragEnd!.call(),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: onSurfaceTap,
                            onVerticalDragStart: onVolumeDragStart == null
                                ? null
                                : (_) => onVolumeDragStart!.call(),
                            onVerticalDragUpdate: onVolumeDragUpdate == null
                                ? null
                                : (details) => onVolumeDragUpdate!.call(
                                    -((details.primaryDelta ?? 0) / height),
                                  ),
                            onVerticalDragEnd: onGestureDragEnd == null
                                ? null
                                : (_) => onGestureDragEnd!.call(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            if (isReady)
              Align(
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: controlsVisible && !player.value.isPlaying
                      ? 1.0
                      : 0.0,
                  child: IgnorePointer(
                    ignoring: !(controlsVisible && !player.value.isPlaying),
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.42),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onTogglePlay,
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 64,
                          height: 64,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (isReady)
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: controlsVisible ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !controlsVisible,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        VideoProgressIndicator(
                          player,
                          allowScrubbing: true,
                          padding: EdgeInsets.zero,
                          colors: VideoProgressColors(
                            playedColor: Colors.white,
                            bufferedColor: Colors.white.withValues(alpha: 0.42),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: onTogglePlay,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                player.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: onToggleFullscreen,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                isFullscreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Spacer(),
                            Text(
                              '${_formatVideoDuration(player.value.position)} / ${_formatVideoDuration(player.value.duration)}',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatVideoDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    if (totalSeconds <= 0) {
      return '00:00';
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PlaybackSnapshot {
  const _PlaybackSnapshot({
    this.position = Duration.zero,
    this.wasPlaying = false,
  });

  final Duration position;
  final bool wasPlaying;
}

enum _FullscreenGestureHudType { brightness, volume }

class _FullscreenGestureHud {
  const _FullscreenGestureHud({required this.type, this.value});

  final _FullscreenGestureHudType type;
  final double? value;
}

class _TopOverlayButton extends StatelessWidget {
  const _TopOverlayButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.26),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _FullscreenGestureHudView extends StatelessWidget {
  const _FullscreenGestureHudView({required this.hud});

  final _FullscreenGestureHud hud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = hud.type == _FullscreenGestureHudType.brightness
        ? Icons.light_mode_rounded
        : Icons.volume_up_rounded;
    final label = hud.type == _FullscreenGestureHudType.brightness
        ? '亮度'
        : '音量';
    final percent = ((hud.value ?? 0) * 100).round().clamp(0, 100);
    final progress = (hud.value ?? 0).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Container(
        width: 152,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 24, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              '$label $percent%',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoInfoRow extends StatelessWidget {
  const _VideoInfoRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 58,
            child: Text(
              '$label：',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6C7777),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: multiline ? null : 1,
              overflow: multiline
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF15201F),
                fontWeight: FontWeight.w700,
                height: multiline ? 1.55 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text('正在加载视频：$title'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
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
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
