import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/presentation/pages/local_library_page.dart';

void main() {
  testWidgets('local library page uses standard app bar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LocalLibraryPage())),
    );

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('本地歌曲'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
    expect(find.byIcon(Icons.clear_all_rounded), findsOneWidget);
  });
}
