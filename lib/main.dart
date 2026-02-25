import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_colors.dart';
import 'firebase_options.dart';
import 'screens/splash.dart';
import 'screens/login.dart';
import 'screens/register.dart';
import 'screens/home.dart';
import 'screens/income.dart';
import 'screens/deductions.dart';
import 'screens/regime_compare.dart';
import 'screens/gst_calculator.dart';
import 'screens/capital_gains.dart';
import 'screens/ai_advice.dart';
import 'screens/summary.dart';
import 'screens/profile_edit.dart';
import 'screens/recommendations.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.widgetBackground,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.text,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: AppColors.widgetBackground,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: AppColors.primaryVeryLight,
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
        '/capital_gains': (_) => const CapitalGainsScreen(),
        '/gst_calculator': (_) => const GSTCalculator(),
        '/regime_compare': (_) => const RegimeCompareScreen(),
        '/summary': (_) => const SummaryScreen(),
        '/profile': (_) => const ProfileEditScreen(),
        '/recommendations': (_) => const RecommendationsScreen(),
        '/ai_advice': (_) => const AiAdviceScreen(),
      },
    );
  }
}
