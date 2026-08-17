import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/apps/receipts/data/ocr/ocr_source.dart';
import 'package:shopping_list/apps/receipts/data/ocr/receipt_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptParser', () {
    test('reads a numeric total without going through a double', () async {
      final parser = ReceiptParser(
        'test-key',
        client: _openRouterClient({
          'merchant': 'Rami Levy',
          'totalAmount': 142.50,
          'currency': 'ILS',
          'date': '2026-08-12',
          'categoryGuess': 'Groceries',
          'description': null,
        }),
      );

      final parsed = await parser.parse('RAMI LEVY\nTOTAL 142.50');
      expect(parsed.merchant, 'Rami Levy');
      expect(parsed.totalAmountMinor, 14250);
      expect(parsed.occurredAt, DateTime(2026, 8, 12));
      expect(parsed.categoryGuess, 'Groceries');
    });

    test('reads a total sent as a string', () async {
      final parser = ReceiptParser(
        'test-key',
        client: _openRouterClient({
          'merchant': 'Super-Pharm',
          'totalAmount': '19.90',
          'currency': 'ILS',
          'date': '2026-08-01',
          'categoryGuess': 'Pharmacy',
          'description': 'vitamins',
        }),
      );

      final parsed = await parser.parse('SUPER-PHARM\n19.90');
      expect(parsed.totalAmountMinor, 1990);
      expect(parsed.description, 'vitamins');
    });

    test('strips a markdown fence around the JSON', () async {
      final parser = ReceiptParser(
        'test-key',
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content':
                        '```json\n{"merchant":"Osher Ad","totalAmount":10,'
                            '"currency":"ILS","date":null,"categoryGuess":null,'
                            '"description":null}\n```',
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final parsed = await parser.parse('OSHER AD 10.00');
      expect(parsed.merchant, 'Osher Ad');
      expect(parsed.totalAmountMinor, 1000);
    });

    test('asks OpenRouter for a JSON schema with reasoning off', () async {
      late Map<String, Object?> body;
      final parser = ReceiptParser(
        'test-key',
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'merchant': 'Rami Levy',
                      'totalAmount': 10,
                      'currency': 'ILS',
                      'date': null,
                      'categoryGuess': null,
                      'description': null,
                    }),
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await parser.parse('RAMI LEVY 10.00');
      expect(body['reasoning'], {
        'enabled': false,
        'effort': 'none',
      });
      final format = body['response_format'] as Map<String, Object?>;
      expect(format['type'], 'json_schema');
      final schema = format['json_schema'] as Map<String, Object?>;
      expect(schema['name'], 'parsed_receipt');
      expect(schema['strict'], true);
    });

    test('retries with json_object when json_schema is rejected', () async {
      var calls = 0;
      late Map<String, Object?> secondBody;
      final parser = ReceiptParser(
        'test-key',
        client: MockClient((request) async {
          calls++;
          if (calls == 1) {
            return http.Response(
              jsonEncode({
                'error': {'message': 'response_format not supported'},
              }),
              400,
              headers: {'content-type': 'application/json'},
            );
          }
          secondBody = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'merchant': 'Yellow',
                      'totalAmount': 50,
                      'currency': 'ILS',
                      'date': null,
                      'categoryGuess': 'Fuel',
                      'description': null,
                    }),
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final parsed = await parser.parse('YELLOW 50.00');
      expect(calls, 2);
      expect(parsed.merchant, 'Yellow');
      expect(parsed.totalAmountMinor, 5000);
      expect(secondBody['reasoning'], {
        'enabled': false,
        'effort': 'none',
      });
      expect(
        (secondBody['response_format'] as Map<String, Object?>)['type'],
        'json_object',
      );
    });
  });

  group('GoogleVisionOcr', () {
    test('uses TEXT_DETECTION, not the dense document model', () async {
      late Map<String, Object?> body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, Object?>;
        return http.Response(
          jsonEncode({
            'responses': [
              {
                'fullTextAnnotation': {'text': 'TOTAL 10'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final dir = Directory.systemTemp.createTempSync('ocr');
      final file = File('${dir.path}/r.jpg')
        ..writeAsBytesSync(const [0xFF, 0xD8]);
      addTearDown(() => dir.deleteSync(recursive: true));

      final text =
          await GoogleVisionOcr('key', client: client).extractText(file);
      expect(text, 'TOTAL 10');
      final request = (body['requests'] as List<Object?>).first as Map;
      expect((request['features'] as List<Object?>).single, {
        'type': 'TEXT_DETECTION',
      });
    });
  });
}

http.Client _openRouterClient(Map<String, Object?> fields) {
  return MockClient((_) async {
    return http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': jsonEncode(fields)}
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}
