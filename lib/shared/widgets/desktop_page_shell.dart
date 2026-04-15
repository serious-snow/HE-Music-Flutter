import 'package:flutter/material.dart';

import '../constants/layout_tokens.dart';

class DesktopPageShell extends StatelessWidget {
  const DesktopPageShell({
    required this.child,
    this.desktopSidebar,
    this.desktopRightPanel,
    this.desktopLayoutBreakpoint = LayoutTokens.desktopBreakpoint,
    this.desktopRightPanelBreakpoint = LayoutTokens.desktopBreakpoint,
    this.persistentFooter,
    this.mobileBottomBar,
    this.maxContentWidth = LayoutTokens.desktopContentMaxWidth,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    super.key,
  });

  final Widget child;
  final Widget? desktopSidebar;
  final Widget? desktopRightPanel;
  final double desktopLayoutBreakpoint;
  final double desktopRightPanelBreakpoint;
  final Widget? persistentFooter;
  final Widget? mobileBottomBar;
  final double maxContentWidth;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopLayout =
            constraints.maxWidth >= desktopLayoutBreakpoint;
        final showDesktopRightPanel =
            constraints.maxWidth >= desktopRightPanelBreakpoint;
        return Scaffold(
          body: Stack(
            children: <Widget>[
              SafeArea(
                bottom: false,
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          if (useDesktopLayout &&
                              desktopSidebar != null) ...<Widget>[
                            SizedBox(
                              width: LayoutTokens.desktopRailWidth,
                              child: desktopSidebar,
                            ),
                            const VerticalDivider(width: 1),
                          ],
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: useDesktopLayout
                                      ? maxContentWidth
                                      : double.infinity,
                                ),
                                child: Padding(
                                  padding: contentPadding,
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (persistentFooter != null) ...<Widget>[
                      persistentFooter!,
                    ],
                  ],
                ),
              ),
              if (showDesktopRightPanel && desktopRightPanel != null)
                Positioned.fill(child: desktopRightPanel!),
            ],
          ),
          bottomNavigationBar: useDesktopLayout ? null : mobileBottomBar,
        );
      },
    );
  }
}
