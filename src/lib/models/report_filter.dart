import 'package:flutter/foundation.dart';

// The two database sort orders offered on the home screen. Both map directly
// to Firestore orderBy calls rather than sorting an already-downloaded list.
enum ReportSortOrder { newestFirst, oldestFirst }

extension ReportSortOrderDetails on ReportSortOrder {
  String get label => switch (this) {
    ReportSortOrder.newestFirst => 'Newest first',
    ReportSortOrder.oldestFirst => 'Oldest first',
  };

  bool get descending => this == ReportSortOrder.newestFirst;
}

// Immutable value passed to Riverpod's family providers. Keeping all database
// criteria together ensures the list and aggregate count use the same query.
@immutable
class ReportFilter {
  static const Object _unchanged = Object();

  final String? reportType;
  final Set<String> categories;
  final String? condition;
  final String? reportStatus;
  final ReportSortOrder sortOrder;

  const ReportFilter({
    this.reportType,
    this.categories = const <String>{},
    this.condition,
    this.reportStatus,
    this.sortOrder = ReportSortOrder.newestFirst,
  });

  bool get hasCriteria =>
      reportType != null ||
      categories.isNotEmpty ||
      condition != null ||
      reportStatus != null;

  bool get isDefault =>
      !hasCriteria && sortOrder == ReportSortOrder.newestFirst;

  // Each selected category is a criterion on the same field, while the other
  // values are criteria on different fields. This drives the filter badge.
  int get criterionCount =>
      (reportType == null ? 0 : 1) +
      categories.length +
      (condition == null ? 0 : 1) +
      (reportStatus == null ? 0 : 1) +
      (sortOrder == ReportSortOrder.newestFirst ? 0 : 1);

  String get compactSummary {
    final parts = <String>[];

    if (reportType != null) parts.add(reportType!);
    if (categories.isNotEmpty) {
      final sortedCategories = categories.toList()..sort();
      parts.add(sortedCategories.join(', '));
    }
    if (condition != null) parts.add(condition!);
    if (reportStatus != null) {
      parts.add(reportStatus![0].toUpperCase() + reportStatus!.substring(1));
    }
    if (sortOrder == ReportSortOrder.oldestFirst) {
      parts.add(sortOrder.label);
    }

    return parts.isEmpty ? 'All reports' : parts.join(' | ');
  }

  ReportFilter copyWith({
    Object? reportType = _unchanged,
    Set<String>? categories,
    Object? condition = _unchanged,
    Object? reportStatus = _unchanged,
    ReportSortOrder? sortOrder,
  }) {
    return ReportFilter(
      reportType: identical(reportType, _unchanged)
          ? this.reportType
          : reportType as String?,
      categories: categories ?? this.categories,
      condition: identical(condition, _unchanged)
          ? this.condition
          : condition as String?,
      reportStatus: identical(reportStatus, _unchanged)
          ? this.reportStatus
          : reportStatus as String?,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReportFilter &&
            other.reportType == reportType &&
            setEquals(other.categories, categories) &&
            other.condition == condition &&
            other.reportStatus == reportStatus &&
            other.sortOrder == sortOrder;
  }

  @override
  int get hashCode {
    final sortedCategories = categories.toList()..sort();
    return Object.hash(
      reportType,
      Object.hashAll(sortedCategories),
      condition,
      reportStatus,
      sortOrder,
    );
  }
}
