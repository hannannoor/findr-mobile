import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:findr_application/models/app_notification.dart';

// handles notifications inside the app and on the device.
// alerts are stored in firestore so users can view them later.
class NotificationService {
  final CollectionReference<Map<String, dynamic>> _notifications =
      FirebaseFirestore.instance.collection('notifications');

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  // settings used for android notifications.
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'findr_alerts',
    'Findr Alerts',
    channelDescription: 'Claims, messages and reward updates',
    importance: Importance.high,
    priority: Priority.high,
  );

  // sets up local notifications when the app starts.
  static Future<void> init() async {
    // stops the plugin from being initialised more than once.
    if (_ready) return;

    const AndroidInitializationSettings android =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const DarwinInitializationSettings ios =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: ios,
      ),
    );

    // asks for notification permission on newer android versions.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    _ready = true;
  }

  // checks if the user has device notifications turned on.
  static Future<bool> alertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool('notificationsEnabled') ?? true;
  }

  // saves whether the user wants device notifications.
  static Future<void> setAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      'notificationsEnabled',
      enabled,
    );
  }

  // shows one notification on the device.
  static Future<void> showLocal(
    AppNotification notification,
  ) async {
    if (!await alertsEnabled()) return;

    try {
      await init();

      await _plugin.show(
        // creates a number id from the firestore document id.
        notification.id.hashCode & 0x7fffffff,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: _androidDetails,
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('local notification failed: $e');
    }
  }

  // creates a notification and stores it in firestore.
  Future<void> create({
    required String userId,
    required String type,
    required String title,
    required String body,
    String reportId = '',
    String claimId = '',
    String chatId = '',
  }) async {
    if (userId.isEmpty) return;

    // does not notify the user about their own action.
    if (userId == FirebaseAuth.instance.currentUser?.uid) {
      return;
    }

    // skips notifications for sample demo accounts.
    if (userId.startsWith('demo-')) {
      return;
    }

    try {
      await _notifications.add({
        'userId': userId,
        'type': type,
        'title': title,
        'body': body,
        'reportId': reportId,
        'claimId': claimId,
        'chatId': chatId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // a failed notification should not stop the original action.
      debugPrint('could not write notification: $e');
    }
  }

  // marks one notification as read.
  Future<void> markRead(String id) async {
    try {
      await _notifications.doc(id).update({
        'read': true,
      });
    } catch (_) {}
  }

  // marks every unread notification as read in one batch.
  Future<void> markAllRead(
    List<AppNotification> items,
  ) async {
    final unread = items
        .where((notification) => !notification.read)
        .toList();

    if (unread.isEmpty) return;

    final WriteBatch batch =
        FirebaseFirestore.instance.batch();

    for (final item in unread) {
      batch.update(
        _notifications.doc(item.id),
        {'read': true},
      );
    }

    await batch.commit();
  }

  // deletes one notification from the user's inbox.
  // returns false if firestore could not delete it.
  Future<bool> delete(String id) async {
    if (id.trim().isEmpty) {
      return false;
    }

    try {
      await _notifications.doc(id).delete();
    } catch (e) {
      debugPrint(
        'could not dismiss notification $id: $e',
      );

      return false;
    }

    // also removes the notification from the device if it is still showing.
    try {
      await _plugin.cancel(
        id.hashCode & 0x7fffffff,
      );
    } catch (e) {
      debugPrint(
        'could not clear local notification $id: $e',
      );
    }

    return true;
  }

  // deletes every notification passed into the method.
  Future<void> clearAll(
    List<AppNotification> items,
  ) async {
    if (items.isEmpty) return;

    final WriteBatch batch =
        FirebaseFirestore.instance.batch();

    for (final item in items) {
      batch.delete(
        _notifications.doc(item.id),
      );
    }

    await batch.commit();
  }
}