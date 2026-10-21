import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/firebase_options.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/screens/auth/login_screen.dart';
import 'package:findr_application/screens/auth/biometric_gate.dart';
import 'package:findr_application/providers/notification_provider.dart';
import 'package:findr_application/providers/theme_provider.dart';
import 'package:findr_application/screens/home_screen.dart';
import 'package:findr_application/services/notification_service.dart';
import 'package:findr_application/theme/app_theme.dart';

// starts the app.
// firebase has to be initialised before the app can use login/signup.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // sets up device alerts and asks for permission on android 13 and above.
  await NotificationService.init();

  // Loads appearance before the first frame so the saved theme is shown
  // immediately instead of briefly flashing the default blue theme.
  final ThemePreferences themePreferences = await loadThemePreferences();

  runApp(
    ProviderScope(
      overrides: [
        initialThemePreferencesProvider.overrideWithValue(themePreferences),
      ],
      child: const MyApp(),
    ),
  );
}

// main app widget.
// this sets the app theme and sends the user to auth gate first.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemePreferences preferences = ref.watch(themeControllerProvider);

    return MaterialApp(
      title: 'Findr',
      debugShowCheckedModeBanner: false,
      theme: FindrTheme.build(
        preferences.palette,
        brightness: Brightness.light,
      ),
      darkTheme: FindrTheme.build(
        preferences.palette,
        brightness: Brightness.dark,
      ),
      themeMode: preferences.darkMode ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 260),
      themeAnimationCurve: Curves.easeOutCubic,
      home: const AuthGate(),
    );
  }
}

// this decides whether to show login or home.
// it listens to firebase auth state using riverpod.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  // stops the app from calling logout again and again.
  bool _signingOut = false;

  // checks if the user logged in using google/github.
  // social login accounts are treated as verified.
  bool _isSocialLogin(User user) {
    return user.providerData.any((info) => info.providerId != 'password');
  }

  // logs out users who signed up with email but did not verify yet.
  // this keeps unverified users from entering the home screen.
  Future<void> _signOutUnverified() async {
    if (_signingOut) {
      return;
    }

    _signingOut = true;

    await ref.read(firebaseServiceProvider).logOut();

    if (mounted) {
      setState(() {
        _signingOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // keeps the alert listener alive for as long as the app is open, so new
    // notifications pop on the device as they arrive.
    ref.watch(notificationPopupProvider);

    return authState.when(
      data: (User? user) {
        // no user means they should stay on the login screen.
        if (user == null) {
          return LoginScreen();
        }

        // verified email users and social login users can enter the app.
        if (user.emailVerified || _isSocialLogin(user)) {
          return BiometricGate(
            key: ValueKey<String>('biometric-${user.uid}'),
            userId: user.uid,
            child: const HomeScreen(),
          );
        }

        // logout happens after the screen builds.
        // this avoids doing async firebase work directly inside build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _signOutUnverified();
        });

        // shows loading while the unverified user is being logged out.
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      loading: () {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      error: (err, stack) {
        return const Scaffold(
          body: Center(child: Text('Something went wrong')),
        );
      },
    );
  }
}
