import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notifications
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermission();

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const HomeHubApp());
}

class HomeHubApp extends StatelessWidget {
  const HomeHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'HomeHub AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: _buildHome(appState),
          );
        },
      ),
    );
  }

  Widget _buildHome(AppState appState) {
    // Not logged in → show auth screen
    if (!appState.isLoggedIn) {
      return AuthScreen();
    }

    // Profile not set up → show profile setup
    if (!appState.isProfileComplete) {
      return ProfileSetupScreen();
    }

    // Logged in but no household → show household setup
    if (!appState.hasHousehold) {
      return HouseholdSetupScreen();
    }

    // Fully set up → show main app
    return HomeShell();
  }
}
