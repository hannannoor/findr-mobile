import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/services/applied_ai_service.dart';

// One shared instance of the Applied AI service, so screens do not each
// create their own. Same pattern as the Applied AI lab.
final appliedAIServiceProvider = Provider<AppliedAIService>((ref) {
  return AppliedAIService();
});
