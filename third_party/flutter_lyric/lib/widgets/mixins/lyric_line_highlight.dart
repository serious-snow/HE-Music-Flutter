import 'package:flutter/material.dart';
import 'package:flutter_lyric/widgets/mixins/lyric_layout_mixin.dart';

// 必须混入 TickerProviderStateMixin 才能使用 AnimationController
mixin LyricLineHightlightMixin<T extends StatefulWidget>
    on State<T>, LyricLayoutMixin<T>, TickerProviderStateMixin<T> {
  var activeHighlightWidthNotifier = ValueNotifier(0.0);

  @override
  void initState() {
    controller.activeIndexNotifiter.addListener(_onActiveIndexChange);
    controller.progressNotifier.addListener(updateHighlightWidth);

    super.initState();
  }

  void _onActiveIndexChange() {
    updateHighlightWidth();
  }

  @override
  void dispose() {
    controller.activeIndexNotifiter.removeListener(_onActiveIndexChange);
    controller.progressNotifier.removeListener(updateHighlightWidth);
    activeHighlightWidthNotifier.dispose();
    super.dispose();
  }

  void updateHighlightWidth() {
    final index = controller.activeIndexNotifiter.value;
    final metrics = layout?.metrics ?? [];

    if (index >= metrics.length || index < 0) {
      _animateWidth(0.0);
      return;
    }

    final line = metrics[index];
    var newWidth = 0.0;
    final currentProgress = controller.progressNotifier.value +
        Duration(milliseconds: controller.lyricOffset);

    line.words?.forEach((wordMetric) {
      if (currentProgress >= wordMetric.word.start) {
        newWidth += wordMetric.highlightWidth;
        final endTime = (wordMetric.word.end ?? Duration.zero);
        if (currentProgress < endTime) {
          final wordDuration = (endTime - wordMetric.word.start).inMilliseconds;
          final elapsed =
              (currentProgress - wordMetric.word.start).inMilliseconds;

          if (wordDuration > 0) {
            newWidth -=
                wordMetric.highlightWidth * (1 - elapsed / wordDuration);
          }
        }
      }
    });
    _animateWidth(newWidth);
  }

  void _animateWidth(double newWidth) {
    final currentWidth = activeHighlightWidthNotifier.value;

    if (currentWidth == newWidth) return;
    // 逐字高亮直接跟随当前播放进度，避免固定时长动画带来体感延迟。
    activeHighlightWidthNotifier.value = newWidth;
  }

  Widget buildActiveHighlightWidth(Widget Function(double value) builder) {
    return ValueListenableBuilder<double>(
      valueListenable: activeHighlightWidthNotifier,
      builder: (context, value, child) {
        return builder(value);
      },
    );
  }
}
