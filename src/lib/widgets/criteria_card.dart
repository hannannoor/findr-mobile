import 'package:flutter/material.dart';
import 'package:findr_application/theme/app_theme.dart';

// Shows the details the user searched with at the top of the results page.
// The compact grid mirrors the report-dashboard style used throughout Findr.
class CriteriaCard extends StatelessWidget {
  final List<List<String>> criteria;

  const CriteriaCard({super.key, required this.criteria});

  IconData iconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'item name':
        return Icons.sell_outlined;
      case 'category':
        return Icons.grid_view_rounded;
      case 'colour':
        return Icons.palette_outlined;
      case 'brand':
        return Icons.shield_outlined;
      case 'condition':
        return Icons.adjust_rounded;
      case 'location':
        return Icons.location_on_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);
    final validCriteria = criteria
        .where((pair) => pair.length >= 2 && pair[1].trim().isNotEmpty)
        .toList();

    if (validCriteria.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeader(context),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              // Three columns match the reference on normal phones. Very
              // narrow layouts fall back to two so values never overflow.
              final columnCount = constraints.maxWidth >= 300 ? 3 : 2;
              return buildGrid(
                context,
                validCriteria,
                columnCount,
                constraints.maxWidth,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildHeader(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.view_in_ar_outlined,
            size: 17,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            'Your Search Criteria',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.15,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildGrid(
    BuildContext context,
    List<List<String>> items,
    int columnCount,
    double availableWidth,
  ) {
    final rowCount = (items.length / columnCount).ceil();
    final cellWidth = availableWidth / columnCount;

    return Wrap(
      children: List.generate(items.length, (index) {
        final columnIndex = index % columnCount;
        final rowIndex = index ~/ columnCount;

        return Container(
          width: cellWidth,
          height: 66,
          decoration: BoxDecoration(
            border: Border(
              right: columnIndex < columnCount - 1
                  ? BorderSide(color: FindrColors.of(context).border)
                  : BorderSide.none,
              bottom: rowIndex < rowCount - 1
                  ? BorderSide(color: FindrColors.of(context).border)
                  : BorderSide.none,
            ),
          ),
          child: buildCriterion(context, items[index]),
        );
      }),
    );
  }

  Widget buildCriterion(BuildContext context, List<String> pair) {
    final FindrColors colors = FindrColors.of(context);
    final label = pair[0];
    final value = pair[1];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(iconForLabel(label), size: 16, color: colors.primary),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
