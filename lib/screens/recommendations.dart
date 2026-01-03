import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _analyzeAndGenerateRecommendations();
  }

  Future<void> _analyzeAndGenerateRecommendations() async {
    try {
      final incomeData = await _firebaseService.getIncome();
      final deductionsData = await _firebaseService.getDeductions();
      final cgData = await _firebaseService.getCapitalGains();
      final gstData = await _firebaseService.getGST();

      List<Map<String, dynamic>> recommendations = [];

      // Parse data
      double salary = ((incomeData?['salary'] ?? 0.0) as num? ?? 0.0).toDouble();
      double section80c = ((deductionsData?['section80c'] ?? 0.0) as num? ?? 0.0).toDouble();
      double section80d = ((deductionsData?['section80d'] ?? 0.0) as num? ?? 0.0).toDouble();
      
      double stcgTotal = ((cgData?['totalSTCG'] ?? 0.0) as num? ?? 0.0).toDouble();
      double ltcgStocks = ((cgData?['ltcgStocks'] ?? 0.0) as num? ?? 0.0).toDouble();
      double gstTax = ((gstData?['totalGSTTax'] ?? 0.0) as num? ?? 0.0).toDouble();
      double itcAmount = ((gstData?['itcAmount'] ?? 0.0) as num? ?? 0.0).toDouble();

      // Recommendation 1: 80C Optimization
      double max80c = 150000;
      double unused80c = max80c - section80c;
      if (unused80c > 0) {
        double savings = unused80c * 0.20; // 20% tax bracket estimate
        recommendations.add({
          'priority': 'HIGH',
          'title': 'Maximize Section 80C Deduction',
          'description': 'You can invest ₹${unused80c.toStringAsFixed(0)} more in 80C (ELSS, PPF, etc.)',
          'savings': savings,
          'color': Colors.red,
          'action': 'Invest in ELSS/PPF',
        });
      }

      // Recommendation 2: 80D (Health Insurance)
      double max80d = 100000;
      double unused80d = max80d - section80d;
      if (unused80d > 25000) {
        double savings = unused80d * 0.20;
        recommendations.add({
          'priority': 'MEDIUM',
          'title': 'Increase Health Insurance (80D)',
          'description': 'You can increase health insurance by ₹${unused80d.toStringAsFixed(0)}',
          'savings': savings,
          'color': Colors.orange,
          'action': 'Increase Coverage',
        });
      }

      // Recommendation 3: STCG Timing
      if (stcgTotal > 0) {
        recommendations.add({
          'priority': 'MEDIUM',
          'title': 'Optimize Short-term Capital Gains',
          'description': 'You have ₹${stcgTotal.toStringAsFixed(0)} in STCG. Consider timing to next FY to split income.',
          'savings': stcgTotal * 0.10, // Estimate 10% savings from timing
          'color': Colors.orange,
          'action': 'Plan Next FY Strategy',
        });
      }

      // Recommendation 4: LTCG Strategy
      if (ltcgStocks > 0) {
        recommendations.add({
          'priority': 'LOW',
          'title': 'Leverage LTCG Tax Exemption',
          'description': 'Your LTCG stocks are 0% tax-exempt! ₹${ltcgStocks.toStringAsFixed(0)} saved from taxation.',
          'savings': ltcgStocks * 0.20, // Potential 0% vs 20% for normal assets
          'color': Colors.green,
          'action': 'Great! No Action Needed',
        });
      }

      // Recommendation 5: GST ITC
      if (gstTax > 0 && itcAmount < gstTax * 0.3) {
        double potentialITC = gstTax * 0.3;
        double savings = potentialITC - itcAmount;
        recommendations.add({
          'priority': 'MEDIUM',
          'title': 'Maximize GST Input Tax Credit',
          'description': 'You can claim up to ₹${potentialITC.toStringAsFixed(0)} as ITC. Currently claiming ₹${itcAmount.toStringAsFixed(0)}',
          'savings': savings,
          'color': Colors.orange,
          'action': 'Collect Input Invoices',
        });
      }

      // Recommendation 6: Income Splitting
      if (salary > 5000000) {
        double surcharge = (salary - 5000000) * 0.25 * 0.30; // 25% surcharge on 30% tax
        recommendations.add({
          'priority': 'HIGH',
          'title': 'Consider Spouse Income Splitting',
          'description': 'Your income exceeds ₹50L. Splitting with spouse can reduce surcharge.',
          'savings': surcharge,
          'color': Colors.red,
          'action': 'Consult CA',
        });
      }

      // Recommendation 7: HRA/LTA Planning
      if (salary > 1000000 && deductionsData?['section10'] == null) {
        recommendations.add({
          'priority': 'HIGH',
          'title': 'Claim HRA/LTA Benefits',
          'description': 'You may be eligible for HRA/LTA deductions. Verify with your employer.',
          'savings': 50000, // Estimate
          'color': Colors.red,
          'action': 'Check with HR',
        });
      }

      // Sort by priority
      recommendations.sort((a, b) {
        Map<String, int> priorityMap = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2};
        return priorityMap[a['priority']]!.compareTo(priorityMap[b['priority']]!);
      });

      setState(() {
        _recommendations = recommendations;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _formatCurrency(double value) {
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L';
    }
    return '₹${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Recommendations', style: TextStyle(color: Colors.white, fontSize: 27)),
        backgroundColor: Colors.deepPurple,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _recommendations.isEmpty
              ? const Center(
                  child: Text('No recommendations at this time. Great tax planning!'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb, color: Colors.deepPurple, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Total Potential Savings: ${_formatCurrency(_recommendations.fold(0.0, (sum, r) => sum + (r['savings'] ?? 0)))}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._recommendations.map((rec) => _buildRecommendationCard(rec)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> rec) {
    String priorityEmoji = rec['priority'] == 'HIGH'
        ? '🔴'
        : rec['priority'] == 'MEDIUM'
            ? '🟡'
            : '🟢';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(priorityEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Priority: ${rec['priority']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Save ${_formatCurrency(rec['savings'] ?? 0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              rec['description'],
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Action: ${rec['action']}')),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: rec['color'],
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  rec['action'],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
