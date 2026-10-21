import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/providers/nets_provider.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/widgets/nets_widget.dart';
import 'package:findr_application/theme/app_theme.dart';

// hosts the NETS QR payment for a lost item reward.
//
// this screen pops with the NETS transaction reference when the payment
// succeeds, or with null if the user backs out. the caller only saves the
// report when it gets a reference back.
class NetsPaymentScreen extends ConsumerStatefulWidget {
  final double amount;
  final String itemName;

  const NetsPaymentScreen({
    super.key,
    required this.amount,
    required this.itemName,
  });

  @override
  ConsumerState<NetsPaymentScreen> createState() => _NetsPaymentScreenState();
}

class _NetsPaymentScreenState extends ConsumerState<NetsPaymentScreen> {
  @override
  void dispose() {
    // clears the payment state so the next report starts fresh.
    ref.read(netsProvider.notifier).cleanup();
    super.dispose();
  }

  void finish(String? txnRef) {
    if (!mounted) return;
    Navigator.of(context).pop(txnRef);
  }

  // leaving mid payment would abandon the report, so it is confirmed first.
  Future<bool> confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel payment?'),
          content: const Text(
            'Your report will not be posted if you leave now. '
            'You can still post it without a reward instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = FindrColors.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (await confirmExit()) {
          finish(null);
        }
      },
      child: AppPage(
        title: 'Reward Payment',
        subtitle: 'Secure Your Reward with NETS QR',
        showBack: true,
        action: AppCircleButton(
          icon: Icons.close,
          onTap: () async {
            if (await confirmExit()) {
              finish(null);
            }
          },
        ),
        child: Column(
          children: [
            // reminds the user what they are paying for.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD0E8).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      size: 20,
                      color: Color(0xFFD94084),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.itemName.isEmpty
                              ? 'Your lost item'
                              : widget.itemName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Reward held until the item is returned',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD94084),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            NETSWidget(
              amount: widget.amount,
              onPaid: (txnRef) => finish(txnRef),
              onCancel: () => finish(null),
            ),
          ],
        ),
      ),
    );
  }
}
