import 'package:flutter/material.dart';

import '../../../../shared/widgets/plaza_loading_skeleton.dart';

class OnlineSearchHotPanel extends StatelessWidget {
  const OnlineSearchHotPanel({
    required this.historyKeywords,
    required this.hotKeywords,
    required this.loadingHistory,
    required this.loadingHot,
    required this.onTapKeyword,
    required this.onClearHistory,
    super.key,
  });

  final List<String> historyKeywords;
  final List<String> hotKeywords;
  final bool loadingHistory;
  final bool loadingHot;
  final ValueChanged<String> onTapKeyword;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      children: <Widget>[
        _SectionHeader(
          title: '搜索历史',
          trailing: IconButton(
            onPressed: onClearHistory,
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ),
        if (loadingHistory)
          const KeywordWrapSkeleton(
            itemWidths: <double>[86, 72, 94, 68, 88, 76],
          )
        else if (historyKeywords.isEmpty)
          const _SectionEmpty(text: '暂无搜索历史')
        else
          _KeywordWrap(items: historyKeywords, onTap: onTapKeyword),
        const SizedBox(height: 14),
        const _SectionHeader(title: '热门搜索'),
        if (loadingHot)
          const HotKeywordListSkeleton()
        else if (hotKeywords.isEmpty)
          const _SectionEmpty(text: '暂无热门搜索')
        else
          _HotKeywordList(items: hotKeywords, onTap: onTapKeyword),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        if (trailing != null) ...<Widget>[trailing!],
      ],
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _KeywordWrap extends StatelessWidget {
  const _KeywordWrap({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => _KeywordTag(label: item, onTap: () => onTap(item)))
          .toList(growable: false),
    );
  }
}

class _KeywordTag extends StatelessWidget {
  const _KeywordTag({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Material(
      color: fill.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
    );
  }
}

class _HotKeywordList extends StatelessWidget {
  const _HotKeywordList({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final displayed = items.take(12).toList(growable: false);
    return Column(
      children: displayed
          .asMap()
          .entries
          .map((entry) {
            final rank = entry.key + 1;
            final keyword = entry.value;
            return InkWell(
              onTap: () => onTap(keyword),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$rank',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: rank <= 3
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        keyword,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
