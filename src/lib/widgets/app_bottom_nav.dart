import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/providers/chat_provider.dart';
import 'package:findr_application/providers/notification_provider.dart';
import 'package:findr_application/screens/home_screen.dart';
import 'package:findr_application/screens/chats_screen.dart';
import 'package:findr_application/screens/post_screen.dart';
import 'package:findr_application/screens/map_screen.dart';
import 'package:findr_application/screens/profile_screen.dart';
import 'package:findr_application/theme/app_theme.dart';

// shared bottom nav bar for the main findr screens.
//
// map and messages sit in the bar because both are things a student comes
// back to repeatedly. my reports is reached from profile, and ai search from
// the home screen, since searching belongs next to the search bar.
class AppBottomNav extends ConsumerWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  // changes to the screen based on the tab the user taps.
  // pushReplacement is used so the tabs dont keep stacking.
  void onTap(BuildContext context, int index) {
    // stops the page from reloading if the user taps the same tab.
    if (index == currentIndex) {
      return;
    }

    Widget nextScreen;

    if (index == 0) {
      nextScreen = const HomeScreen();
    } else if (index == 1) {
      nextScreen = const MapScreen();
    } else if (index == 2) {
      nextScreen = PostScreen();
    } else if (index == 3) {
      nextScreen = const ChatsScreen();
    } else {
      nextScreen = const ProfileScreen();
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => nextScreen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FindrColors colors = FindrColors.of(context);
    // unread messages sit on the messages tab, and anything else that needs
    // attention shows as a plain dot on profile, since that is where
    // notifications and claims are reached from.
    final int unreadMessages = ref.watch(unreadMessageCountProvider);
    final int unreadAlerts = ref.watch(unreadNotificationCountProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.24
                  : 0.07,
            ),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildTab(context, 0, Icons.home_rounded, 'Home'),
              buildTab(context, 1, Icons.map_rounded, 'Map'),
              buildPostButton(context),
              buildTab(
                context,
                3,
                Icons.chat_bubble_rounded,
                'Messages',
                badge: unreadMessages,
              ),
              buildTab(
                context,
                4,
                Icons.person_rounded,
                'Profile',
                showDot: unreadAlerts > 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // one tab. the selected one gets a tinted pill behind the icon so the
  // current page is obvious without relying on colour alone.
  Widget buildTab(
    BuildContext context,
    int index,
    IconData icon,
    String label, {
    int badge = 0,
    bool showDot = false,
  }) {
    final bool selected = index == currentIndex;
    final FindrColors colors = FindrColors.of(context);

    return Expanded(
      child: InkWell(
        onTap: () => onTap(context, index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? colors.surfaceSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      size: 21,
                      color: selected ? colors.primary : colors.navUnselected,
                    ),
                  ),

                  // number badge, used for unread messages.
                  if (badge > 0)
                    Positioned(
                      right: 6,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 17),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0415F),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: colors.surface, width: 1.6),
                        ),
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  // plain dot, used when there is something to look at but a
                  // number would be noise.
                  if (showDot && badge == 0)
                    Positioned(
                      right: 12,
                      top: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0415F),
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 1.6),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 3),

              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? colors.primary : colors.navUnselected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // posting is the main action, so it gets a raised circular button in the
  // middle rather than looking like just another tab.
  Widget buildPostButton(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Expanded(
      child: InkWell(
        onTap: () => onTap(context, 2),
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.accent, colors.primary],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.35),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, size: 21, color: Colors.white),
              ),

              const SizedBox(height: 3),

              Text(
                'Post',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: currentIndex == 2
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: currentIndex == 2
                      ? colors.primary
                      : colors.navUnselected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
