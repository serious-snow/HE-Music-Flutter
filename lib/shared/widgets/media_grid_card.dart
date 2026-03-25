import 'package:flutter/material.dart';

import '../utils/compact_number_formatter.dart';

const _mediaGridCardRadius = 14.0;
const _mediaGridOverlayFontSize = 10.0;

enum MediaGridCardKind { album, playlist }

class MediaGridCard extends StatelessWidget {
  const MediaGridCard({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    this.caption,
    this.playCount,
    required this.onTap,
    super.key,
  });

  final MediaGridCardKind kind;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String? caption;
  final String? playCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final showSubtitle = subtitle.trim().isNotEmpty;
    final showCaption = (caption ?? '').trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_mediaGridCardRadius + 2),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          _mediaGridCardRadius,
                        ),
                        child: _MediaGridCover(url: coverUrl, kind: kind),
                      ),
                    ),
                    if ((playCount ?? '').trim().isNotEmpty)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.play_arrow_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                formatCompactPlayCount(playCount!, locale),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: _mediaGridOverlayFontSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              if (showSubtitle) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.1,
                  ),
                ),
              ],
              if (showCaption) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaGridCover extends StatelessWidget {
  const _MediaGridCover({required this.url, required this.kind});

  final String url;
  final MediaGridCardKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlbum = kind == MediaGridCardKind.album;
    final fallback = Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Icon(
        isAlbum ? Icons.album_rounded : Icons.queue_music_rounded,
        size: isAlbum ? 28 : 24,
        color: theme.hintColor,
      ),
    );
    if (url.trim().isEmpty) {
      return fallback;
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: 420,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, error, stackTrace) => fallback,
        ),
        if (!isAlbum)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.16),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
