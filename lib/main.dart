import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/patients.dart';
import 'screens/appointments.dart';
import 'screens/metrics.dart';
import 'screens/settings.dart';
import 'widgets/sidebar.dart';
import 'theme/app_theme.dart';
import 'utils/backup_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } catch (e) {
    debugPrint('SQLite init error: $e');
  }

  try {
    // Initialize window manager for close intercept
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
  } catch (e) {
    debugPrint('Window manager error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChiroTrack',
      theme: AppTheme.buildLightTheme(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    PatientsScreen(),
    AppointmentsScreen(),
    MetricsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    try {
      windowManager.addListener(this);
    } catch (e) {
      debugPrint('Window listener error: $e');
    }
  }

  @override
  void dispose() {
    try {
      windowManager.removeListener(this);
    } catch (e) {
      debugPrint('Window dispose error: $e');
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    try {
      // Perform auto-backup before closing
      await BackupHelper.autoBackup();
      await windowManager.destroy();
    } catch (e) {
      debugPrint('Window close error: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChiroTrack'),
      ),
      body: Row(
        children: <Widget>[
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemTapped: _onItemTapped,
          ),
          Expanded(
            child: _widgetOptions.elementAt(_selectedIndex),
          ),
        ],
      ),
    );
  }
}
