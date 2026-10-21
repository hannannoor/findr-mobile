import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/services/firebase_service.dart';
import 'package:findr_application/screens/auth/auth_widgets.dart';
import 'package:findr_application/screens/auth/signup_screen.dart';
import 'package:findr_application/screens/auth/reset_password_screen.dart';
import 'package:findr_application/screens/home_screen.dart';
import 'package:findr_application/theme/app_theme.dart';

// login screen for email/password and social login.
// this uses ConsumerStatefulWidget so it can use riverpod ref and also update UI with setState.
class LoginScreen extends ConsumerStatefulWidget {
  static String routeName = '/login';

  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? email;
  String? password;
  var form = GlobalKey<FormState>();

  bool obscurePassword = true;
  String? errorMessage;

  // handles login for email, google and github.
  // mode decides which login method to use so i can keep all login logic in one function.
  Future<void> login(BuildContext context, String mode) async {
    setState(() {
      errorMessage = null;
    });

    bool isValid = mode == 'email' ? form.currentState!.validate() : true;

    if (isValid) {
      if (mode == 'email') {
        form.currentState!.save();
      }

      try {
        FirebaseService firebaseService = ref.read(firebaseServiceProvider);

        if (mode == 'google') {
          await firebaseService.signInWithGoogle();
        } else if (mode == 'github') {
          await firebaseService.signInWithGitHub();
        } else {
          await firebaseService.login(email!, password!);

          final user = firebaseService.getCurrentUser();

          if (user != null && !user.emailVerified) {
            await firebaseService.logOut();

            setState(() {
              errorMessage =
                  'Your email is not verified. Please check your inbox and click the verification link before logging in.';
            });

            return;
          }
        }

        FocusScope.of(context).unfocus();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User logged in successfully!')),
        );

        if (!mounted) {
          return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
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

  // changes firebase error codes into nicer messages for the user.
  // this looks cleaner than showing raw firebase codes on the screen.
  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return 'Login failed: $code';
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
                'Welcome back!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Login to continue',
                style: TextStyle(fontSize: 15, color: colors.textSecondary),
              ),

              const SizedBox(height: 22),

              if (errorMessage != null) ...[
                AuthErrorBanner(message: errorMessage!),
                const SizedBox(height: 14),
              ],

              Form(
                key: form,
                child: Column(
                  children: [
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
                          return 'Please enter your password';
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
                  ],
                ),
              ),

              const SizedBox(height: 6),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ResetPasswordScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              AuthPrimaryButton(
                label: 'Login',
                onTap: () {
                  login(context, 'email');
                },
              ),

              const SizedBox(height: 18),

              const AuthDivider(),

              const SizedBox(height: 16),

              AuthSocialButton(
                label: 'Sign in with Google',
                imagePath: 'assets/images/google.png',
                fallbackIcon: Icons.g_mobiledata,
                onTap: () {
                  login(context, 'google');
                },
              ),

              const SizedBox(height: 12),

              AuthSocialButton(
                label: 'Sign in with GitHub',
                imagePath: 'assets/images/github.png',
                fallbackIcon: Icons.code,
                onTap: () {
                  login(context, 'github');
                },
              ),

              const SizedBox(height: 18),

              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SignupScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Sign up',
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
