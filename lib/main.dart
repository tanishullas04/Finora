import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash.dart';
import 'screens/login.dart';
import 'screens/register.dart';
import 'screens/home.dart';
import 'screens/income.dart';
import 'screens/deductions.dart';
import 'screens/regime_compare.dart';
import 'screens/gst.dart';
import 'screens/capital_gains.dart';
import 'screens/ai_advice.dart';
import 'screens/summary.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TaxApp());
}

class TaxApp extends StatelessWidget {
  const TaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: Colors.grey.shade500,
        appBarTheme: AppBarTheme(centerTitle: true, elevation: 0, backgroundColor: Colors.grey.shade500),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.indigo.withOpacity(0.04),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        }),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomeScreen(),
        '/income': (_) => const IncomeScreen(),
        '/deductions': (_) => const DeductionsScreen(),
        '/regime_compare': (_) => const RegimeCompareScreen(),
        '/gst': (_) => const GSTScreen(),
        '/capital_gains': (_) => const CapitalGainsScreen(),
        '/ai_advice': (_) => const AiAdviceScreen(),
        '/summary': (_) => const SummaryScreen(),
      },
    );
  }
}
