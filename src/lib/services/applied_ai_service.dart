import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:findr_application/models/item_report.dart';

// handles the ai matching feature using groq.
// it compares one item against possible lost or found reports.
class AppliedAIService {
  // groq api settings.
  
  static const String groqKey = 'REPLACE_WITH_GROQ_API_KEY';

  static const String groqModel = 'llama-3.1-8b-instant';
  static const String groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // checks if a groq api key has been added.
  bool get isConfigured =>
      groqKey.startsWith('gsk_') && groqKey != 'gsk_XXX';

  // sends a prompt to groq and returns the text from its reply.
  Future<String> askGroq(String prompt) async {
    final response = await http.post(
      Uri.parse(groqUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $groqKey',
      },
      body: jsonEncode({
        'model': groqModel,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          },
        ],

        // keeps the ai response more consistent.
        'temperature': 0.2,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Groq API error ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body);

    return json['choices'][0]['message']['content'];
  }

  // asks the ai to rank which reports are most likely the same item.
  // returns the report id together with its confidence and reason.
  Future<Map<String, AiVerdict>> rankReports({
    required String searchingFor,
    required String itemName,
    required String category,
    required String colour,
    required String brand,
    required String description,
    required String location,
    required List<ItemReport> candidates,
    int maxResults = 5,
  }) async {
    // skips the ai call if there is no key or nothing to compare.
    if (!isConfigured || candidates.isEmpty) {
      return {};
    }

    // converts the report objects into text that can be sent to the ai.
    String reportList = '';

    for (final report in candidates) {
      reportList +=
          '${report.id} | ${report.name} | category: ${report.category} | '
          'colour: ${report.colour} | brand: ${report.brand} | '
          'location: ${report.location} | ${report.description}\n';
    }

    final String lookingFor =
        searchingFor == 'Lost' ? 'lost' : 'found';

    final String otherSide =
        searchingFor == 'Lost' ? 'found' : 'lost';

    // tells the ai what to compare and exactly how the reply should look.
    final String prompt = '''
You are the matching engine for Findr, a campus lost and found app.

A student has $lookingFor an item and described it like this:
Item name: ${itemName.isEmpty ? '(not given)' : itemName}
Category: ${category.isEmpty ? '(not given)' : category}
Colour: ${colour.isEmpty ? '(not given)' : colour}
Brand: ${brand.isEmpty ? '(not given)' : brand}
Location: ${location.isEmpty ? '(not given)' : location}
Description: ${description.isEmpty ? '(not given)' : description}

Below are $otherSide item reports posted by other students.
REPORT LIST (only choose from here):
$reportList

RULES:

1. Return AT MOST $maxResults reports.
2. Only use IDs from the report list above.
3. Only include a report if it could plausibly be the SAME physical object.
4. Judge by meaning, not just wording. A "Casio FX-991EX" is a calculator.
   "AirPods" are earphones. A "Hydro Flask" is a water bottle.
5. A shared category alone is NOT a match. Ignore reports that are merely
   the same type of thing but clearly a different object.
6. confidence is 0 to 100, where 100 means almost certainly the same item.
7. reason must be under 12 words and explain the match in plain English.
8. Rank by confidence, highest first.

Respond with ONLY this JSON, no extra text:
{
  "matches": [
    {
      "id": "report ID here",
      "confidence": 85,
      "reason": "short reason here"
    }
  ]
}
''';

    try {
      final String aiReply = await askGroq(prompt);

      return _parseReply(aiReply);
    } catch (e) {
      // keeps the normal matching feature working if the ai request fails.
      debugPrint(
        'Groq matching failed, using local scores only: $e',
      );

      return {};
    }
  }

  // converts the ai json reply into verdict objects the app can use.
  Map<String, AiVerdict> _parseReply(String aiReply) {
    String clean = aiReply.trim();

    // removes markdown code blocks if the ai added them.
    clean = clean
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    // removes any extra text outside the json object.
    final int start = clean.indexOf('{');
    final int end = clean.lastIndexOf('}');

    if (start == -1 || end == -1 || end <= start) {
      return {};
    }

    clean = clean.substring(start, end + 1);

    final Map<String, AiVerdict> verdicts = {};

    try {
      final data = jsonDecode(clean);
      final matches = data['matches'];

      if (matches is! List) {
        return {};
      }

      for (final match in matches) {
        if (match is! Map) {
          continue;
        }

        final id = match['id'];

        if (id is! String || id.isEmpty) {
          continue;
        }

        final rawConfidence = match['confidence'];

        // makes sure confidence always stays between 0 and 100.
        final int confidence = rawConfidence is num
            ? rawConfidence.toInt().clamp(0, 100)
            : 0;

        final reason = match['reason'];

        verdicts[id] = AiVerdict(
          confidence: confidence,
          reason: reason is String ? reason.trim() : '',
        );
      }
    } catch (e) {
      debugPrint('Could not read the AI reply: $e');

      return {};
    }

    return verdicts;
  }
}

// stores the ai confidence and reason for one possible match.
class AiVerdict {
  final int confidence;
  final String reason;

  const AiVerdict({
    required this.confidence,
    this.reason = '',
  });
}