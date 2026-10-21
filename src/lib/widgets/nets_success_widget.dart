import 'package:flutter/material.dart';
import 'package:findr_application/theme/app_theme.dart';

// shown when the reward payment goes through.
// the report is saved straight after this, so it only confirms and moves on.
class NETSSuccessWidget extends StatelessWidget {
  final double amount;

  const NETSSuccessWidget({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    final colors = FindrColors.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // uses the lab image if it has been added to assets/images,
        // otherwise falls back to a drawn tick so nothing is missing.
        Image.asset(
          'assets/images/green_tick.png',
          width: MediaQuery.of(context).size.width * 0.4,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.check_circle,
              size: 96,
              color: Color(0xFF5BA681),
            );
          },
        ),

        const SizedBox(height: 16),

        const Text(
          'Payment Successful',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5BA681),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          '\$${amount.toStringAsFixed(2)} is now held by Findr and will be\n'
          'released to whoever returns your item.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: colors.textSecondary,
          ),
        ),

        const SizedBox(height: 18),

        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),

        const SizedBox(height: 10),

        Text(
          'Saving your report...',
          style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
        ),
      ],
    );
  }
}
