import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/chat.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final _chatsCollection = FirebaseFirestore.instance.collection('chats');

// every conversation the logged in user is part of.
//
// arrayContains finds both sides of the conversation with one query, and the
// sorting is done in dart so firestore does not need a composite index.
final myChatsProvider = StreamProvider<List<Chat>>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Chat>[]);
      }

      return _chatsCollection
          .where('participants', arrayContains: user.uid)
          .snapshots()
          .map((snapshot) {
            final chats = snapshot.docs
                .map((doc) => Chat.fromFirestore(doc))
                .toList();

            chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
            return chats;
          });
    },
    loading: () => Stream.value(<Chat>[]),
    error: (e, _) => Stream.error(e),
  );
});

// one live conversation, so the header and unread state stay current.
final chatProvider = StreamProvider.autoDispose.family<Chat?, String>((
  ref,
  chatId,
) {
  if (chatId.trim().isEmpty) {
    return Stream.value(null);
  }

  return _chatsCollection.doc(chatId).snapshots().map((doc) {
    if (!doc.exists) return null;
    return Chat.fromFirestore(doc);
  });
});

// the messages inside one conversation, oldest first.
//
// this orders on a single field inside a subcollection, which firestore
// indexes automatically, so there is nothing to set up by hand.
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, chatId) {
      if (chatId.trim().isEmpty) {
        return Stream.value(<ChatMessage>[]);
      }

      return _chatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ChatMessage.fromFirestore(doc))
                .toList();
          });
    });

// total unread messages across every conversation, for the badge.
final unreadMessageCountProvider = Provider<int>((ref) {
  final chats = ref.watch(myChatsProvider).value ?? <Chat>[];
  final user = ref.watch(authStateProvider).value;

  if (user == null) return 0;

  int total = 0;
  for (final chat in chats) {
    total += chat.unreadFor(user.uid);
  }
  return total;
});
