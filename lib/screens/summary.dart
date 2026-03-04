import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});
  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late AnimationController _pieAnim;
  late Animation<double> _pieProgress;

  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _userProfile;

  // Income fields — each stored separately for the pie chart
  double _taxableSalary  = 0;
  double _otherIncome    = 0;
  double _rentalIncome   = 0;
  double _businessIncome = 0;
  double _stcgTotal      = 0;

  double _totalDeductions = 0;
  double _ltcgTax         = 0;
  double _totalGSTTax     = 0;
  double _oldRegimeTax    = 0;
  double _newRegimeTax    = 0;
  String _bestRegime      = '';
  double _savings         = 0;

  // Total income computed from the individual fields
  double get _totalIncome =>
      _taxableSalary + _otherIncome + _rentalIncome + _businessIncome + _stcgTotal;

  @override
  void initState() {
    super.initState();
    _pieAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pieProgress =
        CurvedAnimation(parent: _pieAnim, curve: Curves.easeOutCubic);
    _loadData();
  }

  @override
  void dispose() {
    _pieAnim.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final incomeData     = await _firebaseService.getIncome();
      final deductionsData = await _firebaseService.getDeductions();
      final cgData         = await _firebaseService.getCapitalGains();
      final gstData        = await _firebaseService.getGST();
      if (_firebaseService.currentUserId != null) {
        _userProfile = await _firebaseService
            .getUserProfile(_firebaseService.currentUserId!);
      }

      // ── Income — correct field names matching firebase_service.dart ──
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

      // ── Capital gains ──
      final double stcgTotal       = ((cgData?['totalSTCG']       ?? 0.0) as num).toDouble();
      final double ltcgRealEstate  = ((cgData?['ltcgRealEstate']  ?? 0.0) as num).toDouble();
      final double ltcgStocks      = ((cgData?['ltcgStocks']      ?? 0.0) as num).toDouble();
      final double ltcgMutualFunds = ((cgData?['ltcgMutualFunds'] ?? 0.0) as num).toDouble();
      final double ltcgOther       = ((cgData?['ltcgOther']       ?? 0.0) as num).toDouble();

      // ── GST ──
      final double gstTax = ((gstData?['totalGSTTax'] ?? 0.0) as num).toDouble();

      final double totalIncome = baseIncome + stcgTotal;

      // ── Tax calculations ──
      final double oldTax  = _calcOld(totalIncome, totalDeductions);
      final double newTax  = _calcNew(totalIncome);
      final double ltcgTax = _calcLTCG(ltcgRealEstate, ltcgStocks, ltcgMutualFunds, ltcgOther);
      final double oldTotal = oldTax + ltcgTax + gstTax;
      final double newTotal = newTax + ltcgTax + gstTax;

      setState(() {
        _taxableSalary   = taxableSalary;
        _otherIncome     = otherIncome;
        _rentalIncome    = rentalIncome;
        _businessIncome  = businessIncome;
        _stcgTotal       = stcgTotal;
        _totalDeductions = totalDeductions;
        _ltcgTax         = ltcgTax;
        _totalGSTTax     = gstTax;
        _oldRegimeTax    = oldTotal;
        _newRegimeTax    = newTotal;
        _bestRegime      = oldTotal > newTotal ? 'New Regime' : 'Old Regime';
        _savings         = (oldTotal - newTotal).abs();
        _loading         = false;
      });

      _pieAnim.forward();
    } catch (e) {
      setState(() {
        _error   = 'Error loading data: $e';
        _loading = false;
      });
    }
  }

  // ── Tax helpers ──────────────────────────────────────────────────
  double _calcOld(double income, double deductions) {
    final t = (income - 50000 - deductions).clamp(0.0, double.infinity);
    double tax = 0, rem = t;
    if (rem > 1000000) { tax += (rem - 1000000) * 0.30; rem = 1000000; }
    if (rem > 500000)  { tax += (rem - 500000)  * 0.20; rem = 500000;  }
    if (rem > 250000)  { tax += (rem - 250000)  * 0.05; }
    if (t <= 500000) tax = 0; // 87A rebate
    return tax * 1.04;        // 4% cess
  }

  double _calcNew(double income) {
    final t = (income - 50000).clamp(0.0, double.infinity);
    double tax = 0, rem = t;
    if (rem > 1500000) { tax += (rem - 1500000) * 0.30; rem = 1500000; }
    if (rem > 1200000) { tax += (rem - 1200000) * 0.20; rem = 1200000; }
    if (rem > 900000)  { tax += (rem - 900000)  * 0.15; rem = 900000;  }
    if (rem > 600000)  { tax += (rem - 600000)  * 0.10; rem = 600000;  }
    if (rem > 300000)  { tax += (rem - 300000)  * 0.05; }
    if (t <= 700000) tax = 0; // 87A rebate new regime
    return tax * 1.04;
  }

  double _calcLTCG(double re, double stocks, double mf, double other) {
    double t = 0;
    if (re > 0)    t += re * 0.20 * 1.04;
    final st = (stocks - 100000).clamp(0.0, double.infinity);
    if (st > 0)    t += st * 0.10 * 1.04;
    if (mf > 0)    t += mf * 0.10 * 1.04;
    if (other > 0) t += other * 0.20 * 1.04;
    return t;
  }

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000)   return '₹${(v / 100000).toStringAsFixed(2)}L';
    return '₹${v.toStringAsFixed(0)}';
  }

  String get _initials {
    final name = _userProfile?['name']?.toString().trim() ?? '';
    if (name.isEmpty) return '?';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  Future<void> _exportPdf() async {
    try {
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(level: 0, text: 'Finora Tax Summary'),
          pw.Header(level: 1, text: 'Profile'),
          pw.Text('Name: ${_userProfile?['name'] ?? '-'}'),
          pw.Text('Email: ${_userProfile?['email'] ?? '-'}'),
          pw.Text('PAN: ${_userProfile?['pan'] ?? '-'}'),
          pw.Text('Filing Status: ${_userProfile?['filingStatus'] ?? '-'}'),
          pw.Text('Tax Regime Preference: ${_userProfile?['taxRegime'] ?? '-'}'),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, text: 'Income'),
          pw.Text('Taxable Salary: ${_fmt(_taxableSalary)}'),
          pw.Text('Other Income: ${_fmt(_otherIncome)}'),
          pw.Text('Rental Income: ${_fmt(_rentalIncome)}'),
          pw.Text('Business Income: ${_fmt(_businessIncome)}'),
          pw.Text('STCG: ${_fmt(_stcgTotal)}'),
          pw.Text('Total: ${_fmt(_totalIncome)}'),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, text: 'Deductions & Tax'),
          pw.Text('Total Deductions: ${_fmt(_totalDeductions)}'),
          pw.Text('LTCG Tax: ${_fmt(_ltcgTax)}'),
          pw.Text('GST Tax: ${_fmt(_totalGSTTax)}'),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, text: 'Regime Comparison'),
          pw.Text('Old Regime: ${_fmt(_oldRegimeTax)}'),
          pw.Text('New Regime: ${_fmt(_newRegimeTax)}'),
          pw.Text('Best: $_bestRegime — Saves ${_fmt(_savings)}'),
        ],
      ));
      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: 'finora_tax_summary.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF failed: $e')));
    }
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Summary',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () { setState(() { _loading = true; _error = ''; }); _loadData(); },
                    child: const Text('Retry'),
                  ),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileCard(),
                      const SizedBox(height: 16),
                      _buildPieCard(),
                      const SizedBox(height: 16),
                      _buildIncomeCard(),
                      const SizedBox(height: 16),
                      _buildTaxCard(),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                        label: const Text('Export PDF', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text('Logout', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  // ── Profile card ─────────────────────────────────────────────────
  Widget _buildProfileCard() {
    final p = _userProfile;
    return _ShadowCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar + name + edit button
        Row(children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary,
            child: Text(_initials,
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p?['name'] ?? 'No name set',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            if ((p?['email'] ?? '').isNotEmpty)
              Row(children: [
                Icon(Icons.email_outlined, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(child: Text(p!['email'],
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
              ]),
          ])),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/profile')
                .then((_) { setState(() => _loading = true); _loadData(); }),
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit Profile',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryVeryLight,
              foregroundColor: AppColors.primary,
            ),
          ),
        ]),

        if (p != null) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Personal details section
          _sectionLabel('PERSONAL DETAILS'),
          const SizedBox(height: 8),
          _detailRow(Icons.phone_outlined,          'Mobile',              p['phone']),
          _detailRow(Icons.cake_outlined,            'Date of Birth',       _formatDob(p['dob'])),
          _detailRow(Icons.wc_outlined,              'Gender',              p['gender']),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Tax information section
          _sectionLabel('TAX INFORMATION'),
          const SizedBox(height: 8),
          _detailRow(Icons.badge_outlined,           'PAN',                 p['pan']),
          _detailRow(Icons.person_outline,           'Filing Status',       p['filingStatus']),
          _detailRow(Icons.home_outlined,            'Residential Status',  p['residentialStatus']),
          _detailRow(Icons.account_balance_outlined, 'Tax Regime',          p['taxRegime']),

          if ((p['lastUpdated'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Icon(Icons.update, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('Last updated: ${_formatLastUpdated(p['lastUpdated'])}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ]),
          ],
        ],
      ],
    ));
  }

  Widget _sectionLabel(String label) => Text(label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.primary, letterSpacing: 0.8));

  Widget _detailRow(IconData icon, String label, dynamic value) {
    final String display = (value == null || value.toString().trim().isEmpty) ? '—' : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.primary.withOpacity(0.7)),
        const SizedBox(width: 10),
        SizedBox(width: 130,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
        Expanded(child: Text(display,
            style: TextStyle(
              fontSize: 13,
              fontWeight: display == '—' ? FontWeight.w400 : FontWeight.w600,
              color: display == '—' ? Colors.grey.shade400 : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  String _formatDob(dynamic dob) {
    if (dob == null || dob.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(dob.toString());
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      // Also show age
      final age = DateTime.now().year - dt.year;
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  (age $age)';
    } catch (_) {
      return dob.toString();
    }
  }

  String _formatLastUpdated(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString());
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return ts.toString();
    }
  }

  // ── Pie chart card ────────────────────────────────────────────────
  Widget _buildPieCard() {
    // Always show the card; display a placeholder if no data yet
    final segments = <_PieSegment>[
      if (_taxableSalary  > 0) _PieSegment('Salary',      _taxableSalary,   const Color(0xFF1F4689)),
      if (_otherIncome    > 0) _PieSegment('Other Inc.',  _otherIncome,     const Color(0xFF5170A6)),
      if (_rentalIncome   > 0) _PieSegment('Rental',      _rentalIncome,    const Color(0xFF22a06b)),
      if (_businessIncome > 0) _PieSegment('Business',    _businessIncome,  const Color(0xFF0ea5a0)),
      if (_stcgTotal      > 0) _PieSegment('STCG',        _stcgTotal,       const Color(0xFFf59e0b)),
      if (_totalDeductions> 0) _PieSegment('Deductions',  _totalDeductions, const Color(0xFFe11d48)),
    ];

    final double total = segments.fold(0.0, (s, e) => s + e.value);

    return _ShadowCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Income & Deductions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
        const SizedBox(height: 16),

        // If no data, show a friendly prompt instead of empty chart
        if (segments.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('No income data yet.\nAdd your income to see the chart.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ]),
            ),
          )
        else
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Donut chart
            SizedBox(
              width: 140, height: 140,
              child: AnimatedBuilder(
                animation: _pieProgress,
                builder: (_, __) => CustomPaint(
                  painter: _PieChartPainter(segments, total, _pieProgress.value),
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Legend
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: segments.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Expanded(child: Text(s.label, style: const TextStyle(fontSize: 11))),
                  Text(_fmt(s.value),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              )).toList(),
            )),
          ]),

        if (segments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.primaryVeryLight, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total Income',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(_fmt(_totalIncome),
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ),
        ],
      ],
    ));
  }

  // ── Income breakdown card ─────────────────────────────────────────
  Widget _buildIncomeCard() => _ShadowCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('💰 Income Breakdown',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
      const SizedBox(height: 12),
      if (_taxableSalary  > 0) _RowItem('Taxable Salary',  _fmt(_taxableSalary),  const Color(0xFF1F4689)),
      if (_otherIncome    > 0) _RowItem('Other Income',    _fmt(_otherIncome),    const Color(0xFF5170A6)),
      if (_rentalIncome   > 0) _RowItem('Rental Income',   _fmt(_rentalIncome),   const Color(0xFF22a06b)),
      if (_businessIncome > 0) _RowItem('Business Income', _fmt(_businessIncome), const Color(0xFF0ea5a0)),
      if (_stcgTotal      > 0) _RowItem('STCG',            _fmt(_stcgTotal),      const Color(0xFFf59e0b)),
      if (_taxableSalary == 0 && _otherIncome == 0 && _rentalIncome == 0 &&
          _businessIncome == 0 && _stcgTotal == 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No income entered yet.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ),
      const Divider(height: 16),
      _RowItem('Total Income', _fmt(_totalIncome), AppColors.primary, bold: true),
      if (_totalDeductions > 0) _RowItem('Deductions', '- ${_fmt(_totalDeductions)}', Colors.green.shade700),
      if (_ltcgTax    > 0) _RowItem('LTCG Tax',  _fmt(_ltcgTax),    Colors.orange.shade700),
      if (_totalGSTTax > 0) _RowItem('GST Tax',  _fmt(_totalGSTTax), Colors.orange.shade700),
    ],
  ));

  // ── Tax comparison card ───────────────────────────────────────────
  Widget _buildTaxCard() => _ShadowCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('⚖️ Tax Comparison',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _TaxBox('Old Regime', _fmt(_oldRegimeTax),
            _bestRegime == 'Old Regime' ? Colors.green.shade600 : Colors.red.shade400,
            _bestRegime == 'Old Regime')),
        const SizedBox(width: 10),
        Expanded(child: _TaxBox('New Regime', _fmt(_newRegimeTax),
            _bestRegime == 'New Regime' ? Colors.green.shade600 : Colors.red.shade400,
            _bestRegime == 'New Regime')),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.green.shade50, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200)),
        child: Row(children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('$_bestRegime saves you ${_fmt(_savings)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700))),
        ]),
      ),
    ],
  ));
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _ShadowCard extends StatelessWidget {
  final Widget child;
  const _ShadowCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: child,
  );
}

class _RowItem extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _RowItem(this.label, this.value, this.color, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ]),
      Text(value, style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: bold ? AppColors.primary : null)),
    ]),
  );
}

class _TaxBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isBest;
  const _TaxBox(this.label, this.value, this.color, this.isBest);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isBest ? Colors.green.shade50 : Colors.red.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: isBest ? Colors.green.shade200 : Colors.red.shade200),
    ),
    child: Column(children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      if (isBest) ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(10)),
          child: const Text('BETTER',
              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      ],
    ]),
  );
}

// ── Pie chart ─────────────────────────────────────────────────────────────────

class _PieSegment {
  final String label;
  final double value;
  final Color color;
  _PieSegment(this.label, this.value, this.color);
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSegment> segments;
  final double total;
  final double progress;
  _PieChartPainter(this.segments, this.total, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const gap = 0.03;
    double startAngle = -math.pi / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.45;

    for (final seg in segments) {
      final sweep = (seg.value / total) * 2 * math.pi * progress - gap;
      if (sweep <= 0) {
        startAngle += (seg.value / total) * 2 * math.pi * progress;
        continue;
      }
      paint.color = seg.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.72),
        startAngle + gap / 2,
        sweep,
        false,
        paint,
      );
      startAngle += sweep + gap;
    }

    // Centre label
    if (progress > 0.8) {
      final label = total >= 100000
          ? '₹${(total / 100000).toStringAsFixed(1)}L'
          : '₹${total.toStringAsFixed(0)}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              color: AppColors.primary,
              fontSize: radius * 0.22,
              fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter old) => old.progress != progress;
}