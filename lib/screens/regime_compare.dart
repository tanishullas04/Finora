import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class RegimeCompareScreen extends StatefulWidget {
  const RegimeCompareScreen({super.key});

  @override
  State<RegimeCompareScreen> createState() => _RegimeCompareScreenState();
}

class _RegimeCompareScreenState extends State<RegimeCompareScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _loading = true;
  String _error = '';
  double _oldRegimeTax = 0;
  double _newRegimeTax = 0;
  double _totalIncome = 0;
  double _totalDeductions = 0;

  @override
  void initState() {
    super.initState();
    _loadAndCalculate();
  }

  Future<void> _loadAndCalculate() async {
    try {
      // Fetch income data
      final incomeData = await _firebaseService.getIncome();
      final income = ((incomeData?['salary'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((incomeData?['otherIncome'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((incomeData?['rentalIncome'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((incomeData?['businessIncome'] ?? 0.0) as num? ?? 0.0).toDouble();

      // Fetch deductions
      final deductionsData = await _firebaseService.getDeductions();
      final deductions = ((deductionsData?['section80c'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((deductionsData?['section80d'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((deductionsData?['section80ccd'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((deductionsData?['section24'] ?? 0.0) as num? ?? 0.0).toDouble();

      // Calculate taxes (pass deductions to old regime calculation)
      final oldRegimeTax = _calculateOldRegimeTax(income, deductions);
      final newRegimeTax = _calculateNewRegimeTax(income);

      setState(() {
        _totalIncome = income;
        _totalDeductions = deductions;
        _oldRegimeTax = oldRegimeTax;
        _newRegimeTax = newRegimeTax;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _loading = false;
      });
    }
  }

  double _calculateOldRegimeTax(double income, double deductions) {
    // Old Regime: Apply all deductions
    // Taxable income after standard deduction (₹50,000) and other deductions
    double taxableIncome = (income - 50000 - deductions).clamp(0, double.infinity);
    
    double tax = 0;
    
    // Old Regime Tax Slabs (FY 2024-25)
    if (taxableIncome > 1000000) {
      tax += (taxableIncome - 1000000) * 0.30;
      taxableIncome = 1000000;
    }
    if (taxableIncome > 500000) {
      tax += (taxableIncome - 500000) * 0.20;
      taxableIncome = 500000;
    }
    if (taxableIncome > 250000) {
      tax += (taxableIncome - 250000) * 0.10;
      taxableIncome = 250000;
    }
    // 0-250000 is 0% in old regime for individuals
    
    // Surcharge (progressive based on income)
    double surcharge = 0;
    if (income > 5000000) surcharge = tax * 0.25;
    else if (income > 1000000) surcharge = tax * 0.15;
    else if (income > 500000) surcharge = tax * 0.10;
    
    // Health and Education Cess: 4% on (tax + surcharge)
    double cess = (tax + surcharge) * 0.04;
    
    return tax + surcharge + cess;
  }

  double _calculateNewRegimeTax(double income) {
    // New Regime: NO deductions allowed
    // Standard deduction: ₹0 for FY 2024-25 (removed)
    double taxableIncome = income.clamp(0, double.infinity);
    
    double tax = 0;
    
    // New Regime Tax Slabs (FY 2024-25) - More favorable rates
    if (taxableIncome > 1500000) {
      tax += (taxableIncome - 1500000) * 0.30;
      taxableIncome = 1500000;
    }
    if (taxableIncome > 1000000) {
      tax += (taxableIncome - 1000000) * 0.20;
      taxableIncome = 1000000;
    }
    if (taxableIncome > 500000) {
      tax += (taxableIncome - 500000) * 0.15;
      taxableIncome = 500000;
    }
    if (taxableIncome > 250000) {
      tax += (taxableIncome - 250000) * 0.05;
      taxableIncome = 250000;
    }
    // 0-250000 is 0% in new regime
    
    // Surcharge (same as old regime, progressive based on income)
    double surcharge = 0;
    if (income > 5000000) surcharge = tax * 0.25;
    else if (income > 1000000) surcharge = tax * 0.15;
    else if (income > 500000) surcharge = tax * 0.10;
    
    // Health and Education Cess: 4% on (tax + surcharge)
    double cess = (tax + surcharge) * 0.04;
    
    return tax + surcharge + cess;
  }

  Widget _regimeCard(String title, String tax, Color color, List<String> bullets) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Estimated Tax: $tax", style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...bullets.map((b) => Row(children: [const Icon(Icons.check, size: 16), const SizedBox(width: 6), Expanded(child: Text(b))])).toList(),
      ]),
    );
  }

  String _formatCurrency(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Regime Comparison", style: TextStyle(color: Colors.white, fontSize: 27))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Regime Comparison", style: TextStyle(color: Colors.white, fontSize: 27))),
        body: Center(child: Text(_error)),
      );
    }

    double savings = (_oldRegimeTax - _newRegimeTax).abs();
    String recommendation = _oldRegimeTax > _newRegimeTax
        ? '✔ New Regime saves you ${_formatCurrency(savings)}'
        : '✔ Old Regime saves you ${_formatCurrency(savings)}';

    return Scaffold(
      appBar: AppBar(title: const Text("Regime Comparison", style: TextStyle(color: Colors.white, fontSize: 27))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text("Total Income: ${_formatCurrency(_totalIncome)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text("Total Deductions: ${_formatCurrency(_totalDeductions)}", style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _regimeCard(
                "Old Regime",
                _formatCurrency(_oldRegimeTax),
                Colors.indigo.shade50,
                [
                  "Deductions allowed",
                  "Standard: ₹50,000",
                  "Sections 80C, 80D, 24",
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _regimeCard(
                "New Regime",
                _formatCurrency(_newRegimeTax),
                Colors.green.shade50,
                [
                  "Lower tax slabs",
                  "Standard: ₹50,000",
                  "Limited deductions",
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(12)),
            child: Text(recommendation, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/gst'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const SizedBox(width: double.infinity, child: Center(child: Text("Next"))),
          ),
        ]),
      ),
    );
  }
}
