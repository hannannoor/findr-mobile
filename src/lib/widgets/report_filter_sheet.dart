import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/report_filter.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/theme/app_theme.dart';

// bottom sheet used to filter and sort reports.
class ReportFilterSheet extends ConsumerStatefulWidget {
  final ReportFilter initialFilter;

  const ReportFilterSheet({
    super.key,
    required this.initialFilter,
  });

  @override
  ConsumerState<ReportFilterSheet> createState() =>
      _ReportFilterSheetState();
}

class _ReportFilterSheetState
    extends ConsumerState<ReportFilterSheet> {
  // options shown in the category filter.
  static const categories = <String>[
    'Electronics',
    'Bags',
    'Bottles',
    'Accessories',
    'Stationery',
    'Other',
  ];

  // options shown in the condition filter.
  static const conditions = <String>[
    'New',
    'Like New',
    'Used',
    'Damaged',
    'Not Sure',
  ];

  // stores the filter changes before the user applies them.
  late ReportFilter draft;

  @override
  void initState() {
    super.initState();

    draft = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final colors = FindrColors.of(context);

    // updates the matching report count whenever the draft filter changes.
    final countAsync =
        ref.watch(filteredReportCountProvider(draft));

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),

              // small handle shown at the top of the sheet.
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              _buildHeader(colors),

              Divider(
                height: 1,
                color: colors.border,
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _buildCountPreview(
                        colors,
                        countAsync,
                      ),

                      const SizedBox(height: 24),

                      _buildSection(
                        colors,
                        title: 'Report type',
                        subtitle:
                            'Choose one type or include both.',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoice(
                              colors,
                              label: 'Any type',
                              icon: Icons.layers_outlined,
                              selected:
                                  draft.reportType == null,
                              onTap: () =>
                                  _setReportType(null),
                            ),
                            _buildChoice(
                              colors,
                              label: 'Lost',
                              icon: Icons.search_rounded,
                              selected:
                                  draft.reportType ==
                                      'Lost',
                              onTap: () =>
                                  _setReportType('Lost'),
                            ),
                            _buildChoice(
                              colors,
                              label: 'Found',
                              icon: Icons
                                  .inventory_2_outlined,
                              selected:
                                  draft.reportType ==
                                      'Found',
                              onTap: () =>
                                  _setReportType('Found'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildSection(
                        colors,
                        title: 'Categories',
                        subtitle:
                            'Select multiple categories to search the same field.',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              categories.map((category) {
                            final selected =
                                draft.categories
                                    .contains(category);

                            return _buildChoice(
                              colors,
                              label: category,
                              selected: selected,
                              showCheck: true,
                              onTap: () =>
                                  _toggleCategory(
                                category,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildSection(
                        colors,
                        title: 'Condition',
                        subtitle:
                            'Optional item condition.',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoice(
                              colors,
                              label: 'Any',
                              selected:
                                  draft.condition == null,
                              onTap: () =>
                                  _setCondition(null),
                            ),
                            ...conditions.map(
                              (condition) =>
                                  _buildChoice(
                                colors,
                                label: condition,
                                selected:
                                    draft.condition ==
                                        condition,
                                onTap: () =>
                                    _setCondition(
                                  condition,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildSection(
                        colors,
                        title: 'Report status',
                        subtitle:
                            'Filter by the report workflow stage.',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoice(
                              colors,
                              label: 'Any',
                              selected:
                                  draft.reportStatus ==
                                      null,
                              onTap: () =>
                                  _setReportStatus(
                                null,
                              ),
                            ),
                            _buildChoice(
                              colors,
                              label: 'Open',
                              selected:
                                  draft.reportStatus ==
                                      'open',
                              onTap: () =>
                                  _setReportStatus(
                                'open',
                              ),
                            ),
                            _buildChoice(
                              colors,
                              label: 'Claimed',
                              selected:
                                  draft.reportStatus ==
                                      'claimed',
                              onTap: () =>
                                  _setReportStatus(
                                'claimed',
                              ),
                            ),
                            _buildChoice(
                              colors,
                              label: 'Resolved',
                              selected:
                                  draft.reportStatus ==
                                      'resolved',
                              onTap: () =>
                                  _setReportStatus(
                                'resolved',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildSection(
                        colors,
                        title: 'Sort order',
                        subtitle:
                            'Order reports by when they were posted.',
                        child: Row(
                          children:
                              ReportSortOrder.values
                                  .map((sortOrder) {
                            return Expanded(
                              child: Padding(
                                padding:
                                    EdgeInsets.only(
                                  right: sortOrder ==
                                          ReportSortOrder
                                              .newestFirst
                                      ? 8
                                      : 0,
                                ),
                                child: _buildChoice(
                                  colors,
                                  label:
                                      sortOrder.label,
                                  icon: sortOrder ==
                                          ReportSortOrder
                                              .newestFirst
                                      ? Icons
                                          .arrow_downward_rounded
                                      : Icons
                                          .arrow_upward_rounded,
                                  selected:
                                      draft.sortOrder ==
                                          sortOrder,
                                  expand: true,
                                  onTap: () {
                                    setState(() {
                                      draft =
                                          draft.copyWith(
                                        sortOrder:
                                            sortOrder,
                                      );
                                    });
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _buildActions(colors),
            ],
          ),
        ),
      ),
    );
  }

  // builds the title and close button at the top.
  Widget _buildHeader(FindrColors colors) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primary.withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter reports',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Refine the campus report database',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close filters',
            onPressed: () =>
                Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // shows how many reports currently match the selected filters.
  Widget _buildCountPreview(
    FindrColors colors,
    AsyncValue<int> countAsync,
  ) {
    final countText = countAsync.when(
      data: (count) =>
          '$count ${count == 1 ? 'report' : 'reports'} match',
      loading: () =>
          'Checking matching reports...',
      error: (_, _) =>
          'Count preview unavailable',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(
              alpha: 0.14,
            ),
            colors.accent.withValues(
              alpha: 0.08,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(
            alpha: 0.22,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.query_stats_rounded,
            color: colors.primary,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  countText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Live total calculated by Firestore',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (countAsync.isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
        ],
      ),
    );
  }

  // builds one labelled group of filter options.
  Widget _buildSection(
    FindrColors colors, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11.5,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 11),
        child,
      ],
    );
  }

  // builds one selectable filter option.
  Widget _buildChoice(
    FindrColors colors, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    bool showCheck = false,
    bool expand = false,
  }) {
    final foreground = selected
        ? colors.primaryStrong
        : colors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(13),
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 160),
          width:
              expand ? double.infinity : null,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(
                    alpha: 0.12,
                  )
                : colors.surfaceSoft,
            borderRadius:
                BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(
                      alpha: 0.52,
                    )
                  : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: expand
                ? MainAxisSize.max
                : MainAxisSize.min,
            mainAxisAlignment: expand
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: foreground,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: foreground,
                ),
              ),
              if (showCheck &&
                  selected) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: colors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // builds the reset and apply buttons at the bottom.
  Widget _buildActions(
    FindrColors colors,
  ) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        14,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.05,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              // resets everything back to the default filter.
              onPressed: () {
                setState(() {
                  draft =
                      const ReportFilter();
                });
              },
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    colors.textPrimary,
                side: BorderSide(
                  color: colors.border,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
              child:
                  const Text('Reset'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              // returns the selected filter to the previous screen.
              onPressed: () =>
                  Navigator.of(context)
                      .pop(draft),
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    colors.primary,
                foregroundColor:
                    Colors.white,
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
              icon: const Icon(
                Icons.check_rounded,
                size: 18,
              ),
              label:
                  const Text('Show results'),
            ),
          ),
        ],
      ),
    );
  }

  // changes the selected report type.
  void _setReportType(String? value) {
    setState(() {
      draft = draft.copyWith(
        reportType: value,
      );
    });
  }

  // adds or removes one category from the selected set.
  void _toggleCategory(
    String category,
  ) {
    final nextCategories =
        Set<String>.from(
      draft.categories,
    );

    if (!nextCategories.add(category)) {
      nextCategories.remove(category);
    }

    setState(() {
      draft = draft.copyWith(
        categories:
            Set.unmodifiable(
          nextCategories,
        ),
      );
    });
  }

  // changes the selected condition.
  void _setCondition(
    String? value,
  ) {
    setState(() {
      draft = draft.copyWith(
        condition: value,
      );
    });
  }

  // changes the selected report status.
  void _setReportStatus(
    String? value,
  ) {
    setState(() {
      draft = draft.copyWith(
        reportStatus: value,
      );
    });
  }
}