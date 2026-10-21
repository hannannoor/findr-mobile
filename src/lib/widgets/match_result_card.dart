import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:findr_application/models/match_result.dart';
import 'package:findr_application/theme/app_theme.dart';

// shows one possible match with its score, details and actions.
class MatchResultCard extends StatelessWidget {
  final MatchResult match;
  final VoidCallback onViewDetails;
  final VoidCallback onContactOwner;

  const MatchResultCard({
    super.key,
    required this.match,
    required this.onViewDetails,
    required this.onContactOwner,
  });

  // uses the ai score if available, otherwise uses the local match score.
  int get score => match.aiConfidence ?? match.matchPercent;

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: match.isBestMatch ? colors.primary : colors.border,
          width: match.isBestMatch ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildImage(context),
              const SizedBox(width: 12),
              Expanded(
                child: buildDetails(context),
              ),
            ],
          ),

          buildReasonLine(context),

          const SizedBox(height: 12),

          buildButtons(context),
        ],
      ),
    );
  }

  // builds the item image and shows a best match label when needed.
  Widget buildImage(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 96,
              height: 96,
              child: match.hasPhoto
                  ? Image.memory(
                      base64Decode(match.base64Image),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          buildPlaceholder(context),
                    )
                  : match.imagePath.isEmpty
                      ? buildPlaceholder(context)
                      : Image.asset(
                          match.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              buildPlaceholder(context),
                        ),
            ),
          ),

          if (match.isBestMatch)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13),
                    bottomRight: Radius.circular(9),
                  ),
                ),
                child: const Text(
                  'Best Match',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // shows a fallback icon if the item image cannot be loaded.
  Widget buildPlaceholder(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      color: colors.surfaceSoft,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 28,
        color: colors.muted,
      ),
    );
  }

  // builds the item name, score and other report details.
  Widget buildDetails(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                match.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  letterSpacing: -0.2,
                  color: colors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 7),
            buildScorePill(context),
          ],
        ),

        const SizedBox(height: 5),

        if (match.description.isNotEmpty)
          Text(
            match.description,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: colors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

        const SizedBox(height: 8),

        buildFact(
          context,
          Icons.location_on_outlined,
          match.location,
        ),
        const SizedBox(height: 3),
        buildFact(
          context,
          Icons.calendar_today_outlined,
          match.timeAgo,
        ),
      ],
    );
  }

  // shows the match percentage using different colours for each range.
  Widget buildScorePill(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    Color background;
    Color text;

    if (score >= 80) {
      background = const Color(0xFFD5FBDD);
      text = const Color(0xFF2F7D57);
    } else if (score >= 55) {
      background = colors.surfaceSoft;
      text = colors.primary;
    } else {
      background = const Color(0xFFFFF0D6);
      text = const Color(0xFFB57A1A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 10,
            color: text,
          ),
          const SizedBox(width: 4),
          Text(
            '$score% Match',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  // builds one small detail row such as location or time.
  Widget buildFact(
    BuildContext context,
    IconData icon,
    String value,
  ) {
    final FindrColors colors = FindrColors.of(context);

    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: colors.muted,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // shows a short explanation of why this result matched.
  Widget buildReasonLine(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);
    final String reason = reasonText();

    if (reason.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool fromAi =
        match.hasAiVerdict &&
        (match.aiReason ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            fromAi
                ? Icons.auto_awesome
                : Icons.check_circle_outline,
            size: 12,
            color: fromAi
                ? const Color(0xFF7C4DFF)
                : colors.muted,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
                fontStyle: FontStyle.italic,
                color: fromAi
                    ? const Color(0xFF7C6BA8)
                    : colors.navUnselected,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // returns the ai reason or builds one from the matched fields.
  String reasonText() {
    if (match.hasAiVerdict &&
        (match.aiReason ?? '').isNotEmpty) {
      return match.aiReason!;
    }

    if (match.matched.isEmpty) {
      return '';
    }

    final List<String> parts = match.matched
        .map((match) => match.toLowerCase())
        .toList();

    if (parts.length == 1) {
      return 'Matched on ${parts.first}.';
    }

    final String last = parts.removeLast();

    return 'Matched on ${parts.join(', ')} and $last.';
  }

  // builds the view details and contact buttons.
  Widget buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: buildOutlineButton(
            context,
            'View Details',
            Icons.chevron_right_rounded,
            false,
            onViewDetails,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: buildOutlineButton(
            context,
            'Contact',
            Icons.chat_bubble_outline,
            true,
            onContactOwner,
          ),
        ),
      ],
    );
  }

  // creates one reusable action button for the card.
  Widget buildOutlineButton(
    BuildContext context,
    String label,
    IconData icon,
    bool iconFirst,
    VoidCallback onTap,
  ) {
    final FindrColors colors = FindrColors.of(context);

    final Widget text = Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colors.primary,
      ),
    );

    final Widget iconWidget = Icon(
      icon,
      size: 15,
      color: colors.primary,
    );

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: colors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: iconFirst
                ? [
                    iconWidget,
                    const SizedBox(width: 5),
                    text,
                  ]
                : [
                    text,
                    const SizedBox(width: 3),
                    iconWidget,
                  ],
          ),
        ),
      ),
    );
  }
}