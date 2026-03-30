import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/music_detail_slivers.dart';

void main() {
  testWidgets('detail sliver app bar action icon follows toolbar color animation', (
    tester,
  ) async {
    const themeIconColor = Colors.teal;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(iconTheme: const IconThemeData(color: themeIconColor)),
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              MusicDetailSliverAppBar(
                title: '测试标题',
                subtitle: '测试副标题',
                coverUrl: '',
                description: '测试描述',
                onBack: () {},
                onShowDescription: () {},
                actions: const <Widget>[
                  Icon(Icons.favorite_border_rounded),
                ],
              ),
              SliverList.builder(
                itemCount: 30,
                itemBuilder: (context, index) =>
                    const SizedBox(height: 60, child: Text('item')),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    expect(
      _iconThemeColor(tester, Icons.favorite_border_rounded)?.toARGB32(),
      Colors.white.toARGB32(),
    );

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(
      _iconThemeColor(tester, Icons.favorite_border_rounded)?.toARGB32(),
      themeIconColor.toARGB32(),
    );
  });
}

Color? _iconThemeColor(WidgetTester tester, IconData icon) {
  final element = tester.element(find.byIcon(icon));
  return IconTheme.of(element).color;
}
