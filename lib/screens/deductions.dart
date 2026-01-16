import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class DeductionsScreen extends StatefulWidget {
  const DeductionsScreen({super.key});
  @override
  State<DeductionsScreen> createState() => _DeductionsScreenState();
}

class _DeductionsScreenState extends State<DeductionsScreen> {
  // Section 80C controllers & state
  final TextEditingController epfController = TextEditingController();
  final TextEditingController lifeInsuranceController = TextEditingController();
  final TextEditingController elssController = TextEditingController();
  final TextEditingController nscController = TextEditingController();
  final TextEditingController tuitionController = TextEditingController();

  bool epfSelected = false;
  bool lifeInsuranceSelected = false;
  bool elssSelected = false;
  bool nscSelected = false;
  bool tuitionSelected = false;

  // Section 80D controllers & state
  final TextEditingController selfFamilyPremiumController =
      TextEditingController();
  final TextEditingController parentsPremiumController =
      TextEditingController();
  bool parentsSeniorCitizen = false;

  // Section 24 controllers & state
  final TextEditingController homeLoanInterestController =
      TextEditingController();
  bool isSelfOccupied = true;

  // Other deductions
  final TextEditingController educationLoanController = TextEditingController();
  final TextEditingController donationController = TextEditingController();
  final TextEditingController npsExtraController = TextEditingController();
  final TextEditingController savingsInterestController =
      TextEditingController();

  // Gross income for summary
  final TextEditingController grossIncomeController = TextEditingController();

  final FirebaseService _firebaseService = FirebaseService();
  bool _saving = false;

  @override
  void dispose() {
    epfController.dispose();
    lifeInsuranceController.dispose();
    elssController.dispose();
    nscController.dispose();
    tuitionController.dispose();
    selfFamilyPremiumController.dispose();
    parentsPremiumController.dispose();
    homeLoanInterestController.dispose();
    educationLoanController.dispose();
    donationController.dispose();
    npsExtraController.dispose();
    savingsInterestController.dispose();
    grossIncomeController.dispose();
    super.dispose();
  }

  double _calculate80C() {
    double total = 0;
    if (epfSelected) total += double.tryParse(epfController.text) ?? 0;
    if (lifeInsuranceSelected)
      total += double.tryParse(lifeInsuranceController.text) ?? 0;
    if (elssSelected) total += double.tryParse(elssController.text) ?? 0;
    if (nscSelected) total += double.tryParse(nscController.text) ?? 0;
    if (tuitionSelected) total += double.tryParse(tuitionController.text) ?? 0;
    return total > 150000 ? 150000 : total;
  }

  double _calculate80D() {
    double selfFamilyLimit = 25000;
    double parentsLimit = 25000;
    if (parentsSeniorCitizen) parentsLimit = 50000;

    double selfFamily = double.tryParse(selfFamilyPremiumController.text) ?? 0;
    double parents = double.tryParse(parentsPremiumController.text) ?? 0;

    selfFamily = selfFamily > selfFamilyLimit ? selfFamilyLimit : selfFamily;
    parents = parents > parentsLimit ? parentsLimit : parents;

    return selfFamily + parents;
  }

  double _calculate24() {
    double amount = double.tryParse(homeLoanInterestController.text) ?? 0;
    double limit = isSelfOccupied ? 200000 : 0; // Only self-occupied has limit
    if (isSelfOccupied) {
      return amount > limit ? limit : amount;
    }
    return amount;
  }

  double _getTotalDeductions() {
    return _calculate80C() +
        _calculate80D() +
        _calculate24() +
        (double.tryParse(educationLoanController.text) ?? 0) +
        (double.tryParse(donationController.text) ?? 0) +
        (double.tryParse(npsExtraController.text) ?? 0) +
        (double.tryParse(savingsInterestController.text) ?? 0);
  }

  double _getTaxableIncome() {
    double grossIncome = double.tryParse(grossIncomeController.text) ?? 0;
    return grossIncome - _getTotalDeductions();
    
  }

  double _getEstimatedTaxSaved() {
    return _getTotalDeductions() * 0.30; // Approximate at 30%
  }

  Widget _expandCard(String title, String subtitle, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        children: children,
      ),
    );
  }

  Widget _checkboxInput(
    String label,
    bool value,
    Function(bool?) onChanged,
    TextEditingController controller,
    String? hint,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Checkbox(value: value, onChanged: onChanged),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(
                  height: 32,
                  child: TextField(
                    controller: controller,
                    enabled: value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: hint ?? '₹ 0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoButton(String title, String content) {
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 18, color: Colors.blue),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAndContinue() async {
    setState(() => _saving = true);

    try {
      await _firebaseService.saveDeductions(
        section80c: _calculate80C(),
        section80d: _calculate80D(),
        section80ccd: double.tryParse(npsExtraController.text) ?? 0,
        section24: _calculate24(),
      );

      if (mounted) {
        Navigator.pushNamed(context, '/capital_gains');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving deductions: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Deductions",
          style: TextStyle(color: Colors.white, fontSize: 27),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deductions reduce your taxable income and help you save tax legally.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter amounts you have invested or spent under different sections of the Income Tax Act.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You only need to fill sections that apply to you.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Gross Income Input
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: TextField(
                  controller: grossIncomeController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Gross Annual Income (₹)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    prefixIcon: const Icon(Icons.currency_rupee),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section 80C
              _expandCard(
                'Section 80C – Investments & Savings',
                'Maximum ₹1,50,000',
                [
                  _checkboxInput(
                    'EPF / PPF',
                    epfSelected,
                    (val) => setState(() => epfSelected = val ?? false),
                    epfController,
                    '₹ 0',
                  ),
                  _checkboxInput(
                    'Life Insurance Premium',
                    lifeInsuranceSelected,
                    (val) =>
                        setState(() => lifeInsuranceSelected = val ?? false),
                    lifeInsuranceController,
                    '₹ 0',
                  ),
                  _checkboxInput(
                    'ELSS Mutual Funds',
                    elssSelected,
                    (val) => setState(() => elssSelected = val ?? false),
                    elssController,
                    '₹ 0',
                  ),
                  _checkboxInput(
                    'NSC / Tax-saving FD',
                    nscSelected,
                    (val) => setState(() => nscSelected = val ?? false),
                    nscController,
                    '₹ 0',
                  ),
                  _checkboxInput(
                    'Tuition Fees (children)',
                    tuitionSelected,
                    (val) => setState(() => tuitionSelected = val ?? false),
                    tuitionController,
                    '₹ 0',
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Eligible Deduction:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₹${_calculate80C().toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Section 80D
              _expandCard(
                'Section 80D – Health Insurance',
                'Self & Family + Parents coverage',
                [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: selfFamilyPremiumController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Self & Family Premium (₹)',
                        helperText: 'Limit: ₹25,000',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: parentsPremiumController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Parents Premium (₹)',
                        helperText: parentsSeniorCitizen
                            ? 'Limit: ₹50,000 (Senior Citizen)'
                            : 'Limit: ₹25,000',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Are parents senior citizens?'),
                        Switch(
                          value: parentsSeniorCitizen,
                          onChanged: (val) =>
                              setState(() => parentsSeniorCitizen = val),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Deduction:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₹${_calculate80D().toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Section 24 - Home Loan Interest
              _expandCard(
                'Section 24(b) – Home Loan Interest',
                'Self-occupied or Rented property',
                [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: homeLoanInterestController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Interest Paid (₹)',
                        helperText: isSelfOccupied
                            ? 'Max deduction: ₹2,00,000'
                            : 'Full amount deductible',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Self-occupied property?'),
                        Switch(
                          value: isSelfOccupied,
                          onChanged: (val) =>
                              setState(() => isSelfOccupied = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Section 80E - Education Loan Interest
              _expandCard(
                'Section 80E – Education Loan Interest',
                'No limit on deduction',
                [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: educationLoanController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Interest Paid on Education Loan (₹)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Section 80G - Donations
              _expandCard(
                'Section 80G – Donations',
                '50% or 100% deduction based on charity type',
                [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: donationController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Donations to Approved Charities (₹)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Section 80CCD(1B) - NPS Extra
              _expandCard(
                'Section 80CCD(1B) – NPS Additional',
                'Extra ₹50,000 beyond 80C limit',
                [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: npsExtraController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'NPS Contribution (₹)',
                        helperText: 'Max: ₹50,000 (in addition to 80C)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Section 80TTA/80TTB - Savings Interest
              _expandCard(
                'Section 80TTA / 80TTB – Savings Interest',
                'Interest from savings account & fixed deposits',
                [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: savingsInterestController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Savings/Interest Income (₹)',
                        helperText:
                            '80TTA: ₹10,000 limit | 80TTB: ₹50,000 (Senior Citizen)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade200, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 Deduction Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Gross Income:'),
                        Text(
                          '₹${(double.tryParse(grossIncomeController.text) ?? 0).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Deductions:'),
                        Text(
                          '₹${_getTotalDeductions().toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Taxable Income:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '₹${_getTaxableIncome().toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimated Tax Saved:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₹${_getEstimatedTaxSaved().toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveAndContinue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.indigo,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Save & Continue',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
