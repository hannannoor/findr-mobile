import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/app_notification.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final _notificationsCollection = FirebaseFirestore.instance.collection(
  'notifications',
);

// every alert belonging to the logged in user, newest first.
//
// sorting happens in dart so firestore does not need a composite index for
// the userId filter combined with an ordering.
final myNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<AppNotification>[]);
      }

      return _notificationsCollection
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
            final items = snapshot.docs
                .map((doc) => AppNotification.fromFirestore(doc))
                .toList();

            items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return items;
          });
    },
    loading: () => Stream.value(<AppNotification>[]),
    error: (e, _) => Stream.error(e),
  );
});

// how many alerts have not been opened yet, used for the badge.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(myNotificationsProvider).value ?? <AppNotification>[];
  return items.where((n) => !n.read).length;
});

// watches the alert stream and raises anything new on the device itself.
//
// ids that have already been shown are remembered so an alert is not raised
// again every time the stream emits.
final notificationPopupProvider = Provider<void>((ref) {
  final Set<String> alreadyShown = <String>{};
  bool firstBatch = true;

  ref.listen<AsyncValue<List<AppNotification>>>(myNotificationsProvider, (
    previous,
    next,
  ) {
    final items = next.value;
    if (items == null) return;

    // the very first load is everything that already existed, so it is
    // recorded without popping a stack of old alerts at the user.
    if (firstBatch) {
      firstBatch = false;
      for (final item in items) {
        alreadyShown.add(item.id);
      }
      return;
    }

    for (final item in items) {
      if (item.read || alreadyShown.contains(item.id)) continue;

      alreadyShown.add(item.id);
      NotificationService.showLocal(item);
    }
  });
});
