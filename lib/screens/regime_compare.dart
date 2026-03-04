import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';

class RegimeCompareScreen extends StatefulWidget {
  const RegimeCompareScreen({super.key});
  @override
  State<RegimeCompareScreen> createState() => _RegimeCompareScreenState();
}

class _RegimeCompareScreenState extends State<RegimeCompareScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late AnimationController _barAnim;
  late Animation<double> _barProgress;

  bool _loading = true;
  String _error = '';

  double _totalIncome = 0;
  double _totalDeductions = 0;
  double _oldRegimeTax = 0;
  double _newRegimeTax = 0;
  double _ltcgTax = 0;
  double _totalGSTTax = 0;
  double _totalCapitalGains = 0;

  // Slab breakdown for detail view
  List<_SlabRow> _oldSlabs = [];
  List<_SlabRow> _newSlabs = [];

  @override
  void initState() {
    super.initState();
    _barAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _barProgress = CurvedAnimation(parent: _barAnim, curve: Curves.easeOutCubic);
    _loadAndCalculate();
  }

  @override
  void dispose() {
    _barAnim.dispose();
    super.dispose();
  }

  Future<void> _loadAndCalculate() async {
    try {
      final incomeData     = await _firebaseService.getIncome();
      final deductionsData = await _firebaseService.getDeductions();
      final cgData         = await _firebaseService.getCapitalGains();
      final gstData        = await _firebaseService.getGST();

      // ── Income ── FIX: use 'taxableSalary' not 'salary'
      final double taxableSalary  = ((incomeData?['taxableSalary']  ?? 0.0) as num).toDouble();
      final double otherIncome    = ((incomeData?['otherIncome']    ?? 0.0) as num).toDouble();
      final double rentalIncome   = ((incomeData?['rentalIncome']   ?? 0.0) as num).toDouble();
      final double businessIncome = ((incomeData?['businessIncome'] ?? 0.0) as num).toDouble();
      final double baseIncome     = taxableSalary + otherIncome + rentalIncome + businessIncome;

      // ── Deductions ──
      final double s80c  = ((deductionsData?['section80c']   ?? 0.0) as num).toDouble();
      final double s80d  = ((deductionsData?['section80d']   ?? 0.0) as num).toDouble();
      final double s80cc = ((deductionsData?['section80ccd'] ?? 0.0) as num).toDouble();
      final double s24   = ((deductionsData?['section24']    ?? 0.0) as num).toDouble();
      final double totalDeductions = s80c + s80d + s80cc + s24;

      // ── Capital Gains ──
      final double stcgTotal      = ((cgData?['totalSTCG']       ?? 0.0) as num).toDouble();
      final double ltcgRealEstate = ((cgData?['ltcgRealEstate']  ?? 0.0) as num).toDouble();
      final double ltcgStocks     = ((cgData?['ltcgStocks']      ?? 0.0) as num).toDouble();
      final double ltcgMutualFunds= ((cgData?['ltcgMutualFunds'] ?? 0.0) as num).toDouble();
      final double ltcgOther      = ((cgData?['ltcgOther']       ?? 0.0) as num).toDouble();

      // ── GST ──
      final double gstTax = ((gstData?['totalGSTTax'] ?? 0.0) as num).toDouble();

      // STCG is added to regular income for slab taxation
      final double totalIncome = baseIncome + stcgTotal;

      // ── Tax calculations ──
      final oldResult = _calcOldRegime(totalIncome, totalDeductions);
      final newResult = _calcNewRegime(totalIncome);
      final double ltcgTax = _calcLTCGTax(ltcgRealEstate, ltcgStocks, ltcgMutualFunds, ltcgOther, totalIncome);

      setState(() {
        _totalIncome      = totalIncome;
        _totalDeductions  = totalDeductions;
        _oldRegimeTax     = oldResult.tax + ltcgTax;
        _newRegimeTax     = newResult.tax + ltcgTax;
        _ltcgTax          = ltcgTax;
        _totalGSTTax      = gstTax;
        _totalCapitalGains = stcgTotal + ltcgRealEstate + ltcgStocks + ltcgMutualFunds + ltcgOther;
        _oldSlabs         = oldResult.slabs;
        _newSlabs         = newResult.slabs;
        _loading          = false;
      });
      _barAnim.forward();
    } catch (e) {
      setState(() { _error = 'Error loading data: $e'; _loading = false; });
    }
  }

  // ── OLD REGIME (FY 2024-25) ──────────────────────────────────
  // Slabs: 0-2.5L=0%, 2.5-5L=5%, 5-10L=20%, >10L=30%
  // Standard deduction ₹50,000 + user deductions
  _TaxResult _calcOldRegime(double income, double deductions) {
    const stdDeduction = 50000.0;
    final taxable = (income - stdDeduction - deductions).clamp(0.0, double.infinity);
    final slabs = <_SlabRow>[];
    double tax = 0;

    void addSlab(String label, double amt, double rate) {
      if (amt <= 0) return;
      final t = amt * rate;
      slabs.add(_SlabRow(label, amt, rate, t));
      tax += t;
    }

    double rem = taxable;
    if (rem > 1000000) { addSlab('Above ₹10L @ 30%',   rem - 1000000, 0.30); rem = 1000000; }
    if (rem > 500000)  { addSlab('₹5L–₹10L @ 20%',     rem - 500000,  0.20); rem = 500000;  }
    if (rem > 250000)  { addSlab('₹2.5L–₹5L @ 5%',     rem - 250000,  0.05); rem = 250000;  }
    if (rem > 0)       { addSlab('Up to ₹2.5L @ 0%',   rem,           0.00); }

    // Rebate u/s 87A: if taxable ≤ 5L, tax = 0
    if (taxable <= 500000) tax = 0;

    final surcharge = _surcharge(tax, income);
    final cess = (tax + surcharge) * 0.04;
    return _TaxResult(tax + surcharge + cess, slabs);
  }

  // ── NEW REGIME (FY 2024-25 / Budget 2023) ────────────────────
  // Slabs: 0-3L=0%, 3-6L=5%, 6-9L=10%, 9-12L=15%, 12-15L=20%, >15L=30%
  // Standard deduction ₹50,000 (added in Budget 2023 for salaried)
  // Rebate u/s 87A up to ₹7L (taxable income)
  _TaxResult _calcNewRegime(double income) {
    const stdDeduction = 50000.0;
    final taxable = (income - stdDeduction).clamp(0.0, double.infinity);
    final slabs = <_SlabRow>[];
    double tax = 0;

    void addSlab(String label, double amt, double rate) {
      if (amt <= 0) return;
      final t = amt * rate;
      slabs.add(_SlabRow(label, amt, rate, t));
      tax += t;
    }

    double rem = taxable;
    if (rem > 1500000) { addSlab('Above ₹15L @ 30%',    rem - 1500000, 0.30); rem = 1500000; }
    if (rem > 1200000) { addSlab('₹12L–₹15L @ 20%',     rem - 1200000, 0.20); rem = 1200000; }
    if (rem > 900000)  { addSlab('₹9L–₹12L @ 15%',      rem - 900000,  0.15); rem = 900000;  }
    if (rem > 600000)  { addSlab('₹6L–₹9L @ 10%',       rem - 600000,  0.10); rem = 600000;  }
    if (rem > 300000)  { addSlab('₹3L–₹6L @ 5%',        rem - 300000,  0.05); rem = 300000;  }
    if (rem > 0)       { addSlab('Up to ₹3L @ 0%',      rem,           0.00); }

    // Rebate u/s 87A: if taxable ≤ 7L, tax = 0
    if (taxable <= 700000) tax = 0;

    final surcharge = _surcharge(tax, income);
    final cess = (tax + surcharge) * 0.04;
    return _TaxResult(tax + surcharge + cess, slabs);
  }

  double _surcharge(double tax, double income) {
    if (income > 50000000) return tax * 0.37;
    if (income > 20000000) return tax * 0.25;
    if (income > 10000000) return tax * 0.15;
    if (income > 5000000)  return tax * 0.10;
    return 0;
  }

  double _calcLTCGTax(double re, double stocks, double mf, double other, double income) {
    double ltcgTax = 0;
    // Real estate: 20% with indexation
    if (re > 0) { final t = re * 0.20; ltcgTax += t + _surcharge(t, income) + (t + _surcharge(t, income)) * 0.04; }
    // Stocks LTCG: exempt up to ₹1L, 10% above
    final stocksTaxable = (stocks - 100000).clamp(0.0, double.infinity);
    if (stocksTaxable > 0) { final t = stocksTaxable * 0.10; ltcgTax += t + _surcharge(t, income) + (t + _surcharge(t, income)) * 0.04; }
    // Mutual funds: 10%
    if (mf > 0) { final t = mf * 0.10; ltcgTax += t + _surcharge(t, income) + (t + _surcharge(t, income)) * 0.04; }
    // Other: 20%
    if (other > 0) { final t = other * 0.20; ltcgTax += t + _surcharge(t, income) + (t + _surcharge(t, income)) * 0.04; }
    return ltcgTax;
  }

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000)   return '₹${(v / 100000).toStringAsFixed(2)}L';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(
      appBar: AppBar(title: const Text('Regime Comparison', style: TextStyle(color: Colors.white))),
      body: const Center(child: CircularProgressIndicator()),
    );
    if (_error.isNotEmpty) return Scaffold(
      appBar: AppBar(title: const Text('Regime Comparison', style: TextStyle(color: Colors.white))),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () { setState(() { _loading = true; _error = ''; }); _loadAndCalculate(); }, child: const Text('Retry')),
      ])),
    );

    final bool newIsBetter = _newRegimeTax <= _oldRegimeTax;
    final double savings   = (_oldRegimeTax - _newRegimeTax).abs();
    final double maxTax    = math.max(_oldRegimeTax, _newRegimeTax);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regime Comparison', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Income summary card ──────────────────────────────
            _SectionCard(
              title: '📊 Your Numbers',
              child: Column(children: [
                _InfoRow('Gross Income',    _fmt(_totalIncome),     bold: true),
                _InfoRow('Deductions',      '- ${_fmt(_totalDeductions)}', color: Colors.green.shade700),
                _InfoRow('Taxable (Old)',   _fmt((_totalIncome - 50000 - _totalDeductions).clamp(0, double.infinity))),
                _InfoRow('Taxable (New)',   _fmt((_totalIncome - 50000).clamp(0, double.infinity))),
                if (_totalCapitalGains > 0)
                  _InfoRow('Capital Gains', _fmt(_totalCapitalGains), color: Colors.orange.shade700),
                if (_ltcgTax > 0)
                  _InfoRow('LTCG Tax',     _fmt(_ltcgTax),          color: Colors.orange.shade700),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Animated bar comparison ──────────────────────────
            _SectionCard(
              title: '📈 Tax Comparison',
              child: Column(children: [
                const SizedBox(height: 8),
                _AnimatedBar(
                  label: 'Old Regime',
                  value: _oldRegimeTax,
                  maxValue: maxTax == 0 ? 1 : maxTax,
                  color: newIsBetter ? Colors.red.shade300 : Colors.green.shade500,
                  progress: _barProgress,
                  formatted: _fmt(_oldRegimeTax),
                ),
                const SizedBox(height: 12),
                _AnimatedBar(
                  label: 'New Regime',
                  value: _newRegimeTax,
                  maxValue: maxTax == 0 ? 1 : maxTax,
                  color: newIsBetter ? Colors.green.shade500 : Colors.red.shade300,
                  progress: _barProgress,
                  formatted: _fmt(_newRegimeTax),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Recommendation banner ────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: newIsBetter
                      ? [Colors.green.shade600, Colors.green.shade400]
                      : [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    newIsBetter ? '✅ New Regime is better for you' : '✅ Old Regime is better for you',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (savings > 0) ...[
                    const SizedBox(height: 4),
                    Text('You save ${_fmt(savings)} by choosing the ${newIsBetter ? "New" : "Old"} Regime',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Side-by-side slab breakdown ──────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _SlabCard('Old Regime', _oldSlabs, AppColors.primaryLight, _oldRegimeTax, _ltcgTax)),
                const SizedBox(width: 10),
                Expanded(child: _SlabCard('New Regime', _newSlabs, Colors.green.shade50, _newRegimeTax, _ltcgTax)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Key differences ──────────────────────────────────
            _SectionCard(
              title: '📋 Key Differences',
              child: Table(
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(1.5)},
                children: [
                  _tableHeader(['Feature', 'Old Regime', 'New Regime']),
                  _tableRow(['Standard Deduction', '₹50,000', '₹50,000']),
                  _tableRow(['80C (up to ₹1.5L)', '✅ Allowed', '❌ Not allowed']),
                  _tableRow(['80D Health Ins.', '✅ Allowed', '❌ Not allowed']),
                  _tableRow(['Section 24 HLP', '✅ Allowed', '❌ Not allowed']),
                  _tableRow(['Rebate u/s 87A', 'Up to ₹5L', 'Up to ₹7L']),
                  _tableRow(['Tax Slabs', '3 slabs', '6 slabs (lower)']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _tableHeader(List<String> cells) => TableRow(
    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1)),
    children: cells.map((c) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    )).toList(),
  );

  TableRow _tableRow(List<String> cells) => TableRow(
    children: cells.map((c) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Text(c, style: const TextStyle(fontSize: 11)),
    )).toList(),
  );
}

// ── Data classes ─────────────────────────────────────────────────────────────

class _TaxResult {
  final double tax;
  final List<_SlabRow> slabs;
  _TaxResult(this.tax, this.slabs);
}

class _SlabRow {
  final String label;
  final double amount, rate, tax;
  _SlabRow(this.label, this.amount, this.rate, this.tax);
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _InfoRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color)),
      ],
    ),
  );
}

class _AnimatedBar extends StatelessWidget {
  final String label, formatted;
  final double value, maxValue;
  final Color color;
  final Animation<double> progress;
  const _AnimatedBar({required this.label, required this.value, required this.maxValue,
      required this.color, required this.progress, required this.formatted});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Text(formatted, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 6),
      AnimatedBuilder(
        animation: progress,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: maxValue == 0 ? 0 : (value / maxValue) * progress.value,
            minHeight: 14,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
    ],
  );
}

class _SlabCard extends StatelessWidget {
  final String title;
  final List<_SlabRow> slabs;
  final Color bgColor;
  final double totalTax, ltcgTax;
  const _SlabCard(this.title, this.slabs, this.bgColor, this.totalTax, this.ltcgTax, {super.key});

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
        const Divider(height: 16),
        const Text('Slab Breakdown', style: TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        ...slabs.where((s) => s.rate > 0).map((s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(s.label, style: const TextStyle(fontSize: 10))),
            Text(_fmt(s.tax), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
          ]),
        )),
        if (ltcgTax > 0) ...[
          const Divider(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('+ LTCG Tax', style: TextStyle(fontSize: 10)),
            Text(_fmt(ltcgTax), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
          ]),
        ],
        const Divider(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(_fmt(totalTax), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
        ]),
      ],
    ),
  );
}