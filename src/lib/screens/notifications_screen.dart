import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/app_notification.dart';
import 'package:findr_application/providers/notification_provider.dart';
import 'package:findr_application/screens/chat_screen.dart';
import 'package:findr_application/screens/report_details_screen.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_page.dart';

// the alerts inbox.
// the on/off switch for device alerts lives in settings, not here.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Cards are removed immediately on tap while Firestore finishes deleting
  // them. This prevents a slow connection from making the alert look stuck.
  final Set<String> locallyDismissedIds = <String>{};

  // Opens whatever the alert refers to, then permanently dismisses that inbox
  // notification. "Mark all as read" remains available as a separate action.
  Future<void> openTarget(AppNotification item) async {
    if (locallyDismissedIds.contains(item.id)) return;

    setState(() {
      locallyDismissedIds.add(item.id);
    });

    final dismissFuture = ref.read(notificationServiceProvider).delete(item.id);

    navigateToTarget(item);

    final dismissed = await dismissFuture;

    if (!mounted || dismissed) return;

    setState(() {
      locallyDismissedIds.remove(item.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not dismiss notification. Please try again.'),
      ),
    );
  }

  void navigateToTarget(AppNotification item) {
    if (!mounted) return;

    if (item.chatId.isNotEmpty &&
        (item.type == 'message' || item.type == 'claim_accepted')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(chatId: item.chatId)),
      );
      return;
    }

    if (item.reportId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportDetailsScreen(reportId: item.reportId),
        ),
      );
    }
  }

  // mark all read / clear all, opened from the button in the heading.
  void showActions(List<AppNotification> items) {
    final FindrColors colors = FindrColors.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.done_all_rounded, color: colors.primary),
                title: const Text('Mark All as Read'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(notificationServiceProvider).markAllRead(items);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Color(0xFFE0415F),
                ),
                title: const Text('Clear All'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(notificationServiceProvider).clearAll(items);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final items = (notificationsAsync.value ?? <AppNotification>[])
        .where((item) => !locallyDismissedIds.contains(item.id))
        .toList();

    return AppPage(
      title: 'Notifications',
      subtitle: 'Claims, Messages and Reward Updates',
      showBack: true,
      action: items.isEmpty
          ? null
          : AppCircleButton(
              icon: Icons.more_horiz,
              onTap: () => showActions(items),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          notificationsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const AppEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could Not Load Notifications',
              subtitle: 'Check your connection and try again.',
            ),
            data: (list) {
              final visibleItems = list
                  .where((item) => !locallyDismissedIds.contains(item.id))
                  .toList();

              if (visibleItems.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'Nothing Yet',
                  subtitle:
                      'Claims, messages and reward updates\n'
                      'will show up here.',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSectionHeading(visibleItems.length),
                  const SizedBox(height: 10),
                  buildActivityPanel(visibleItems),
                ],
              );
            },
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget buildSectionHeading(int count) {
    final FindrColors colors = FindrColors.of(context);

    return Row(
      children: [
        Text(
          'Recent activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: colors.textPrimary,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildActivityPanel(List<AppNotification> items) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (int index = 0; index < items.length; index++)
            buildTile(items[index], showDivider: index < items.length - 1),
        ],
      ),
    );
  }

  Widget buildTile(AppNotification item, {required bool showDivider}) {
    final FindrColors colors = FindrColors.of(context);
    final style = iconStyleFor(item.type);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => openTarget(item),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: style.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: style.colour.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Icon(style.icon, size: 22, color: style.colour),
                      ),
                      if (!item.read)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.25,
                            letterSpacing: -0.15,
                            fontWeight: item.read
                                ? FontWeight.w700
                                : FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.body,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: style.background,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                labelFor(item.type),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.45,
                                  color: style.colour,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: colors.navUnselected,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item.timeAgo,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: colors.navUnselected,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 21,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 70,
            endIndent: 14,
            color: colors.border,
          ),
      ],
    );
  }

  // short readable name for the tag on each card.
  String labelFor(String type) {
    switch (type) {
      case 'claim':
        return 'NEW CLAIM';
      case 'claim_accepted':
        return 'ACCEPTED';
      case 'claim_rejected':
        return 'REJECTED';
      case 'reward':
        return 'REWARD';
      case 'match':
        return 'AI MATCH';
      default:
        return 'MESSAGE';
    }
  }

  // each alert type gets its own colour and icon so the list scans quickly.
  _IconStyle iconStyleFor(String type) {
    final FindrColors colors = FindrColors.of(context);
    Color soft(Color colour) {
      return Color.alphaBlend(colour.withValues(alpha: 0.16), colors.surface);
    }

    switch (type) {
      case 'claim':
        return _IconStyle(
          Icons.pan_tool_alt_outlined,
          colors.primary,
          colors.surfaceSoft,
        );
      case 'claim_accepted':
        return _IconStyle(
          Icons.check_circle_outline,
          const Color(0xFF5BA681),
          soft(const Color(0xFF5BA681)),
        );
      case 'claim_rejected':
        return _IconStyle(
          Icons.cancel_outlined,
          const Color(0xFFE0415F),
          soft(const Color(0xFFE0415F)),
        );
      case 'reward':
        return _IconStyle(
          Icons.card_giftcard,
          const Color(0xFFD94084),
          soft(const Color(0xFFD94084)),
        );
      case 'match':
        return _IconStyle(
          Icons.auto_awesome,
          const Color(0xFF7C4DFF),
          soft(const Color(0xFF7C4DFF)),
        );
      default:
        return _IconStyle(
          Icons.chat_bubble_outline,
          colors.primary,
          colors.surfaceSoft,
        );
    }
  }
}

// small holder for the colours used by each alert type.
class _IconStyle {
  final IconData icon;
  final Color colour;
  final Color background;

  _IconStyle(this.icon, this.colour, this.background);
}
