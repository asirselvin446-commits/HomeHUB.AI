import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';



/// Global navigator key for accessing context from FCM handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);



  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const HomeHubApp());
}

class HomeHubApp extends StatefulWidget {
  const HomeHubApp({super.key});

  @override
  State<HomeHubApp> createState() => _HomeHubAppState();
}

class _HomeHubAppState extends State<HomeHubApp> with WidgetsBindingObserver {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize services
    _appState.init().then((_) async {
      await NotificationService.instance.init();
      await NotificationService.instance.requestPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
  }



  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
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
    if (!appState.isInitialized || appState.isLoadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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

