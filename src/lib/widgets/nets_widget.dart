import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/providers/nets_provider.dart';
import 'package:findr_application/widgets/nets_fail_widget.dart';
import 'package:findr_application/widgets/nets_success_widget.dart';
import 'package:findr_application/theme/app_theme.dart';

// handles the nets qr payment for a lost item reward.
class NETSWidget extends ConsumerStatefulWidget {
  // amount the user needs to pay.
  final double amount;

  // runs after payment succeeds and returns the transaction reference.
  final void Function(String txnRef) onPaid;

  // runs when the user cancels the payment.
  final VoidCallback onCancel;

  const NETSWidget({
    super.key,
    required this.amount,
    required this.onPaid,
    required this.onCancel,
  });

  @override
  ConsumerState<NETSWidget> createState() => _NETSWidgetState();
}

class _NETSWidgetState extends ConsumerState<NETSWidget> {
  // stops the success callback from running more than once.
  bool handled = false;

  @override
  void initState() {
    super.initState();

    // requests the qr code after the widget appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(netsProvider.notifier).generateQR(widget.amount);
    });
  }

  // changes seconds into a mm:ss timer.
  String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');

    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(netsProvider);
    final colors = FindrColors.of(context);

    // sends the successful payment back to the previous screen.
    if (state.isComplete && !handled) {
      handled = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPaid(state.txnRef ?? '');
      });
    }

    // shows loading while nets is creating the qr code.
    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 70),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(
              'Contacting NETS...',
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // shows the success screen after payment is confirmed.
    if (state.isSuccess || state.isComplete) {
      return NETSSuccessWidget(
        amount: state.amount,
      );
    }

    // shows the failure screen and lets the user retry or cancel.
    if (state.isFail) {
      return NETSFailWidget(
        message: state.message,
        onRetry: () {
          handled = false;

          ref
              .read(netsProvider.notifier)
              .generateQR(widget.amount);
        },
        onCancel: () {
          ref.read(netsProvider.notifier).cleanup();
          widget.onCancel();
        },
      );
    }

    return buildQrView(
      state.qrCode,
      state.timeLeft,
      state.message,
    );
  }

  // builds the qr code payment screen.
  Widget buildQrView(
    Uint8List? qrCode,
    int timeLeft,
    String? message,
  ) {
    final colors = FindrColors.of(context);

    if (qrCode == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // shows the timer in red when less than one minute is left.
    final bool runningOut = timeLeft < 60;

    return Column(
      children: [
        Text(
          'Reward Payment: \$${widget.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 6),

        Text(
          'Scan this QR code with the TWallet app to place your\n'
          'reward in escrow. Your report is posted once it clears.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: colors.textSecondary,
          ),
        ),

        const SizedBox(height: 18),

        // keeps a white background behind the qr code for easier scanning.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Image.memory(
            qrCode,
            width: 210,
            height: 210,
            fit: BoxFit.contain,
          ),
        ),

        const SizedBox(height: 14),

        // shows the nets instruction image if it exists.
        Image.asset(
          'assets/images/nets_qr_info.png',
          width: MediaQuery.of(context).size.width * 0.62,
          errorBuilder: (_, _, _) =>
              const SizedBox.shrink(),
        ),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: runningOut
                ? const Color(0xFFFFD9E1)
                : colors.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: runningOut
                    ? const Color(0xFFE0415F)
                    : colors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Expires in ${formatTime(timeLeft)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: runningOut
                      ? const Color(0xFFE0415F)
                      : colors.primary,
                ),
              ),
            ],
          ),
        ),

        // shows live payment updates such as when the qr was scanned.
        if (message != null) ...[
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF5BA681),
            ),
          ),
        ],

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              ref.read(netsProvider.notifier).cleanup();
              widget.onCancel();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textSecondary,
              side: BorderSide(
                color: colors.border,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text('Cancel payment'),
          ),
        ),
      ],
    );
  }
}