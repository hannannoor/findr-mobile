import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/widgets/app_bottom_nav.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/screens/auth/login_screen.dart';
import 'package:findr_application/providers/notification_provider.dart';
import 'package:findr_application/screens/claims_screen.dart';
import 'package:findr_application/screens/my_reports_screen.dart';
import 'package:findr_application/screens/notifications_screen.dart';
import 'package:findr_application/screens/settings_screen.dart';
import 'package:findr_application/theme/app_theme.dart';

// this screen shows the user's profile and account settings.
// it uses riverpod because logout and auth actions need firebase service.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  FindrColors get themeColors => FindrColors.of(context);

  // logs the user out from firebase.
  // after logout, it clears the navigation stack and goes back to login.
  Future<void> logout(BuildContext context) async {
    try {
      await ref.read(firebaseServiceProvider).logOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User logged out successfully!')),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.code)));
    }
  }

  // sends another verification email to the current user.
  // this only shows when the email account is not verified yet.
  Future<void> resendVerification(BuildContext context) async {
    try {
      await ref.read(firebaseServiceProvider).sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.code)));
    }
  }

  // opens a small dialog so the user can change their password.
  // firebase may ask the user to login again if the login is too old.
  void showChangePasswordDialog(BuildContext context) {
    final dialogForm = GlobalKey<FormState>();
    String? newPassword;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Change Password'),
          content: Form(
            key: dialogForm,
            child: TextFormField(
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
              onSaved: (value) {
                newPassword = value;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (dialogForm.currentState!.validate()) {
                  dialogForm.currentState!.save();
                  Navigator.of(dialogContext).pop();

                  try {
                    await ref
                        .read(firebaseServiceProvider)
                        .changePassword(newPassword!);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully!'),
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    String msg = e.code == 'requires-recent-login'
                        ? 'Please log out and log in again before changing your password.'
                        : e.code;

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // gets the current firebase user so the profile can show their email/photo.
    final User? user = ref.read(firebaseServiceProvider).getCurrentUser();

    // social login accounts like google/github are treated as verified.
    final bool isSocial =
        user?.providerData.any((info) => info.providerId != 'password') ??
        false;

    final bool isVerified = (user?.emailVerified ?? false) || isSocial;

    return Scaffold(
      backgroundColor: themeColors.backgroundAlt,
      bottomNavigationBar: AppBottomNav(currentIndex: 4),
      body: SizedBox.expand(
        child: Stack(
          children: [
            const AppPageBackground(),

            // main profile content goes above the background image.
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeading(),
                    const SizedBox(height: 18),
                    buildProfileCard(user),
                    const SizedBox(height: 14),
                    buildStatsRow(),
                    const SizedBox(height: 14),

                    // only email/password users need to see this banner.
                    if (!isVerified) ...[
                      buildVerificationBanner(),
                      const SizedBox(height: 14),
                    ],

                    buildMenuGrid(),
                    const SizedBox(height: 14),
                    buildLogoutButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // builds the top logo and subtitle for the profile page.
  // repeated here so the page matches the other findr screens.
  Widget buildHeading() {
    // a dot on the gear when something is waiting in notifications.
    final int unreadAlerts = ref.watch(unreadNotificationCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Transform.translate(
                offset: const Offset(-25, 0),
                child: const FindrLogo(height: 125),
              ),
            ),
            buildSettingsButton(unreadAlerts),
          ],
        ),
        Text(
          'Manage your account and settings.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: themeColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // bell button that opens the notification inbox.
  // settings is reached from the card in the menu grid below.
  Widget buildSettingsButton(int unreadAlerts) {
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: themeColors.surface.withValues(alpha: 0.94),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 22,
              color: themeColors.textSecondary,
            ),
            if (unreadAlerts > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0415F),
                    shape: BoxShape.circle,
                    border: Border.all(color: themeColors.surface, width: 1.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // builds the profile card with avatar, name and email.
  // firebase gives the photo for google/github users if available.
  Widget buildProfileCard(User? user) {
    String email = user?.email ?? 'Not logged in';
    String name = user?.displayName ?? 'Findr User';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // the photo is set through backgroundImage rather than as a child,
          // because a child is drawn on top of the circle without being
          // clipped to it, which is what made it look square.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [themeColors.accent, themeColors.primary],
              ),
            ),
            child: CircleAvatar(
              radius: 31,
              backgroundColor: themeColors.backgroundAlt,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : const AssetImage('assets/images/default_pfp.jpg')
                        as ImageProvider,
              // the initial shows through only if neither image loads.
              onBackgroundImageError: (_, __) {},
              child: null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: themeColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // builds the lost, found and resolved summary cards.
  // the counts come from the user's own reports in firestore, so they stay
  // in step with what the my reports screen shows.
  Widget buildStatsRow() {
    final myReportsAsync = ref.watch(myReportsProvider);

    // while loading or on error, show dashes instead of wrong numbers.
    final List<ItemReport> reports = myReportsAsync.value ?? <ItemReport>[];
    final bool ready = myReportsAsync.hasValue;

    String count(bool Function(ItemReport) test) {
      if (!ready) {
        return '-';
      }
      return '${reports.where(test).length}';
    }

    return Row(
      children: [
        buildStatCard(
          Icons.work_outline_rounded,
          count((r) => r.reportType == 'Lost'),
          'Lost Posts',
          const Color(0xFFD94084),
          const Color(0xFFFFD0E8),
        ),
        const SizedBox(width: 10),
        buildStatCard(
          Icons.inventory_2_outlined,
          count((r) => r.reportType == 'Found'),
          'Found Posts',
          const Color(0xFF5BA681),
          const Color(0xFFD5FBDD),
        ),
        const SizedBox(width: 10),
        buildStatCard(
          Icons.check_circle_outline,
          count((r) => r.reportStatus == 'resolved'),
          'Resolved',
          themeColors.primary,
          themeColors.surfaceSoft,
        ),
      ],
    );
  }

  // builds one profile stat card.
  // reused for the three counts above.
  Widget buildStatCard(
    IconData icon,
    String count,
    String label,
    Color iconColor,
    Color bgColor,
  ) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: themeColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dark
                    ? iconColor.withValues(alpha: 0.14)
                    : Color.alphaBlend(
                        bgColor.withValues(alpha: 0.5),
                        themeColors.surface,
                      ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: themeColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: themeColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // builds the email verification banner.
  // this only shows for email/password users who are not verified yet.
  Widget buildVerificationBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.orange, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email Not Verified',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: themeColors.textPrimary,
                  ),
                ),
                Text(
                  'Please verify your email address.',
                  style: TextStyle(
                    fontSize: 11,
                    color: themeColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => resendVerification(context),
            child: Text(
              'Resend',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: themeColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // builds the 2 by 2 menu grid.
  // some buttons are part 3 placeholders while auth buttons already work.
  Widget buildMenuGrid() {
    // how many claims are waiting on this user, shown as a badge.
    final int pendingClaims = ref.watch(pendingClaimCountProvider);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: buildMenuCard(
                Icons.how_to_reg_outlined,
                'Claims',
                pendingClaims > 0
                    ? '$pendingClaims waiting for your decision'
                    : 'Claims you sent and received',
                const Color(0xFF7C4DFF),
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ClaimsScreen()),
                  );
                },
                badgeCount: pendingClaims,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildMenuCard(
                Icons.description_outlined,
                'My Reports',
                'View your Lost & Found Reports',
                themeColors.primary,
                () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => MyReportsScreen()));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: buildMenuCard(
                Icons.lock_reset,
                'Change Password',
                'Update your password',
                themeColors.primary,
                () => showChangePasswordDialog(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildMenuCard(
                Icons.settings_outlined,
                'Settings',
                'Notifications, theme and security',
                const Color(0xFF5BA681),
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                badgeCount: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // builds one menu card in the profile grid.
  // the onTap is passed in so each card can do something different.
  Widget buildMenuCard(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
    VoidCallback onTap, {
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),

                // red counter shown when something needs attention.
                if (badgeCount > 0) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0415F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: themeColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: themeColors.textSecondary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: themeColors.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // builds the logout button at the bottom.
  // this is kept separate because it has a different red style.
  Widget buildLogoutButton() {
    return GestureDetector(
      onTap: () => logout(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, size: 20, color: Colors.red),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sign out of your account',
                    style: TextStyle(
                      fontSize: 11,
                      color: themeColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.red[300]),
          ],
        ),
      ),
    );
  }
}
