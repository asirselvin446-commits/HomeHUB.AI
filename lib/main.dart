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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

/// Global navigator key for accessing context from FCM handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notifications
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermission();

  // Setup FCM Background handler
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

class _HomeHubAppState extends State<HomeHubApp> {
  final AppState _appState = AppState()..init();

  @override
  void initState() {
    super.initState();
    _setupFCMListeners();
  }

  void _setupFCMListeners() {
    // Foreground messages — show local notification + add to in-app feed
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      if (message.notification != null) {
        final title = message.notification!.title ?? 'New Message';
        final body = message.notification!.body ?? '';
        final type = message.data['type'] ?? 'chat';

        // Show as local push notification
        NotificationService.instance.showRemoteNotification(
          title: title,
          body: body,
          channel: type == 'chat_message' ? 'chat' : 'general',
        );

        // Also add to in-app notification feed
        String actionRoute = 'chat';
        if (type == 'task_assigned') actionRoute = 'tasks';
        if (type == 'expense_added') actionRoute = 'finance';
        if (type == 'grocery_batch') actionRoute = 'grocery';

        _appState.addNotificationFromExternal(
          title: title,
          body: body,
          type: type == 'chat_message' ? 'chat' : type,
          actionRoute: actionRoute,
        );
      }
    });

    // When app is opened from a notification tap (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened app: ${message.data}');
      // Deep-linking can be handled here in the future
      // based on message.data['type']
    });
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

