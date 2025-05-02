import 'package:flutter/material.dart';
import 'screens/patients.dart';
import 'screens/appointments.dart';
import 'widgets/sidebar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1) Build a Material 3 ColorScheme from a purple seed,
    //    then tweak containers to match Material 2 defaults.
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6200EE),
      brightness: Brightness.light,
    ).copyWith(
      primaryContainer: const Color(0xFF6200EE),
      onPrimaryContainer: Colors.white,
      secondaryContainer: const Color(0xFF03DAC6),
      onSecondaryContainer: Colors.black,
      error: const Color(0xFFB00020),
      onError: Colors.white,
    );

    return MaterialApp(
      title: 'Chiropractic App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: cs,

        // 2) Use the surface color for your scaffold background.
        scaffoldBackgroundColor: cs.surface,

        appBarTheme: AppBarTheme(
          backgroundColor: cs.surface,
          elevation: 0,
          iconTheme: IconThemeData(color: cs.onSurface),
          titleTextStyle: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        textTheme: GoogleFonts.openSansTextTheme().apply(
          bodyColor: cs.onSurface,
          displayColor: cs.onSurface,
        ),

        dataTableTheme: DataTableThemeData(
          // 3) Use MaterialStateProperty, not WidgetStateProperty:
          headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
          headingTextStyle: const TextStyle(fontWeight: FontWeight.w600),
          // 4) Replace deprecated dataRowHeight:
          dataRowMinHeight: 48,
          dataRowMaxHeight: 48,
          horizontalMargin: 24,
          columnSpacing: 32,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[500]!),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
