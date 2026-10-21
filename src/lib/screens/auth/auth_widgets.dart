import 'package:flutter/material.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_page.dart';

// this is a reusable layout for all the auth screens to like keep code concise and easy to manage.
// it gives all auth pages the same background image, safe area, scroll and max width.
class AuthLayout extends StatelessWidget {
  final Widget child;

  const AuthLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SizedBox.expand(
        child: Stack(
          children: [
            const AppPageBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: child,
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

// reusable card layout for auth forms with rounded corners and shadow.
// this is used so login, signup and reset password all have the same card style.
class AuthCard extends StatelessWidget {
  final List<Widget> children;

  const AuthCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// this is the shared heading for the auth screens.
// it shows the findr logo and the small tagline below it.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key});

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(-25, 0),
          child: const FindrLogo(height: 125),
        ),
        Text(
          "Lost Something? Let's find it.",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// reusable input styling for the auth textfields.
// so i dont need to repeat the same border, icon and colour styling for every field.
InputDecoration authInputDecoration(
  BuildContext context,
  String hint,
  IconData icon,
) {
  final FindrColors colors = FindrColors.of(context);

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 14, color: colors.muted),
    prefixIcon: Icon(icon, size: 20, color: colors.muted),
    filled: true,
    fillColor: colors.surfaceSoft,
    contentPadding: const EdgeInsets.symmetric(vertical: 15),
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
      borderSide: BorderSide(color: colors.primary, width: 1.25),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );
}

// reusable main blue button for auth actions like login, signup and continue.
// the icon is optional so i can use it with or without an icon.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        child: icon != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// reusable outlined button for social logins like google and github.
// if the logo image fails to load, it shows the fallback icon instead.
class AuthSocialButton extends StatelessWidget {
  final String label;
  final String imagePath;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  const AuthSocialButton({
    super.key,
    required this.label,
    required this.imagePath,
    required this.fallbackIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);
    final bool tintForDarkMode =
        Theme.of(context).brightness == Brightness.dark &&
        imagePath.endsWith('github.png');

    Widget socialIcon = Image.asset(
      imagePath,
      height: 20,
      width: 20,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallbackIcon, size: 22, color: colors.textSecondary);
      },
    );

    if (tintForDarkMode) {
      socialIcon = ColorFiltered(
        colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
        child: socialIcon,
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            socialIcon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// small divider used between normal login and social login buttons.
// it just makes the auth screen look cleaner.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Row(
      children: [
        Expanded(child: Divider(color: colors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'or continue with',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ),
        Expanded(child: Divider(color: colors.border)),
      ],
    );
  }
}

// red error message box used when login/signup fails.
// this is better than only using snackbar because the message stays visible on the form.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

// green success message box used for things like reset password or email resend.
// same idea as error banner but for successful actions.
class AuthSuccessBanner extends StatelessWidget {
  final String message;

  const AuthSuccessBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.green.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
