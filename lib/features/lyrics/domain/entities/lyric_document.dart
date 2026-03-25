import 'lyric_line.dart';

class LyricDocument {
  const LyricDocument({required this.lines});

  const LyricDocument.empty() : lines = const <LyricLine>[];

  final List<LyricLine> lines;

  bool get isEmpty => lines.isEmpty;

  bool get hasWordTiming => lines.any((line) => line.hasWordTiming);
}
