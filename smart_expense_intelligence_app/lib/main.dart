import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const SmartExpenseApp());
}

class SmartExpenseApp extends StatelessWidget {
  const SmartExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Expense Intelligence',
      theme: ThemeData(
        brightness: Brightness.light, // Restored to Light
        primaryColor: const Color(0xFF006064),
        scaffoldBackgroundColor: Colors.grey[100], // Your original light grey
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
