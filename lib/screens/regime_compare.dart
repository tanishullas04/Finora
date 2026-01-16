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
  double _totalCapitalGains = 0;
  double _ltcgTax = 0;
  double _totalGSTTax = 0;

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

      // Fetch capital gains data
      final cgData = await _firebaseService.getCapitalGains();
      double stcgTotal = ((cgData?['totalSTCG'] ?? 0.0) as num? ?? 0.0).toDouble();
      double ltcgRealEstate = ((cgData?['ltcgRealEstate'] ?? 0.0) as num? ?? 0.0).toDouble();
      double ltcgStocks = ((cgData?['ltcgStocks'] ?? 0.0) as num? ?? 0.0).toDouble();
      double ltcgMutualFunds = ((cgData?['ltcgMutualFunds'] ?? 0.0) as num? ?? 0.0).toDouble();
      double ltcgOther = ((cgData?['ltcgOther'] ?? 0.0) as num? ?? 0.0).toDouble();

      // Fetch GST data
      final gstData = await _firebaseService.getGST();
      double gstTax = ((gstData?['totalGSTTax'] ?? 0.0) as num? ?? 0.0).toDouble();

      // Total income = Regular income + STCG (added to income) 
      // LTCG is taxed separately
      double totalIncome = income + stcgTotal;
      double ltcgTax = _calculateLTCGTax(ltcgRealEstate, ltcgStocks, ltcgMutualFunds, ltcgOther);

      // Calculate taxes (pass deductions to old regime calculation)
      final oldRegimeTax = _calculateOldRegimeTax(totalIncome, deductions);
      final newRegimeTax = _calculateNewRegimeTax(totalIncome);

      setState(() {
        _totalIncome = totalIncome;
        _totalDeductions = deductions;
        _totalCapitalGains = stcgTotal + ltcgRealEstate + ltcgStocks + ltcgMutualFunds + ltcgOther;
        _ltcgTax = ltcgTax;
        _totalGSTTax = gstTax;
        _oldRegimeTax = oldRegimeTax + ltcgTax; // Add LTCG tax to total
        _newRegimeTax = newRegimeTax + ltcgTax; // Add LTCG tax to total
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _loading = false;
      });
    }
  }

  double _calculateLTCGTax(double ltcgRealEstate, double ltcgStocks, double ltcgMutualFunds, double ltcgOther) {
    double ltcgTax = 0;
    
    // Real Estate LTCG: 20% + Surcharge (progressive) + 4% Cess
    if (ltcgRealEstate > 0) {
      double tax = ltcgRealEstate * 0.20;
      double surcharge = 0;
      if ((_totalIncome + ltcgRealEstate) > 5000000) surcharge = tax * 0.25;
      else if ((_totalIncome + ltcgRealEstate) > 1000000) surcharge = tax * 0.15;
      else if ((_totalIncome + ltcgRealEstate) > 500000) surcharge = tax * 0.10;
      double cess = (tax + surcharge) * 0.04;
      ltcgTax += tax + surcharge + cess;
    }
    
    // Stocks LTCG: 0% (no tax!)
    // ltcgStocks are exempt from tax
    
    // Mutual Funds LTCG: 15% + Surcharge + 4% Cess
    if (ltcgMutualFunds > 0) {
      double tax = ltcgMutualFunds * 0.15;
      double surcharge = 0;
      if ((_totalIncome + ltcgMutualFunds) > 5000000) surcharge = tax * 0.25;
      else if ((_totalIncome + ltcgMutualFunds) > 1000000) surcharge = tax * 0.15;
      else if ((_totalIncome + ltcgMutualFunds) > 500000) surcharge = tax * 0.10;
      double cess = (tax + surcharge) * 0.04;
      ltcgTax += tax + surcharge + cess;
    }
    
    // Other LTCG: 20% + Surcharge + 4% Cess
    if (ltcgOther > 0) {
      double tax = ltcgOther * 0.20;
      double surcharge = 0;
      if ((_totalIncome + ltcgOther) > 5000000) surcharge = tax * 0.25;
      else if ((_totalIncome + ltcgOther) > 1000000) surcharge = tax * 0.15;
      else if ((_totalIncome + ltcgOther) > 500000) surcharge = tax * 0.10;
      double cess = (tax + surcharge) * 0.04;
      ltcgTax += tax + surcharge + cess;
    }
    
    return ltcgTax;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Regime Comparison", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Income breakdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("📊 Income Breakdown", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 8),
                Text("Regular Income: ${_formatCurrency(_totalIncome - _totalCapitalGains + ((_ltcgTax > 0 || _totalCapitalGains > 0) ? 0 : 0))}", 
                    style: const TextStyle(fontSize: 13)),
                if (_totalCapitalGains > 0)
                  Text("Capital Gains: ${_formatCurrency(_totalCapitalGains)}", 
                      style: const TextStyle(fontSize: 13, color: Colors.orange)),
                Text("Total Income: ${_formatCurrency(_totalIncome)}", 
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text("Deductions: ${_formatCurrency(_totalDeductions)}", 
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tax comparison
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
                  if (_ltcgTax > 0) "LTCG: ${_formatCurrency(_ltcgTax)}",
                  if (_totalGSTTax > 0) "GST: ${_formatCurrency(_totalGSTTax)}",
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
                  if (_ltcgTax > 0) "LTCG: ${_formatCurrency(_ltcgTax)}",
                  if (_totalGSTTax > 0) "GST: ${_formatCurrency(_totalGSTTax)}",
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Recommendation
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(12)),
            child: Text(
              _oldRegimeTax > _newRegimeTax
                  ? '✔ New Regime saves you ${_formatCurrency((_oldRegimeTax - _newRegimeTax).abs())}'
                  : '✔ Old Regime saves you ${_formatCurrency((_oldRegimeTax - _newRegimeTax).abs())}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/summary'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const SizedBox(width: double.infinity, child: Center(child: Text("View Summary & Recommendations"))),
          ),
        ]),
      ),
    );
  }
}
