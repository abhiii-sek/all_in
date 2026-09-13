import 'package:flutter/material.dart';
import 'screens/saved_designs_launcher_screen.dart';
import 'services/design_option_manager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesignOptionManagerService.init();
  runApp(const BuildMateApp());
}

class BuildMateApp extends StatelessWidget {
  const BuildMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeCraft OS • 2D Architectural CAD Floor Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF0F172A),
          onSurface: Colors.white,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF0F172A),
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const SavedDesignsLauncherScreen(),
    );
  }
}
