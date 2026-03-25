import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/album/presentation/pages/album_detail_page.dart';
import '../../features/artist/presentation/pages/artist_detail_page.dart';
import '../../features/artist/presentation/pages/artist_plaza_page.dart';
import '../../features/auth/presentation/pages/captcha_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/music_library/presentation/pages/local_library_page.dart';
import '../../features/my/presentation/pages/my_collection_page.dart';
import '../../features/my/presentation/pages/my_history_page.dart';
import '../../features/my/presentation/pages/user_playlist_detail_page.dart';
import '../../features/online/presentation/pages/online_comments_page.dart';
import '../../features/online/presentation/pages/online_page.dart';
import '../../features/online/presentation/pages/online_search_page.dart';
import '../../features/playlist/presentation/pages/playlist_detail_page.dart';
import '../../features/playlist/presentation/pages/playlist_plaza_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/ranking/presentation/pages/ranking_detail_page.dart';
import '../../features/ranking/presentation/pages/ranking_list_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/about_page.dart';
import '../../features/video/presentation/pages/video_detail_page.dart';
import '../../features/video/presentation/pages/video_plaza_page.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: <GoRoute>[
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            LoginPage(redirectLocation: _readOptionalQuery(state, 'redirect')),
      ),
      GoRoute(
        path: AppRoutes.captcha,
        builder: (context, state) => CaptchaPage(
          scene: _readQuery(state, 'scene'),
          meta: _readQuery(state, 'meta'),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.player,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const PlayerPage(),
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final offsetAnimation =
                Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                );
            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            );
            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.library,
        builder: (context, state) => const LocalLibraryPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: AppRoutes.online,
        builder: (context, state) => const OnlinePage(),
      ),
      GoRoute(
        path: AppRoutes.onlineSearch,
        builder: (context, state) => OnlineSearchPage(
          platform: _readQuery(state, 'platform'),
          initialKeyword: _readOptionalQuery(state, 'keyword'),
          initialType: _readOptionalQuery(state, 'type'),
        ),
      ),
      GoRoute(
        path: AppRoutes.onlineComments,
        builder: (context, state) => OnlineCommentsPage(
          resourceId: _readQuery(state, 'id'),
          resourceType: _readQuery(state, 'resource_type'),
          platform: _readQuery(state, 'platform'),
          title: _readOptionalQuery(state, 'title'),
        ),
      ),
      GoRoute(
        path: AppRoutes.discoverDetail,
        builder: (context, state) => ArtistDetailPage(
          id: _readQuery(state, 'id'),
          platform: _readQuery(state, 'platform'),
          title: _readQuery(state, 'title'),
        ),
      ),
      GoRoute(
        path: AppRoutes.artistDetail,
        builder: (context, state) => ArtistDetailPage(
          id: _readQuery(state, 'id'),
          platform: _readQuery(state, 'platform'),
          title: _readQuery(state, 'title'),
        ),
      ),
      GoRoute(
        path: AppRoutes.artistPlaza,
        builder: (context, state) => ArtistPlazaPage(
          initialPlatform: _readOptionalQuery(state, 'platform'),
        ),
      ),
      GoRoute(
        path: AppRoutes.playlistPlaza,
        builder: (context, state) => PlaylistPlazaPage(
          initialPlatform: _readOptionalQuery(state, 'platform'),
        ),
      ),
      GoRoute(
        path: AppRoutes.playlistDetail,
        builder: (context, state) => PlaylistDetailPage(
          id: _readQuery(state, 'id'),
          platform: _readQuery(state, 'platform'),
          title: _readQuery(state, 'title'),
        ),
      ),
      GoRoute(
        path: AppRoutes.albumDetail,
        builder: (context, state) => AlbumDetailPage(
          id: _readQuery(state, 'id'),
          platform: _readQuery(state, 'platform'),
          title: _readQuery(state, 'title'),
        ),
      ),
      GoRoute(
        path: AppRoutes.videoDetail,
        builder: (context, state) => VideoDetailPage(
          id: _readQuery(state, 'id'),
          platform: _readQuery(state, 'platform'),
          title: _readQuery(state, 'title'),
        ),
      ),
      GoRoute(
        path: AppRoutes.videoPlaza,
        builder: (context, state) => VideoPlazaPage(
          initialPlatform: _readOptionalQuery(state, 'platform'),
        ),
      ),
      GoRoute(
        path: AppRoutes.rankingList,
        builder: (context, state) => RankingListPage(
          initialPlatform: _readOptionalQuery(state, 'platform'),
        ),
      ),
      GoRoute(
        path: AppRoutes.rankingDetail,
        builder: (context, state) => RankingDetailPage(
          id: _readQuery(state, 'id'),
          platform: _readQuery(state, 'platform'),
          title: _readOptionalQuery(state, 'title'),
        ),
      ),
      GoRoute(
        path: AppRoutes.myHistory,
        builder: (context, state) => const MyHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.myCollection,
        builder: (context, state) => const MyCollectionPage(),
      ),
      GoRoute(
        path: AppRoutes.userPlaylistDetail,
        builder: (context, state) => UserPlaylistDetailPage(
          id: _readQuery(state, 'id'),
          title: _readOptionalQuery(state, 'title') ?? '歌单',
        ),
      ),
    ],
  );
});

String _readQuery(GoRouterState state, String key) {
  final value = state.uri.queryParameters[key];
  if (value == null || value.isEmpty) {
    throw StateError('Missing query parameter: $key');
  }
  return value;
}

String? _readOptionalQuery(GoRouterState state, String key) {
  final value = state.uri.queryParameters[key];
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}
