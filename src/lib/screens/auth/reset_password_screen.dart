import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/services/firebase_service.dart';
import 'package:findr_application/screens/auth/auth_widgets.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/theme/app_theme.dart';

// screen for when the user forgets their password.
// user enters email and firebase sends them a reset password link.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  static String routeName = '/reset';

  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  String? email;
  final form = GlobalKey<FormState>();

  String? errorMessage;
  bool emailSent = false;

  // sends the password reset email using firebase.
  // if it works, the screen changes from the form to the success message.
  Future<void> reset(BuildContext context) async {
    setState(() {
      errorMessage = null;
    });

    bool isValid = form.currentState!.validate();

    if (isValid) {
      form.currentState!.save();

      try {
        FirebaseService firebaseService = ref.read(firebaseServiceProvider);

        await firebaseService.forgotPassword(email!);

        FocusScope.of(context).unfocus();

        setState(() {
          emailSent = true;
        });
      } on FirebaseAuthException catch (e) {
        setState(() {
          errorMessage = _friendlyError(e.code);
        });
      }
    }
  }

  // changes firebase error codes into cleaner messages.
  // this makes it easier for the user to understand what went wrong.
  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return 'Failed to send reset email: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthHeading(),

          emailSent ? buildSuccessCard(context) : buildFormCard(context),
        ],
      ),
    );
  }

  // this builds the form where the user enters their email.
  // it also shows the error banner if firebase gives an error.
  Widget buildFormCard(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return AuthCard(
      children: [
        Text(
          'Password reset',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'You will receive instructions for resetting your password.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),

        const SizedBox(height: 20),

        if (errorMessage != null) ...[
          AuthErrorBanner(message: errorMessage!),
          const SizedBox(height: 14),
        ],

        Form(
          key: form,
          child: TextFormField(
            keyboardType: TextInputType.emailAddress,
            decoration: authInputDecoration(
              context,
              'Your email address',
              Icons.email_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }

              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email';
              }

              return null;
            },
            onSaved: (value) {
              email = value!.trim();
            },
          ),
        ),

        const SizedBox(height: 20),

        AuthPrimaryButton(
          label: 'SEND',
          icon: Icons.email_outlined,
          onTap: () {
            reset(context);
          },
        ),

        const SizedBox(height: 14),

        Center(
          child: AppBackAction(
            label: 'Back to Login',
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }

  // this builds the success screen after the reset email is sent.
  // it replaces the form so the user clearly knows the action worked.
  Widget buildSuccessCard(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return AuthCard(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 48,
              color: colors.primary,
            ),
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: Text(
            'Email sent!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ),

        const SizedBox(height: 10),

        Center(
          child: Text(
            'We sent a password reset link to:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
        ),

        const SizedBox(height: 4),

        Center(
          child: Text(
            email ?? '',
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
            'Click the link in the email to reset your password. Check your spam folder if you don\'t see it.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: AppBackAction(
            label: 'Back to Login',
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}
