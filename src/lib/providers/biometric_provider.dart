import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/services/biometric_service.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final biometricAvailabilityProvider = FutureProvider<BiometricAvailability>((
  ref,
) {
  return ref.read(biometricServiceProvider).availability();
});

final biometricEnabledProvider = FutureProvider.family<bool, String>((
  ref,
  userId,
) {
  return ref
      .read(biometricServiceProvider)
      .isEnabledForUser(userId);
});
