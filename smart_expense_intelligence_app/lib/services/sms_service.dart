import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import '../database/database_helper.dart';

// 1. THIS MUST BE A TOP-LEVEL FUNCTION
@pragma('vm:entry-point')
void onBackgroundMessage(SmsMessage message) async {
  debugPrint("Background SMS received: ${message.body}");
  await processSms(message.body ?? "");
}

// Top-level processing function
Future<void> processSms(String text) async {
  if (!text.toLowerCase().contains('debited') &&
      !text.toLowerCase().contains('paid')) {
    return;
  }

  double? amount = _extractAmount(text);
  String merchant = _extractMerchant(text);

  if (amount != null) {
    final dbHelper = DatabaseHelper.instance;

    // --- THIS IS THE UPDATED MAP ---
    await dbHelper.insertPendingExpense({
      'amount': amount,
      'merchant_name': merchant, // Fixed column name
      'date_time': DateTime.now().toIso8601String(), // Fixed column name
      'source': 'sms', // Required by your tables.dart CHECK constraint

      // I removed 'category' and 'is_confirmed' because those
      // columns do not exist in your pending_expenses table!
    });

    debugPrint("Expense successfully saved to database!");
  }
}

double? _extractAmount(String text) {
  // Regex to find amounts like Rs. 1500.00, LKR 500, $50.00
  RegExp regExp = RegExp(r"(?:Rs|LKR|\$|USD)\.?\s*([\d,]+(?:\.\d{1,2})?)",
      caseSensitive: false);
  var match = regExp.firstMatch(text);
  if (match != null) {
    String amountStr = match.group(1)!.replaceAll(',', '');
    return double.tryParse(amountStr);
  }
  return null;
}

String _extractMerchant(String text) {
  // This is highly dependent on bank formats.
  // Example: "paid to Uber via..." or "at Keells Super"
  if (text.toLowerCase().contains('at ')) {
    var parts = text.split(RegExp(r'at ', caseSensitive: false));
    if (parts.length > 1) {
      return parts[1].split(' ')[0]; // Grabs the first word after "at "
    }
  }
  return "Unknown Merchant";
}

String _guessCategory(String merchant) {
  String m = merchant.toLowerCase();
  if (m.contains('uber') || m.contains('pickme')) return 'Transport';
  if (m.contains('keells') || m.contains('cargills')) return 'Groceries';
  if (m.contains('dialog') || m.contains('mobitel')) return 'Bills';
  return 'Uncategorized';
}

// --- The Actual Service Class ---
class SmsService {
  final Telephony telephony = Telephony.instance;

  void initialize() async {
    // Request permissions first
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted != null && permissionsGranted) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          // Handle SMS while app is in foreground
          processSms(message.body ?? "");
        },
        onBackgroundMessage: onBackgroundMessage,
      );
    }
  }
}
