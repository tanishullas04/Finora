import 'package:flutter/material.dart';

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
    {"title": "Capital Gains", "route": "/capital_gains", "icon": Icons.trending_up},
    {"title": "GST Calculator", "route": "/gst_calculator", "icon": Icons.calculate},
    {"title": "Regime Compare", "route": "/regime_compare", "icon": Icons.compare_arrows},
    {"title": "AI Advisor", "route": "/ai_advice", "icon": Icons.smart_toy},
    {"title": "Summary", "route": "/summary", "icon": Icons.summarize},
    {"title": "Recommendations", "route": "/recommendations", "icon": Icons.lightbulb},
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        appBar: AppBar(title: const Text("Dashboard", style: TextStyle(color: Colors.white, fontSize: 27))),
        body: Padding(
          padding: const EdgeInsets.all(14),
          child: GridView.builder(
            itemCount: features.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 1, mainAxisSpacing: 16, crossAxisSpacing: 16
            ),
            itemBuilder: (context, index) {
              final f = features[index];
              return TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 350 + 40),
                builder: (context, double scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, f['route']),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(f['icon'], size: 42, color: Colors.indigo),
                        const SizedBox(height: 10),
                        Text(f['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
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
