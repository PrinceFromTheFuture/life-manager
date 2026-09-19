import 'dart:io';

import 'package:shopping_list/apps/receipts/data/ocr/ocr_source.dart';
import 'package:shopping_list/apps/receipts/data/ocr/receipt_parser.dart';

/// What a scan produced, plus the raw OCR text — kept so a bad parse can be
/// retried later without photographing the receipt again.
class ScanResult {
  const ScanResult({
    required this.parsed,
    required this.rawText,
    required this.model,
  });

  final ParsedReceipt parsed;
  final String rawText;
  final String model;
}

/// The two-call pipeline: Vision reads the receipt, OpenRouter structures
/// what it read. Both sit behind interfaces so either could be swapped —
/// or the whole pipeline replaced by a single vision-capable model later —
/// without the form knowing.
class ReceiptScanner {
  ReceiptScanner({
    required this.ocr,
    required this.parser,
    required this.model,
  });

  final OcrSource ocr;
  final ReceiptParser parser;
  final String model;

  Future<ScanResult> scan(File image,
      {List<String> categories = const []}) async {
    final text = await ocr.extractText(image);
    if (text.trim().isEmpty) {
      throw OcrException(
        "Couldn't read that receipt. Fill it in yourself — the photo is "
        'saved either way.',
      );
    }
    final parsed = await parser.parse(text, categories: categories);
    return ScanResult(parsed: parsed, rawText: text, model: model);
  }
}
