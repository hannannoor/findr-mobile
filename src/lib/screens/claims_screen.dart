import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/claim.dart';
import 'package:findr_application/providers/chat_provider.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/screens/chat_screen.dart';
import 'package:findr_application/screens/report_details_screen.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/widgets/claim_card.dart';
import 'package:findr_application/theme/app_theme.dart';

// shows claim activity in two tabs:
//  - Received: claims other students made on this user's reports
//  - Sent: claims this user made on other people's reports
class ClaimsScreen extends ConsumerStatefulWidget {
  const ClaimsScreen({super.key});

  @override
  ConsumerState<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends ConsumerState<ClaimsScreen> {
  // 0 = received, 1 = sent
  int tabIndex = 0;

  bool isWorking = false;

  // accepts or rejects a claim on one of the user's own reports.
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
        SnackBar(content: Text(accept ? 'Claim accepted.' : 'Claim rejected.')),
      );
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

  void showFailure(Object error) {
    if (!mounted) return;

    String message = error
        .toString()
        .replaceFirst('StateError: ', '')
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE0415F),
        content: Text(message),
      ),
    );
  }

  void openReport(String reportId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailsScreen(reportId: reportId),
      ),
    );
  }

  // opens the conversation for a claim, creating it the first time.
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

  @override
  Widget build(BuildContext context) {
    final colors = FindrColors.of(context);

    return AppPage(
      title: 'Claims',
      subtitle: 'Requests to Return Items',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWorking) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
          ],

          // pill switcher instead of a tab bar, so it matches the filter
          // chips used everywhere else in the app.
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [buildToggle('Received', 0), buildToggle('Sent', 1)],
            ),
          ),

          const SizedBox(height: 16),

          if (tabIndex == 0) buildReceivedTab() else buildSentTab(),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // one half of the received/sent switcher.
  Widget buildToggle(String label, int index) {
    final bool selected = tabIndex == index;
    final colors = FindrColors.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // claims other people made on this user's reports.
  Widget buildReceivedTab() {
    final claimsAsync = ref.watch(incomingClaimsProvider);

    return claimsAsync.when(
      data: (claims) {
        if (claims.isEmpty) {
          return const AppEmptyState(
            icon: Icons.how_to_reg_outlined,
            title: 'No Claims Received',
            subtitle:
                'When someone claims one of your reports,\n'
                'it will appear here.',
          );
        }

        return Column(
          children: claims.map((claim) {
            return ClaimCard(
              claim: claim,
              showDecisionButtons: true,
              showReportName: true,
              busy: isWorking,
              onAccept: () => decideClaim(claim, accept: true),
              onReject: () => decideClaim(claim, accept: false),
              onMessage: () => openChat(claim),
              onTap: () => openReport(claim.reportId),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const AppEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could Not Load Claims',
        subtitle: 'Check your connection and try again.',
      ),
    );
  }

  // claims this user made on other people's reports.
  Widget buildSentTab() {
    final claimsAsync = ref.watch(myClaimsProvider);

    return claimsAsync.when(
      data: (claims) {
        if (claims.isEmpty) {
          return const AppEmptyState(
            icon: Icons.pan_tool_alt_outlined,
            title: 'No Claims Sent',
            subtitle:
                'Claims you make on other students\'\n'
                'reports will show up here.',
          );
        }

        return Column(
          children: claims.map((claim) {
            return ClaimCard(
              claim: claim,
              showReportName: true,
              busy: isWorking,
              onWithdraw: () => withdrawClaim(claim),
              onMessage: () => openChat(claim),
              onTap: () => openReport(claim.reportId),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const AppEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could Not Load Claims',
        subtitle: 'Check your connection and try again.',
      ),
    );
  }
}
