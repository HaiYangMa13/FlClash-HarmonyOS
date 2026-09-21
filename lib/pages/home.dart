import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _handleToPage(PageLabel pageLabel) {
    globalState.container
        .read(currentPageLabelProvider.notifier)
        .toPage(pageLabel);
  }

  @override
  Widget build(BuildContext context) {
    return HomeBackScopeContainer(
      child: AppSidebarContainer(
        child: Material(
          color: context.colorScheme.surface,
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(navigationStateProvider);
              final systemUiOverlayStyle = ref.read(
                systemUiOverlayStyleStateProvider,
              );
              final isMobile = state.viewMode == ViewMode.mobile;
              final navigationItems = state.navigationItems;
              final currentIndex = state.currentIndex;
              if (!isMobile && !system.isOhos) {
                return child!;
              }
              if (system.isOhos) {
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: systemUiOverlayStyle.copyWith(
                    systemNavigationBarColor: Colors.transparent,
                    systemNavigationBarDividerColor: Colors.transparent,
                  ),
                  child: _OhosNativeTabHost(
                    items: navigationItems,
                    currentIndex: currentIndex,
                    onSelected: (index) {
                      _handleToPage(navigationItems[index].label);
                    },
                    child: child!,
                  ),
                );
              }
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: systemUiOverlayStyle.copyWith(
                  systemNavigationBarColor: context.colorScheme.surfaceContainer,
                  systemNavigationBarDividerColor: Colors.transparent,
                ),
                child: Column(
                  children: [
                    Flexible(
                      flex: 1,
                      child: MediaQuery.removePadding(
                        removeTop: false,
                        removeBottom: true,
                        removeLeft: true,
                        removeRight: true,
                        context: context,
                        child: child!,
                      ),
                    ),
                    NavigationBar(
                      selectedIndex: currentIndex,
                      onDestinationSelected: (index) {
                        _handleToPage(navigationItems[index].label);
                      },
                      destinations: [
                        for (final item in navigationItems)
                          NavigationDestination(
                            icon: item.icon,
                            label: Intl.message(item.label.name),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
            child: Consumer(
              builder: (_, ref, _) {
                final navigationItems = ref
                    .watch(currentNavigationItemsStateProvider)
                    .value;
                final isMobile = ref.watch(isMobileViewProvider);
                return _HomePageView(
                  navigationItems: navigationItems,
                  pageBuilder: (_, index) {
                    final navigationItem = navigationItems[index];
                    final navigationView = navigationItem.builder(context);
                    final view = KeepScope(
                      keep: navigationItem.keep,
                      child: isMobile || system.isOhos
                          ? navigationView
                          : Navigator(
                              pages: [MaterialPage(child: navigationView)],
                              onDidRemovePage: (_) {},
                            ),
                    );
                    return view;
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _OhosNativeTabHost extends ConsumerStatefulWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Widget child;

  const _OhosNativeTabHost({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.child,
  });

  @override
  ConsumerState<_OhosNativeTabHost> createState() => _OhosNativeTabHostState();
}

class _OhosNativeTabHostState extends ConsumerState<_OhosNativeTabHost> {
  Timer? _idleShowTimer;
  bool _tabBarHidden = false;

  @override
  void initState() {
    super.initState();
    app?.onNativeTabSelected = _handleNativeTabSelected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncNativeTabs();
    });
  }

  @override
  void didUpdateWidget(covariant _OhosNativeTabHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemsChanged = oldWidget.items.length != widget.items.length ||
        !_sameItems(oldWidget.items, widget.items);
    if (itemsChanged) {
      _syncNativeTabs();
      return;
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
      app?.setNativeTabIndex(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _idleShowTimer?.cancel();
    if (app?.onNativeTabSelected == _handleNativeTabSelected) {
      app?.onNativeTabSelected = null;
    }
    super.dispose();
  }

  bool _sameItems(List<NavigationItem> a, List<NavigationItem> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label) {
        return false;
      }
    }
    return true;
  }

  void _handleNativeTabSelected(int index) {
    if (index < 0 || index >= widget.items.length) {
      return;
    }
    if (index == widget.currentIndex) {
      return;
    }
    widget.onSelected(index);
  }

  Future<void> _syncNativeTabs() async {
    await app?.syncNativeTabs(
      items: [
        for (final item in widget.items)
          {
            'id': item.label.name,
            'label': Intl.message(item.label.name),
          },
      ],
      index: widget.currentIndex,
    );
  }

  bool _isUserScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      return notification.dragDetails != null;
    }
    if (notification is ScrollUpdateNotification) {
      return notification.dragDetails != null;
    }
    return false;
  }

  void _hideTabBarOnScroll() {
    _idleShowTimer?.cancel();
    if (_tabBarHidden) {
      return;
    }
    _tabBarHidden = true;
    app?.setNativeTabBarVisible(visible: false, mode: 'scroll');
  }

  void _showTabBarAfterScroll() {
    _idleShowTimer?.cancel();
    _idleShowTimer = Timer(const Duration(milliseconds: 280), () {
      if (!_tabBarHidden) {
        return;
      }
      _tabBarHidden = false;
      app?.setNativeTabBarVisible(visible: true, mode: 'scroll');
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_isUserScroll(notification)) {
          _hideTabBarOnScroll();
        } else if (notification is ScrollEndNotification) {
          _showTabBarAfterScroll();
        }
        return false;
      },
      child: widget.child,
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    final pageLabel = ref.read(currentPageLabelProvider);
    return widget.navigationItems.indexWhere((item) => item.label == pageLabel);
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    final isMobile = ref.read(isMobileViewProvider) || system.isOhos;
    commonPrint.log(
      '[tab-nav] toPage label=${pageLabel.name} index=$index '
      'animate=${isAnimateToPage && isMobile && !ignoreAnimateTo} '
      'isMobile=$isMobile ignore=$ignoreAnimateTo',
    );
    if (isAnimateToPage && isMobile && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
      commonPrint.log('[tab-nav] animateToPage done label=${pageLabel.name}');
    } else {
      _pageController.jumpToPage(index);
      commonPrint.log('[tab-nav] jumpToPage done label=${pageLabel.name}');
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(
      currentNavigationItemsStateProvider.select((state) => state.value.length),
    );
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
  }
}

class HomeBackScopeContainer extends ConsumerWidget {
  final Widget child;

  const HomeBackScopeContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context, ref) {
    return CommonPopScope(
      onPop: (context) async {
        final pageLabel = ref.read(currentPageLabelProvider);
        final realContext =
            GlobalObjectKey(pageLabel).currentContext ?? context;
        final canPop = Navigator.canPop(realContext);
        if (canPop) {
          Navigator.of(realContext).pop();
        } else {
          await globalState.container
              .read(systemActionProvider.notifier)
              .handleBackOrExit();
        }
        return false;
      },
      child: child,
    );
  }
}
