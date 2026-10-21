import 'package:flutter/material.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/theme/app_theme.dart';

// shown when the reward payment fails, expires or is cancelled.
// the user can try the payment again or go back and edit the report.
class NETSFailWidget extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const NETSFailWidget({
    super.key,
    required this.onRetry,
    required this.onCancel,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = FindrColors.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // uses the lab image if it has been added to assets/images,
        // otherwise falls back to a drawn cross.
        Image.asset(
          'assets/images/red_cross.png',
          width: MediaQuery.of(context).size.width * 0.4,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.cancel, size: 96, color: Color(0xFFE0415F));
          },
        ),

        const SizedBox(height: 16),

        const Text(
          'Payment Failed',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE0415F),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          message ??
              'The payment was not completed, so your report has '
                  'not been posted yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: colors.textSecondary,
          ),
        ),

        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: AppBackAction(label: 'Back to report', onTap: onCancel),
        ),
      ],
    );
  }
}
