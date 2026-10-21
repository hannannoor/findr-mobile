import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/providers/biometric_provider.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/providers/notification_provider.dart';
import 'package:findr_application/providers/theme_provider.dart';
import 'package:findr_application/screens/auth/login_screen.dart';
import 'package:findr_application/screens/notifications_screen.dart';
import 'package:findr_application/services/biometric_service.dart';
import 'package:findr_application/services/notification_service.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_page.dart';

// app settings, grouped into sections.
//
// notifications and demo data work now. appearance and security are laid out
// ready for the theme picker and fingerprint unlock, so those drop straight
// in without anything being moved around.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool deviceAlertsOn = true;
  bool isWorking = false;
  bool biometricWorking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A fingerprint may have been enrolled while Findr was backgrounded.
      // Rechecking here makes the switch usable immediately on return.
      ref.invalidate(biometricAvailabilityProvider);
    }
  }

  Future<void> loadPreferences() async {
    final enabled = await NotificationService.alertsEnabled();
    if (!mounted) return;
    setState(() => deviceAlertsOn = enabled);
  }

  Future<void> toggleAlerts(bool value) async {
    setState(() => deviceAlertsOn = value);
    await NotificationService.setAlertsEnabled(value);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Device alerts turned on.'
              : 'Device alerts turned off. You can still read them in the app.',
        ),
      ),
    );
  }

  Future<void> toggleBiometrics(bool value) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || biometricWorking) return;

    setState(() => biometricWorking = true);

    final BiometricAuthResult result = await ref
        .read(biometricServiceProvider)
        .changeSetting(userId: user.uid, enabled: value);

    ref.invalidate(biometricEnabledProvider(user.uid));
    ref.invalidate(biometricAvailabilityProvider);

    if (!mounted) return;

    setState(() => biometricWorking = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.succeeded ? null : const Color(0xFFE0415F),
        content: Text(result.message),
      ),
    );
  }

  Future<void> handleBiometricRowTap({
    required bool enabled,
    required BiometricAvailability? availability,
  }) async {
    if (biometricWorking || isWorking) return;

    if (availability?.canAuthenticate ?? false) {
      await toggleBiometrics(!enabled);
      return;
    }

    if (availability == null) {
      ref.invalidate(biometricAvailabilityProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checking biometric support again...')),
      );
      return;
    }

    await showBiometricSetupDialog(availability);
  }

  Future<void> showBiometricSetupDialog(
    BiometricAvailability availability,
  ) async {
    final bool canOpenAndroidSettings =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final bool needsEnrollment =
        availability == BiometricAvailability.notEnrolled;

    final String explanation;
    if (needsEnrollment) {
      explanation =
          'This device has a biometric sensor, but no fingerprint or face '
          'is enrolled yet.';
    } else if (kIsWeb) {
      explanation =
          'Web browsers cannot use Findr\'s biometric app lock. Open the '
          'Android app on a supported phone or emulator instead.';
    } else {
      explanation = availability.message;
    }

    final bool? openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final FindrColors colors = FindrColors.of(dialogContext);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(
            Icons.fingerprint_rounded,
            size: 38,
            color: colors.primary,
          ),
          title: Text(
            needsEnrollment ? 'Set up biometrics' : 'Biometrics unavailable',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(explanation, style: const TextStyle(height: 1.4)),
              if (canOpenAndroidSettings) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceSoft,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: colors.border),
                  ),
                  child: const Text(
                    'Add a screen lock, enroll a fingerprint, then return '
                    'to Findr. On the emulator, use More (...) > Fingerprint '
                    '> Touch Sensor when asked to scan.',
                    style: TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(canOpenAndroidSettings ? 'Cancel' : 'OK'),
            ),
            if (canOpenAndroidSettings)
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Open device settings'),
              ),
          ],
        );
      },
    );

    if (openSettings != true || !mounted) return;

    final bool opened = await ref
        .read(biometricServiceProvider)
        .openEnrollmentSettings();

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open biometric settings. Open Security in device Settings.',
          ),
        ),
      );
    }
  }

  void showThemePicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, sheetRef, _) {
            final ThemePreferences preferences = sheetRef.watch(
              themeControllerProvider,
            );
            final FindrColors colors = FindrColors.of(context);

            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Choose your theme',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'The colour updates across Findr immediately.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final FindrPalette palette in FindrPalette.values) ...[
                      buildThemeOption(
                        context: context,
                        palette: palette,
                        selected: preferences.palette == palette,
                        darkMode: preferences.darkMode,
                        onTap: () {
                          sheetRef
                              .read(themeControllerProvider.notifier)
                              .setPalette(palette);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                      if (palette != FindrPalette.values.last)
                        const SizedBox(height: 9),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildThemeOption({
    required BuildContext context,
    required FindrPalette palette,
    required bool selected,
    required bool darkMode,
    required VoidCallback onTap,
  }) {
    final FindrColors current = FindrColors.of(context);
    final FindrColors preview = FindrTheme.build(
      palette,
      brightness: darkMode ? Brightness.dark : Brightness.light,
    ).extension<FindrColors>()!;

    return Material(
      color: selected ? current.surfaceSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? current.primary : current.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 42,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: preview.backgroundAlt,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: preview.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 9,
                      height: 18,
                      decoration: BoxDecoration(
                        color: preview.primary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    Container(
                      width: 9,
                      height: 27,
                      decoration: BoxDecoration(
                        color: preview.accent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    Container(
                      width: 9,
                      height: 12,
                      decoration: BoxDecoration(
                        color: preview.primaryStrong,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palette.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: current.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      palette.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: current.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? current.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? current.primary : current.border,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // account actions
  // ---------------------------------------------------------------------

  void showChangePasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'New password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a new password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FindrColors.of(context).primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final String password = controller.text;
                Navigator.of(dialogContext).pop();

                try {
                  await ref
                      .read(firebaseServiceProvider)
                      .changePassword(password);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully!'),
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  if (!mounted) return;

                  // firebase refuses this if the login is old, which is the
                  // one case worth explaining properly.
                  final String message = e.code == 'requires-recent-login'
                      ? 'Please log out and log in again before changing '
                            'your password.'
                      : e.code;

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  void confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FindrColors.of(context).primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await ref.read(firebaseServiceProvider).logOut();

                if (!mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  // deleting the account also removes everything the user posted, so it asks
  // the person to type DELETE rather than relying on a single tap.
  void confirmDeleteAccount() {
    final controller = TextEditingController();
    final FindrColors colors = FindrColors.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: dark ? 0.72 : 0.46),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool confirmed =
                controller.text.trim().toUpperCase() == 'DELETE';

            return AlertDialog(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black.withValues(alpha: dark ? 0.55 : 0.18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: colors.border),
              ),
              title: Text(
                'Delete Account',
                style: TextStyle(color: colors.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This permanently deletes your account, your reports '
                    'and your claims. It cannot be undone.\n\n'
                    'Type DELETE to confirm.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      filled: true,
                      fillColor: colors.surfaceSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colors.primary,
                          width: 1.25,
                        ),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0415F),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: confirmed
                      ? () {
                          Navigator.of(dialogContext).pop();
                          deleteAccount();
                        }
                      : null,
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => controller.dispose());
  }

  Future<void> deleteAccount() async {
    if (isWorking) return;

    setState(() => isWorking = true);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      await ref.read(firebaseServiceProvider).deleteAccount();

      if (userId != null) {
        await ref.read(biometricServiceProvider).clearForUser(userId);
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() => isWorking = false);

      // firebase requires a fresh login before destructive account changes.
      final String message = e.code == 'requires-recent-login'
          ? 'Please log out and log in again before deleting your account.'
          : e.code;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE0415F),
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => isWorking = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE0415F),
          content: Text('Could not delete the account: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int unread = ref.watch(unreadNotificationCountProvider);
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final AsyncValue<BiometricAvailability> biometricAvailabilityState = ref
        .watch(biometricAvailabilityProvider);
    final AsyncValue<bool>? biometricEnabledState = currentUser == null
        ? null
        : ref.watch(biometricEnabledProvider(currentUser.uid));
    final BiometricAvailability? biometricAvailability =
        biometricAvailabilityState.value;
    final bool biometricsOn = biometricEnabledState?.value ?? false;
    final bool biometricLoading =
        biometricWorking ||
        biometricAvailabilityState.isLoading ||
        (biometricEnabledState?.isLoading ?? false);
    final bool canChangeBiometrics =
        currentUser != null &&
        !biometricLoading &&
        !isWorking &&
        (biometricAvailability?.canAuthenticate ?? false);
    final bool canTapBiometricRow =
        currentUser != null && !biometricLoading && !isWorking;
    final String? biometricActionLabel = canChangeBiometrics
        ? null
        : biometricsOn
        ? 'FIX'
        : kIsWeb
        ? 'INFO'
        : 'SET UP';
    final ThemePreferences themePreferences = ref.watch(
      themeControllerProvider,
    );
    final FindrColors colors = FindrColors.of(context);

    return AppPage(
      subtitle: 'Account & Preferences',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWorking) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
          ],

          const AppSectionLabel('Notifications'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                buildNavRow(
                  icon: Icons.notifications_none_rounded,
                  colour: colors.primary,
                  background: colors.surfaceSoft,
                  title: 'Notification Inbox',
                  subtitle: unread > 0
                      ? '$unread unread'
                      : 'Claims, messages and reward updates',
                  badge: unread,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                buildDivider(),
                buildSwitchRow(
                  icon: Icons.phone_android_rounded,
                  colour: colors.primary,
                  background: colors.surfaceSoft,
                  title: 'Device Alerts',
                  subtitle: 'Show alerts on your phone as they arrive',
                  value: deviceAlertsOn,
                  onChanged: toggleAlerts,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const AppSectionLabel('Account'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                buildNavRow(
                  icon: Icons.lock_reset_rounded,
                  colour: colors.primary,
                  background: colors.surfaceSoft,
                  title: 'Change Password',
                  subtitle: 'Update the password you sign in with',
                  onTap: showChangePasswordDialog,
                ),
                buildDivider(),
                buildNavRow(
                  icon: Icons.logout_rounded,
                  colour: colors.primary,
                  background: colors.surfaceSoft,
                  title: 'Log Out',
                  subtitle: 'Sign out of this device',
                  onTap: confirmLogout,
                ),
                buildDivider(),
                buildNavRow(
                  icon: Icons.person_remove_outlined,
                  colour: const Color(0xFFE0415F),
                  background: Theme.of(context).brightness == Brightness.dark
                      ? colors.surfaceSoft
                      : const Color(0xFFFFE3E9),
                  title: 'Delete Account',
                  subtitle: 'Permanently remove your account and reports',
                  danger: true,
                  onTap: confirmDeleteAccount,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const AppSectionLabel('Appearance'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                buildNavRow(
                  icon: Icons.palette_outlined,
                  colour: colors.primary,
                  background: colors.surfaceSoft,
                  title: 'Theme',
                  subtitle: themePreferences.palette == FindrPalette.blue
                      ? 'Blue (default)'
                      : themePreferences.palette.label,
                  onTap: showThemePicker,
                ),
                buildDivider(),
                buildSwitchRow(
                  icon: Icons.dark_mode_outlined,
                  colour: colors.primary,
                  background: colors.surfaceSoft,
                  title: 'Dark Mode',
                  subtitle: 'Easier on the eyes at night',
                  value: themePreferences.darkMode,
                  onChanged: (value) {
                    ref
                        .read(themeControllerProvider.notifier)
                        .setDarkMode(value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const AppSectionLabel('Security'),
          AppCard(
            padding: EdgeInsets.zero,
            child: buildSwitchRow(
              icon: Icons.fingerprint_rounded,
              colour: colors.primary,
              background: colors.surfaceSoft,
              title: 'Biometric Authentication',
              subtitle: _biometricSubtitle(
                enabled: biometricsOn,
                enabledState: biometricEnabledState,
                availabilityState: biometricAvailabilityState,
              ),
              value: biometricsOn,
              loading: biometricLoading,
              onChanged: canChangeBiometrics ? toggleBiometrics : null,
              onTap: canTapBiometricRow
                  ? () => handleBiometricRowTap(
                      enabled: biometricsOn,
                      availability: biometricAvailability,
                    )
                  : null,
              trailingActionLabel: biometricActionLabel,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget buildDivider() {
    return Divider(
      height: 1,
      indent: 62,
      color: FindrColors.of(context).border,
    );
  }

  String _biometricSubtitle({
    required bool enabled,
    required AsyncValue<bool>? enabledState,
    required AsyncValue<BiometricAvailability> availabilityState,
  }) {
    if (enabledState == null) {
      return 'Sign in to manage biometric authentication';
    }

    if (enabledState.isLoading || availabilityState.isLoading) {
      return 'Checking this device…';
    }

    if (enabledState.hasError || availabilityState.hasError) {
      return 'Biometric status could not be checked';
    }

    if (enabled) {
      return 'Required after sign-in when opening Findr';
    }

    return availabilityState.value?.message ??
        'Biometric authentication is unavailable';
  }

  Widget buildIconBox(IconData icon, Color colour, Color background) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: colour),
    );
  }

  Widget buildNavRow({
    required IconData icon,
    required Color colour,
    required Color background,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badge = 0,
    bool comingSoon = false,
    bool showChevron = true,
    bool danger = false,
  }) {
    final FindrColors colors = FindrColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              buildIconBox(icon, colour, background),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: danger
                                  ? const Color(0xFFE0415F)
                                  : colors.textPrimary,
                            ),
                          ),
                        ),

                        // makes clear which settings are not built yet, so
                        // they do not look broken.
                        if (comingSoon) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'SOON',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: colors.muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: colors.muted),
                    ),
                  ],
                ),
              ),

              if (badge > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0415F),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSwitchRow({
    required IconData icon,
    required Color colour,
    required Color background,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool loading = false,
    VoidCallback? onTap,
    String? trailingActionLabel,
  }) {
    final FindrColors colors = FindrColors.of(context);

    // the same vertical padding as buildNavRow, so rows in one card are all
    // the same height. the switch is nudged with a transform instead of by
    // shrinking the padding, which is what made the first card look uneven.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              buildIconBox(icon, colour, background),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (loading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: colors.primary,
                    ),
                  ),
                )
              else if (trailingActionLabel != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 7, 7, 7),
                  decoration: BoxDecoration(
                    color: colors.surfaceSoft,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        trailingActionLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 17,
                        color: colors.primary,
                      ),
                    ],
                  ),
                )
              else
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: value,
                    activeThumbColor: colors.primary,
                    onChanged: onChanged,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
