import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/firebase_service.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _loading = true;
  String _error = '';
  
  double _totalIncome = 0;
  double _totalDeductions = 0;
  double _totalCapitalGains = 0;
  double _stcgTotal = 0;
  double _ltcgTax = 0;
  double _totalGSTTax = 0;
  double _oldRegimeTax = 0;
  double _newRegimeTax = 0;
  String _bestRegime = '';
  double _savings = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Fetch all data
      final incomeData = await _firebaseService.getIncome();
      final deductionsData = await _firebaseService.getDeductions();
      final cgData = await _firebaseService.getCapitalGains();
      final gstData = await _firebaseService.getGST();

      // Parse income
      double income = ((incomeData?['salary'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((incomeData?['otherIncome'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((incomeData?['rentalIncome'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((incomeData?['businessIncome'] ?? 0.0) as num? ?? 0.0).toDouble();

      // Parse deductions
      double deductions = ((deductionsData?['section80c'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((deductionsData?['section80d'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((deductionsData?['section80ccd'] ?? 0.0) as num? ?? 0.0).toDouble() +
          ((deductionsData?['section24'] ?? 0.0) as num? ?? 0.0).toDouble();

      // Parse capital gains
      double stcgTotal = ((cgData?['totalSTCG'] ?? 0.0) as num? ?? 0.0).toDouble();
      double ltcgRealEstate = ((cgData?['ltcgRealEstate'] ?? 0.0) as num? ?? 0.0).toDouble();
      double ltcgStocks = ((cgData?['ltcgStocks'] ?? 0.0) as num? ?? 0.0).toDouble();
      double ltcgMutualFunds = ((cgData?['ltcgMutualFunds'] ?? 0.0) as num? ?? 0.0).toDouble();
      double ltcgOther = ((cgData?['ltcgOther'] ?? 0.0) as num? ?? 0.0).toDouble();

      // Parse GST
      double gstTax = ((gstData?['totalGSTTax'] ?? 0.0) as num? ?? 0.0).toDouble();

      // Calculate taxes
      double totalIncome = income + stcgTotal;
      double taxableIncome = totalIncome - deductions;
      
      // Old Regime Tax Calculation
      double oldRegimeTax = _calculateOldRegimeTax(taxableIncome);
      
      // New Regime Tax Calculation
      double newRegimeTax = _calculateNewRegimeTax(totalIncome);

      // Calculate LTCG tax
      double ltcgTax = _calculateLTCGTax(ltcgRealEstate, ltcgStocks, ltcgMutualFunds, ltcgOther, totalIncome);

      // Total with LTCG and GST
      double oldTotal = oldRegimeTax + ltcgTax + gstTax;
      double newTotal = newRegimeTax + ltcgTax + gstTax;

      setState(() {
        _totalIncome = income;
        _totalDeductions = deductions;
        _totalCapitalGains = stcgTotal + ltcgRealEstate + ltcgStocks + ltcgMutualFunds + ltcgOther;
        _stcgTotal = stcgTotal;
        _ltcgTax = ltcgTax;
        _totalGSTTax = gstTax;
        _oldRegimeTax = oldTotal;
        _newRegimeTax = newTotal;
        _bestRegime = oldTotal > newTotal ? 'New Regime' : 'Old Regime';
        _savings = (oldTotal - newTotal).abs();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _loading = false;
      });
    }
  }

  double _calculateOldRegimeTax(double taxableIncome) {
    if (taxableIncome <= 250000) return 0;
    if (taxableIncome <= 500000) return (taxableIncome - 250000) * 0.05;
    if (taxableIncome <= 1000000) return 12500 + (taxableIncome - 500000) * 0.20;
    if (taxableIncome <= 1500000) return 112500 + (taxableIncome - 1000000) * 0.30;
    return 262500 + (taxableIncome - 1500000) * 0.30;
  }

  double _calculateNewRegimeTax(double taxableIncome) {
    if (taxableIncome <= 300000) return 0;
    if (taxableIncome <= 600000) return (taxableIncome - 300000) * 0.05;
    if (taxableIncome <= 900000) return 15000 + (taxableIncome - 600000) * 0.10;
    if (taxableIncome <= 1200000) return 45000 + (taxableIncome - 900000) * 0.15;
    if (taxableIncome <= 1500000) return 90000 + (taxableIncome - 1200000) * 0.20;
    return 150000 + (taxableIncome - 1500000) * 0.30;
  }

  double _calculateLTCGTax(double ltcgRealEstate, double ltcgStocks, double ltcgMutualFunds, double ltcgOther, double totalIncome) {
    double ltcgTax = 0;
    
    if (ltcgRealEstate > 0) {
      double tax = ltcgRealEstate * 0.20;
      double surcharge = 0;
      if (totalIncome > 5000000) surcharge = tax * 0.25;
      else if (totalIncome > 1000000) surcharge = tax * 0.15;
      else if (totalIncome > 500000) surcharge = tax * 0.10;
      double cess = (tax + surcharge) * 0.04;
      ltcgTax += tax + surcharge + cess;
    }
    
    if (ltcgMutualFunds > 0) {
      double tax = ltcgMutualFunds * 0.15;
      double surcharge = 0;
      if (totalIncome > 5000000) surcharge = tax * 0.25;
      else if (totalIncome > 1000000) surcharge = tax * 0.15;
      else if (totalIncome > 500000) surcharge = tax * 0.10;
      double cess = (tax + surcharge) * 0.04;
      ltcgTax += tax + surcharge + cess;
    }
    
    if (ltcgOther > 0) {
      double tax = ltcgOther * 0.20;
      double surcharge = 0;
      if (totalIncome > 5000000) surcharge = tax * 0.25;
      else if (totalIncome > 1000000) surcharge = tax * 0.15;
      else if (totalIncome > 500000) surcharge = tax * 0.10;
      double cess = (tax + surcharge) * 0.04;
      ltcgTax += tax + surcharge + cess;
    }
    
    return ltcgTax;
  }

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)}Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L';
    }
    return '₹${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tax Summary", style: TextStyle(color: Colors.white, fontSize: 27))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Lottie.asset('assets/lottie/success.json', height: 120),
                        const SizedBox(height: 16),
                        
                        // Income Breakdown
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Income Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                ListTile(title: const Text('Salary & Other Income'), trailing: Text(_formatCurrency(_totalIncome))),
                                ListTile(title: const Text('STCG (Short-term Gains)'), trailing: Text(_formatCurrency(_stcgTotal))),
                                ListTile(title: const Text('Total Income'), trailing: Text(_formatCurrency(_totalIncome + _stcgTotal), style: const TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                        ),

                        // Deductions & Capital Gains
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Deductions & Capital Gains', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                ListTile(title: const Text('Deductions (80C/80D/24)'), trailing: Text(_formatCurrency(_totalDeductions))),
                                ListTile(title: const Text('LTCG Tax'), trailing: Text(_formatCurrency(_ltcgTax))),
                                ListTile(title: const Text('GST Tax'), trailing: Text(_formatCurrency(_totalGSTTax))),
                              ],
                            ),
                          ),
                        ),

                        // Regime Comparison
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tax Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text('Old Regime', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Text(_formatCurrency(_oldRegimeTax), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text('New Regime', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Text(_formatCurrency(_newRegimeTax), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Best: $_bestRegime\nSavings: ${_formatCurrency(_savings)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Action Buttons
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, '/recommendations'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const SizedBox(width: double.infinity, child: Center(child: Text('View Recommendations', style: TextStyle(color: Colors.white)))),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF Export Coming Soon"))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const SizedBox(width: double.infinity, child: Center(child: Text('Export PDF', style: TextStyle(color: Colors.white)))),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
