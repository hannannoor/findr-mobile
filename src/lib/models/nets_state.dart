import 'dart:typed_data';

// immutable state for the NETS QR payment flow.
//
// status moves through: idle -> loading -> success/fail -> complete
class NetsState {
  // the decoded QR image ready to hand to Image.memory.
  final Uint8List? qrCode;

  final String status;

  // seconds remaining before the QR code expires. NETS allows 5 minutes.
  final int timeLeft;

  // latest message from the webhook or the query api.
  final String? message;

  // reference used to track this transaction with NETS.
  final String? txnRef;

  // the reward amount being paid, kept so the ui can show it.
  final double amount;

  NetsState({
    this.qrCode,
    this.status = 'idle',
    this.timeLeft = 300,
    this.message,
    this.txnRef,
    this.amount = 0,
  });

  NetsState copyWith({
    Uint8List? qrCode,
    String? status,
    int? timeLeft,
    String? message,
    String? txnRef,
    double? amount,
  }) {
    return NetsState(
      qrCode: qrCode ?? this.qrCode,
      status: status ?? this.status,
      timeLeft: timeLeft ?? this.timeLeft,
      message: message ?? this.message,
      txnRef: txnRef ?? this.txnRef,
      amount: amount ?? this.amount,
    );
  }

  bool get isLoading => status == 'loading';
  bool get isShowingQr => status == 'idle' && qrCode != null;
  bool get isSuccess => status == 'success';
  bool get isFail => status == 'fail';
  bool get isComplete => status == 'complete';
}
