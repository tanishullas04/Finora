import 'package:flutter/material.dart';

class GSTScreen extends StatefulWidget {
  const GSTScreen({super.key});
  @override
  State<GSTScreen> createState() => _GSTScreenState();
}

class _GSTScreenState extends State<GSTScreen> {
  final TextEditingController amountCtrl = TextEditingController();
  double selectedGst = 18;
  double gstAmount = 0;
  double finalAmount = 0;

  void compute() {
    final amt = double.tryParse(amountCtrl.text) ?? 0;
    gstAmount = amt * (selectedGst / 100);
    finalAmount = amt + gstAmount;
    setState(() {});
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GST Calculator", style: TextStyle(color: Colors.white, fontSize: 27))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount (₹)")),
          const SizedBox(height: 12),
          Row(children: [
            const Text("GST Rate: ", style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            DropdownButton<double>(
              value: selectedGst,
              items: const [5, 12, 18, 28].map((e) => DropdownMenuItem(value: e.toDouble(), child: Text("$e%"))).toList(),
              onChanged: (v) => setState(() => selectedGst = v!),
            )
          ]),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: compute, child: const SizedBox(width: double.infinity, child: Center(child: Text("Calculate")))),
          const SizedBox(height: 24),
          if (gstAmount > 0) ...[
            Text("GST Amount: ₹${gstAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Final Price: ₹${finalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]
        ]),
      ),
    );
  }
}
