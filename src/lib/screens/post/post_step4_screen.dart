import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/models/post_data.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/services/firebase_service.dart';
import 'package:findr_application/widgets/post_widgets.dart';
import 'package:findr_application/widgets/report_photo_picker.dart';
import 'package:findr_application/screens/home_screen.dart';
import 'package:findr_application/screens/nets_payment_screen.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_page.dart';

// final step of creating a report.
// this screen lets the user add an image and review everything before submitting.
class PostStep4Screen extends ConsumerStatefulWidget {
  final PostData data;

  const PostStep4Screen({super.key, required this.data});

  @override
  ConsumerState<PostStep4Screen> createState() => _PostStep4ScreenState();
}

class _PostStep4ScreenState extends ConsumerState<PostStep4Screen> {
  FindrColors get themeColors => FindrColors.of(context);

  // stops the user from tapping submit twice and creating two reports.
  bool isSaving = false;
  bool isPickingImage = false;

  PostData get data => widget.data;

  // saves the report into the firestore 'reports' collection.
  Future<void> submit() async {
    if (isSaving || isPickingImage) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    // the reward is optional and only applies to lost reports.
    double? reward;
    if (data.reportType == 'Lost' && data.rewardAmount.trim().isNotEmpty) {
      reward = double.tryParse(data.rewardAmount.trim());
    }

    // build the report object out of everything collected across the 4 steps.
    // the owner and created date get stamped on inside addReport().
    final ItemReport report = ItemReport(
      name: data.itemName,
      category: data.category,
      colour: data.colour,
      brand: data.brand,
      condition: data.condition,
      description: data.description,
      location: data.location,
      latitude: data.latitude,
      longitude: data.longitude,
      reportType: data.reportType,
      reportStatus: 'open',
      dateLostFound: data.dateLostFound ?? DateTime.now(),
      base64Image: data.base64Image,
      reward: reward,
    );

    // a lost report that offers a reward has to be paid for first.
    // the money is held by findr and released once the item comes back,
    // so the report is only saved after NETS confirms the payment.
    if (reward != null && reward > 0) {
      final String? txnRef = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) =>
              NetsPaymentScreen(amount: reward!, itemName: report.name),
        ),
      );

      if (!mounted) return;

      // the user backed out or the payment failed, so nothing is posted.
      if (txnRef == null) {
        setState(() {
          isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment cancelled. Your report has not been posted.',
            ),
          ),
        );
        return;
      }

      report.rewardPaid = true;
      report.paymentTxnRef = txnRef;
    }

    try {
      final FirebaseService firebaseService = ref.read(firebaseServiceProvider);

      await firebaseService.addReport(report);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully!')),
      );

      // clear the whole post flow off the stack and go back to home,
      // where the new report will already be in the list.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit the report. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeColors.backgroundAlt,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AppPageBackground(),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildHeading(),
                          const SizedBox(height: 16),
                          const PostStepper(currentStep: 3),
                          const SizedBox(height: 18),
                          ReportPhotoPicker(
                            base64Image: data.base64Image,
                            enabled: !isSaving,
                            onImageChanged: (value) {
                              setState(() {
                                data.base64Image = value;
                              });
                            },
                            onBusyChanged: (value) {
                              if (mounted && isPickingImage != value) {
                                setState(() {
                                  isPickingImage = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          buildReviewCard(context),
                        ],
                      ),
                    ),
                  ),
                  PostBottomButtons(
                    nextLabel: isSaving
                        ? 'Submitting...'
                        : isPickingImage
                        ? 'Processing...'
                        : 'Submit',
                    onBack: () {
                      if (!isSaving && !isPickingImage) {
                        Navigator.of(context).pop();
                      }
                    },
                    onNext: () {
                      submit();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // builds the top logo and subtitle for the post screens.
  // kept same as other post steps so the flow looks consistent.
  Widget buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(-25, 0),
          child: const FindrLogo(height: 115),
        ),
        Text(
          'Create a lost or found report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: themeColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // builds the review section with all the data from the previous steps.
  // this lets the user check their report before pressing submit.
  Widget buildReviewCard(BuildContext context) {
    return PostSectionCard(
      icon: Icons.checklist_outlined,
      title: 'Review Report',
      children: [
        Text(
          'Please review your details before submitting.',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),

        const SizedBox(height: 14),

        buildReviewRow(
          'Type',
          data.reportType,
          color: data.reportType == 'Lost'
              ? const Color(0xFFD94084)
              : const Color(0xFF5BA681),
        ),
        buildReviewRow('Item Name', data.itemName),
        buildReviewRow('Category', data.category),
        buildReviewRow('Colour', data.colour),
        if (data.brand.isNotEmpty) buildReviewRow('Brand', data.brand),
        if (data.condition.isNotEmpty)
          buildReviewRow('Condition', data.condition),
        buildReviewRow('Location', data.location),
        buildReviewRow(
          'Map Pin',
          data.hasLocation
              ? '${data.latitude!.toStringAsFixed(5)}, '
                    '${data.longitude!.toStringAsFixed(5)}'
              : 'Not set',
          color: data.hasLocation ? null : const Color(0xFFE0415F),
        ),
        buildReviewRow('Date & Time', _formatDateTime(context)),

        if (data.reportType == 'Lost' && data.rewardAmount.isNotEmpty)
          buildReviewRow('Reward Amount', '\$${data.rewardAmount}'),
      ],
    );
  }

  // formats the saved date and time into one line for the review card.
  // if both are empty, it shows a dash instead.
  String _formatDateTime(BuildContext context) {
    if (data.date.isEmpty && data.time.isEmpty) {
      return '-';
    }

    return '${data.date} ${data.time}'.trim();
  }

  // reusable row for each review detail.
  // label is on the left and the user's answer is on the right.
  Widget buildReviewRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: Colors.grey[400]),

          const SizedBox(width: 8),

          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),

          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color ?? themeColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
