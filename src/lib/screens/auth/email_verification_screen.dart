import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/screens/auth/auth_widgets.dart';
import 'package:findr_application/screens/auth/login_screen.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/theme/app_theme.dart';

// this screen shows after the user signs up with email/password.
// it tells them to check their email and verify before logging in.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool resendSent = false;

  // resends the verification email if the user did not receive it.
  // after sending, it changes resendSent to true so the success banner can show.
  Future<void> resend(BuildContext context) async {
    try {
      await ref.read(firebaseServiceProvider).sendEmailVerification();

      setState(() {
        resendSent = true;
      });
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.code)));
    }
  }

  // checks if the user has verified their email already.
  // if verified, it logs them out and sends them back to login to sign in again.
  Future<void> continueAfterVerification(BuildContext context) async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();

      bool verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

      if (verified) {
        await ref.read(firebaseServiceProvider).logOut();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified! Please log in to continue.'),
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified yet. Please check your inbox.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check verification status.')),
      );
    }
  }

  // logs the user out and brings them back to login.
  // pushAndRemoveUntil clears the old screens so back button wont return here.
  Future<void> backToLogin(BuildContext context) async {
    await ref.read(firebaseServiceProvider).logOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthHeading(),
          AuthCard(
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 48,
                    color: colors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: Text(
                  'Check your inbox',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  'We sent a verification email to:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
              ),

              const SizedBox(height: 4),

              Center(
                child: Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Center(
                child: Text(
                  'Click the link in the email to verify your account before logging in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ),

              const SizedBox(height: 24),

              if (resendSent) ...[
                const AuthSuccessBanner(
                  message: 'Verification email resent! Check your inbox.',
                ),
                const SizedBox(height: 16),
              ],

              AuthPrimaryButton(
                label: "I've verified — Continue",
                icon: Icons.check_circle_outline,
                onTap: () {
                  continueAfterVerification(context);
                },
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: resendSent
                      ? null
                      : () {
                          resend(context);
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    resendSent ? 'Email sent ✓' : 'Resend verification email',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: resendSent ? colors.muted : colors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Center(
                child: AppBackAction(
                  label: 'Back to Login',
                  onTap: () {
                    backToLogin(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
