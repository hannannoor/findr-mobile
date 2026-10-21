// one scored result from the AI matching feature.
//
// it carries the report it points at, the score, and the reasons behind that
// score, so the results screen can explain the match instead of only showing
// a number.
class MatchResult {
  // the firestore document id, used to open the full report.
  final String reportId;

  final String name;
  final String description;
  final String condition;
  final String location;
  final String timeAgo;

  // bundled asset for sample reports.
  final String imagePath;

  // uploaded photo, when the report has one.
  final String base64Image;

  final int matchPercent;

  // which details lined up, and which did not.
  final List<String> matched;
  final List<String> missed;

  // set on the strongest result when it is clearly ahead of the others.
  bool isBestMatch;

  // The language model's confidence out of 100, and its short explanation.
  // Both stay null when the model was not used or could not be reached.
  int? aiConfidence;
  String? aiReason;

  MatchResult({
    this.reportId = '',
    required this.name,
    required this.description,
    required this.condition,
    required this.location,
    required this.timeAgo,
    this.imagePath = '',
    this.base64Image = '',
    required this.matchPercent,
    List<String>? matched,
    List<String>? missed,
    this.isBestMatch = false,
    this.aiConfidence,
    this.aiReason,
  }) : matched = matched ?? const [],
       missed = missed ?? const [];

  bool get hasPhoto => base64Image.isNotEmpty;

  // True when the language model also looked at this result.
  bool get hasAiVerdict => aiConfidence != null;

  // plain english confidence, so the number has some context next to it.
  String get confidenceLabel {
    if (matchPercent >= 80) return 'Very strong match';
    if (matchPercent >= 60) return 'Strong match';
    if (matchPercent >= 40) return 'Possible match';
    return 'Weak match';
  }
}
