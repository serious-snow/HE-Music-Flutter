import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/domain/repositories/lyric_repository.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';

void main() {
  test('preload ignores stale lyric result from previous request', () async {
    final firstCompleter = Completer<LyricDocument>();
    final secondCompleter = Completer<LyricDocument>();
    final repository = _FakeLyricRepository(
      handlers: <String, Future<LyricDocument> Function()>{
        'qq::song-1': () => firstCompleter.future,
        'qq::song-2': () => secondCompleter.future,
      },
    );
    final container = ProviderContainer(
      overrides: <Override>[
        lyricRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(currentLyricStoreProvider.notifier);
    const firstRequest = LyricRequest(trackId: 'song-1', platform: 'qq');
    const secondRequest = LyricRequest(trackId: 'song-2', platform: 'qq');
    const firstDocument = LyricDocument(
      lines: <LyricLine>[LyricLine(start: Duration.zero, text: '第一首歌词')],
    );
    const secondDocument = LyricDocument(
      lines: <LyricLine>[LyricLine(start: Duration.zero, text: '第二首歌词')],
    );

    final firstFuture = notifier.preload(firstRequest);
    final secondFuture = notifier.preload(secondRequest);

    secondCompleter.complete(secondDocument);
    await secondFuture;
    firstCompleter.complete(firstDocument);
    await firstFuture;

    final state = container.read(currentLyricStoreProvider);
    expect(state.request, secondRequest);
    expect(state.document, isA<AsyncData<LyricDocument>>());
    expect(state.document.requireValue.lines.single.text, '第二首歌词');
  });
}

class _FakeLyricRepository implements LyricRepository {
  _FakeLyricRepository({required this.handlers});

  final Map<String, Future<LyricDocument> Function()> handlers;

  @override
  Future<LyricDocument> fetchLyrics({
    required String trackId,
    String? platform,
    String? localPath,
  }) {
    final key = '${platform ?? ''}::$trackId';
    final handler = handlers[key];
    if (handler == null) {
      throw StateError('缺少 $key 的测试响应');
    }
    return handler();
  }
}
