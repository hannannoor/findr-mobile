import 'dart:math';

import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/models/match_result.dart';

// handles the local matching feature.
// it scores how similar a report is to what the user is looking for.
class MatchService {
  // controls how much each field affects the final match score.
  static const Map<String, double> weights = {
    'category': 22,
    'colour': 18,
    'itemName': 16,
    'location': 14,
    'brand': 10,
    'description': 10,
    'date': 6,
    'condition': 4,
  };

  // checks all reports and returns the best matches first.
  List<MatchResult> findMatches({
    required List<ItemReport> reports,
    required String searchingFor,
    String itemName = '',
    String category = '',
    String colour = '',
    String brand = '',
    String condition = '',
    String description = '',
    String location = '',
    DateTime? date,
    int minimumScore = 38,
    int limit = 20,
  }) {
    // lost reports only match found reports and vice versa.
    final String wantedType =
        searchingFor == 'Lost' ? 'Found' : 'Lost';

    final List<MatchResult> results = [];

    for (final report in reports) {
      // skips reports that cannot be matched anymore.
      if (report.reportType != wantedType) continue;
      if (report.reportStatus == 'resolved') continue;

      final _Score score = _scoreReport(
        report: report,
        itemName: itemName,
        category: category,
        colour: colour,
        brand: brand,
        condition: condition,
        description: description,
        location: location,
        date: date,
      );

      // ignores weak matches.
      if (score.percent < minimumScore) continue;

      results.add(
        MatchResult(
          reportId: report.id,
          name: report.name,
          description: report.description,
          condition: report.condition,
          location: report.location,
          timeAgo: report.timeAgo,
          imagePath: report.imagePath,
          base64Image: report.base64Image,
          matchPercent: score.percent,
          matched: score.matched,
          missed: score.missed,
        ),
      );
    }

    // sorts matches from highest score to lowest.
    results.sort(
      (a, b) => b.matchPercent.compareTo(a.matchPercent),
    );

    // marks the top result as best match only if it is clearly stronger.
    if (results.isNotEmpty) {
      final bool clearWinner =
          results.length == 1 ||
          results[0].matchPercent - results[1].matchPercent >= 8;

      if (clearWinner && results[0].matchPercent >= 60) {
        results[0].isBestMatch = true;
      }
    }

    return results.take(limit).toList();
  }

  // calculates the match score for one report.
  _Score _scoreReport({
    required ItemReport report,
    required String itemName,
    required String category,
    required String colour,
    required String brand,
    required String condition,
    required String description,
    required String location,
    DateTime? date,
  }) {
    double earned = 0;
    double available = 0;

    final List<String> matched = [];
    final List<String> missed = [];

    // keeps track of whether there is enough information to identify the item.
    double identityStrength = 0;

    // compares one field and adds its score.
    // blank fields are skipped so they do not lower the result.
    void judge(
      String label,
      String weightKey,
      String a,
      String b,
      double similarity,
    ) {
      if (a.trim().isEmpty || b.trim().isEmpty) return;

      final double weight = weights[weightKey]!;

      available += weight;
      earned += weight * similarity;

      if (similarity >= 0.6) {
        matched.add(label);
      } else {
        missed.add(label);
      }
    }

    judge(
      'Category',
      'category',
      category,
      report.category,
      _exact(category, report.category),
    );

    // checks colour from the colour field or description if needed.
    judge(
      'Colour',
      'colour',
      colour,
      report.colour.isNotEmpty
          ? report.colour
          : report.description,
      report.colour.isNotEmpty
          ? _exact(colour, report.colour)
          : report.description
                  .toLowerCase()
                  .contains(colour.toLowerCase())
              ? 0.85
              : 0.0,
    );

    // compares the item name against both the name and description.
    final double nameScore = max(
      _textSimilarity(itemName, report.name),
      _textSimilarity(itemName, report.description) * 0.8,
    );

    if (itemName.trim().isNotEmpty) {
      identityStrength = max(
        identityStrength,
        nameScore,
      );
    }

    judge(
      'Item Name',
      'itemName',
      itemName,
      report.name,
      nameScore,
    );

    judge(
      'Location',
      'location',
      location,
      report.location,
      _textSimilarity(location, report.location),
    );

    // uses text similarity so small brand differences can still match.
    judge(
      'Brand',
      'brand',
      brand,
      report.brand,
      _textSimilarity(brand, report.brand),
    );

    final double descriptionScore = max(
      _textSimilarity(description, report.description),
      _textSimilarity(description, report.name) * 0.8,
    );

    if (description.trim().isNotEmpty) {
      identityStrength = max(
        identityStrength,
        descriptionScore,
      );
    }

    judge(
      'Description',
      'description',
      description,
      report.description,
      descriptionScore,
    );

    // a matching brand also helps identify the item.
    if (brand.trim().isNotEmpty &&
        report.brand.trim().isNotEmpty) {
      identityStrength = max(
        identityStrength,
        _textSimilarity(brand, report.brand) * 0.9,
      );
    }

    judge(
      'Condition',
      'condition',
      condition,
      report.condition,
      _exact(condition, report.condition),
    );

    // gives a better score when the report dates are closer together.
    if (date != null) {
      final double weight = weights['date']!;
      final int days =
          date.difference(report.dateLostFound).inDays.abs();

      final double similarity = days == 0
          ? 1.0
          : days <= 14
              ? 1.0 - (days / 14)
              : 0.0;

      available += weight;
      earned += weight * similarity;

      if (similarity >= 0.6) {
        matched.add('Date');
      } else {
        missed.add('Date');
      }
    }

    // no useful fields were available to compare.
    if (available == 0) {
      return _Score(
        0,
        matched,
        missed,
      );
    }

    // converts the earned score into a percentage.
    double percent = (earned / available) * 100;

    // lowers the score if only a small amount of data was compared.
    final int comparedFields =
        matched.length + missed.length;

    if (comparedFields <= 1) {
      percent *= 0.55;
    } else if (comparedFields == 2) {
      percent *= 0.8;
    }

    // stops weak identity matches from getting unrealistically high scores.
    if (identityStrength < 0.35) {
      percent = min(percent, 35);
    } else if (identityStrength < 0.6) {
      percent = min(percent, 62);
    }

    return _Score(
      percent.round().clamp(0, 99),
      matched,
      missed,
    );
  }

  // compares dropdown values without caring about capital letters.
  double _exact(String a, String b) {
    return a.trim().toLowerCase() ==
            b.trim().toLowerCase()
        ? 1.0
        : 0.0;
  }

  // groups words that mean roughly the same thing.
  static const List<Set<String>> _synonyms = [
    {
      'earphones',
      'earbuds',
      'airpods',
      'headphones',
      'buds',
      'earpiece',
    },
    {
      'phone',
      'mobile',
      'iphone',
      'samsung',
      'handphone',
      'smartphone',
    },
    {
      'laptop',
      'notebook',
      'macbook',
      'computer',
    },
    {
      'wallet',
      'purse',
      'pouch',
    },
    {
      'bottle',
      'flask',
      'tumbler',
      'thermos',
    },
    {
      'bag',
      'backpack',
      'haversack',
      'knapsack',
      'sling',
    },
    {
      'calculator',
      'calc',
    },
    {
      'card',
      'ezlink',
      'concession',
      'matric',
      'id',
    },
    {
      'charger',
      'cable',
      'powerbank',
      'adapter',
    },
    {
      'watch',
      'smartwatch',
      'fitbit',
    },
    {
      'keys',
      'keychain',
      'key',
    },
    {
      'glasses',
      'spectacles',
      'specs',
      'sunglasses',
    },
    {
      'jacket',
      'hoodie',
      'sweater',
      'coat',
    },
    {
      'umbrella',
      'brolly',
    },
    {
      'drive',
      'thumbdrive',
      'pendrive',
      'usb',
      'flashdrive',
    },
  ];

  // checks if two words are in the same synonym group.
  bool _areSynonyms(String a, String b) {
    for (final group in _synonyms) {
      if (group.contains(a) && group.contains(b)) {
        return true;
      }
    }

    return false;
  }

  // compares two pieces of text and returns how similar they are.
  double _textSimilarity(String a, String b) {
    final String left = a.toLowerCase().trim();
    final String right = b.toLowerCase().trim();

    if (left.isEmpty || right.isEmpty) {
      return 0;
    }

    if (left == right) {
      return 1;
    }

    // a full phrase appearing inside the other is already a strong match.
    if (left.contains(right) || right.contains(left)) {
      return 0.92;
    }

    final Set<String> leftWords =
        _meaningfulWords(left);

    final Set<String> rightWords =
        _meaningfulWords(right);

    if (leftWords.isEmpty || rightWords.isEmpty) {
      return 0;
    }

    double total = 0;

    // finds the best matching word for each word on the left.
    for (final word in leftWords) {
      double best = 0;

      for (final other in rightWords) {
        double score = 0;

        if (word == other) {
          score = 1.0;
        } else if (_areSynonyms(word, other)) {
          score = 0.9;
        } else if (
            word.startsWith(other) ||
            other.startsWith(word)) {
          score = 0.75;
        } else if (_closeEnough(word, other)) {
          score = 0.7;
        }

        if (score > best) {
          best = score;
        }
      }

      total += best;
    }

    // uses the shorter side so long descriptions do not lower the score too much.
    final double overlap =
        total / min(leftWords.length, rightWords.length);

    return overlap.clamp(0.0, 1.0);
  }

  // removes filler words and keeps the useful ones for comparison.
  Set<String> _meaningfulWords(String text) {
    const Set<String> ignore = {
      'a',
      'an',
      'the',
      'my',
      'with',
      'and',
      'of',
      'in',
      'on',
      'at',
      'is',
      'it',
      'this',
      'that',
      'for',
      'to',
      'near',
      'from',
      'has',
      'have',
      'was',
      'are',
      'lost',
      'found',
      'item',
      'some',
      'someone',
      'there',
      'his',
      'her',
      'its',
      'about',
      'been',
      'very',
      'really',
    };

    return text
        .replaceAll(
          RegExp(r'[^a-z0-9\s]'),
          ' ',
        )
        .split(RegExp(r'\s+'))
        .where(
          (word) =>
              word.length > 2 &&
              !ignore.contains(word),
        )
        .toSet();
  }

  // checks if two words are close enough to probably mean the same thing.
  bool _closeEnough(String a, String b) {
    if (a == b) {
      return true;
    }

    if ((a.length - b.length).abs() > 2) {
      return false;
    }

    // handles simple plural differences.
    if (a == '${b}s' || b == '${a}s') {
      return true;
    }

    return _editDistance(a, b) <=
        (a.length > 5 ? 2 : 1);
  }

  // calculates the number of character changes between two words.
  int _editDistance(String a, String b) {
    final List<int> previous =
        List<int>.generate(
      b.length + 1,
      (i) => i,
    );

    final List<int> current =
        List<int>.filled(
      b.length + 1,
      0,
    );

    for (int i = 0; i < a.length; i++) {
      current[0] = i + 1;

      for (int j = 0; j < b.length; j++) {
        final int cost =
            a[i] == b[j] ? 0 : 1;

        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce(min);
      }

      previous.setAll(
        0,
        current,
      );
    }

    return previous[b.length];
  }
}

// stores the score and which fields matched or did not match.
class _Score {
  final int percent;
  final List<String> matched;
  final List<String> missed;

  _Score(
    this.percent,
    this.matched,
    this.missed,
  );
}