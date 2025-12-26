import 'package:flutter/material.dart';
import 'screens/patients.dart';
import 'screens/appointments.dart';
import 'screens/receipts.dart';
import 'widgets/sidebar.dart';
import 'theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chiropractic App',
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

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    PatientsScreen(),
    AppointmentsScreen(),
    ReceiptsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chiropractic App'),
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
