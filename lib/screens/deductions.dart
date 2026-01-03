import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class DeductionsScreen extends StatefulWidget {
  const DeductionsScreen({super.key});
  @override
  State<DeductionsScreen> createState() => _DeductionsScreenState();
}

class _DeductionsScreenState extends State<DeductionsScreen> {
  final TextEditingController sec80c = TextEditingController();
  final TextEditingController sec80d = TextEditingController();
  final TextEditingController sec24 = TextEditingController();
  final TextEditingController sec80ccd = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _saving = false;

  @override
  void dispose() {
    sec80c.dispose();
    sec80d.dispose();
    sec24.dispose();
    sec80ccd.dispose();
    super.dispose();
  }

  Widget _expandCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: children,
      ),
    );
  }

  Widget _input(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    setState(() => _saving = true);

    try {
      // Parse values
      final d80c = double.tryParse(sec80c.text) ?? 0;
      final d80d = double.tryParse(sec80d.text) ?? 0;
      final d80ccd = double.tryParse(sec80ccd.text) ?? 0;
      final d24 = double.tryParse(sec24.text) ?? 0;

      // Save to Firebase
      await _firebaseService.saveDeductions(
        section80c: d80c,
        section80d: d80d,
        section80ccd: d80ccd,
        section24: d24,
      );

      // Navigate to capital gains
      if (mounted) {
        Navigator.pushNamed(context, '/capital_gains');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving deductions: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Deductions", style: TextStyle(color: Colors.white, fontSize: 27)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _expandCard(
              "Section 80C (limit ₹1,50,000)",
              [_input("ELSS/PPF/EPF etc. (₹)", sec80c)],
            ),
            _expandCard(
              "Section 80D (Health Insurance)",
              [_input("Self/Family (₹)", sec80d)],
            ),
            _expandCard(
              "Section 80CCD(1B) (NPS extra ₹50,000)",
              [_input("NPS Contribution (₹)", sec80ccd)],
            ),
            _expandCard(
              "Section 24 (Home Loan Interest)",
              [_input("Interest Paid (₹)", sec24)],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saving ? null : _saveAndContinue,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text("Continue"),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
