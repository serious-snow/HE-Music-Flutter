import 'package:flutter_lyric/core/lyric_model.dart' as flm;
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/lyric_panel.dart';

void main() {
  test('buildFlutterLyricModel should pass lyric offset to flutter_lyric', () {
    const document = LyricDocument(
      offset: 180,
      lines: <LyricLine>[LyricLine(start: Duration(seconds: 1), text: '第一句')],
    );

    final model = buildFlutterLyricModel(document);

    expect(model, isA<flm.LyricModel>());
    expect(model.offset, 180);
    expect(model.lines, hasLength(1));
    expect(model.lines.single.text, '第一句');
  });
}
