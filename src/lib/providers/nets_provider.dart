import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:findr_application/models/nets_state.dart';
import 'package:findr_application/services/nets_service.dart';

final netsServiceProvider = Provider<NETSService>((ref) {
  return NETSService();
});

// manages the whole NETS payment flow: requesting the QR, counting down,
// listening for the live webhook update and checking the final result.
final netsProvider = StateNotifierProvider<NetsController, NetsState>((ref) {
  final service = ref.read(netsServiceProvider);
  return NetsController(service);
});

class NetsController extends StateNotifier<NetsState> {
  final NETSService service;

  Timer? _timer;
  StreamSubscription<String>? _webhookSubscription;

  NetsController(this.service) : super(NetsState());

  // 1. asks NETS for a QR code covering the reward amount.
  Future<void> generateQR(double amount) async {
    _timer?.cancel();
    _webhookSubscription?.cancel();

    state = NetsState(status: 'loading', amount: amount);

    final decoded = await service.requestQR(amount);

    if (!mounted) return;

    final String? qrString = decoded['qrCode'] as String?;
    final String? txnRef = decoded['txnRef'] as String?;

    // the sandbox limits how many QR codes can be created per second, so an
    // empty response here is expected sometimes rather than a real fault.
    if (qrString == null || txnRef == null) {
      state = state.copyWith(
        status: 'fail',
        message: 'NETS did not return a QR code.\n\n'
            'The sandbox limits how many codes can be created per second, '
            'so this often clears on its own. Check the amount is a small '
            'whole number and try again.',
      );
      return;
    }

    Uint8List qr;
    try {
      qr = base64Decode(qrString);
    } catch (e) {
      state = state.copyWith(
        status: 'fail',
        message: 'The QR code from NETS could not be read.',
      );
      return;
    }

    state = state.copyWith(
      qrCode: qr,
      status: 'idle',
      timeLeft: 300,
      txnRef: txnRef,
      message: null,
    );

    startTimer(txnRef);
    startWebhookListener(txnRef);
  }

  // 2. counts the 5 minutes down, then falls back to the query api.
  void startTimer(String txnRef) {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (state.timeLeft > 0) {
        state = state.copyWith(timeLeft: state.timeLeft - 1);
      } else {
        timer.cancel();
        checkPayment(txnRef);
      }
    });
  }

  // 3. listens for the live update telling us the QR has been scanned.
  //
  // important: "QR code scanned" only means TWallet has read the code. the
  // user still has to confirm the payment inside the wallet afterwards, so
  // querying immediately would report a failure for a payment that is simply
  // not finished yet. the check is polled instead of asked once.
  void startWebhookListener(String txnRef) {
    _webhookSubscription?.cancel();

    _webhookSubscription = service.webhookStream(txnRef).listen(
      (data) {
        if (!mounted) return;

        debugPrint('NETS webhook chunk: $data');

        if (data.contains('QR code scanned')) {
          state = state.copyWith(message: 'QR scanned. Confirm in TWallet...');
          _webhookSubscription?.cancel();
          checkPayment(txnRef);
        }
      },
      onError: (e) {
        debugPrint('webhook listener error: $e');
      },
    );
  }

  // NETS reports success as '00'. the sandbox is not consistent about
  // whether that comes back as a string or a number, so a few shapes of the
  // same answer are all treated as success.
  bool _isSuccessCode(String code) {
    return code == '00' || code == '0';
  }

  // a code that means the transaction is still in progress rather than
  // actually failed, so it is worth asking again.
  bool _isPendingCode(String code) {
    return code == '99' || code.isEmpty || code == 'null';
  }

  // 4. confirms the outcome with NETS, retrying while it is still pending.
  Future<void> checkPayment(String txnRef, {int attempt = 0}) async {
    _timer?.cancel();

    final decoded = await service.checkPayment(txnRef);

    if (!mounted) return;

    final String code = decoded['response_code']?.toString() ?? '';
    final String? message = decoded['message'] as String?;

    debugPrint('NETS query attempt $attempt -> code="$code" message="$message"');

    if (_isSuccessCode(code)) {
      state = state.copyWith(status: 'success', message: message);

      // brief pause so the user sees the confirmation before moving on.
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;
      state = state.copyWith(status: 'complete');
      return;
    }

    // give the user time to approve the payment in TWallet before deciding
    // it failed. roughly 45 seconds of polling in total.
    if (_isPendingCode(code) && attempt < 15) {
      state = state.copyWith(
        message: 'Waiting for payment confirmation...',
      );

      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;
      return checkPayment(txnRef, attempt: attempt + 1);
    }

    // the raw code is shown as well, because it is what the response code
    // table at the end of the mini-project brief is looked up against.
    final String detail = message == null || message.isEmpty
        ? 'The payment was not completed.'
        : message;

    state = state.copyWith(
      status: 'fail',
      message: '$detail\n\n(NETS response code: '
          '${code.isEmpty ? 'none returned' : code})',
    );
  }

  // resets everything so the next payment starts from a clean state.
  void cleanup() {
    _timer?.cancel();
    _webhookSubscription?.cancel();

    if (mounted) {
      state = NetsState();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _webhookSubscription?.cancel();
    super.dispose();
  }
}
