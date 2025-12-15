import 'package:flutter/material.dart';

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
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Income Details", style: TextStyle(color: Colors.white, fontSize: 27))),
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
              onPressed: () {
                // you will later pass values to services/state
                Navigator.pushNamed(context, '/deductions');
              },
              child: const SizedBox(width: double.infinity, child: Center(child: Text("Continue"))),
            )
          ],
        ),
      ),
    );
  }
}
