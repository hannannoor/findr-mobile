import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/providers/biometric_provider.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/services/biometric_service.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_page.dart';

// checks biometric security after the user has logged in normally.
// it only needs to unlock once for the current app session.
class BiometricGate extends ConsumerStatefulWidget {
  final String userId;
  final Widget child;

  const BiometricGate({
    super.key,
    required this.userId,
    required this.child,
  });

  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate> {
  bool _unlocked = false;
  bool _busy = true;
  String _message = 'Checking your security preference…';

  @override
  void initState() {
    super.initState();

    // waits until the first frame is ready before checking biometrics.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareGate();
    });
  }

  // checks whether biometric unlock is enabled for this user.
  Future<void> _prepareGate() async {
    try {
      final BiometricService service = ref.read(biometricServiceProvider);
      final bool enabled =
          await service.isEnabledForUser(widget.userId);

      if (!mounted) {
        return;
      }

      // skips biometric authentication if the user did not enable it.
      if (!enabled) {
        setState(() {
          _unlocked = true;
          _busy = false;
        });

        return;
      }

      await _authenticate();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _message =
            'Findr could not read the biometric setting. Please try again.';
      });
    }
  }

  // asks the device to verify the user using face id or fingerprint.
  Future<void> _authenticate() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _busy = true;
      _message = 'Waiting for Face ID or fingerprint…';
    });

    final BiometricService service = ref.read(biometricServiceProvider);

    // checks if biometric authentication can be used on this device.
    final BiometricAvailability availability =
        await service.availability();

    if (!mounted) {
      return;
    }

    if (!availability.canAuthenticate) {
      setState(() {
        _busy = false;
        _message = availability.message;
      });

      return;
    }

    final BiometricAuthResult result =
        await service.authenticateForAppUnlock();

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _unlocked = result.succeeded;
      _message =
          result.succeeded ? 'Identity confirmed.' : result.message;
    });
  }

  // logs the user out if they do not want to unlock the app.
  Future<void> _logOut() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _message = 'Signing out…';
    });

    await ref.read(firebaseServiceProvider).logOut();
  }

  @override
  Widget build(BuildContext context) {
    // shows the actual app once biometric authentication succeeds.
    if (_unlocked) {
      return widget.child;
    }

    final FindrColors colors = FindrColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SizedBox.expand(
        child: Stack(
          children: [
            const AppPageBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FindrLogo(
                          height: 62,
                          alignment: Alignment.center,
                        ),
                        const SizedBox(height: 22),
                        AppCard(
                          padding: const EdgeInsets.fromLTRB(
                            24,
                            26,
                            24,
                            22,
                          ),
                          child: Column(
                            children: [
                              _SecurityMark(busy: _busy),
                              const SizedBox(height: 20),
                              Text(
                                'Unlock Findr',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.45,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  height: 1.45,
                                  fontSize: 13.5,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: FilledButton.icon(
                                  onPressed:
                                      _busy ? null : _authenticate,
                                  icon: const Icon(
                                    Icons.fingerprint_rounded,
                                    size: 22,
                                  ),
                                  label: Text(
                                    _busy
                                        ? 'Checking…'
                                        : 'Try again',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors.primary,
                                    foregroundColor:
                                        Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: OutlinedButton(
                                  onPressed:
                                      _busy ? null : _logOut,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        colors.textSecondary,
                                    side: BorderSide(
                                      color: colors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'Log out',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Your biometric data stays on this device',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// shows either a loading spinner or the fingerprint icon.
class _SecurityMark extends StatelessWidget {
  final bool busy;

  const _SecurityMark({
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceSoft,
        border: Border.all(color: colors.border),
      ),
      child: Center(
        child: busy
            ? SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.primary,
                ),
              )
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 46,
                    color: colors.primary,
                  ),
                  Positioned(
                    right: -7,
                    bottom: -5,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                        border: Border.all(
                          color: colors.surface,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}