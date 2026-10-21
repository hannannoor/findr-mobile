import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:findr_application/models/chat.dart';
import 'package:findr_application/models/claim.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/services/notification_service.dart';

// handles the in-app conversation between a report owner and a claimer.
//
// structure in firestore:
//   chats/{claimId}                  <- one document per claim
//   chats/{claimId}/messages/{auto}  <- the messages inside it
//
// using the claim id as the chat id means the conversation for a claim can
// always be opened directly, with no lookup and no chance of duplicates.
class ChatService {
  final CollectionReference<Map<String, dynamic>> _chats = FirebaseFirestore
      .instance
      .collection('chats');

  CollectionReference<Map<String, dynamic>> messagesRef(String chatId) {
    return _chats.doc(chatId).collection('messages');
  }

  // builds the id for a conversation from the report and the two people in it.
  //
  // the ids are sorted so both people always work out the same value, which
  // means one conversation per pair per report no matter who starts it, and
  // no lookup is ever needed to find it. it also means messaging someone
  // first and claiming afterwards continues the same thread.
  String chatIdFor(String reportId, String userA, String userB) {
    final List<String> ids = [userA, userB]..sort();
    return '${reportId}_${ids[0]}_${ids[1]}';
  }

  // opens the conversation between the logged in user and a report's owner.
  // used by the message button on a report, so no claim is required first.
  Future<String> openChatForReport(ItemReport report) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('You must be logged in to use chat.');
    }

    if (user.uid == report.userId) {
      throw StateError('This is your own report.');
    }

    if (report.userId.isEmpty || report.userId.startsWith('demo-')) {
      throw StateError('This sample report has no real poster to message.');
    }

    return _open(
      chatId: chatIdFor(report.id, user.uid, report.userId),
      reportId: report.id,
      reportName: report.name,
      reportImagePath: report.imagePath,
      reportImage: report.base64Image,
      reportType: report.reportType,
      reportReward: report.reward,
      ownerId: report.userId,
      ownerEmail: report.userEmail,
      claimerId: user.uid,
      claimerEmail: user.email ?? '',
      claimId: '',
    );
  }

  // opens the conversation attached to a claim.
  Future<String> openChatForClaim(Claim claim) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('You must be logged in to use chat.');
    }

    // only the two people involved in the claim may open it.
    if (user.uid != claim.ownerId && user.uid != claim.claimerId) {
      throw StateError('You are not part of this conversation.');
    }

    return _open(
      chatId: chatIdFor(claim.reportId, claim.ownerId, claim.claimerId),
      reportId: claim.reportId,
      reportName: claim.reportName,
      reportImagePath: claim.reportImagePath,
      reportImage: '',
      reportType: claim.reportType,
      reportReward: null,
      ownerId: claim.ownerId,
      ownerEmail: '',
      claimerId: claim.claimerId,
      claimerEmail: claim.claimerEmail,
      claimId: claim.id,
    );
  }

  // shared setup for both entry points.
  // creates the document the first time and fills in any missing details
  // afterwards, so it is safe to call as often as needed.
  Future<String> _open({
    required String chatId,
    required String reportId,
    required String reportName,
    required String reportImagePath,
    required String reportImage,
    required String reportType,
    required double? reportReward,
    required String ownerId,
    required String ownerEmail,
    required String claimerId,
    required String claimerEmail,
    required String claimId,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final DocumentReference<Map<String, dynamic>> doc = _chats.doc(chatId);
    final snapshot = await doc.get();

    if (!snapshot.exists) {
      final Chat chat = Chat(
        claimId: claimId,
        reportId: reportId,
        reportName: reportName,
        reportImagePath: reportImagePath,
        reportImage: reportImage,
        reportType: reportType,
        reportReward: reportReward,
        ownerId: ownerId,
        ownerEmail: ownerEmail,
        claimerId: claimerId,
        claimerEmail: claimerEmail,
        lastMessage: '',
      );

      final data = chat.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['lastMessageAt'] = FieldValue.serverTimestamp();

      // whoever opens it first fills in their own email.
      if (user?.uid == ownerId) {
        data['ownerEmail'] = user?.email ?? '';
      } else if (user?.uid == claimerId) {
        data['claimerEmail'] = user?.email ?? '';
      }

      await doc.set(data);
      return chatId;
    }

    // fill in anything that was not known when the chat was created, such
    // as the owner's email or the claim it later became attached to.
    final existing = snapshot.data() ?? {};
    final Map<String, dynamic> updates = {};

    if (user?.uid == ownerId &&
        ((existing['ownerEmail'] as String?)?.isEmpty ?? true)) {
      updates['ownerEmail'] = user?.email ?? '';
    }

    if (user?.uid == claimerId &&
        ((existing['claimerEmail'] as String?)?.isEmpty ?? true)) {
      updates['claimerEmail'] = user?.email ?? '';
    }

    if (claimId.isNotEmpty &&
        ((existing['claimId'] as String?)?.isEmpty ?? true)) {
      updates['claimId'] = claimId;
    }

    // details about the item may not have been known when the conversation
    // was first opened, so they are filled in whenever they become available.
    if (reportImage.isNotEmpty &&
        ((existing['reportImage'] as String?)?.isEmpty ?? true)) {
      updates['reportImage'] = reportImage;
    }

    if (reportType.isNotEmpty &&
        ((existing['reportType'] as String?)?.isEmpty ?? true)) {
      updates['reportType'] = reportType;
    }

    if (reportReward != null && existing['reportReward'] == null) {
      updates['reportReward'] = reportReward;
    }

    if (updates.isNotEmpty) {
      await doc.update(updates);
    }

    return chatId;
  }

  // adds a message and updates the preview fields on the parent chat.
  //
  // both writes go in one batch so the conversation list can never show a
  // preview for a message that failed to save.
  Future<void> sendMessage(Chat chat, String text) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('You must be logged in to send a message.');
    }

    final String trimmed = text.trim();

    if (trimmed.isEmpty) {
      return;
    }

    if (trimmed.length > 500) {
      throw ArgumentError('Messages are limited to 500 characters.');
    }

    // whoever is not sending is the one who gains an unread message.
    final String recipientId = user.uid == chat.ownerId
        ? chat.claimerId
        : chat.ownerId;

    final WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.set(messagesRef(chat.id).doc(), {
      'senderId': user.uid,
      'senderEmail': user.email ?? '',
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(_chats.doc(chat.id), {
      'lastMessage': trimmed,
      'lastSenderId': user.uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      // increment is used instead of reading then writing, so two messages
      // arriving at once cannot overwrite each other's count.
      'unread.$recipientId': FieldValue.increment(1),
    });

    await batch.commit();

    // let the other person know, so they do not have to sit in the app
    // waiting for a reply.
    final String senderName = (user.email ?? '').split('@').first;

    await NotificationService().create(
      userId: recipientId,
      type: 'message',
      title: senderName.isEmpty ? 'New message' : 'Message from $senderName',
      body: trimmed,
      reportId: chat.reportId,
      claimId: chat.claimId,
      chatId: chat.id,
    );
  }

  // clears this user's unread counter, called when they open the chat.
  Future<void> markRead(String chatId) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      await _chats.doc(chatId).update({'unread.${user.uid}': 0});
    } catch (_) {
      // the chat may not exist yet, which is not worth surfacing.
    }
  }

  // removes a conversation and everything inside it.
  // used when the underlying claim is withdrawn or the report is deleted.
  Future<void> deleteChat(String chatId) async {
    final messages = await messagesRef(chatId).get();

    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_chats.doc(chatId));

    await batch.commit();
  }
}
