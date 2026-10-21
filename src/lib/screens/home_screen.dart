import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/models/report_filter.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/screens/ai_match_screen.dart';
import 'package:findr_application/screens/report_details_screen.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_bottom_nav.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/widgets/item_report_card.dart';
import 'package:findr_application/widgets/report_filter_sheet.dart';

// home screen shows the main list of lost and found reports.
// the reports are read live from the firestore 'reports' collection.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Criteria passed into the Firestore query. The default still orders by
  // newest first, but does not restrict which reports are selected.
  ReportFilter activeFilter = const ReportFilter();

  // what the user typed into the search bar.
  String searchText = '';

  // true while the demo reports are being written to firestore.

  // Firestore already applies the structured filters. Free-text contains
  // search is layered over that result because Firestore has no native
  // case-insensitive substring search across several fields.
  List<ItemReport> applySearch(List<ItemReport> reports) {
    List<ItemReport> result = reports;

    // free text search across the fields a user would realistically type.
    if (searchText.trim().isNotEmpty) {
      final String query = searchText.toLowerCase().trim();

      result = result.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.location.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            item.colour.toLowerCase().contains(query) ||
            item.brand.toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  // opens a live select-one view for the tapped firestore report.
  Future<void> onItemTapped(ItemReport item) async {
    final wasDeleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReportDetailsScreen(reportId: item.id)),
    );

    if (!mounted || wasDeleted != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report deleted successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: AppBottomNav(currentIndex: 0),
      body: SizedBox.expand(
        child: Stack(
          children: [
            const AppPageBackground(),

            // main home content sits on top of the background image.
            SafeArea(
              child: SingleChildScrollView(
                key: const PageStorageKey('homeScroll'),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeading(),
                    const SizedBox(height: 18),
                    buildSearchBar(),
                    const SizedBox(height: 12),
                    buildAiSearchButton(),
                    if (!activeFilter.isDefault) ...[
                      const SizedBox(height: 12),
                      buildActiveFilterSummary(),
                    ],
                    const SizedBox(height: 18),
                    buildReportsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // watches the firestore reports stream and decides what to draw.
  // the stream keeps listening, so a report added or deleted by anyone shows
  // up here without the user having to refresh the screen.
  Widget buildReportsSection() {
    final reportsAsync = ref.watch(filteredReportsProvider(activeFilter));
    final countAsync = ref.watch(filteredReportCountProvider(activeFilter));

    return reportsAsync.when(
      data: (reports) {
        final List<ItemReport> visible = applySearch(reports);

        // With no criteria, an empty list means the collection itself is empty.
        if (reports.isEmpty) {
          if (!activeFilter.hasCriteria) {
            return buildEmptyState(
              icon: Icons.inbox_rounded,
              title: 'No Reports Yet',
              subtitle:
                  'Post a lost or found item and it will\n'
                  'appear here for the whole campus.',
            );
          }

          return buildEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'No Filter Matches',
            subtitle: 'Try removing one or two filter criteria.',
          );
        }

        // there are reports, but none survive the current filter or search.
        if (visible.isEmpty) {
          return buildEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Nothing Matches',
            subtitle: 'Try a different search term.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildResultsHeader(
              visibleCount: visible.length,
              databaseCount: countAsync,
            ),
            const SizedBox(height: 12),
            buildItemGrid(visible),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => buildEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could Not Load Reports',
        subtitle: 'Check your connection, or try a simpler filter combination.',
      ),
    );
  }

  // shared placeholder used when there is nothing to show in the grid.
  // it is given a generous height so the message sits in the middle of the
  // page instead of floating just under the filter chips.
  Widget buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final FindrColors colors = FindrColors.of(context);

    return SizedBox(
      width: double.infinity,
      height: 330,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.78),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: colors.muted),
          ),

          const SizedBox(height: 16),

          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // builds the top logo and home subtitle.
  // repeated here to keep the home page style same as the other screens.
  Widget buildHeading() {
    final FindrColors colors = FindrColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(-25, 0),
          child: const FindrLogo(height: 125),
        ),
        Text(
          "Lost something? Let's find it.",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  // builds the search bar under the heading.
  // the search typing is visual for part 2, but the tune button works.
  Widget buildSearchBar() {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: colors.muted, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search for lost or found items...',
                hintStyle: TextStyle(fontSize: 13),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
              // typing re-filters the reports straight away.
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Filter reports',
                icon: Icon(
                  Icons.tune_rounded,
                  color: activeFilter.isDefault ? colors.muted : colors.primary,
                ),
                onPressed: openFilterMenu,
              ),
              if (!activeFilter.isDefault)
                Positioned(
                  right: 3,
                  top: 3,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: colors.surface, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${activeFilter.criterionCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // AI search lives here rather than in the nav bar, because it is a way of
  // searching and belongs beside the search field.
  Widget buildAiSearchButton() {
    final FindrColors colors = FindrColors.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AiMatchScreen()));
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.surface, colors.surfaceSoft],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.accent, colors.primary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'AI Search',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Describe your item and let Findr match it',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: colors.backgroundAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: colors.primaryStrong,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openFilterMenu() async {
    final selected = await showModalBottomSheet<ReportFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => ReportFilterSheet(initialFilter: activeFilter),
    );

    if (!mounted || selected == null || selected == activeFilter) return;

    setState(() {
      activeFilter = selected;
    });
  }

  Widget buildActiveFilterSummary() {
    final colors = FindrColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openFilterMenu,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.filter_alt_rounded,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${activeFilter.criterionCount} active ${activeFilter.criterionCount == 1 ? 'filter' : 'filters'}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeFilter.compactSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Clear filters',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    activeFilter = const ReportFilter();
                  });
                },
                icon: Icon(
                  Icons.close_rounded,
                  size: 19,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildResultsHeader({
    required int visibleCount,
    required AsyncValue<int> databaseCount,
  }) {
    final colors = FindrColors.of(context);
    final total = databaseCount.value ?? visibleCount;
    final hasSearch = searchText.trim().isNotEmpty;
    final label = hasSearch && visibleCount != total
        ? '$visibleCount of $total results'
        : '$total ${total == 1 ? 'result' : 'results'}';

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const Spacer(),
        Tooltip(
          message: activeFilter.sortOrder == ReportSortOrder.newestFirst
              ? 'Show oldest reports first'
              : 'Show newest reports first',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  activeFilter = activeFilter.copyWith(
                    sortOrder:
                        activeFilter.sortOrder == ReportSortOrder.newestFirst
                        ? ReportSortOrder.oldestFirst
                        : ReportSortOrder.newestFirst,
                  );
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      activeFilter.sortOrder == ReportSortOrder.newestFirst
                          ? Icons.south_rounded
                          : Icons.north_rounded,
                      size: 14,
                      color: colors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activeFilter.sortOrder.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // builds the report grid from the reports passed in.
  // card height is calculated so it scales better on different screen sizes.
  Widget buildItemGrid(List<ItemReport> reports) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 40;
    const double spacing = 12;
    final double cardWidth = (screenWidth - horizontalPadding - spacing) / 2;
    final double cardHeight = (cardWidth / 1.7) + 110;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reports.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: spacing,
        mainAxisSpacing: 14,
        mainAxisExtent: cardHeight,
      ),
      itemBuilder: (context, index) {
        ItemReport item = reports[index];

        return ItemReportCard(item: item, onTap: () => onItemTapped(item));
      },
    );
  }
}
