import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/services/firebase_service.dart';
import 'package:findr_application/screens/auth/auth_widgets.dart';
import 'package:findr_application/screens/auth/email_verification_screen.dart';
import 'package:findr_application/theme/app_theme.dart';

// signup screen for creating a new account.
// it supports email/password signup and also social signup with google/github.
class SignupScreen extends ConsumerStatefulWidget {
  static String routeName = '/signup';

  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  String? fullName;
  String? email;
  String? phone;
  String? password;
  String? confirmPassword;
  var form = GlobalKey<FormState>();

  bool obscurePassword = true;
  bool obscureConfirm = true;
  String? errorMessage;

  // handles normal email/password registration.
  // it validates the form, checks password match, creates the account and sends verification email.
  Future<void> register(BuildContext context) async {
    setState(() {
      errorMessage = null;
    });

    bool isValid = form.currentState!.validate();

    if (isValid) {
      form.currentState!.save();

      if (password != confirmPassword) {
        setState(() {
          errorMessage = 'Password and Confirm Password do not match.';
        });
        return;
      }

      try {
        FirebaseService firebaseService = ref.read(firebaseServiceProvider);

        await firebaseService.register(email!, password!);

        await firebaseService.sendEmailVerification();

        FocusScope.of(context).unfocus();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(email: email!),
          ),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          errorMessage = _friendlyError(e.code);
        });
      } catch (e) {
        setState(() {
          errorMessage = 'An error occurred. Please try again.';
        });
      }
    }
  }

  // handles social signup using google or github.
  // mode decides which provider to use so both buttons can reuse this function.
  Future<void> signUpWithSocial(BuildContext context, String mode) async {
    setState(() {
      errorMessage = null;
    });

    try {
      FirebaseService firebaseService = ref.read(firebaseServiceProvider);

      if (mode == 'google') {
        await firebaseService.signInWithGoogle();
      } else {
        await firebaseService.signInWithGitHub();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = _friendlyError(e.code);
      });
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred. Please try again.';
      });
    }
  }

  // changes firebase error codes into nicer messages.
  // this makes the signup errors easier to understand.
  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      default:
        return 'Sign up failed: $code';
    }
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
              Text(
                'Create account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Sign up to get started',
                style: TextStyle(fontSize: 15, color: colors.textSecondary),
              ),

              const SizedBox(height: 20),

              // shows error inside the card if signup fails.
              if (errorMessage != null) ...[
                AuthErrorBanner(message: errorMessage!),
                const SizedBox(height: 14),
              ],

              // form fields for the user's signup details.
              Form(
                key: form,
                child: Column(
                  children: [
                    TextFormField(
                      keyboardType: TextInputType.name,
                      decoration: authInputDecoration(
                        context,
                        'Full name',
                        Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }

                        return null;
                      },
                      onSaved: (value) {
                        fullName = value!.trim();
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: authInputDecoration(
                        context,
                        'Email address',
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

                    const SizedBox(height: 14),

                    TextFormField(
                      keyboardType: TextInputType.phone,
                      decoration: authInputDecoration(
                        context,
                        'Phone number',
                        Icons.phone_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }

                        if (value.trim().length < 8) {
                          return 'Please enter a valid phone number';
                        }

                        return null;
                      },
                      onSaved: (value) {
                        phone = value!.trim();
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      obscureText: obscurePassword,
                      decoration:
                          authInputDecoration(
                            context,
                            'Password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: colors.muted,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }

                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }

                        return null;
                      },
                      onSaved: (value) {
                        password = value!;
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      obscureText: obscureConfirm,
                      decoration:
                          authInputDecoration(
                            context,
                            'Confirm password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: colors.muted,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscureConfirm = !obscureConfirm;
                                });
                              },
                            ),
                          ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }

                        return null;
                      },
                      onSaved: (value) {
                        confirmPassword = value!;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // main signup button for email/password account creation.
              AuthPrimaryButton(
                label: 'Sign up',
                onTap: () {
                  register(context);
                },
              ),

              const SizedBox(height: 18),

              const AuthDivider(),

              const SizedBox(height: 16),

              // social signup buttons.
              AuthSocialButton(
                label: 'Sign up with Google',
                imagePath: 'assets/images/google.png',
                fallbackIcon: Icons.g_mobiledata,
                onTap: () {
                  signUpWithSocial(context, 'google');
                },
              ),

              const SizedBox(height: 12),

              AuthSocialButton(
                label: 'Sign up with GitHub',
                imagePath: 'assets/images/github.png',
                fallbackIcon: Icons.code,
                onTap: () {
                  signUpWithSocial(context, 'github');
                },
              ),

              const SizedBox(height: 18),

              // link back to login screen.
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Log in',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
