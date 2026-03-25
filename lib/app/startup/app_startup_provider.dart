import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_controller.dart';
import '../../features/online/presentation/providers/online_providers.dart';

/// App 启动初始化：先拉取 platforms 并缓存到内存，后续功能页直接复用。
final appStartupProvider = FutureProvider<void>((ref) async {
  final apiBaseUrl = ref.read(appConfigProvider).apiBaseUrl.trim();
  if (apiBaseUrl.isEmpty) {
    throw StateError('未配置接口地址，请检查 assets/app_config.json。');
  }
  try {
    await ref.read(onlinePlatformsProvider.future);
  } catch (_) {
    // 启动阶段不再把 platforms 预热失败当成致命错误；
    // 后续页面会按各自链路重试或回退到独立拉取。
  }
});
