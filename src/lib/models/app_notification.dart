import 'package:cloud_firestore/cloud_firestore.dart';

// one alert for a single user, stored in the 'notifications' collection.
//
// these are written whenever something happens that the user would want to
// know about: a claim on their report, a decision on a claim they made, a
// new message, or a reward being released.
class AppNotification {
  String id;

  // who this alert belongs to.
  String userId;

  // what kind of event it was, used to pick the icon and where to navigate.
  // one of: claim, claim_accepted, claim_rejected, message, reward, match
  String type;

  String title;
  String body;

  // where tapping the alert should take the user.
  String reportId;
  String claimId;
  String chatId;

  bool read;
  DateTime createdAt;

  AppNotification({
    this.id = '',
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.reportId = '',
    this.claimId = '',
    this.chatId = '',
    this.read = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static AppNotification fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    String readString(String key, [String fallback = '']) {
      final value = data[key];
      return value is String ? value : fallback;
    }

    DateTime created = DateTime.now();
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) created = rawDate.toDate();

    return AppNotification(
      id: doc.id,
      userId: readString('userId'),
      type: readString('type', 'message'),
      title: readString('title'),
      body: readString('body'),
      reportId: readString('reportId'),
      claimId: readString('claimId'),
      chatId: readString('chatId'),
      read: data['read'] == true,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'reportId': reportId,
      'claimId': claimId,
      'chatId': chatId,
      'read': read,
      'createdAt': createdAt,
    };
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
