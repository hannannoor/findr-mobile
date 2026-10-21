import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The states shown by Settings before the user tries to enable biometrics.
enum BiometricAvailability {
  available,
  unsupported,
  notEnrolled,
  temporarilyUnavailable,
}

extension BiometricAvailabilityMessage on BiometricAvailability {
  bool get canAuthenticate => this == BiometricAvailability.available;

  String get message {
    switch (this) {
      case BiometricAvailability.available:
        return 'Use Face ID or fingerprint as a second sign-in step';
      case BiometricAvailability.unsupported:
        return kIsWeb
            ? 'Biometric authentication is not available in a web browser'
            : 'Biometric authentication is not supported on this device';
      case BiometricAvailability.notEnrolled:
        return 'Tap to set up Face ID or fingerprint';
      case BiometricAvailability.temporarilyUnavailable:
        return 'Biometrics are temporarily unavailable. Try again shortly';
    }
  }
}

class BiometricAuthResult {
  final bool succeeded;
  final String message;

  const BiometricAuthResult._({required this.succeeded, required this.message});

  const BiometricAuthResult.success(String message)
    : this._(succeeded: true, message: message);

  const BiometricAuthResult.failure(String message)
    : this._(succeeded: false, message: message);
}

// Kept behind a small interface so the security rules can be tested without
// opening a real device prompt in automated tests.
abstract class BiometricAuthenticator {
  Future<BiometricAvailability> availability();

  Future<BiometricAuthResult> authenticate({required String reason});
}

class DeviceBiometricAuthenticator implements BiometricAuthenticator {
  final LocalAuthentication _localAuthentication;

  // Shared with the enrolment launcher below, and handled in MainActivity.
  static const MethodChannel _channel = MethodChannel('findr/biometrics');

  DeviceBiometricAuthenticator({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  bool get _platformSupportsStrictBiometrics {
    if (kIsWeb) return false;

    // Windows Hello cannot enforce biometric-only authentication. Findr uses
    // this as a genuine second biometric step, so Windows is not offered.
    return defaultTargetPlatform != TargetPlatform.windows;
  }

  // Asks Android's own BiometricManager, which is the only source that can
  // tell "this device has no sensor" apart from "nobody has set one up yet".
  Future<BiometricAvailability?> _androidStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      final String? status = await _channel.invokeMethod<String>(
        'biometricStatus',
      );

      switch (status) {
        case 'available':
          return BiometricAvailability.available;
        case 'notEnrolled':
          return BiometricAvailability.notEnrolled;
        case 'unsupported':
          return BiometricAvailability.unsupported;
        case 'temporarilyUnavailable':
          return BiometricAvailability.temporarilyUnavailable;
      }
    } catch (_) {
      // An older build of the app without the channel, so fall through to the
      // plugin based check rather than reporting a failure.
    }

    return null;
  }

  @override
  Future<BiometricAvailability> availability() async {
    if (!_platformSupportsStrictBiometrics) {
      return BiometricAvailability.unsupported;
    }

    final BiometricAvailability? androidStatus = await _androidStatus();
    if (androidStatus != null) return androidStatus;

    try {
      // Enrolment is checked first, because a device that reports enrolled
      // biometrics is usable no matter what the capability flags say.
      final List<BiometricType> enrolled = await _localAuthentication
          .getAvailableBiometrics();

      if (enrolled.isNotEmpty) return BiometricAvailability.available;

      // canCheckBiometrics is false both with no sensor and with a sensor that
      // has nothing enrolled, so it cannot be treated as a hardware test on its
      // own. Only when the device reports no support at all is this genuinely
      // unsupported; otherwise the user simply has to enrol.
      final bool canCheck = await _localAuthentication.canCheckBiometrics;
      final bool deviceSupported = await _localAuthentication
          .isDeviceSupported();

      if (!canCheck && !deviceSupported) {
        return BiometricAvailability.unsupported;
      }

      return BiometricAvailability.notEnrolled;
    } on LocalAuthException catch (error) {
      return _availabilityForException(error.code);
    } catch (_) {
      return BiometricAvailability.temporarilyUnavailable;
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({required String reason}) async {
    if (!_platformSupportsStrictBiometrics) {
      return BiometricAuthResult.failure(
        BiometricAvailability.unsupported.message,
      );
    }

    try {
      final bool authenticated = await _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      return authenticated
          ? const BiometricAuthResult.success('Identity confirmed.')
          : const BiometricAuthResult.failure(
              'Biometric authentication was not completed.',
            );
    } on LocalAuthException catch (error) {
      return BiometricAuthResult.failure(_messageForException(error.code));
    } catch (_) {
      return const BiometricAuthResult.failure(
        'Biometric authentication could not start. Please try again.',
      );
    }
  }

  BiometricAvailability _availabilityForException(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return BiometricAvailability.notEnrolled;
      case LocalAuthExceptionCode.noBiometricHardware:
        return BiometricAvailability.unsupported;
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return BiometricAvailability.temporarilyUnavailable;
      default:
        return BiometricAvailability.temporarilyUnavailable;
    }
  }

  String _messageForException(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
        return 'Authentication was cancelled. Your setting was not changed.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return BiometricAvailability.notEnrolled.message;
      case LocalAuthExceptionCode.noBiometricHardware:
        return BiometricAvailability.unsupported.message;
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return BiometricAvailability.temporarilyUnavailable.message;
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Too many attempts. Wait a moment, then try again.';
      case LocalAuthExceptionCode.biometricLockout:
        return 'Biometrics are locked. Unlock your device, then try again.';
      case LocalAuthExceptionCode.authInProgress:
        return 'A biometric check is already in progress.';
      default:
        return 'Biometric authentication failed. Please try again.';
    }
  }
}

abstract class BiometricEnrollmentLauncher {
  Future<bool> open();
}

class DeviceBiometricEnrollmentLauncher implements BiometricEnrollmentLauncher {
  static const MethodChannel _channel = MethodChannel('findr/biometrics');

  @override
  Future<bool> open() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('openBiometricEnrollment') ??
          false;
    } catch (_) {
      return false;
    }
  }
}

class BiometricService {
  final BiometricAuthenticator authenticator;
  final BiometricEnrollmentLauncher enrollmentLauncher;
  final Future<SharedPreferences> Function() _loadPreferences;

  BiometricService({
    BiometricAuthenticator? authenticator,
    BiometricEnrollmentLauncher? enrollmentLauncher,
    Future<SharedPreferences> Function()? loadPreferences,
  }) : authenticator = authenticator ?? DeviceBiometricAuthenticator(),
       enrollmentLauncher =
           enrollmentLauncher ?? DeviceBiometricEnrollmentLauncher(),
       _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  String _preferenceKey(String userId) {
    return 'findr_biometric_enabled_$userId';
  }

  Future<bool> isEnabledForUser(String userId) async {
    final SharedPreferences preferences = await _loadPreferences();
    return preferences.getBool(_preferenceKey(userId)) ?? false;
  }

  Future<BiometricAvailability> availability() {
    return authenticator.availability();
  }

  Future<bool> openEnrollmentSettings() {
    return enrollmentLauncher.open();
  }

  // Enabling and disabling both require confirmation. This prevents someone
  // who picks up an unlocked phone from silently weakening the setting.
  Future<BiometricAuthResult> changeSetting({
    required String userId,
    required bool enabled,
  }) async {
    final BiometricAvailability currentAvailability = await availability();
    if (!currentAvailability.canAuthenticate) {
      return BiometricAuthResult.failure(currentAvailability.message);
    }

    final BiometricAuthResult authentication = await authenticator.authenticate(
      reason: enabled
          ? 'Confirm your identity to turn on biometric authentication for Findr'
          : 'Confirm your identity to turn off biometric authentication for Findr',
    );

    if (!authentication.succeeded) return authentication;

    final SharedPreferences preferences = await _loadPreferences();
    final bool saved = await preferences.setBool(
      _preferenceKey(userId),
      enabled,
    );

    if (!saved) {
      return const BiometricAuthResult.failure(
        'The biometric setting could not be saved. Please try again.',
      );
    }

    return BiometricAuthResult.success(
      enabled
          ? 'Biometric authentication is now on.'
          : 'Biometric authentication is now off.',
    );
  }

  Future<BiometricAuthResult> authenticateForAppUnlock() {
    return authenticator.authenticate(
      reason: 'Confirm your identity to open Findr',
    );
  }

  Future<void> clearForUser(String userId) async {
    final SharedPreferences preferences = await _loadPreferences();
    await preferences.remove(_preferenceKey(userId));
  }
}
