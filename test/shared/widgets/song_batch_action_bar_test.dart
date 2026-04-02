import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/song_batch_action_bar.dart';

void main() {
  testWidgets('batch action bar opens bottom sheet actions', (tester) async {
    var playTapped = false;
    var addToQueueTapped = false;
    var addToPlaylistTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: SongBatchActionBar(
            enabled: true,
            onPlayPressed: () {
              playTapped = true;
            },
            onAddToQueuePressed: () {
              addToQueueTapped = true;
            },
            onAddToPlaylistPressed: () {
              addToPlaylistTapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Batch'), findsOneWidget);
    expect(find.text('Play'), findsNothing);

    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Add to Queue'), findsOneWidget);
    expect(find.text('Add to Playlist'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(playTapped, isTrue);

    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Queue'));
    await tester.pumpAndSettle();
    expect(addToQueueTapped, isTrue);

    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Playlist'));
    await tester.pumpAndSettle();
    expect(addToPlaylistTapped, isTrue);
  });
}
