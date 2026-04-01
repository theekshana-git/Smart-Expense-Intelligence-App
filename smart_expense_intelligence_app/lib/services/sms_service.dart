import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

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

    await dbHelper.insertPendingExpense({
      'amount': amount,
      'merchant_name': merchant,
      'date_time': DateTime.now().toIso8601String(),
      'source': 'sms',
    });

    debugPrint("✅ SMS successfully staged in database!");
  }
}

double? _extractAmount(String text) {
  RegExp regExp = RegExp(r"(?:Rs\.?|LKR|\$|USD)\s*([\d,]+(?:\.\d{1,2})?)", caseSensitive: false);
  var match = regExp.firstMatch(text);
  if (match != null) {
    String amountStr = match.group(1)!.replaceAll(',', '');
    return double.tryParse(amountStr);
  }
  return null;
}

String _extractMerchant(String text) {
  String lowerText = text.toLowerCase();
  try {
    if (lowerText.contains('at ')) {
      var parts = text.split(RegExp(r'\bat\b', caseSensitive: false));
      if (parts.length > 1) {
        String afterAt = parts[1];
        String merchant = afterAt.split(RegExp(r'\bon\b|\bvia\b', caseSensitive: false))[0];
        return merchant.trim().toUpperCase();
      }
    } else if (lowerText.contains('to ')) {
      var parts = text.split(RegExp(r'\bto\b', caseSensitive: false));
      if (parts.length > 1) {
        String afterTo = parts[1];
        String merchant = afterTo.split(RegExp(r'\bon\b|\bvia\b', caseSensitive: false))[0];
        return merchant.trim().toUpperCase();
      }
    }
  } catch (e) {
    debugPrint("Error parsing merchant: $e");
  }
  return "UNKNOWN MERCHANT";
}

// --- The Actual Service Class ---
class SmsService {
  // 🛡️ THE SINGLETON PATTERN: Guarantees it only runs once!
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Telephony telephony = Telephony.instance;
  static const String _lastSyncKey = 'last_sms_sync_timestamp';
  bool _isInitialized = false;

  Future<void> initialize() async {
    // If it already ran this session, abort immediately!
    if (_isInitialized) return; 
    
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted != null && permissionsGranted) {
      _isInitialized = true; // Mark as running

      // 1. Sync any messages that arrived while the app was closed
      await syncMissedMessages();

      // 2. Listen for new messages while the app is actively open
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          debugPrint("Foreground SMS received!");
          await processSms(message.body ?? "");
          
          // 🛡️ THE TIMESTAMP FIX: Update the time so it doesn't resync on reboot!
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        },
        listenInBackground: false, 
      );
    }
  }

  // 🧠 THE BOOT-UP SYNC ENGINE
  Future<void> syncMissedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    
    int lastSyncTimestamp = prefs.getInt(_lastSyncKey) ?? 
        DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;

    List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)] 
    );

    final bankSenders = ['BOC', 'COMMERCIAL', 'HNB', 'SAMPATH', 'NDB'];

    for (var message in messages) {
      // 🛡️ Check if it arrived AFTER our last sync
      if (message.date != null && message.date! > lastSyncTimestamp) {
        if (bankSenders.contains(message.address?.toUpperCase())) {
          await processSms(message.body ?? "");
        }
      }
    }

    // Save the new exact time
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }
}