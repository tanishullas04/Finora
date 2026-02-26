import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> features = const [
    {"title": "Income", "route": "/income", "icon": Icons.attach_money},
    {"title": "Deductions", "route": "/deductions", "icon": Icons.receipt_long},
    {
      "title": "Capital Gains",
      "route": "/capital_gains",
      "icon": Icons.trending_up,
    },
    {
      "title": "GST Calculator",
      "route": "/gst_calculator",
      "icon": Icons.calculate,
    },
    {"title": "AI Advisor", "route": "/ai_advice", "icon": Icons.smart_toy},
    {
      "title": "Understanding Tax",
      "route": "/understanding_tax",
      "icon": Icons.school,
    },
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start fade-in animation
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Welcome back, $displayName 👋",
            style: const TextStyle(
              color: AppColors.widgetBackground,
              fontSize: 22,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.pushNamed(context, '/summary'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(14),
          child: GridView.builder(
            itemCount: features.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              childAspectRatio: 1,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final f = features[index];
              return TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 350 + 40),
                builder: (context, double scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pushNamed(context, f['route']),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(f['icon'], size: 42, color: AppColors.primary),
                          const SizedBox(height: 10),
                          Text(
                            f['title'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
