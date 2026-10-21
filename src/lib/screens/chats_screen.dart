import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/chat.dart';
import 'package:findr_application/providers/chat_provider.dart';
import 'package:findr_application/screens/chat_screen.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_bottom_nav.dart';
import 'package:findr_application/widgets/app_page.dart';

// every conversation the user is part of, newest activity first.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String searchText = '';

  // hides conversations that do not match what the user typed.
  List<Chat> applySearch(List<Chat> chats, String myId) {
    if (searchText.trim().isEmpty) return chats;

    final query = searchText.toLowerCase().trim();

    return chats.where((chat) {
      return chat.otherName(myId).toLowerCase().contains(query) ||
          chat.reportName.toLowerCase().contains(query) ||
          chat.lastMessage.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(myChatsProvider);
    final String myId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return AppPage(
      subtitle: 'Your Conversations',
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSearchBar(),
          const SizedBox(height: 18),
          chatsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const AppEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could Not Load Messages',
              subtitle: 'Check your connection and try again.',
            ),
            data: (chats) {
              if (chats.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No Conversations Yet',
                  subtitle:
                      'Open any report and tap Message to start\n'
                      'talking to whoever posted it.',
                );
              }

              final visible = applySearch(chats, myId);

              if (visible.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No Matches',
                  subtitle: 'Try a different name or item.',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildListHeading(visible.length),
                  const SizedBox(height: 11),
                  ...visible.map((c) => buildChatCard(c, myId)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildSearchBar() {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      height: 49,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: colors.surfaceSoft.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colors.muted, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              style: TextStyle(fontSize: 13.5, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: TextStyle(fontSize: 13, color: colors.muted),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
              onChanged: (value) => setState(() => searchText = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildListHeading(int count) {
    final FindrColors colors = FindrColors.of(context);

    return Row(
      children: [
        Text(
          'Conversations',
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
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count ${count == 1 ? 'chat' : 'chats'}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: colors.primaryStrong,
            ),
          ),
        ),
      ],
    );
  }

  // one conversation, drawn as a card rather than a plain list tile so
  // unread ones can be lifted visually.
  Widget buildChatCard(Chat chat, String myId) {
    final FindrColors colors = FindrColors.of(context);
    final int unread = chat.unreadFor(myId);
    final bool hasUnread = unread > 0;
    final String name = chat.otherName(myId);

    final String preview = chat.lastMessage.isEmpty
        ? 'No messages yet'
        : chat.lastSenderId == myId
        ? 'You: ${chat.lastMessage}'
        : chat.lastMessage;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasUnread
              ? colors.primary.withValues(alpha: 0.42)
              : colors.border,
          width: hasUnread ? 1.3 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildAvatar(name, hasUnread),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: hasUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            chat.timeAgo,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: hasUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: hasUnread
                                  ? colors.primary
                                  : colors.navUnselected,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      // small chip naming the item, so it is obvious what
                      // the conversation is about.
                      if (chat.reportName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 11,
                                color: colors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  chat.reportName,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.3,
                                color: hasUnread
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              constraints: const BoxConstraints(minWidth: 20),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Initial avatar using the same circular treatment as the rest of Findr.
  Widget buildAvatar(String name, bool hasUnread) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasUnread
              ? [colors.accent, colors.primary]
              : [colors.surfaceSoft, colors.backgroundAlt],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: hasUnread ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
