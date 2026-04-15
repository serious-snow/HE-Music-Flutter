import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/desktop_page_shell.dart';
import '../../../my/presentation/pages/my_page.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../player/presentation/widgets/mini_player_bar.dart';
import '../../../player/presentation/widgets/player_queue_panel.dart';
import '../providers/home_discover_providers.dart';
import '../widgets/discover_home_tab.dart';

const _tabHome = 0;
const _tabMy = 1;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _tabIndex = _tabHome;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab == 'my' ? _tabMy : _tabHome;
    Future.microtask(() {
      ref.read(playerControllerProvider.notifier).initialize();
      ref.read(homeDiscoverControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    return DesktopPageShell(
      desktopLayoutBreakpoint: playerQueuePanelBreakpoint,
      desktopSidebar: _HomeNavigationRail(
        selectedIndex: _tabIndex,
        homeLabel: AppI18n.t(config, 'tab.home'),
        myLabel: AppI18n.t(config, 'tab.my'),
        onDestinationSelected: _onDestinationSelected,
      ),
      desktopRightPanel: const PlayerQueuePanelOverlay(),
      desktopRightPanelBreakpoint: playerQueuePanelBreakpoint,
      persistentFooter: MiniPlayerBar(
        onOpenFullPlayer: () => context.push(AppRoutes.player),
      ),
      mobileBottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(20),
            shadowColor: Colors.black.withValues(alpha: 0.06),
            child: NavigationBar(
              selectedIndex: _tabIndex,
              backgroundColor: Colors.transparent,
              indicatorColor: theme.colorScheme.primaryContainer,
              onDestinationSelected: _onDestinationSelected,
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: AppI18n.t(config, 'tab.home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.account_circle_outlined),
                  selectedIcon: const Icon(Icons.account_circle_rounded),
                  label: AppI18n.t(config, 'tab.my'),
                ),
              ],
            ),
          ),
        ),
      ),
      child: IndexedStack(
        index: _tabIndex,
        children: const <Widget>[DiscoverHomeTab(), MyPage()],
      ),
    );
  }

  void _onDestinationSelected(int index) {
    if (_tabIndex == index) {
      return;
    }
    setState(() {
      _tabIndex = index;
    });
  }
}

class _HomeNavigationRail extends StatelessWidget {
  const _HomeNavigationRail({
    required this.selectedIndex,
    required this.homeLabel,
    required this.myLabel,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final String homeLabel;
  final String myLabel;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.85,
      onDestinationSelected: onDestinationSelected,
      destinations: <NavigationRailDestination>[
        NavigationRailDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: Text(homeLabel),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.account_circle_outlined),
          selectedIcon: const Icon(Icons.account_circle_rounded),
          label: Text(myLabel),
        ),
      ],
    );
  }
}
