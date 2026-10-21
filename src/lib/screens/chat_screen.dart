import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/chat.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/providers/chat_provider.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/screens/report_details_screen.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_page.dart';

// one conversation between the report owner and the person claiming it.
class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isSending = false;
  bool hasText = false;

  @override
  void initState() {
    super.initState();

    // the send button only lights up once something has been typed.
    controller.addListener(() {
      final bool now = controller.text.trim().isNotEmpty;
      if (now != hasText) {
        setState(() => hasText = now);
      }
    });

    // opening the conversation counts as reading it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatServiceProvider).markRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  String get myId => FirebaseAuth.instance.currentUser?.uid ?? '';

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> send(Chat chat) async {
    final String text = controller.text.trim();

    if (text.isEmpty || isSending) return;

    setState(() => isSending = true);
    controller.clear();

    try {
      await ref.read(chatServiceProvider).sendMessage(chat, text);
      scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      // put the text back so nothing typed is lost.
      controller.text = text;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE0415F),
          content: Text(e.toString().replaceFirst('Invalid argument(s): ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);
    final chatAsync = ref.watch(chatProvider(widget.chatId));

    return Scaffold(
      backgroundColor: colors.backgroundAlt,
      body: chatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text('Could not open this conversation.')),
        data: (chat) {
          if (chat == null) {
            return const Center(
              child: Text('This conversation is no longer available.'),
            );
          }

          return Column(
            children: [
              buildHeader(chat),
              Expanded(child: buildMessageArea(chat)),
              buildComposer(chat),
            ],
          );
        },
      ),
    );
  }

  // The conversation header.
  //
  // Two bands inside one white sheet: the person on top, then the item being
  // discussed underneath with its photo. Marketplace apps do the same thing,
  // because in a handover conversation the object matters as much as the
  // person, and it stops either side forgetting which report this is about.
  Widget buildHeader(Chat chat) {
    final String name = chat.otherName(myId);
    final FindrColors colors = FindrColors.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surface, colors.backgroundAlt],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -62,
            right: -42,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.34),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 46,
            right: 86,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: colors.primaryStrong.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  buildPersonRow(name),
                  if (chat.reportName.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    buildItemBanner(chat),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Back button, avatar and who you are talking to.
  Widget buildPersonRow(String name) {
    final FindrColors colors = FindrColors.of(context);

    return Row(
      children: [
        AppBackButton(onTap: () => Navigator.of(context).pop()),

        const SizedBox(width: 13),

        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.accent, colors.primary],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: colors.surface, width: 2),
          ),
          child: Center(
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.2,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // The item strip: photo, name, type tag and reward, tappable to open the
  // full report.
  Widget buildItemBanner(Chat chat) {
    final bool isLost = chat.reportType == 'Lost';
    final bool hasReward = (chat.reportReward ?? 0) > 0;
    final FindrColors colors = FindrColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: chat.reportId.isEmpty
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReportDetailsScreen(reportId: chat.reportId),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: buildItemThumbnail(chat),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chat.reportType.isEmpty
                            ? 'ITEM REPORT'
                            : '${chat.reportType.toUpperCase()} ITEM',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isLost
                              ? const Color(0xFFD94084)
                              : const Color(0xFF3E8C63),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        chat.reportName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (hasReward)
                            Text(
                              '\$${chat.reportReward!.toStringAsFixed(0)} reward',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD94084),
                              ),
                            )
                          else
                            Text(
                              'Open report details',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: colors.primary,
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

  // The item photo.
  //
  // The live report is read rather than the copy stored on the conversation,
  // because conversations created before the photo was copied across have an
  // empty value, and because the owner may have changed the photo since.
  Widget buildItemThumbnail(Chat chat) {
    if (chat.reportId.isNotEmpty) {
      final ItemReport? report = ref.watch(reportProvider(chat.reportId)).value;

      if (report != null) {
        if (report.hasPhoto) {
          return Image.memory(
            base64Decode(report.base64Image),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => buildThumbPlaceholder(),
          );
        }

        if (report.imagePath.isNotEmpty) {
          return Image.asset(
            report.imagePath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => buildThumbPlaceholder(),
          );
        }

        return buildThumbPlaceholder();
      }
    }

    // Falls back to whatever was stored on the conversation itself.
    if (chat.hasReportImage) {
      return Image.memory(
        base64Decode(chat.reportImage),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => buildThumbPlaceholder(),
      );
    }

    if (chat.reportImagePath.isEmpty) {
      return buildThumbPlaceholder();
    }

    return Image.asset(
      chat.reportImagePath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => buildThumbPlaceholder(),
    );
  }

  Widget buildThumbPlaceholder() {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      color: colors.surfaceSoft,
      child: Icon(Icons.inventory_2_outlined, size: 20, color: colors.muted),
    );
  }

  // the scrolling message area.
  //
  // the chat wallpaper is painted over a solid colour rather than over the
  // campus illustration, because two artworks showing through each other is
  // what made this look muddled.
  Widget buildMessageArea(Chat chat) {
    final FindrColors colors = FindrColors.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: colors.backgroundAlt)),
        Positioned.fill(
          child: dark
              ? Image.asset(
                  'assets/images/chat_bg_dark.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                )
              : Opacity(
                  opacity: 0.78,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      colors.illustrationTint,
                      BlendMode.hue,
                    ),
                    child: Image.asset(
                      'assets/images/chat_bg.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
        ),
        buildMessageList(),
      ],
    );
  }

  Widget buildMessageList() {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Could not load messages.')),
      data: (messages) {
        if (messages.isEmpty) {
          return buildEmptyConversation();
        }

        scrollToBottom();

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(15, 18, 15, 14),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final bool isMine = message.senderId == myId;

            final previous = index == 0 ? null : messages[index - 1];
            final next = index == messages.length - 1
                ? null
                : messages[index + 1];

            final bool showDate =
                previous == null ||
                !_sameDay(previous.createdAt, message.createdAt);

            // consecutive messages from the same person are grouped, so only
            // the last one in a run gets the tail and the timestamp.
            final bool sameAsPrevious =
                previous != null &&
                previous.senderId == message.senderId &&
                !showDate;

            final bool sameAsNext =
                next != null &&
                next.senderId == message.senderId &&
                _sameDay(next.createdAt, message.createdAt);

            return Column(
              children: [
                if (showDate) buildDateDivider(message.createdAt),
                buildBubble(
                  message,
                  isMine,
                  groupedAbove: sameAsPrevious,
                  groupedBelow: sameAsNext,
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget buildDateDivider(DateTime date) {
    final FindrColors colors = FindrColors.of(context);
    final now = DateTime.now();
    String label;

    if (_sameDay(date, now)) {
      label = 'Today';
    } else if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget buildBubble(
    ChatMessage message,
    bool isMine, {
    required bool groupedAbove,
    required bool groupedBelow,
  }) {
    final FindrColors colors = FindrColors.of(context);

    // the tail corner is squared off only on the last bubble of a run.
    const double round = 18;
    const double tail = 5;

    return Padding(
      padding: EdgeInsets.only(bottom: groupedBelow ? 3 : 9),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                gradient: isMine
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.accent, colors.primary],
                      )
                    : null,
                color: isMine ? null : colors.surface,
                border: isMine ? null : Border.all(color: colors.border),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(
                    isMine ? round : (groupedAbove ? tail : round),
                  ),
                  topRight: Radius.circular(
                    isMine ? (groupedAbove ? tail : round) : round,
                  ),
                  bottomLeft: Radius.circular(
                    isMine ? round : (groupedBelow ? tail : round),
                  ),
                  bottomRight: Radius.circular(
                    isMine ? (groupedBelow ? tail : round) : round,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMine
                        ? colors.primary.withValues(alpha: 0.2)
                        : colors.textPrimary.withValues(alpha: 0.055),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      color: isMine ? Colors.white : colors.textPrimary,
                    ),
                  ),

                  // only the last bubble in a run carries the time.
                  if (!groupedBelow) ...[
                    const SizedBox(height: 3),
                    Text(
                      message.timeLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.82)
                            : colors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyConversation() {
    final FindrColors colors = FindrColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.waving_hand_outlined,
                size: 38,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Say hello',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Arrange where and when to hand the item over.\n'
              'Meet somewhere public on campus.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildComposer(Chat chat) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 14.5, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: colors.navUnselected,
                      ),
                      counterText: '',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                    ),
                    onSubmitted: (_) => send(chat),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    gradient: hasText && !isSending
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [colors.accent, colors.primary],
                          )
                        : null,
                    color: hasText && !isSending ? null : colors.border,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: hasText && !isSending
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.3),
                              blurRadius: 9,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: (!hasText || isSending)
                        ? null
                        : () => send(chat),
                    icon: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            size: 21,
                            color: hasText ? Colors.white : colors.muted,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
