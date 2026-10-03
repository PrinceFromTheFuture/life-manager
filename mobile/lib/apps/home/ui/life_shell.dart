import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:shopping_list/apps/calendar/calendar_app.dart';
import 'package:shopping_list/apps/groceries/groceries_app.dart';
import 'package:shopping_list/apps/gym/gym_app.dart';
import 'package:shopping_list/apps/home/ui/home_nav.dart';
import 'package:shopping_list/apps/home/ui/home_palette.dart';
import 'package:shopping_list/apps/home/ui/home_screen.dart';
import 'package:shopping_list/apps/receipts/receipts_app.dart';
import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Home, then the apps, in the order the day actually uses them.
///
/// Receipts is the slips app: its first surface is the slip list. Groceries
/// follows Gym.
const _destinations = <_Destination>[
  _Destination.home(),
  _Destination.app(ReceiptsApp(), SolarIcons.BillList, 'Slips'),
  _Destination.app(CalendarApp(), SolarIcons.Calendar, 'Calendar'),
  _Destination.app(GymApp(), SolarIcons.Dumbbell, 'Gym'),
  _Destination.app(GroceriesApp(), SolarIcons.Bag, 'Groceries'),
];

class _Destination {
  const _Destination.home()
      : app = null,
        icon = SolarIcons.HomeAngle,
        label = 'Home';

  const _Destination.app(this.app, this.icon, this.label);

  final MiniApp? app;
  final SolarIconData icon;
  final String label;
}

/// The front door. Apps wipe in from the side; the bar is the other way there.
class LifeShell extends StatefulWidget {
  const LifeShell({super.key});

  @override
  State<LifeShell> createState() => _LifeShellState();
}

class _LifeShellState extends State<LifeShell> {
  final _pages = PageController();
  final _covered = List<bool>.filled(_destinations.length, false);
  var _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    final reduce = MediaQuery.disableAnimationsOf(context);
    _pages.animateToPage(
      index,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _setCovered(int index, int depth) {
    final covered = depth > 1;
    if (_covered[index] == covered) return;
    void apply() {
      if (!mounted || _covered[index] == covered) return;
      setState(() => _covered[index] = covered);
    }

    // The home route is pushed while this shell is still building.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
      return;
    }
    apply();
  }

  @override
  Widget build(BuildContext context) {
    final barInset = HomeNavBar.occupiedHeight(context);
    final covered = _covered[_index];

    return Scaffold(
      backgroundColor: HomePalette.ground,
      // The body is the full screen. The bar floats over the home route, and
      // steps aside once a drawer or another screen is open so that screen
      // can use the space the bar was occupying.
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView(
              controller: _pages,
              onPageChanged: (index) {
                if (index == _index) return;
                setState(() => _index = index);
              },
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  _KeptPage(
                    child: i == 0
                        ? _LifeBarSeat(
                            inset: barInset,
                            child: HomeView(onOpen: _go),
                          )
                        : MiniAppHost(
                            app: _destinations[i].app!,
                            interceptBack: i == _index,
                            onExit: () => _go(0),
                            onStackDepth: (depth) => _setCovered(i, depth),
                            lifeBarInset: HomeNavBar.occupiedHeight,
                          ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: covered,
              child: Visibility(
                visible: !covered,
                maintainState: true,
                maintainAnimation: true,
                child: HomeNavBar(
                  index: _index,
                  onChanged: _go,
                  items: [
                    for (final destination in _destinations)
                      HomeNavItem(
                        icon: destination.icon,
                        label: destination.label,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Home has no nested navigator, so the bar inset lives on the page itself.
/// Sheets opened from Home use the root navigator and already cover the bar.
class _LifeBarSeat extends StatelessWidget {
  const _LifeBarSeat({required this.inset, required this.child});

  final double inset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(bottom: 0),
        viewPadding: media.viewPadding.copyWith(bottom: 0),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: child,
      ),
    );
  }
}

class _KeptPage extends StatefulWidget {
  const _KeptPage({required this.child});

  final Widget child;

  @override
  State<_KeptPage> createState() => _KeptPageState();
}

class _KeptPageState extends State<_KeptPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
