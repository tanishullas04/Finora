import 'package:flutter/material.dart';

class RegimeCompareScreen extends StatelessWidget {
  const RegimeCompareScreen({super.key});

  Widget _regimeCard(String title, String tax, Color color, List<String> bullets) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Estimated Tax: $tax", style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...bullets.map((b) => Row(children: [const Icon(Icons.check, size: 16), const SizedBox(width: 6), Text(b)])).toList(),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // placeholder values — replace with computed values later
    return Scaffold(
      appBar: AppBar(title: const Text("Regime Comparison", style: TextStyle(color: Colors.white, fontSize: 27))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: _regimeCard("Old Regime", "₹1,45,000", Colors.indigo.shade50, ["Deductions allowed", "HRA, 80C etc."])),
            const SizedBox(width: 12),
            Expanded(child: _regimeCard("New Regime", "₹1,20,000", Colors.green.shade50, ["Lower slabs", "Fewer deductions"])),
          ]),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(12)), child: const Text("✔ Recommended: New Regime saves you ₹25,000", style: TextStyle(fontWeight: FontWeight.bold))),
          const Spacer(),
          ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/gst'), child: const SizedBox(width: double.infinity, child: Center(child: Text("Next")))),
        ]),
      ),
    );
  }
}
