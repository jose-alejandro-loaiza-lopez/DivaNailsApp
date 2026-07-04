import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/database_helper.dart';
import 'screens/services_screen.dart';
import 'screens/appointments/appointments_screen.dart';
import 'screens/manicurists_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_data.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');
  await ThemeService.instance.load();
  runApp(const DivaNailsApp());
}

class DivaNailsApp extends StatefulWidget {
  const DivaNailsApp({super.key});

  @override
  State<DivaNailsApp> createState() => _DivaNailsAppState();
}

class _DivaNailsAppState extends State<DivaNailsApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diva Nails',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ThemeService.instance.seedColor,
          brightness: ThemeService.instance.brightness,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          toolbarHeight: 42,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 58,
          indicatorColor: ThemeService.instance.seedColor.withValues(alpha: 0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          elevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: ThemeService.instance.brightness == Brightness.dark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.08)),
          ),
          margin: EdgeInsets.zero,
        ),
        dialogTheme: DialogThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: const OutlineInputBorder(),
          filled: false,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: const _SplashScreen(),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.backupIfNewDay();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            const Text('Diva Nails', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    AppData.instance.addListener(_onAppDataChanged);
  }

  @override
  void dispose() {
    AppData.instance.removeListener(_onAppDataChanged);
    super.dispose();
  }

  void _onAppDataChanged() {
    if (AppData.instance.navigateToDate != null) {
      setState(() => _currentIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          AppointmentsScreen(),
          ClientsScreen(),
          ServicesScreen(),
          ManicuristsScreen(),
          StatsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          AppData.instance.notifyChanged();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Registro',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa),
            label: 'Servicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Manicuristas',
          ),
          NavigationDestination(
            icon: Icon(Icons.monetization_on_outlined),
            selectedIcon: Icon(Icons.monetization_on),
            label: 'Caja',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
