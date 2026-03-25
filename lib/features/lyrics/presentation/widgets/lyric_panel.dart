import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart' as flm;
import 'package:flutter_lyric/flutter_lyric.dart' as fl;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_line.dart' as domain;
import '../providers/lyrics_providers.dart';

class LyricPanel extends ConsumerStatefulWidget {
  const LyricPanel({
    required this.emptyText,
    this.compact = false,
    this.onSeek,
    super.key,
  });

  final String emptyText;
  final bool compact;
  final ValueChanged<Duration>? onSeek;

  @override
  ConsumerState<LyricPanel> createState() => _LyricPanelState();
}

class _LyricPanelState extends ConsumerState<LyricPanel> {
  late final fl.LyricController _controller = fl.LyricController();
  String? _loadedKey;
  DateTime? _lastTapSeekAt;
  Duration? _lastTapSeekPosition;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Duration>(lyricPositionProvider, (previous, next) {
      if (_disposed) {
        return;
      }
      _controller.setProgress(next);
    });

    _bindTapToSeekIfNeeded();

    final request = ref.watch(currentLyricRequestProvider);
    final documentAsync = ref.watch(currentLyricDocumentProvider);

    return documentAsync.when(
      data: (document) {
        if (document.isEmpty) {
          return _buildFallback(context);
        }
        _loadDocumentIfNeeded(request?.cacheKey, document);
        return fl.LyricView(
          controller: _controller,
          style: widget.compact ? _compactStyle : _fullStyle,
          width: double.infinity,
          height: double.infinity,
        );
      },
      loading: () => widget.compact
          ? const SizedBox.shrink()
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (error, stackTrace) => widget.compact
          ? const SizedBox.shrink()
          : Center(
              child: Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                ),
              ),
            ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    if (widget.compact) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Text(
        widget.emptyText,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.76),
        ),
      ),
    );
  }

  fl.LyricStyle get _fullStyle {
    return fl.LyricStyles.default1.copyWith(
      textStyle: TextStyle(fontSize: 20, color: Colors.white70),
      activeStyle: TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      translationStyle:TextStyle(fontSize: 14, color: Colors.white70),
      lineGap:16,
      translationLineGap: 4,
      translationActiveColor: Colors.white,
      activeHighlightGradient: const LinearGradient(
        colors: <Color>[Color(0xFF3BB2B8), Color(0xFF42E695)],
      ),
    );
  }

  fl.LyricStyle get _compactStyle {
    return fl.LyricStyles.single.copyWith(
      textAlign: TextAlign.left,
      textStyle: const TextStyle(
        fontSize: 12,
        color: Colors.white70,
        height: 1.0,
      ),
      activeStyle: const TextStyle(
        fontSize: 16,
        height: 1.0,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      translationStyle: const TextStyle(fontSize: 9, color: Colors.white70),
      translationActiveColor: Colors.white,
      activeHighlightGradient: const LinearGradient(
        colors: <Color>[Color(0xFF3BB2B8), Color(0xFF42E695)],
      ),
    );
  }

  void _bindTapToSeekIfNeeded() {
    if (widget.compact || widget.onSeek == null) {
      _controller.cancelOnTapLineCallback();
      return;
    }
    _controller.setOnTapLineCallback(_onTapSeek);
  }

  void _onTapSeek(Duration position) {
    final onSeek = widget.onSeek;
    if (onSeek == null) {
      return;
    }
    final now = DateTime.now();
    final lastAt = _lastTapSeekAt;
    final lastPosition = _lastTapSeekPosition;

    // flutter_lyric 在某些布局下可能一次点击命中多行 rect，导致同一手势触发多次 tapLine。
    // 这里用短时间窗口做去重，保证一次点击只 seek 一次。
    if (lastAt != null &&
        now.difference(lastAt).inMilliseconds < 250 &&
        lastPosition == position) {
      return;
    }
    _lastTapSeekAt = now;
    _lastTapSeekPosition = position;
    onSeek(position);
  }

  void _loadDocumentIfNeeded(String? cacheKey, LyricDocument document) {
    final key = cacheKey ?? 'current';
    if (_loadedKey == key) {
      return;
    }
    _loadedKey = key;
    _controller.loadLyricModel(
      flm.LyricModel(
        lines: document.lines.map(_toLyricLine).toList(growable: false),
      ),
    );
  }

  flm.LyricLine _toLyricLine(domain.LyricLine line) {
    final translation = line.translation.trim();
    final romanization = line.romanization.trim();
    return flm.LyricLine(
      start: line.start,
      end: line.end,
      text: line.text,
      translation: translation.isNotEmpty
          ? translation
          : (romanization.isNotEmpty ? romanization : null),
      words: line.tokens.isEmpty
          ? null
          : line.tokens
                .map(
                  (token) => flm.LyricWord(
                    text: token.text,
                    start: line.start + token.startOffset,
                    end: line.start + token.endOffset,
                  ),
                )
                .toList(growable: false),
    );
  }
}
