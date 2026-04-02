import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/song_actions_sheet.dart';

void main() {
  testWidgets('song actions sheet shows add to playlist when provided', (
    tester,
  ) async {
    var addToPlaylistTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showSongActionsSheet(
                      context: context,
                      coverUrl: null,
                      title: '测试歌曲',
                      subtitle: '测试歌手',
                      hasMv: false,
                      sourceLabel: 'QQ 音乐',
                      onPlay: () {},
                      onPlayNext: () {},
                      onAddToPlaylist: () {},
                      onAddToUserPlaylist: () {
                        addToPlaylistTapped = true;
                      },
                      onWatchMv: () {},
                      onCopySongName: () {},
                      onCopySongId: () {},
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Playlist'), findsWidgets);

    await tester.tap(find.text('Add to Playlist').last);
    await tester.pumpAndSettle();

    expect(addToPlaylistTapped, isTrue);
  });
}
