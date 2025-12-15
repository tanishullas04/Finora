import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // placeholder summary — later provide real data
    final Map<String, String> summary = {
      "Total Income": "₹ 9,80,000",
      "Total Deductions": "₹ 1,62,000",
      "Taxable Income": "₹ 8,18,000",
      "Tax Payable": "₹ 66,040",
      "Recommended Regime": "New Regime"
    };

    return Scaffold(
      appBar: AppBar(title: const Text("Tax Summary", style: TextStyle(color: Colors.white, fontSize: 27))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Lottie.asset('assets/lottie/success.json', height: 140),
          const SizedBox(height: 8),
          ...summary.entries.map((e) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(title: Text(e.key), trailing: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold))),
              )),
          const Spacer(),
          ElevatedButton(onPressed: () {
            // placeholder export action
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Exported PDF (placeholder)")));
          }, child: const SizedBox(width: double.infinity, child: Center(child: Text("Export PDF")))),
        ]),
      ),
    );
  }
}
