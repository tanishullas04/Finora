import 'package:flutter/material.dart';

class CapitalGainsScreen extends StatefulWidget {
  const CapitalGainsScreen({super.key});
  @override
  State<CapitalGainsScreen> createState() => _CapitalGainsScreenState();
}

class _CapitalGainsScreenState extends State<CapitalGainsScreen> {
  final TextEditingController buyCtrl = TextEditingController();
  final TextEditingController sellCtrl = TextEditingController();
  final TextEditingController monthsCtrl = TextEditingController();
  double? taxResult;

  void calculate() {
    final buy = double.tryParse(buyCtrl.text) ?? 0;
    final sell = double.tryParse(sellCtrl.text) ?? 0;
    final months = int.tryParse(monthsCtrl.text) ?? 0;
    final gain = sell - buy;
    double tax = 0;
    if (gain <= 0) tax = 0;
    else if (months >= 12) tax = gain * 0.10; // LTCG simplified
    else tax = gain * 0.15; // STCG simplified
    setState(() => taxResult = tax);
  }

  @override
  void dispose() {
    buyCtrl.dispose();
    sellCtrl.dispose();
    monthsCtrl.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Capital Gains", style: TextStyle(color: Colors.white, fontSize: 27))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _field("Buy Price (₹)", buyCtrl),
          _field("Sell Price (₹)", sellCtrl),
          _field("Holding Period (months)", monthsCtrl),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: calculate, child: const SizedBox(width: double.infinity, child: Center(child: Text("Calculate")))),
          const SizedBox(height: 20),
          if (taxResult != null) Text("Estimated Capital Gains Tax: ₹${taxResult!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/ai_advice'), child: const Text("Next: AI Advice"))
        ]),
      ),
    );
  }
}
