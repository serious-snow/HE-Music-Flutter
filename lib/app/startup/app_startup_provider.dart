import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_controller.dart';
import '../i18n/app_i18n.dart';
import '../../features/my/presentation/providers/favorite_collection_status_providers.dart';
import '../../features/my/presentation/providers/favorite_song_status_providers.dart';
import '../../features/online/presentation/providers/online_providers.dart';

/// App 启动初始化：先拉取 platforms 并缓存到内存，后续功能页直接复用。
final appStartupProvider = FutureProvider<void>((ref) async {
  final apiBaseUrl = ref.read(appConfigProvider).apiBaseUrl.trim();
  if (apiBaseUrl.isEmpty) {
    final config = ref.read(appConfigProvider);
    throw StateError(AppI18n.t(config, 'startup.config_missing'));
  }
  try {
    await ref.read(onlinePlatformsProvider.future);
  } catch (_) {
    // 启动阶段不再把 platforms 预热失败当成致命错误；
    // 后续页面会按各自链路重试或回退到独立拉取。
  }
  final token = ref.read(appConfigProvider).authToken?.trim() ?? '';
  if (token.isEmpty) {
    return;
  }
  try {
    await ref.read(favoriteSongStatusProvider.notifier).refresh();
  } catch (_) {
    // 启动阶段不再把喜欢歌曲状态预热失败当成致命错误；
    // 后续页面会按各自链路重试或在交互时更新状态。
  }
  try {
    await ref.read(favoriteCollectionStatusProvider.notifier).refresh();
  } catch (_) {
    // 启动阶段不再把收藏状态预热失败当成致命错误；
    // 后续页面会按各自链路重试或在交互时更新状态。
  }
});
