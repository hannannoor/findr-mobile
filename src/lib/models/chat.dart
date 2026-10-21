import 'package:cloud_firestore/cloud_firestore.dart';

// one conversation between a report owner and someone who claimed it.
//
// there is exactly one chat per claim, and the firestore document id is the
// claim id. that means a chat can always be found without searching for it,
// and the same claim can never end up with two conversations.
class Chat {
  String id;

  String claimId;
  String reportId;
  String reportName;
  String reportImagePath;

  // The uploaded photo of the item, so the banner at the top of the
  // conversation can show what is being discussed.
  String reportImage;

  // 'Lost' or 'Found', used for the tag on that banner.
  String reportType;

  // The reward on the item, shown on the banner when there is one.
  double? reportReward;

  // the two people talking. participants holds both ids so firestore can
  // find every chat a user belongs to with one arrayContains query.
  List<String> participants;
  String ownerId;
  String ownerEmail;
  String claimerId;
  String claimerEmail;

  // a preview of the newest message, stored on the chat itself so the
  // conversation list does not have to read every message subcollection.
  String lastMessage;
  String lastSenderId;
  DateTime lastMessageAt;

  // how many messages each person has not read yet, keyed by user id.
  Map<String, int> unread;

  DateTime createdAt;

  Chat({
    this.id = '',
    required this.claimId,
    required this.reportId,
    this.reportName = '',
    this.reportImagePath = '',
    this.reportImage = '',
    this.reportType = '',
    this.reportReward,
    List<String>? participants,
    required this.ownerId,
    this.ownerEmail = '',
    required this.claimerId,
    this.claimerEmail = '',
    this.lastMessage = '',
    this.lastSenderId = '',
    DateTime? lastMessageAt,
    Map<String, int>? unread,
    DateTime? createdAt,
  }) : participants = participants ?? [ownerId, claimerId],
       unread = unread ?? {ownerId: 0, claimerId: 0},
       lastMessageAt = lastMessageAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  static Chat fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    String readString(String key, [String fallback = '']) {
      final value = data[key];
      return value is String ? value : fallback;
    }

    DateTime readDate(String key) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    // the unread map comes back with dynamic values, so each one is
    // converted carefully rather than cast in one go.
    final Map<String, int> unreadCounts = {};
    final rawUnread = data['unread'];
    if (rawUnread is Map) {
      rawUnread.forEach((key, value) {
        if (key is String && value is num) {
          unreadCounts[key] = value.toInt();
        }
      });
    }

    return Chat(
      id: doc.id,
      claimId: readString('claimId'),
      reportId: readString('reportId'),
      reportName: readString('reportName'),
      reportImagePath: readString('reportImagePath'),
      reportImage: readString('reportImage'),
      reportType: readString('reportType'),
      reportReward: (data['reportReward'] as num?)?.toDouble(),
      participants: (data['participants'] as List?)?.whereType<String>().toList(),
      ownerId: readString('ownerId'),
      ownerEmail: readString('ownerEmail'),
      claimerId: readString('claimerId'),
      claimerEmail: readString('claimerEmail'),
      lastMessage: readString('lastMessage'),
      lastSenderId: readString('lastSenderId'),
      lastMessageAt: readDate('lastMessageAt'),
      unread: unreadCounts,
      createdAt: readDate('createdAt'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'claimId': claimId,
      'reportId': reportId,
      'reportName': reportName,
      'reportImagePath': reportImagePath,
      'reportImage': reportImage,
      'reportType': reportType,
      'reportReward': reportReward,
      'participants': participants,
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'claimerId': claimerId,
      'claimerEmail': claimerEmail,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'lastMessageAt': lastMessageAt,
      'unread': unread,
      'createdAt': createdAt,
    };
  }

  // the email of whoever the given user is talking to.
  String otherEmail(String myId) {
    return myId == ownerId ? claimerEmail : ownerEmail;
  }

  // display name for the other person, taken from their email.
  String otherName(String myId) {
    final email = otherEmail(myId);
    if (email.isEmpty) return 'Student';
    return email.split('@').first;
  }

  // how many messages this user has not read.
  int unreadFor(String myId) => unread[myId] ?? 0;

  // True when the item has an uploaded photo rather than a bundled asset.
  bool get hasReportImage => reportImage.isNotEmpty;

  // short timestamp for the conversation list.
  String get timeAgo {
    final diff = DateTime.now().difference(lastMessageAt);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}

// one message inside a chat, stored in the 'messages' subcollection.
class ChatMessage {
  String id;
  String senderId;
  String senderEmail;
  String text;
  DateTime createdAt;

  ChatMessage({
    this.id = '',
    required this.senderId,
    this.senderEmail = '',
    required this.text,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static ChatMessage fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    final rawDate = data['createdAt'];
    DateTime created = DateTime.now();
    if (rawDate is Timestamp) created = rawDate.toDate();

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] is String ? data['senderId'] : '',
      senderEmail: data['senderEmail'] is String ? data['senderEmail'] : '',
      text: data['text'] is String ? data['text'] : '',
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'text': text,
      'createdAt': createdAt,
    };
  }

  // clock time shown under each bubble.
  String get timeLabel {
    final int hour24 = createdAt.hour;
    final String period = hour24 >= 12 ? 'PM' : 'AM';
    int hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    return '$hour12:${createdAt.minute.toString().padLeft(2, '0')} $period';
  }
}
