import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/claim.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/providers/chat_provider.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/screens/chat_screen.dart';
import 'package:findr_application/screens/edit_report_screen.dart';
import 'package:findr_application/services/firebase_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:findr_application/services/campus.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/claim_card.dart';
import 'package:findr_application/widgets/claim_message_sheet.dart';
import 'package:findr_application/widgets/post_widgets.dart';

// shows one live firestore report selected by its document id.
// edits and status changes appear here automatically through reportProvider.
class ReportDetailsScreen extends ConsumerStatefulWidget {
  final String reportId;

  const ReportDetailsScreen({super.key, required this.reportId});

  @override
  ConsumerState<ReportDetailsScreen> createState() =>
      _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends ConsumerState<ReportDetailsScreen> {
  FindrColors get themeColors => FindrColors.of(context);
  bool isWorking = false;

  bool isOwner(ItemReport report) {
    return FirebaseAuth.instance.currentUser?.uid == report.userId;
  }

  Future<void> openEdit(ItemReport report) async {
    final wasUpdated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditReportScreen(report: report)),
    );

    if (!mounted || wasUpdated != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report updated successfully!')),
    );
  }

  void confirmResolve(ItemReport report) {
    // resolving also hands over any reward findr is holding, so the dialog
    // has to say so before the owner confirms.
    final bool releasesReward = report.hasEscrow;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mark as Resolved'),
          content: Text(
            releasesReward
                ? 'Has "${report.name}" been returned to you?\n\n'
                      'The \$${report.reward!.toStringAsFixed(2)} reward '
                      'being held will be released to the finder, and this '
                      'cannot be undone.'
                : 'Has "${report.name}" been returned to its owner? '
                      'This will move the report out of the active list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                resolveReport(report);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5BA681),
                foregroundColor: Colors.white,
              ),
              child: const Text('Resolve'),
            ),
          ],
        );
      },
    );
  }

  Future<void> resolveReport(ItemReport report) async {
    if (isWorking) return;

    setState(() {
      isWorking = true;
    });

    try {
      final service = ref.read(firebaseServiceProvider);
      final bool releasesReward = report.hasEscrow;

      await service.updateReportStatus(report.id, 'resolved');

      // the held reward is handed over at the same time the report closes.
      if (releasesReward) {
        await service.releaseReward(report.id);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            releasesReward
                ? '${report.name} resolved. The reward has been released '
                      'to the finder.'
                : '${report.name} marked as resolved.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update the report. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isWorking = false;
        });
      }
    }
  }

  void confirmDelete(ItemReport report) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: Text(
            'Are you sure you want to permanently delete the report for '
            '"${report.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                deleteReport(report);
              },
              child: const Text(
                'Yes, Delete',
                style: TextStyle(color: Color(0xFFE0415F)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteReport(ItemReport report) async {
    if (isWorking) return;

    setState(() {
      isWorking = true;
    });

    try {
      final FirebaseService service = ref.read(firebaseServiceProvider);
      await service.deleteReport(report.id);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isWorking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the report. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportProvider(widget.reportId));

    return Scaffold(
      backgroundColor: themeColors.backgroundAlt,
      body: Stack(
        children: [
          const AppPageBackground(),
          SafeArea(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => buildMessageState(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load this report',
                message: 'Check your connection and try again.',
              ),
              data: (report) {
                if (report == null) {
                  return buildMessageState(
                    icon: Icons.find_in_page_outlined,
                    title: 'Report no longer available',
                    message: 'It may have been deleted by its owner.',
                  );
                }

                return buildReportPage(report);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReportPage(ItemReport report) {
    final owner = isOwner(report);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeading(),
          const SizedBox(height: 16),
          buildHeroCard(report),
          const SizedBox(height: 14),
          buildItemDetailsCard(report),
          const SizedBox(height: 14),
          buildLocationCard(report),
          if (report.reportType == 'Lost' &&
              report.reward != null &&
              report.reward! > 0) ...[
            const SizedBox(height: 14),
            buildRewardCard(report),
          ],
          const SizedBox(height: 14),
          buildReportInfoCard(report, owner),

          // the owner reviews incoming claims, everyone else gets the
          // button to make a claim of their own.
          const SizedBox(height: 14),
          if (owner) buildClaimsCard(report) else buildClaimActionCard(report),

          if (owner) ...[const SizedBox(height: 14), buildOwnerActions(report)],
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  Widget buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppBackButton(),
            const SizedBox(width: 8),
            Expanded(
              child: Transform.translate(
                offset: const Offset(-8, 0),
                child: const FindrLogo(height: 105),
              ),
            ),
          ],
        ),
        Text(
          'View the full report details.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: themeColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget buildHeroCard(ItemReport report) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(aspectRatio: 16 / 9, child: buildReportPhoto(report)),
              Positioned(
                top: 12,
                left: 12,
                child: buildTypeBadge(report.reportType),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: buildStatusBadge(report.reportStatus),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.name,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: themeColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  children: [
                    buildSmallInfo(Icons.grid_view_rounded, report.category),
                    buildSmallInfo(Icons.schedule, report.timeAgo),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildItemDetailsCard(ItemReport report) {
    return PostSectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Item Details',
      children: [
        Text(
          report.description,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF43516B),
          ),
        ),
        const SizedBox(height: 15),
        buildDetailRow(Icons.grid_view_rounded, 'Category', report.category),
        buildDetailRow(Icons.palette_outlined, 'Colour', report.colour),
        if (report.brand.isNotEmpty)
          buildDetailRow(Icons.business_outlined, 'Brand', report.brand),
        if (report.condition.isNotEmpty)
          buildDetailRow(
            Icons.fact_check_outlined,
            'Condition',
            report.condition,
          ),
      ],
    );
  }

  Widget buildLocationCard(ItemReport report) {
    return PostSectionCard(
      icon: Icons.location_on_outlined,
      title: 'Location & Date',
      children: [
        buildDetailRow(Icons.location_on_outlined, 'Location', report.location),
        buildDetailRow(
          Icons.calendar_today,
          report.reportType == 'Lost' ? 'Date Lost' : 'Date Found',
          formatDateTime(report.dateLostFound),
        ),

        // A small non interactive map, so the written location is backed up
        // by the exact spot on campus.
        if (report.hasLocation) ...[
          const SizedBox(height: 12),
          buildMiniMap(report),
        ],
      ],
    );
  }

  // A preview of where the report was pinned.
  //
  // Gestures are switched off so it never fights the page scroll, and it
  // opens the full map screen when tapped instead.
  Widget buildMiniMap(ItemReport report) {
    final LatLng point = LatLng(report.latitude!, report.longitude!);
    final bool isLost = report.reportType == 'Lost';

    final Color pinColour = isLost
        ? const Color(0xFFD94084)
        : const Color(0xFF3E8C63);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 150,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 17.2,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: Campus.tileUrl,
                  userAgentPackageName: Campus.userAgent,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: pinColour,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.4),
                        ),
                        child: Icon(
                          isLost
                              ? Icons.work_outline_rounded
                              : Icons.inventory_2_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            Positioned(
              right: 9,
              bottom: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: themeColors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: themeColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 12,
                      color: themeColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Pinned on campus',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: themeColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRewardCard(ItemReport report) {
    return PostSectionCard(
      icon: Icons.card_giftcard,
      title: 'Reward Offered',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/images/present.png',
                width: 38,
                height: 38,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.card_giftcard, color: Color(0xFFD94084)),
              ),
              const SizedBox(width: 10),
              Text(
                '\$${report.reward!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD94084),
                ),
              ),
            ],
          ),
        ),

        // makes clear whether the money is actually secured, which is the
        // whole point of paying the reward up front through NETS.
        const SizedBox(height: 10),
        buildEscrowNote(report),
      ],
    );
  }

  // one line explaining where the reward money currently sits.
  Widget buildEscrowNote(ItemReport report) {
    IconData icon;
    Color colour;
    String text;

    if (report.rewardReleased) {
      icon = Icons.task_alt;
      colour = const Color(0xFF5BA681);
      text = 'This reward has been released to the finder.';
    } else if (report.rewardPaid) {
      icon = Icons.lock_outline;
      colour = const Color(0xFF5BA681);
      text =
          'Paid via NETS QR and held securely by Findr. It is released '
          'to whoever returns the item.';
    } else {
      icon = Icons.info_outline;
      colour = themeColors.textSecondary;
      text = 'This reward has not been secured through NETS yet.';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: colour),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, height: 1.4, color: colour),
          ),
        ),
        if (report.rewardPaid && report.paymentTxnRef.isNotEmpty)
          const SizedBox(width: 4),
      ],
    );
  }

  Widget buildReportInfoCard(ItemReport report, bool owner) {
    return PostSectionCard(
      icon: Icons.info_outline,
      title: 'Report Information',
      children: [
        buildDetailRow(
          Icons.person_outline,
          'Reported By',
          owner ? 'You' : 'Findr community member',
        ),
        buildDetailRow(
          Icons.upload_outlined,
          'Posted',
          formatDateTime(report.createdAt),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // claims
  // ---------------------------------------------------------------------

  // opens the sheet where a user writes their claim message.
  // the sheet manages its own controller, so nothing is disposed early here.
  Future<void> openClaimSheet(ItemReport report) async {
    final String? message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: themeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ClaimMessageSheet(reportType: report.reportType);
      },
    );

    if (message == null || message.isEmpty || !mounted) {
      return;
    }

    await submitClaim(report, message);
  }

  Future<void> submitClaim(ItemReport report, String message) async {
    if (isWorking) return;

    setState(() => isWorking = true);

    try {
      await ref.read(firebaseServiceProvider).submitClaim(report, message);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim submitted. The owner will review it.'),
        ),
      );
    } catch (e) {
      showFailure(e);
    } finally {
      if (mounted) setState(() => isWorking = false);
    }
  }

  Future<void> decideClaim(Claim claim, {required bool accept}) async {
    if (isWorking) return;

    setState(() => isWorking = true);

    try {
      final service = ref.read(firebaseServiceProvider);

      if (accept) {
        await service.acceptClaim(claim);
      } else {
        await service.rejectClaim(claim);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Claim accepted. Other pending claims were rejected.'
                : 'Claim rejected.',
          ),
        ),
      );
    } catch (e) {
      showFailure(e);
    } finally {
      if (mounted) setState(() => isWorking = false);
    }
  }

  // shows the readable part of an error instead of the raw exception text.
  void showFailure(Object error) {
    if (!mounted) return;

    String message = error.toString();
    message = message
        .replaceFirst('StateError: ', '')
        .replaceFirst('ArgumentError: ', '')
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE0415F),
        content: Text(message),
      ),
    );
  }

  // card shown to everyone who does not own the report.
  Widget buildClaimActionCard(ItemReport report) {
    final claimsAsync = ref.watch(claimsForReportProvider(report.id));
    final String? myId = FirebaseAuth.instance.currentUser?.uid;

    final claims = claimsAsync.value ?? <Claim>[];

    // the claim this user already made on this report, if any.
    // kept as a final local so it stays non-null inside the button callbacks.
    final List<Claim> mine = claims.where((c) => c.claimerId == myId).toList();
    final Claim? existingClaim = mine.isEmpty ? null : mine.first;

    final bool resolved = report.reportStatus == 'resolved';

    return PostSectionCard(
      icon: Icons.pan_tool_alt_outlined,
      title: report.reportType == 'Found' ? 'Is this yours?' : 'Found this?',
      children: [
        if (existingClaim != null) ...[
          Text(
            'You have already submitted a claim on this report.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          ClaimCard(
            claim: existingClaim,
            busy: isWorking,
            onWithdraw: () => withdrawClaim(existingClaim),
            onMessage: () => openChat(existingClaim),
          ),
        ] else if (resolved) ...[
          Text(
            'This report has been resolved, so it can no longer be claimed.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ] else ...[
          Text(
            report.reportType == 'Found'
                ? 'If this item belongs to you, send the finder a message '
                      'describing it so they can verify your claim.'
                : 'If you have found this item, let the owner know so they '
                      'can arrange to collect it.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isWorking ? null : () => openClaimSheet(report),
              icon: const Icon(Icons.pan_tool_alt_outlined, size: 18),
              label: Text(
                report.reportType == 'Found' ? 'Claim Item' : 'I found this',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],

        // asking a question should not require committing to a claim, so
        // the message option is always available to anyone but the poster.
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isWorking ? null : () => openChatWithPoster(report),
            icon: const Icon(Icons.chat_bubble_outline, size: 17),
            label: Text(
              report.reportType == 'Found'
                  ? 'Message the finder'
                  : 'Message the owner',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: themeColors.primary,
              side: BorderSide(
                color: themeColors.primary.withValues(alpha: 0.38),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // messages the person who posted the report, without needing a claim.
  Future<void> openChatWithPoster(ItemReport report) async {
    if (isWorking) return;

    setState(() => isWorking = true);

    try {
      final String chatId = await ref
          .read(chatServiceProvider)
          .openChatForReport(report);

      if (!mounted) return;

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
    } catch (e) {
      showFailure(e);
    } finally {
      if (mounted) setState(() => isWorking = false);
    }
  }

  // opens (and creates on first use) the conversation for a claim.
  Future<void> openChat(Claim claim) async {
    if (isWorking) return;

    setState(() => isWorking = true);

    try {
      final String chatId = await ref
          .read(chatServiceProvider)
          .openChatForClaim(claim);

      if (!mounted) return;

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
    } catch (e) {
      showFailure(e);
    } finally {
      if (mounted) setState(() => isWorking = false);
    }
  }

  Future<void> withdrawClaim(Claim claim) async {
    if (isWorking) return;

    setState(() => isWorking = true);

    try {
      await ref.read(firebaseServiceProvider).withdrawClaim(claim);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Claim withdrawn.')));
    } catch (e) {
      showFailure(e);
    } finally {
      if (mounted) setState(() => isWorking = false);
    }
  }

  // card shown to the report owner, listing everyone who has claimed.
  Widget buildClaimsCard(ItemReport report) {
    final claimsAsync = ref.watch(claimsForReportProvider(report.id));

    return PostSectionCard(
      icon: Icons.how_to_reg_outlined,
      title: 'Claims',
      children: [
        claimsAsync.when(
          data: (claims) {
            if (claims.isEmpty) {
              return Text(
                'No one has claimed this item yet. You will see their '
                'message here when they do.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.grey[600],
                ),
              );
            }

            final int pending = claims.where((c) => c.isPending).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending > 0
                      ? '$pending claim${pending == 1 ? '' : 's'} waiting for '
                            'your decision.'
                      : 'All claims have been reviewed.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                ...claims.map((claim) {
                  return ClaimCard(
                    claim: claim,
                    showDecisionButtons: true,
                    busy: isWorking,
                    onAccept: () => decideClaim(claim, accept: true),
                    onReject: () => decideClaim(claim, accept: false),
                    onMessage: () => openChat(claim),
                  );
                }),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Could not load claims.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget buildOwnerActions(ItemReport report) {
    final isResolved = report.reportStatus == 'resolved';

    return PostSectionCard(
      icon: Icons.settings_outlined,
      title: 'Manage Report',
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isWorking ? null : () => openEdit(report),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
            if (!isResolved) ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isWorking ? null : () => confirmResolve(report),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Resolve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5BA681),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isWorking ? null : () => confirmDelete(report),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete Report'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE0415F),
              side: const BorderSide(color: Color(0xFFE0415F)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
        if (isWorking) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: themeColors.surfaceSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: themeColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: themeColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSmallInfo(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 5),
        Text(value, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget buildTypeBadge(String type) {
    final lost = type == 'Lost';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: lost
            ? const Color(0xFFFFD0E8).withOpacity(0.92)
            : const Color(0xFFD5FBDD).withOpacity(0.92),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: lost ? const Color(0xFFD94084) : const Color(0xFF5BA681),
        ),
      ),
    );
  }

  Widget buildStatusBadge(String status) {
    String label = 'Active';
    Color background = themeColors.surfaceSoft;
    Color foreground = themeColors.primary;

    if (status == 'resolved') {
      label = 'Resolved';
      background = const Color(0xFFE8DFFF);
      foreground = const Color(0xFF7C4DFF);
    } else if (status == 'claimed') {
      label = 'Claimed';
      background = const Color(0xFFFFE9C7);
      foreground = const Color(0xFFCC8A1F);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background.withOpacity(0.94),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }

  Widget buildReportPhoto(ItemReport report) {
    Uint8List? bytes;

    if (report.hasPhoto) {
      try {
        bytes = base64Decode(report.base64Image);
      } catch (_) {
        bytes = null;
      }
    }

    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => buildPhotoPlaceholder(),
      );
    }

    if (report.imagePath.isNotEmpty) {
      return Image.asset(
        report.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => buildPhotoPlaceholder(),
      );
    }

    return buildPhotoPlaceholder();
  }

  Widget buildPhotoPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.image_outlined, size: 54, color: Colors.grey),
      ),
    );
  }

  Widget buildMessageState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Align(alignment: Alignment.centerLeft, child: buildMessageBack()),
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: themeColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 54, color: themeColors.textSecondary),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: themeColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMessageBack() {
    return const AppBackButton();
  }

  String formatDateTime(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final period = value.hour >= 12 ? 'PM' : 'AM';
    int hour = value.hour % 12;
    if (hour == 0) hour = 12;

    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day} ${months[value.month - 1]} ${value.year}'
        ' - $hour:$minute $period';
  }
}
