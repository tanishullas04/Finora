import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class CapitalGainsScreen extends StatefulWidget {
  const CapitalGainsScreen({super.key});

  @override
  State<CapitalGainsScreen> createState() => _CapitalGainsScreenState();
}

class _CapitalGainsScreenState extends State<CapitalGainsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _saving = false;

  // Short-term capital gains (STCG) - taxed as regular income
  final TextEditingController _stcgRealEstateController = TextEditingController();
  final TextEditingController _stcgStocksController = TextEditingController();
  final TextEditingController _stcgMutualFundsController = TextEditingController();
  final TextEditingController _stcgOtherController = TextEditingController();

  // Long-term capital gains (LTCG) - special rates (0%, 15%, 20%)
  final TextEditingController _ltcgRealEstateController = TextEditingController();
  final TextEditingController _ltcgStocksController = TextEditingController();
  final TextEditingController _ltcgMutualFundsController = TextEditingController();
  final TextEditingController _ltcgOtherController = TextEditingController();

  @override
  void dispose() {
    _stcgRealEstateController.dispose();
    _stcgStocksController.dispose();
    _stcgMutualFundsController.dispose();
    _stcgOtherController.dispose();
    _ltcgRealEstateController.dispose();
    _ltcgStocksController.dispose();
    _ltcgMutualFundsController.dispose();
    _ltcgOtherController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    try {
      setState(() => _saving = true);

      // Parse short-term capital gains
      double stcgRealEstate = double.tryParse(_stcgRealEstateController.text) ?? 0;
      double stcgStocks = double.tryParse(_stcgStocksController.text) ?? 0;
      double stcgMutualFunds = double.tryParse(_stcgMutualFundsController.text) ?? 0;
      double stcgOther = double.tryParse(_stcgOtherController.text) ?? 0;

      // Parse long-term capital gains
      double ltcgRealEstate = double.tryParse(_ltcgRealEstateController.text) ?? 0;
      double ltcgStocks = double.tryParse(_ltcgStocksController.text) ?? 0;
      double ltcgMutualFunds = double.tryParse(_ltcgMutualFundsController.text) ?? 0;
      double ltcgOther = double.tryParse(_ltcgOtherController.text) ?? 0;

      // Check if at least one capital gain is entered
      double totalCapitalGains = stcgRealEstate +
          stcgStocks +
          stcgMutualFunds +
          stcgOther +
          ltcgRealEstate +
          ltcgStocks +
          ltcgMutualFunds +
          ltcgOther;

      if (totalCapitalGains == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter at least one capital gain amount')),
        );
        setState(() => _saving = false);
        return;
      }

      // Save to Firebase
      await _firebaseService.saveCapitalGains(
        stcgRealEstate: stcgRealEstate,
        stcgStocks: stcgStocks,
        stcgMutualFunds: stcgMutualFunds,
        stcgOther: stcgOther,
        ltcgRealEstate: ltcgRealEstate,
        ltcgStocks: ltcgStocks,
        ltcgMutualFunds: ltcgMutualFunds,
        ltcgOther: ltcgOther,
      );

      // Navigate to GST calculator screen
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/gst_calculator');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving capital gains: $e')),
      );
      setState(() => _saving = false);
    }
  }

  Widget _capitalGainInput(String label, TextEditingController controller, String taxInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              hintText: '0',
              prefixText: '₹ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(taxInfo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capital Gains',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: const Text(
                '💡 Short-term gains (< 2 years) are taxed as regular income. Long-term gains have special rates: Stocks 0%, Mutual Funds 15%, Real Estate 20%.',
                style: TextStyle(fontSize: 13, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 20),

            // Short-term Capital Gains Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 Short-Term Capital Gains (STCG)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const Text('Held for less than 2 years - taxed as regular income',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _capitalGainInput('Real Estate STCG', _stcgRealEstateController, 'Added to income, taxed at your slab rate'),
                  _capitalGainInput('Stocks STCG', _stcgStocksController, 'Added to income, taxed at your slab rate'),
                  _capitalGainInput('Mutual Funds STCG', _stcgMutualFundsController, 'Added to income, taxed at your slab rate'),
                  _capitalGainInput('Other STCG', _stcgOtherController, 'Added to income, taxed at your slab rate'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Long-term Capital Gains Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📈 Long-Term Capital Gains (LTCG)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  const Text('Held for 2+ years - special tax rates apply',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _capitalGainInput('Real Estate LTCG', _ltcgRealEstateController, 'Tax: 20% + Surcharge + 4% Cess'),
                  _capitalGainInput('Stocks LTCG', _ltcgStocksController, 'Tax: 0% (no tax on equity gains!)'),
                  _capitalGainInput('Mutual Funds LTCG', _ltcgMutualFundsController, 'Tax: 15% + Surcharge + 4% Cess'),
                  _capitalGainInput('Other LTCG', _ltcgOtherController, 'Tax: 20% + Surcharge + 4% Cess'),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Continue Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2),
                      )
                    : const Text('Continue to Tax Comparison',
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 15),

            // Skip Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/regime_compare'),
                child: const Text('Skip (No capital gains)',
                    style: TextStyle(fontSize: 14, color: Colors.indigo)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
