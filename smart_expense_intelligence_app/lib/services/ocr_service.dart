import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/pending_expense.dart';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart'; // NEW: Import DB Helper

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<PendingExpense?> processReceipt(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      String? detectedMerchant;
      double? detectedAmount;

      // 1. Extract Merchant Name
      if (recognizedText.blocks.isNotEmpty) {
        detectedMerchant = recognizedText.blocks.first.lines.first.text;
      }

      // 2. Extract Amount - ATTEMPT 1: Keyword Hunting (Looks for "Total")
      final looseAmountRegex = RegExp(r'\b\d{1,3}(?:,\d{3})*(?:\.\d{2})?\b');
      
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final lowerText = line.text.toLowerCase();
          
          if (lowerText.contains('total') || lowerText.contains('amount') || lowerText.contains('net')) {
            Iterable<RegExpMatch> matches = looseAmountRegex.allMatches(line.text);
            if (matches.isNotEmpty) {
              String cleanNumber = matches.last.group(0)!.replaceAll(',', '');
              double? parsedValue = double.tryParse(cleanNumber);
              if (parsedValue != null && parsedValue > 0) {
                detectedAmount = parsedValue;
                break; 
              }
            }
          }
        }
        if (detectedAmount != null) break;
      }

      // 3. Extract Amount - ATTEMPT 2: Fallback to largest STRICT decimal number
      if (detectedAmount == null) {
        final RegExp strictAmountRegex = RegExp(r'\b\d{1,3}(?:,\d{3})*\.\d{2}\b'); 
        List<double> allFoundNumbers = [];

        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            Iterable<RegExpMatch> matches = strictAmountRegex.allMatches(line.text);
            
            for (final match in matches) {
              String cleanNumber = match.group(0)!.replaceAll(',', '');
              double? parsedValue = double.tryParse(cleanNumber);
              
              if (parsedValue != null && parsedValue > 10.0) {
                allFoundNumbers.add(parsedValue);
              }
            }
          }
        }

        if (allFoundNumbers.isNotEmpty) {
          allFoundNumbers.sort();
          detectedAmount = allFoundNumbers.last; 
        }
      }

      return PendingExpense(
        amount: detectedAmount,
        merchantName: detectedMerchant,
        dateTime: DateTime.now(),
        source: 'ocr',
        createdAt: DateTime.now(),
      );

    } catch (e) {
      debugPrint('Error processing receipt OCR: $e');
      return null;
    } finally {
      _textRecognizer.close();
    }
  }

  // 🧠 THE INTELLIGENCE ENGINE v3: Self-Learning + Keyword Fallback
  // Notice this is now a Future<int> because it checks the database
  Future<int> guessCategoryId(String? merchantName) async {
    if (merchantName == null || merchantName.isEmpty) return 6; // Default to 'Other'

    // STEP 1: SELF-LEARNING CHECK
    // Did the user ever save an expense with this exact or similar merchant name?
    final pastCategoryId = await DatabaseHelper.instance.getCategoryForMerchant(merchantName);
    if (pastCategoryId != null) {
      debugPrint("🧠 AI learned from past behavior: Selected Category $pastCategoryId for $merchantName");
      return pastCategoryId; // Return the user's historical preference!
    }

    // STEP 2: FALLBACK TO RULE-BASED CHECK
    final name = merchantName.toLowerCase();

    final supermarketBrands = ['cargills', 'food city', 'keells', 'arpico', 'spar', 'glitz', 'laugfs'];
    if (supermarketBrands.any((word) => name.contains(word))) return 4; 

    final foodKeywords = ['pizza', 'cafe', 'restaurant', 'burger', 'kfc', 'mcdonalds', 'kottu', 'bake', 'food', 'dinemore', 'hotel'];
    final transportKeywords = ['uber', 'pickme', 'bus', 'train', 'fuel', 'petrol', 'taxi', 'ceypetco', 'ioc'];
    final shoppingKeywords = ['fashion', 'clothing', 'supermarket', 'mart', 'store'];
    final billsKeywords = ['ceb', 'water', 'dialog', 'mobitel', 'electricity', 'bill', 'slt'];

    if (foodKeywords.any((word) => name.contains(word))) return 1; 
    if (transportKeywords.any((word) => name.contains(word))) return 2; 
    if (shoppingKeywords.any((word) => name.contains(word))) return 4; 
    if (billsKeywords.any((word) => name.contains(word))) return 5; 

    return 6; // Default fallback: Other
  }
}