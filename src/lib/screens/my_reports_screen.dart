import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/screens/report_details_screen.dart';
import 'package:findr_application/services/firebase_service.dart';
import 'package:findr_application/widgets/app_bottom_nav.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/theme/app_theme.dart';

// this screen shows the reports created by the logged in user.
// the reports are read live from firestore through myReportsProvider.
class MyReportsScreen extends ConsumerStatefulWidget {
  const MyReportsScreen({super.key});

  @override
  ConsumerState<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends ConsumerState<MyReportsScreen> {
  FindrColors get themeColors => FindrColors.of(context);
  // keeps track of which filter chip is selected.
  String selectedFilter = 'All';

  // stores what the user types in the search bar.
  String searchQuery = '';

  // filters shown under the search bar.
  final List<String> filters = ['All', 'Active', 'Lost', 'Found', 'Resolved'];

  // narrows the user's reports using the selected chip and the search text.
  List<ItemReport> applyFilters(List<ItemReport> reports) {
    List<ItemReport> filtered = reports;

    if (selectedFilter == 'Active') {
      filtered = filtered.where((r) => r.isOpen).toList();
    } else if (selectedFilter == 'Lost') {
      filtered = filtered.where((r) => r.reportType == 'Lost').toList();
    } else if (selectedFilter == 'Found') {
      filtered = filtered.where((r) => r.reportType == 'Found').toList();
    } else if (selectedFilter == 'Resolved') {
      filtered = filtered.where((r) => r.reportStatus == 'resolved').toList();
    }

    if (searchQuery.isNotEmpty) {
      final String query = searchQuery.toLowerCase();

      filtered = filtered.where((r) {
        return r.name.toLowerCase().contains(query) ||
            r.description.toLowerCase().contains(query) ||
            r.location.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  // counts the user's still-open lost reports.
  int lostCount(List<ItemReport> reports) {
    return reports.where((r) => r.reportType == 'Lost' && r.isOpen).length;
  }

  // counts the user's still-open found reports.
  int foundCount(List<ItemReport> reports) {
    return reports.where((r) => r.reportType == 'Found' && r.isOpen).length;
  }

  // counts reports that have already been returned to their owner.
  int resolvedCount(List<ItemReport> reports) {
    return reports.where((r) => r.reportStatus == 'resolved').length;
  }

  // deletes a report from firestore.
  // the list updates by itself afterwards because it is watching a stream.
  Future<void> deleteReport(ItemReport report) async {
    final FirebaseService firebaseService = ref.read(firebaseServiceProvider);

    try {
      await firebaseService.deleteReport(report.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report deleted successfully!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the report. Please try again.'),
        ),
      );
    }
  }

  // asks the user to confirm before deleting, so a report is not lost
  // because of an accidental tap.
  void confirmDelete(ItemReport report) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: Text(
            'Are you sure you want to delete your report for '
            '"${report.name}"? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                deleteReport(report);
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  // marks a report as resolved once the item has been returned.
  // this only changes the one field instead of rewriting the document.
  Future<void> markResolved(ItemReport report) async {
    final FirebaseService firebaseService = ref.read(firebaseServiceProvider);

    try {
      await firebaseService.updateReportStatus(report.id, 'resolved');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${report.name} marked as resolved.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update the report. Please try again.'),
        ),
      );
    }
  }

  // gives each filter chip a matching icon.
  IconData filterIcon(String filter) {
    switch (filter) {
      case 'All':
        return Icons.grid_view_rounded;
      case 'Active':
        return Icons.access_time;
      case 'Lost':
        return Icons.work_outline_rounded;
      case 'Found':
        return Icons.inventory_2_outlined;
      case 'Resolved':
        return Icons.check_circle_outline;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    // watches only the reports belonging to the logged in user.
    final myReportsAsync = ref.watch(myReportsProvider);

    return Scaffold(
      backgroundColor: themeColors.backgroundAlt,
      bottomNavigationBar: const AppBottomNav(currentIndex: -1),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AppPageBackground(),

            // main my reports content goes above the background image.
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeading(),
                    const SizedBox(height: 18),
                    buildSearchBar(),
                    const SizedBox(height: 14),
                    buildFilterChips(),
                    const SizedBox(height: 14),

                    myReportsAsync.when(
                      data: (reports) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildStatsRow(reports),
                            const SizedBox(height: 18),
                            buildReportsList(applyFilters(reports)),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text('Error loading your reports.'),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // builds the top logo and subtitle.
  // repeated here so the page matches the other findr screens.
  Widget buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // this page is opened from profile rather than the nav bar, so it
        // needs its own way back.
        const Row(children: [AppBackButton()]),
        const SizedBox(height: 6),
        Transform.translate(
          offset: const Offset(-25, 0),
          child: const FindrLogo(height: 115),
        ),
        Text(
          'Manage and track your reports.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: themeColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // builds the search bar.
  // typing here filters the sample reports.
  Widget buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search your reports...',
                hintStyle: TextStyle(fontSize: 13),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Icon(Icons.tune, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }

  // builds the horizontal filter chips.
  // tapping a chip changes which reports are shown.
  Widget buildFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          String filter = filters[index];
          bool isSelected = selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = filter;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? themeColors.primary : themeColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    filterIcon(filter),
                    size: 14,
                    color: isSelected ? Colors.white : Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // builds the lost, found and resolved summary cards.
  // the counts are worked out from the reports fetched from firestore.
  Widget buildStatsRow(List<ItemReport> reports) {
    return Row(
      children: [
        buildStatCard(
          Icons.work_outline_rounded,
          '${lostCount(reports)}',
          'Lost',
          'active posts',
          const Color(0xFFD94084),
          const Color(0xFFFFD0E8),
        ),
        const SizedBox(width: 10),
        buildStatCard(
          Icons.inventory_2_outlined,
          '${foundCount(reports)}',
          'Found',
          'active posts',
          const Color(0xFF5BA681),
          const Color(0xFFD5FBDD),
        ),
        const SizedBox(width: 10),
        buildStatCard(
          Icons.check_circle_outline,
          '${resolvedCount(reports)}',
          'Resolved',
          'completed posts',
          themeColors.primary,
          themeColors.surfaceSoft,
        ),
      ],
    );
  }

  // builds one stat card.
  // reused for the three counts above.
  Widget buildStatCard(
    IconData icon,
    String count,
    String label,
    String sublabel,
    Color iconColor,
    Color bgColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: themeColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: bgColor.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // builds the list of report cards.
  // if no reports match, an empty state is shown instead.
  Widget buildReportsList(List<ItemReport> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              'No reports found',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items.map((report) {
        return buildReportCard(report);
      }).toList(),
    );
  }

  // builds one report card.
  // each card shows image, report info, badges and action buttons.
  Widget buildReportCard(ItemReport report) {
    bool isResolved = report.reportStatus == 'resolved';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // image stays on the left side of the report card.
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(width: 95, child: buildReportPhoto(report)),
            ),

            const SizedBox(width: 12),

            // middle section shows the report details.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // lost/found badge on the left and status badge on the right.
                  Row(
                    children: [
                      buildTypeBadge(report.reportType),
                      const Spacer(),
                      buildStatusBadge(report.reportStatus),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: themeColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.description,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  buildInfoRow(Icons.location_on_outlined, report.location),
                  const SizedBox(height: 3),
                  buildInfoRow(
                    Icons.calendar_today,
                    formatDateTime(report.dateLostFound),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // divider separates the details from the action buttons.
            Container(width: 1, color: Colors.grey[200]),

            const SizedBox(width: 12),

            // actions the user can take on their own report.
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // an already resolved report cannot be resolved again.
                if (!isResolved) ...[
                  buildActionButton(
                    Icons.check_circle_outline,
                    'Resolve',
                    const Color(0xFF5BA681),
                    () => markResolved(report),
                  ),
                  buildActionDivider(),
                ],
                buildActionButton(
                  Icons.delete_outline,
                  'Delete',
                  const Color(0xFFE0415F),
                  () => confirmDelete(report),
                ),
                buildActionDivider(),
                buildActionButton(
                  Icons.chevron_right,
                  'View Details',
                  themeColors.primary,
                  () async {
                    final wasDeleted = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            ReportDetailsScreen(reportId: report.id),
                      ),
                    );

                    if (!mounted || wasDeleted != true) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report deleted successfully!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // builds one icon and text row for location and date.
  Widget buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // builds the thin line between action buttons.
  Widget buildActionDivider() {
    return Container(
      width: 90,
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 9),
      color: Colors.grey[200],
    );
  }

  // builds one action button for the report card.
  // the action to run is passed in, so each button can do something different.
  Widget buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 18, child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // builds the lost/found badge.
  // lost uses pink and found uses green.
  Widget buildTypeBadge(String type) {
    bool isLost = type == 'Lost';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLost
            ? const Color(0xFFFFD0E8).withOpacity(0.65)
            : const Color(0xFFD5FBDD).withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isLost ? const Color(0xFFD94084) : const Color(0xFF5BA681),
        ),
      ),
    );
  }

  // builds the active/claimed/resolved badge.
  // the status is stored lowercase in firestore, so it is tidied up for display.
  Widget buildStatusBadge(String status) {
    bool isResolved = status == 'resolved';
    bool isClaimed = status == 'claimed';

    String label = 'Active';
    if (isResolved) {
      label = 'Resolved';
    } else if (isClaimed) {
      label = 'Claimed';
    }

    Color background = themeColors.surfaceSoft;
    Color textColor = themeColors.primary;

    if (isResolved) {
      background = const Color(0xFFE8DFFF);
      textColor = const Color(0xFF7C4DFF);
    } else if (isClaimed) {
      background = const Color(0xFFFFE9C7);
      textColor = const Color(0xFFCC8A1F);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  // decides how to draw the report photo.
  // reports created in the app hold a base64 string, older sample reports
  // only have a bundled asset path.
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
        errorBuilder: (context, error, stackTrace) => buildPhotoPlaceholder(),
      );
    }

    if (report.imagePath.isEmpty) {
      return buildPhotoPlaceholder();
    }

    return Image.asset(
      report.imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => buildPhotoPlaceholder(),
    );
  }

  // grey box shown when a report has no usable photo.
  Widget buildPhotoPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  // turns the stored date into something readable on the card,
  // for example "12 May 2025 - 2:15 PM".
  String formatDateTime(DateTime dateTime) {
    const List<String> months = [
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

    // convert 24 hour time into 12 hour time with am/pm.
    final int hour24 = dateTime.hour;
    final String period = hour24 >= 12 ? 'PM' : 'AM';

    int hour12 = hour24 % 12;
    if (hour12 == 0) {
      hour12 = 12;
    }

    final String minute = dateTime.minute.toString().padLeft(2, '0');

    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}'
        ' - $hour12:$minute $period';
  }
}
