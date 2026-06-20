import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/services/notification_service.dart';
import 'data/services/offline_cache_service.dart';
import 'data/services/connectivity_service.dart';
import 'data/services/revenuecat_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/shared/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp();

  // Hive offline cache
  await OfflineCacheService.initialize();

  // Connectivity
  await ConnectivityService().initialize();

  // FCM notifikacije
  await NotificationService().initialize();

  // Status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;

  // RevenueCat se inicijalizuje nakon što user bude poznat (u AuthProvider)
  // Ovdje samo inicijalizujemo SDK

  runApp(ShiftioApp(initialDarkMode: isDark));
}

class ShiftioApp extends StatefulWidget {
  final bool initialDarkMode;

  const ShiftioApp({super.key, this.initialDarkMode = false});

  @override
  State<ShiftioApp> createState() => _ShiftioAppState();

  static _ShiftioAppState of(BuildContext context) {
    return context.findAncestorStateOfType<_ShiftioAppState>()!;
  }
}

class _ShiftioAppState extends State<ShiftioApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() async {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _themeMode == ThemeMode.dark);
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Shiftio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        home: const SplashScreen(),
      ),
    );
  }
}
