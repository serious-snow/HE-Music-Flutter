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

  testWidgets('song actions sheet shows download action only when provided', (
    tester,
  ) async {
    var downloadTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Column(
                children: <Widget>[
                  FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        coverUrl: null,
                        title: '在线歌曲',
                        subtitle: '在线歌手',
                        hasMv: false,
                        sourceLabel: 'QQ 音乐',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onWatchMv: () {},
                        onCopySongName: () {},
                        onCopySongId: () {},
                        onDownload: () {
                          downloadTapped = true;
                        },
                      );
                    },
                    child: const Text('Open online'),
                  ),
                  FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        coverUrl: null,
                        title: '本地歌曲',
                        subtitle: '本地歌手',
                        hasMv: false,
                        sourceLabel: '本地',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onWatchMv: () {},
                        onCopySongName: () {},
                        onCopySongId: () {},
                      );
                    },
                    child: const Text('Open local'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open online'));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(downloadTapped, isTrue);

    await tester.tap(find.text('Open local'));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsNothing);
  });

  testWidgets('song actions uses anchored context menu on desktop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: Builder(
                    builder: (buttonContext) => FilledButton(
                      onPressed: () {
                        showSongActionsSheet(
                          context: context,
                          anchorContext: buttonContext,
                          coverUrl: null,
                          title: '桌面歌曲',
                          subtitle: '桌面歌手',
                          hasMv: false,
                          sourceLabel: 'QQ 音乐',
                          onPlay: () {},
                          onPlayNext: () {},
                          onAddToPlaylist: () {},
                          onWatchMv: () {},
                          onCopySongName: () {},
                          onCopySongId: () {},
                        );
                      },
                      child: const Text('Open desktop'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open desktop'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(PopupMenuItem<VoidCallback>), findsWidgets);
    expect(find.text('Play'), findsOneWidget);

    final triggerCenter = tester.getCenter(find.text('Open desktop'));
    final popupTopLeft = tester.getTopLeft(find.text('Play'));
    expect(popupTopLeft.dx, greaterThan(triggerCenter.dx - 160));
    expect(popupTopLeft.dy, greaterThan(triggerCenter.dy - 220));
  });

  testWidgets('song actions sheet stays scrollable on small mobile heights', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 520)),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        coverUrl: null,
                        title: '在线歌曲',
                        subtitle: '在线歌手',
                        hasMv: true,
                        sourceLabel: 'QQ 音乐',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onDownload: () {},
                        onAddToUserPlaylist: () {},
                        onWatchMv: () {},
                        onViewComment: () {},
                        albumActionLabel: '查看专辑',
                        onViewAlbum: () {},
                        artistActionLabel: '查看歌手',
                        onViewArtists: () {},
                        onCopySongName: () {},
                        onCopySongShareLink: () {},
                        onSearchSameName: () {},
                        onCopySongId: () {},
                      );
                    },
                    child: const Text('Open compact'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open compact'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
