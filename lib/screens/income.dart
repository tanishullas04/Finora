import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});
  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final TextEditingController salaryCtrl = TextEditingController();
  final TextEditingController otherCtrl = TextEditingController();
  final TextEditingController rentCtrl = TextEditingController();
  final TextEditingController businessCtrl = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _saving = false;

  @override
  void dispose() {
    salaryCtrl.dispose();
    otherCtrl.dispose();
    rentCtrl.dispose();
    businessCtrl.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
    // Validate inputs
    final salary = double.tryParse(salaryCtrl.text) ?? 0;
    final other = double.tryParse(otherCtrl.text) ?? 0;
    final rent = double.tryParse(rentCtrl.text) ?? 0;
    final business = double.tryParse(businessCtrl.text) ?? 0;

    if (salary + other + rent + business == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one income source')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Save to Firebase
      await _firebaseService.saveIncome(
        salary: salary,
        otherIncome: other,
        rentalIncome: rent,
        businessIncome: business,
      );

      // Navigate to next screen
      if (mounted) {
        Navigator.pushNamed(context, '/deductions');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving income: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Income Details", style: TextStyle(color: Colors.white, fontSize: 27)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _field("Annual Salary (₹)", salaryCtrl),
            _field("Other Income (₹)", otherCtrl),
            _field("Rental Income (₹)", rentCtrl),
            _field("Business / Professional Income (₹)", businessCtrl),
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
