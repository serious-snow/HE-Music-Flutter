import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../providers/online_providers.dart';

enum _CommentTabType { hot, newest }

extension on _CommentTabType {
  String label(String localeCode) {
    return switch (this) {
      _CommentTabType.hot => AppI18n.tByLocaleCode(
        localeCode,
        'comments.tab.hot',
      ),
      _CommentTabType.newest => AppI18n.tByLocaleCode(
        localeCode,
        'comments.tab.newest',
      ),
    };
  }

  bool get isHot => this == _CommentTabType.hot;
}

class OnlineCommentsPage extends ConsumerStatefulWidget {
  const OnlineCommentsPage({
    required this.resourceId,
    required this.resourceType,
    required this.platform,
    this.title,
    super.key,
  });

  final String resourceId;
  final String resourceType;
  final String platform;
  final String? title;

  @override
  ConsumerState<OnlineCommentsPage> createState() => _OnlineCommentsPageState();
}

class _OnlineCommentsPageState extends ConsumerState<OnlineCommentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: _CommentTabType.values.length,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final pageTitle = widget.title == null || widget.title!.trim().isEmpty
        ? AppI18n.t(config, 'comments.title')
        : '${widget.title} · ${AppI18n.t(config, 'comments.title')}';
    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            tooltip: AppI18n.t(config, 'common.back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(pageTitle),
          scrolledUnderElevation: 0,
        ),
        body: Column(
          children: <Widget>[
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TabBar(
                controller: _tabController,
                tabAlignment: TabAlignment.start,
                isScrollable: true,
                tabs: _CommentTabType.values
                    .map((type) => Tab(text: type.label(config.localeCode)))
                    .toList(growable: false),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _CommentTabType.values
                    .map(
                      (type) => _CommentTabPane(
                        key: PageStorageKey<String>(
                          'comment-pane-${type.name}',
                        ),
                        tabType: type,
                        resourceId: widget.resourceId,
                        resourceType: widget.resourceType,
                        platform: widget.platform,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTabPane extends ConsumerStatefulWidget {
  const _CommentTabPane({
    required this.tabType,
    required this.resourceId,
    required this.resourceType,
    required this.platform,
    super.key,
  });

  final _CommentTabType tabType;
  final String resourceId;
  final String resourceType;
  final String platform;

  @override
  ConsumerState<_CommentTabPane> createState() => _CommentTabPaneState();
}

class _CommentTabPaneState extends ConsumerState<_CommentTabPane>
    with AutomaticKeepAliveClientMixin<_CommentTabPane> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _pageIndex = 1;
  String _lastId = '';
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_refresh);
  }

  @override
  void didUpdateWidget(covariant _CommentTabPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.tabType != widget.tabType ||
        oldWidget.resourceId != widget.resourceId ||
        oldWidget.resourceType != widget.resourceType ||
        oldWidget.platform != widget.platform;
    if (!changed) {
      return;
    }
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _comments.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (_error != null && _comments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 160),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: <Widget>[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _refresh, child: const Text('重试')),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        itemCount: _comments.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _comments.length) {
            return _CommentFooter(
              loadingMore: _loadingMore,
              hasMore: _hasMore,
              error: _error,
              hasComments: _comments.isNotEmpty,
              onRetry: _loadMore,
            );
          }
          final item = _comments[index];
          return _CommentCard(
            comment: item,
            onViewAllReplies: () => _openReplies(item),
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadingMore = false;
      _hasMore = true;
      _pageIndex = 1;
      _lastId = '';
      _error = null;
      _comments.clear();
    });
    await _loadPage(reset: true);
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) {
      return;
    }
    await _loadPage(reset: false);
  }

  Future<void> _loadPage({required bool reset}) async {
    if (_loadingMore) {
      return;
    }
    if (!reset) {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await ref
          .read(onlineApiClientProvider)
          .fetchCommentPage(
            resourceId: widget.resourceId,
            resourceType: widget.resourceType,
            platform: widget.platform,
            pageIndex: _pageIndex,
            pageSize: _pageSize,
            lastId: _lastId.isEmpty ? null : _lastId,
            isHot: widget.tabType.isHot,
          );
      if (!mounted) {
        return;
      }
      final next = result.list
          .map<Map<String, dynamic>>(_normalizeComment)
          .toList(growable: false);
      setState(() {
        _comments.addAll(next);
        _hasMore = result.hasMore;
        _lastId = result.lastId;
        _pageIndex += 1;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = '$error';
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 180) {
      return;
    }
    unawaited(_loadMore());
  }

  void _openReplies(Map<String, dynamic> parentComment) {
    final parentId = _asText(parentComment['id']) ?? '';
    if (parentId.isEmpty) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ReplySheet(
        resourceId: widget.resourceId,
        resourceType: widget.resourceType,
        platform: widget.platform,
        parentComment: parentComment,
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.onViewAllReplies});

  final Map<String, dynamic> comment;
  final VoidCallback onViewAllReplies;

  @override
  Widget build(BuildContext context) {
    final author = _commentAuthor(comment);
    final content = _commentContent(comment);
    final timeText = _commentTime(comment);
    final ipLocation = _asText(comment['ip_location']);
    final praiseCount = _asInt(comment['praise_count']);
    final replyCount = _asInt(comment['reply_count']);
    final avatar = _commentAvatar(comment);
    final subComments = _asMapList(comment['sub_comments']);
    final preview = subComments.toList(growable: false);
    final hasMoreReplies = replyCount > subComments.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundImage: avatar == null ? null : NetworkImage(avatar),
                child: avatar == null ? const Icon(Icons.person_rounded) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        if (timeText != null)
                          Text(
                            timeText,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        if (ipLocation != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              ipLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CommentContentView(
            content: content,
            textStyle: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                Icons.thumb_up_alt_outlined,
                size: 14,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$praiseCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(width: 14),
              Icon(
                Icons.mode_comment_outlined,
                size: 14,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$replyCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
          if (preview.isNotEmpty || replyCount > 0) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ...preview.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SubCommentPreviewTile(comment: item),
                    ),
                  ),
                  if (hasMoreReplies)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onViewAllReplies,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                        ),
                        child: Text('查看全部回复（$replyCount）'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubCommentPreviewTile extends StatelessWidget {
  const _SubCommentPreviewTile({required this.comment});

  final Map<String, dynamic> comment;

  @override
  Widget build(BuildContext context) {
    final author = _commentAuthor(comment);
    final avatar = _commentAvatar(comment);
    final content = _commentContent(comment);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 10,
          backgroundImage: avatar == null ? null : NetworkImage(avatar),
          child: avatar == null
              ? const Icon(Icons.person_rounded, size: 12)
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CommentContentView(
            content: '$author：$content',
            textStyle: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            allowBlockImages: false,
          ),
        ),
      ],
    );
  }
}

class _CommentFooter extends StatelessWidget {
  const _CommentFooter({
    required this.loadingMore,
    required this.hasMore,
    required this.error,
    required this.hasComments,
    required this.onRetry,
  });

  final bool loadingMore;
  final bool hasMore;
  final String? error;
  final bool hasComments;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (error != null && hasComments) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                error!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 0),
                padding: EdgeInsets.zero,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (!hasMore && hasComments) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            '没有更多了',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}

class _ReplySheet extends ConsumerStatefulWidget {
  const _ReplySheet({
    required this.resourceId,
    required this.resourceType,
    required this.platform,
    required this.parentComment,
  });

  final String resourceId;
  final String resourceType;
  final String platform;
  final Map<String, dynamic> parentComment;

  @override
  ConsumerState<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends ConsumerState<_ReplySheet> {
  static const int _pageSize = 15;

  final List<Map<String, dynamic>> _replies = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _pageIndex = 1;
  String _lastId = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    final totalReplyCount = _asInt(widget.parentComment['reply_count']);
    final parentAuthor = _commentAuthor(widget.parentComment);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LayoutTokens.compactPageGutter,
                6,
                LayoutTokens.compactPageGutter,
                10,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '回复（$totalReplyCount）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    parentAuthor,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _buildReplyList(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyList(BuildContext context) {
    if (_loading && _replies.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (_error != null && _replies.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: <Widget>[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _refresh, child: const Text('重试')),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      itemCount: _replies.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= _replies.length) {
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          if (_hasMore) {
            return Center(
              child: TextButton(
                onPressed: _loadMore,
                child: const Text('加载更多回复'),
              ),
            );
          }
          return const SizedBox(height: 8);
        }
        final item = _replies[index];
        return _ReplyTile(comment: item);
      },
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadingMore = false;
      _hasMore = true;
      _pageIndex = 1;
      _lastId = '';
      _error = null;
      _replies.clear();
    });
    await _loadPage(reset: true);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) {
      return;
    }
    await _loadPage(reset: false);
  }

  Future<void> _loadPage({required bool reset}) async {
    final parentId = _asText(widget.parentComment['id']) ?? '';
    if (parentId.isEmpty) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _hasMore = false;
      });
      return;
    }
    if (!reset) {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await ref
          .read(onlineApiClientProvider)
          .fetchSubCommentPage(
            resourceId: widget.resourceId,
            parentId: parentId,
            resourceType: widget.resourceType,
            platform: widget.platform,
            pageIndex: _pageIndex,
            pageSize: _pageSize,
            lastId: _lastId.isEmpty ? null : _lastId,
          );
      if (!mounted) {
        return;
      }
      final next = result.list
          .map<Map<String, dynamic>>(_normalizeComment)
          .toList(growable: false);
      setState(() {
        _replies.addAll(next);
        _hasMore = result.hasMore;
        _lastId = result.lastId;
        _pageIndex += 1;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = '$error';
      });
    }
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.comment});

  final Map<String, dynamic> comment;

  @override
  Widget build(BuildContext context) {
    final author = _commentAuthor(comment);
    final avatar = _commentAvatar(comment);
    final content = _commentContent(comment);
    final timeText = _commentTime(comment);
    final praiseCount = _asInt(comment['praise_count']);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 14,
                backgroundImage: avatar == null ? null : NetworkImage(avatar),
                child: avatar == null
                    ? const Icon(Icons.person_rounded, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _CommentContentView(
            content: content,
            textStyle: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              if (timeText != null)
                Text(
                  timeText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              const SizedBox(width: 10),
              Icon(
                Icons.thumb_up_alt_outlined,
                size: 14,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$praiseCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentContentView extends StatelessWidget {
  const _CommentContentView({
    required this.content,
    this.textStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.allowBlockImages = true,
  });

  final String content;
  final TextStyle? textStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final bool allowBlockImages;

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? Theme.of(context).textTheme.bodyMedium;
    final normalized = _normalizeCommentSegments(
      _parseCommentSegments(content),
      allowBlockImages: allowBlockImages,
    );
    final hasBlockImage = normalized.any(
      (segment) => segment.type == _CommentSegmentType.blockImage,
    );

    if (!hasBlockImage) {
      return RichText(
        maxLines: maxLines,
        overflow: overflow,
        text: TextSpan(
          style: style,
          children: _buildInlineSpans(
            context: context,
            segments: normalized,
            style: style,
          ),
        ),
      );
    }

    final rows = <Widget>[];
    final buffer = <_CommentSegment>[];
    void flushBuffer() {
      if (buffer.isEmpty) {
        return;
      }
      rows.add(
        RichText(
          text: TextSpan(
            style: style,
            children: _buildInlineSpans(
              context: context,
              segments: List<_CommentSegment>.from(buffer),
              style: style,
            ),
          ),
        ),
      );
      buffer.clear();
    }

    for (final segment in normalized) {
      if (segment.type == _CommentSegmentType.blockImage) {
        flushBuffer();
        rows.add(_CommentImageBlock(url: segment.value));
        continue;
      }
      buffer.add(segment);
    }
    flushBuffer();

    if (rows.isEmpty) {
      return Text('-', style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map(
            (widget) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: widget,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CommentImageBlock extends StatelessWidget {
  const _CommentImageBlock({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _normalizeImageUrl(url);
    return GestureDetector(
      onTap: () => _previewImage(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: SizedBox(
            width: double.infinity,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return Container(
                  height: 110,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 110,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _previewImage(BuildContext context, String imageUrl) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'comment-image-preview',
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.92),
      pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: 8,
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(0, 0, 0, 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '图片预览',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(0, 0, 0, 0.4),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 18,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(0, 0, 0, 0.38),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.zoom_in_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '双指缩放，点击遮罩关闭',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<InlineSpan> _buildInlineSpans({
  required BuildContext context,
  required List<_CommentSegment> segments,
  TextStyle? style,
}) {
  final spans = <InlineSpan>[];
  for (final segment in segments) {
    if (segment.type == _CommentSegmentType.text) {
      if (segment.value.isEmpty) {
        continue;
      }
      spans.add(TextSpan(text: segment.value));
      continue;
    }
    if (segment.type == _CommentSegmentType.inlineImage) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Image.network(
              _normalizeImageUrl(segment.value),
              width: 18,
              height: 18,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.tag_faces_rounded,
                size: 15,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
        ),
      );
      continue;
    }
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: '-', style: style));
  }
  return spans;
}

List<_CommentSegment> _normalizeCommentSegments(
  List<_CommentSegment> source, {
  required bool allowBlockImages,
}) {
  if (allowBlockImages) {
    return source;
  }
  return source
      .map((segment) {
        if (segment.type == _CommentSegmentType.blockImage) {
          return const _CommentSegment(_CommentSegmentType.text, '[图片]');
        }
        return segment;
      })
      .toList(growable: false);
}

List<_CommentSegment> _parseCommentSegments(String raw) {
  final content = raw.trim();
  if (content.isEmpty) {
    return const <_CommentSegment>[
      _CommentSegment(_CommentSegmentType.text, '-'),
    ];
  }
  final imageTagRegex = RegExp(
    r'''<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>''',
    caseSensitive: false,
  );
  final segments = <_CommentSegment>[];
  var cursor = 0;
  for (final match in imageTagRegex.allMatches(content)) {
    if (match.start > cursor) {
      final textPart = _cleanCommentText(
        content.substring(cursor, match.start),
      );
      if (textPart.isNotEmpty) {
        segments.add(_CommentSegment(_CommentSegmentType.text, textPart));
      }
    }
    final tagText = match.group(0) ?? '';
    final src = (match.group(1) ?? '').trim();
    if (src.isNotEmpty) {
      final inline = _isInlineImage(tagText, src);
      segments.add(
        _CommentSegment(
          inline
              ? _CommentSegmentType.inlineImage
              : _CommentSegmentType.blockImage,
          src,
        ),
      );
    }
    cursor = match.end;
  }
  if (cursor < content.length) {
    final tail = _cleanCommentText(content.substring(cursor));
    if (tail.isNotEmpty) {
      segments.add(_CommentSegment(_CommentSegmentType.text, tail));
    }
  }
  if (segments.isEmpty) {
    final fallback = _cleanCommentText(content);
    if (fallback.isNotEmpty) {
      return <_CommentSegment>[
        _CommentSegment(_CommentSegmentType.text, fallback),
      ];
    }
    return const <_CommentSegment>[
      _CommentSegment(_CommentSegmentType.text, '-'),
    ];
  }
  return segments;
}

bool _isInlineImage(String tag, String src) {
  final classValue = _extractTagAttr(tag, 'class')?.toLowerCase() ?? '';
  if (classValue.contains('emoji') || classValue.contains('emj')) {
    return true;
  }
  final width = int.tryParse(_extractTagAttr(tag, 'width') ?? '');
  final height = int.tryParse(_extractTagAttr(tag, 'height') ?? '');
  if ((width != null && width <= 32) || (height != null && height <= 32)) {
    return true;
  }
  final url = src.toLowerCase();
  if (url.contains('/emoji/') || url.contains('emoticon')) {
    return true;
  }
  return false;
}

String? _extractTagAttr(String tag, String attr) {
  final regex = RegExp(
    '$attr\\s*=\\s*["\']([^"\']+)["\']',
    caseSensitive: false,
  );
  final match = regex.firstMatch(tag);
  if (match == null) {
    return null;
  }
  return match.group(1);
}

String _normalizeImageUrl(String raw) {
  final value = raw.trim();
  if (value.startsWith('http://')) {
    return 'https://${value.substring('http://'.length)}';
  }
  return value;
}

String _cleanCommentText(String raw) {
  if (raw.isEmpty) {
    return '';
  }
  var text = raw
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  text = _decodeBasicHtmlEntities(text);
  return text.trim();
}

String _decodeBasicHtmlEntities(String raw) {
  return raw
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}

enum _CommentSegmentType { text, inlineImage, blockImage }

class _CommentSegment {
  const _CommentSegment(this.type, this.value);

  final _CommentSegmentType type;
  final String value;
}

Map<String, dynamic> _normalizeComment(Map<String, dynamic> raw) {
  final subComments = _asMapList(
    raw['sub_comments'],
  ).map<Map<String, dynamic>>(_normalizeComment).toList(growable: false);
  final replyCount = _asInt(raw['reply_count']);
  return <String, dynamic>{
    ...raw,
    'sub_comments': subComments,
    'reply_count': replyCount,
    'praise_count': _asInt(raw['praise_count']),
  };
}

String _commentAuthor(Map<String, dynamic> comment) {
  final user = _asMap(comment['user']);
  final candidates = <dynamic>[
    user['name'],
    user['nickname'],
    comment['nickname'],
    comment['name'],
    user['username'],
    comment['username'],
  ];
  for (final candidate in candidates) {
    final value = _asText(candidate);
    if (value != null) {
      return value;
    }
  }
  return '匿名用户';
}

String _commentContent(Map<String, dynamic> comment) {
  final beReplied = _asMap(comment['be_replied']);
  final replyContent = _asText(beReplied['content']);
  final replyUser = _commentAuthor(beReplied);
  final content =
      _asText(comment['content']) ??
      _asText(comment['text']) ??
      _asText(comment['comment']) ??
      '-';
  if (replyContent != null && replyContent.isNotEmpty) {
    return '$content\n回复 @$replyUser：$replyContent';
  }
  return content;
}

String? _commentAvatar(Map<String, dynamic> comment) {
  final user = _asMap(comment['user']);
  final candidates = <dynamic>[
    user['avatar'],
    user['avatar_url'],
    user['avatarUrl'],
    comment['avatar'],
    comment['avatar_url'],
    comment['avatarUrl'],
  ];
  for (final candidate in candidates) {
    final value = _asText(candidate);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _commentTime(Map<String, dynamic> comment) {
  final candidates = <dynamic>[
    comment['timestamp'],
    comment['time'],
    comment['create_time'],
    comment['createTime'],
    comment['created_at'],
    comment['createdAt'],
  ];
  for (final candidate in candidates) {
    final dateTime = _parseDateTime(candidate);
    if (dateTime != null) {
      return _formatDateTime(dateTime);
    }
  }
  return null;
}

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is int || raw is double) {
    final value = raw is int ? raw : raw.toInt();
    if (value <= 0) {
      return null;
    }
    final milliseconds = value > 9999999999 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  }
  final text = '$raw'.trim();
  if (text.isEmpty) {
    return null;
  }
  final numeric = int.tryParse(text);
  if (numeric != null && numeric > 0) {
    final milliseconds = numeric > 9999999999 ? numeric : numeric * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  }
  return DateTime.tryParse(text)?.toLocal();
}

String _formatDateTime(DateTime dateTime) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} ${two(dateTime.hour)}:${two(dateTime.minute)}';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value.map<Map<String, dynamic>>(_asMap).toList(growable: false);
}

String? _asText(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == '-') {
    return null;
  }
  return text;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse('$value') ?? 0;
}
