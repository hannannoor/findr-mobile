import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/theme/app_theme.dart';

// this card shows one lost/found item on the home screen.
// it is reused in the home grid so the home file stays cleaner.
class ItemReportCard extends StatelessWidget {
  final ItemReport item;
  final VoidCallback onTap;

  const ItemReportCard({super.key, required this.item, required this.onTap});

  // text colour changes based on whether the item is lost or found.
  Color get statusTextColor {
    if (item.reportType == 'Lost') {
      return const Color(0xFFD94084);
    } else {
      return const Color(0xFF5BA681);
    }
  }

  // background colour for the lost/found badge.
  // lost uses pink and found uses green.
  Color get statusBackgroundColor {
    if (item.reportType == 'Lost') {
      return const Color(0xFFFFD0E8).withOpacity(0.65);
    } else {
      return const Color(0xFFD5FBDD).withOpacity(0.8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildImageSection(),
            Expanded(child: buildInfo(context)),
          ],
        ),
      ),
    );
  }

  // builds the text section under the image.
  // shows item name, description, location and bottom info.
  Widget buildInfo(BuildContext context) {
    bool isLost = item.reportType == 'Lost';
    final FindrColors colors = FindrColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 2),

          Text(
            item.description,
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 5),

          // location row with the pin icon.
          Row(
            children: [
              Icon(Icons.location_on, size: 13, color: colors.muted),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  item.location,
                  style: TextStyle(fontSize: 11, color: colors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const Spacer(),

          // bottom row changes depending on lost or found.
          Row(
            children: [
              Expanded(child: isLost ? buildReward() : buildReadyToClaim()),
              Text(
                item.timeAgo,
                style: TextStyle(fontSize: 10, color: colors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // builds the image section at the top of the card.
  // the lost/found badge is placed on top of the image.
  Widget buildImageSection() {
    return Stack(
      children: [
        AspectRatio(aspectRatio: 1.7, child: buildPhoto()),

        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusBackgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              item.reportType,
              style: TextStyle(
                color: statusTextColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // decides how to draw the item photo.
  // reports made in the app store the photo as a base64 string in firestore,
  // while the older sample reports only have a bundled asset path.
  Widget buildPhoto() {
    Uint8List? bytes;

    if (item.hasPhoto) {
      try {
        bytes = base64Decode(item.base64Image);
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

    if (item.imagePath.isEmpty) {
      return buildPhotoPlaceholder();
    }

    return Image.asset(
      item.imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => buildPhotoPlaceholder(),
    );
  }

  // grey box with an icon, shown when there is no usable photo.
  Widget buildPhotoPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.image, size: 36, color: Colors.grey),
    );
  }

  // builds the reward row for lost items.
  // lost items use the present image beside the reward amount.
  Widget buildReward() {
    // a lost report does not have to offer a reward, so fall back to the
    // claim row instead of crashing on a null reward.
    if (item.reward == null || item.reward == 0) {
      return buildReadyToClaim();
    }

    return Row(
      children: [
        Image.asset(
          'assets/images/present.png',
          height: 28,
          width: 28,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.card_giftcard,
              size: 24,
              color: Colors.pink,
            );
          },
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            '\$${item.reward!.toStringAsFixed(0)} Reward',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.pink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // builds the ready to claim row for found items.
  // this replaces the reward row because found items do not have rewards.
  Widget buildReadyToClaim() {
    return SizedBox(
      height: 28,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: const [
            Icon(
              Icons.check_circle_outline,
              size: 17,
              color: Color(0xFF5BA681),
            ),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'Ready to claim',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5BA681),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
