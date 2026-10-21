import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';

// handles all communication with the NETS QR sandbox api.
//
// findr uses this for the reward escrow. when a student posts a lost item and
// offers a reward, the reward is paid up front through NETS QR and only
// released to the finder once the item has actually been returned.
class NETSService {
  
  final String apiKey = 'REPLACE_WITH_API_KEY';
  final String projectId = '6fff485f-0046-4736-8f43-0b4530fd556e';

  static const String _base =
      'https://sandbox.nets.openapipaas.com/api/v1/common/payments';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'api-key': apiKey,
    'project-id': projectId,
  };

  // asks NETS to generate a QR code for the given reward amount.
  // returns the base64 QR image plus the reference used to track the payment.
  Future<Map<String, dynamic>> requestQR(double amount) async {
    try {
      final response = await post(
        Uri.parse('$_base/nets-qr/request'),
        headers: _headers,
        body: jsonEncode({
          'txn_id': 'sandbox_nets|m|8ff8e5b6-d43e-4786-8ac5-7accf8c5bd9b',
          'amt_in_dollars': amount,
          'notify_mobile': 0,
        }),
      );

      debugPrint('NETS request raw response: ${response.body}');

      final data = jsonDecode(response.body);

      // the sandbox nests everything under result -> data.
      final result = data['result']?['data'];

      if (result == null) {
        debugPrint('requestQR unexpected response: ${response.body}');
        return {};
      }

      return {
        'qrCode': result['qr_code'],
        'txnRef': result['txn_retrieval_ref'],
      };
    } catch (e) {
      debugPrint('requestQR error: $e');
      return {};
    }
  }

  // server sent events stream that reports live updates such as the moment
  // the QR code is scanned, so the app does not have to poll.
  Stream<String> webhookStream(String txnRef) async* {
    final client = Client();

    try {
      final request =
          Request('GET', Uri.parse('$_base/nets/webhook?txn_retrieval_ref=$txnRef'))
            ..headers.addAll({
              'Accept': 'text/event-stream',
              'Connection': 'keep-alive',
              'api-key': apiKey,
              'project-id': projectId,
            });

      final response = await client.send(request);

      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          yield chunk;
        }
      }
    } catch (e) {
      debugPrint('webhookStream error: $e');
    } finally {
      client.close();
    }
  }

  // asks NETS for the final outcome of the transaction.
  // used as the fallback when the QR expires or no live update arrives.
  Future<Map<String, dynamic>> checkPayment(String txnRef) async {
    try {
      final response = await post(
        Uri.parse('$_base/nets-qr/query'),
        headers: _headers,
        body: jsonEncode({
          'txn_retrieval_ref': txnRef,
          'frontend_timeout_status': 1,
        }),
      );

      // the full body is logged because the sandbox wraps the useful part
      // several levels deep and the exact shape is worth being able to see.
      debugPrint('NETS query raw response: ${response.body}');

      final data = jsonDecode(response.body);
      final result = data['result']?['data'];

      if (result == null) {
        debugPrint('checkPayment unexpected response: ${response.body}');
        return {};
      }

      return {
        // the sandbox sometimes returns this as a number, so it is forced
        // to a string before it gets compared against '00'.
        'response_code': result['response_code']?.toString(),
        'message': result['message'],
      };
    } catch (e) {
      debugPrint('checkPayment error: $e');
      return {};
    }
  }
}
