import 'package:flutter/material.dart';
import 'package:findr_application/models/claim.dart';
import 'package:findr_application/theme/app_theme.dart';

// shows one claim inside a reusable card.
// owners can accept or reject while claimers can view their claim status.
class ClaimCard extends StatelessWidget {
  final Claim claim;
  final bool showDecisionButtons;
  final bool showReportName;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onWithdraw;
  final VoidCallback? onTap;

  // opens the chat between the owner and claimer.
  final VoidCallback? onMessage;

  const ClaimCard({
    super.key,
    required this.claim,
    this.showDecisionButtons = false,
    this.showReportName = false,
    this.busy = false,
    this.onAccept,
    this.onReject,
    this.onWithdraw,
    this.onTap,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = FindrColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // shows the first letter of the claimer's name.
                CircleAvatar(
                  radius: 17,
                  backgroundColor: colors.surfaceSoft,
                  child: Text(
                    claim.claimerName.isEmpty
                        ? '?'
                        : claim.claimerName[0].toUpperCase(),
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim.claimerName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        claim.timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                buildStatusChip(),
              ],
            ),

            // shows the report name when this card is used in the claims list.
            if (showReportName) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    claim.reportType == 'Lost'
                        ? Icons.work_outline_rounded
                        : Icons.inventory_2_outlined,
                    size: 13,
                    color: colors.muted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      claim.reportName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // shows the message written when the claim was submitted.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: colors.surfaceSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                claim.claimMessage,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
            ),

            // lets both users message each other about the claim.
            if (onMessage != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onMessage,
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                  ),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),
            ],

            // owners can accept or reject pending claims.
            if (showDecisionButtons && claim.isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : onAccept,
                      icon: const Icon(
                        Icons.check,
                        size: 17,
                      ),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5BA681),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onReject,
                      icon: const Icon(
                        Icons.close,
                        size: 17,
                      ),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE0415F),
                        side: const BorderSide(
                          color: Color(0xFFE0415F),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // claimers can withdraw while the claim is still pending.
            if (onWithdraw != null && claim.isPending) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: busy ? null : onWithdraw,
                  icon: const Icon(
                    Icons.undo,
                    size: 16,
                  ),
                  label: const Text('Withdraw claim'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                  ),
                ),
              ),
            ],

            // explains what happened after the claim was decided.
            if (claim.isAccepted) ...[
              const SizedBox(height: 10),
              buildOutcomeNote(
                Icons.check_circle_outline,
                const Color(0xFF5BA681),
                'Claim accepted. Arrange a handover, then mark the '
                'report as resolved.',
              ),
            ],

            if (claim.isRejected) ...[
              const SizedBox(height: 10),
              buildOutcomeNote(
                Icons.cancel_outlined,
                const Color(0xFFE0415F),
                'This claim was rejected.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  // shows the current claim status.
  Widget buildStatusChip() {
    Color background = const Color(0xFFFFE9C7);
    Color textColor = const Color(0xFFCC8A1F);
    String label = 'Pending';

    if (claim.isAccepted) {
      background = const Color(0xFFD5FBDD);
      textColor = const Color(0xFF5BA681);
      label = 'Accepted';
    } else if (claim.isRejected) {
      background = const Color(0xFFFFD9E1);
      textColor = const Color(0xFFE0415F);
      label = 'Rejected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  // shows the accepted or rejected message under the card.
  Widget buildOutcomeNote(
    IconData icon,
    Color color,
    String text,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}