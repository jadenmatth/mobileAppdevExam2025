import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentService {
  static const String apiId = "HDEV-2f7b3554-eb27-477b-8ebb-2ca799f03412-ID";
  static const String apiKey = "HDEV-28407ece-5d24-438d-a9e8-73105c905a7d-KEY";
  static const String apiUrl =
      "https://payment.hdevtech.cloud/api_pay/api/$apiId/$apiKey";

  static Future<Map<String, dynamic>> initiatePayment({
    required String tel,
    required String amount,
  }) async {
    String txRef = "TX-${DateTime.now().millisecondsSinceEpoch}";
    final response = await http.post(
      Uri.parse(apiUrl),
      body: {
        'ref': 'pay',
        'tel': tel,
        'tx_ref': txRef,
        'amount': amount,
        'link': 'bookmytalent.app',
      },
    );
    final data = json.decode(response.body);
    if (data['status'] == 'success') {
      await FirebaseFirestore.instance.collection('payments').doc(txRef).set({
        'amount': amount,
        'payment_gateway': 'MoMo MTN',
        'tx_ref': txRef,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'tel': tel,
      });
      return {
        'success': true,
        'tx_ref': txRef,
        'message': 'Please confirm payment on your phone.',
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Payment initiation failed.',
      };
    }
  }

  static Future<String> pollPaymentStatus(
    String txRef, {
    Function(String status)? onStatus,
  }) async {
    const pollInterval = Duration(seconds: 5);
    bool done = false;
    String statusMessage = '';
    while (!done) {
      await Future.delayed(pollInterval);
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {'ref': 'read', 'tx_ref': txRef},
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(txRef)
            .update({'status': 'paid'});
        statusMessage = '✅ Payment successful!';
        onStatus?.call('paid');
        done = true;
      } else if (data['status'] == 'pending') {
        statusMessage = 'Please confirm payment on your phone...';
        onStatus?.call('pending');
      } else {
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(txRef)
            .update({'status': 'failed'});
        statusMessage = '❌ Payment failed or cancelled.';
        onStatus?.call('failed');
        done = true;
      }
    }
    return statusMessage;
  }
}
