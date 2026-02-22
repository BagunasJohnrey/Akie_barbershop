import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

// Internal Imports
import 'providers/counter_provider.dart';
import 'screens/login_screen.dart'; 
import 'screens/landing_page.dart'; 
import 'screens/counter_screen.dart'; 

void main() async {
  // Ensure Flutter is fully initialized before starting Supabase
  WidgetsFlutterBinding.ensureInitialized();
  
  // REQUIRED: Connect to your Supabase project
  await Supabase.initialize(
    url: '', 
    anonKey: '',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => CounterProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Akie Barbershop',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'SanFrancisco', // Applied iOS Typography
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        // Ensures smooth iOS-style transitions between screens
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      // Navigation flow: Landing -> Login -> Counter
      initialRoute: '/landing',
      routes: {
        '/landing': (context) => const LandingPage(), 
        '/': (context) => const LoginScreen(),
        '/counter': (context) => const CounterScreen(),
      },
    );
  }
}