import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/models/match_result.dart';
import 'package:findr_application/providers/chat_provider.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/screens/chat_screen.dart';
import 'package:findr_application/screens/report_details_screen.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/widgets/criteria_card.dart';
import 'package:findr_application/widgets/match_result_card.dart';
import 'package:findr_application/theme/app_theme.dart';

// shows the scored matches for whatever the user described.
//
// the scoring itself happens in MatchService, so this screen only presents
// the results and explains how they were reached.
class AiMatchResultsScreen extends ConsumerWidget {
  final List<MatchResult> matches;
  final List<List<String>> criteria;

  // 'Lost' or 'Found', describing what the user was searching for.
  final String searchingFor;

  // how many reports were actually compared, shown so the user knows
  // whether an empty result means no match or simply nothing to search.
  final int searchedCount;

  // True when the language model was reached and re-ranked the results.
  final bool usedAi;

  const AiMatchResultsScreen({
    super.key,
    required this.matches,
    required this.criteria,
    required this.searchingFor,
    this.searchedCount = 0,
    this.usedAi = false,
  });

  void openReport(BuildContext context, MatchResult match) {
    if (match.reportId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailsScreen(reportId: match.reportId),
      ),
    );
  }

  // Opens a conversation with whoever posted the matched report.
  //
  // The full report is read first because the conversation needs the owner
  // and the item details, and only the id is carried on a match result.
  Future<void> contactOwner(
    BuildContext context,
    WidgetRef ref,
    MatchResult match,
  ) async {
    if (match.reportId.isEmpty) return;

    try {
      final ItemReport? report = ref.read(reportProvider(match.reportId)).value;

      if (report == null) {
        // The report stream has not arrived yet, so the details page is
        // opened instead, where the message button also lives.
        openReport(context, match);
        return;
      }

      final String chatId = await ref
          .read(chatServiceProvider)
          .openChatForReport(report);

      if (!context.mounted) return;

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE0415F),
          content: Text(
            e
                .toString()
                .replaceFirst('StateError: ', '')
                .replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FindrColors colors = FindrColors.of(context);
    // Subscribing here means the reports are loaded by the time the contact
    // button is pressed.
    ref.watch(openReportsProvider);

    final String searchedType = searchingFor == 'Lost' ? 'found' : 'lost';

    return AppPage(
      title: 'Matches',
      subtitle: matches.isEmpty
          ? 'No matches found.'
          : '${matches.length} possible '
                '${matches.length == 1 ? 'match' : 'matches'} found.',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (criteria.isNotEmpty) ...[
            CriteriaCard(criteria: criteria),
            const SizedBox(height: 14),
          ],

          if (matches.isEmpty)
            AppEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No Matches Yet',
              subtitle: searchedCount == 0
                  ? 'There are no open $searchedType reports to\n'
                        'compare against right now.'
                  : 'Findr compared $searchedCount $searchedType '
                        '${searchedCount == 1 ? 'report' : 'reports'} but '
                        'none\nwere close enough. Try fewer details.',
              height: 300,
            )
          else ...[
            buildExplainer(context, searchedType),
            const SizedBox(height: 18),

            // Section header, so the list reads as a labelled group rather
            // than cards floating under the search summary.
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 17, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Top Matches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${matches.length} '
                  '${matches.length == 1 ? 'result' : 'results'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.muted,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ...matches.map((match) {
              return MatchResultCard(
                match: match,
                onViewDetails: () => openReport(context, match),
                onContactOwner: () => contactOwner(context, ref, match),
              );
            }),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget buildExplainer(BuildContext context, String searchedType) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: colors.muted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Findr compared your details against $searchedCount open '
              '$searchedType ${searchedCount == 1 ? 'report' : 'reports'}. '
              'Each score is weighted by how many details lined up.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
