import 'package:flutter/material.dart';
import 'package:finora/services/firebase_service.dart';

class GSTCalculator extends StatefulWidget {
  const GSTCalculator({Key? key}) : super(key: key);

  @override
  State<GSTCalculator> createState() => _GSTCalculatorState();
}

class _GSTCalculatorState extends State<GSTCalculator> {
  final FirebaseService _firebaseService = FirebaseService();
  
  // Controllers for GST rate categories
  final TextEditingController _gst0QuantityController = TextEditingController();
  final TextEditingController _gst0PriceController = TextEditingController();
  final TextEditingController _gst0HSNController = TextEditingController();
  
  final TextEditingController _gst5QuantityController = TextEditingController();
  final TextEditingController _gst5PriceController = TextEditingController();
  final TextEditingController _gst5HSNController = TextEditingController();
  
  final TextEditingController _gst12QuantityController = TextEditingController();
  final TextEditingController _gst12PriceController = TextEditingController();
  final TextEditingController _gst12HSNController = TextEditingController();
  
  final TextEditingController _gst18QuantityController = TextEditingController();
  final TextEditingController _gst18PriceController = TextEditingController();
  final TextEditingController _gst18HSNController = TextEditingController();
  
  final TextEditingController _gst28QuantityController = TextEditingController();
  final TextEditingController _gst28PriceController = TextEditingController();
  final TextEditingController _gst28HSNController = TextEditingController();
  
  final TextEditingController _itcController = TextEditingController();
  
  bool _skipGST = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGSTData();
  }

  Future<void> _loadGSTData() async {
    try {
      final gstData = await _firebaseService.getGST();
      if (gstData != null) {
        setState(() {
          _gst0QuantityController.text = (gstData['gst0Quantity'] ?? 0).toString();
          _gst0PriceController.text = (gstData['gst0Price'] ?? 0).toString();
          _gst0HSNController.text = gstData['gst0HSN'] ?? '';
          
          _gst5QuantityController.text = (gstData['gst5Quantity'] ?? 0).toString();
          _gst5PriceController.text = (gstData['gst5Price'] ?? 0).toString();
          _gst5HSNController.text = gstData['gst5HSN'] ?? '';
          
          _gst12QuantityController.text = (gstData['gst12Quantity'] ?? 0).toString();
          _gst12PriceController.text = (gstData['gst12Price'] ?? 0).toString();
          _gst12HSNController.text = gstData['gst12HSN'] ?? '';
          
          _gst18QuantityController.text = (gstData['gst18Quantity'] ?? 0).toString();
          _gst18PriceController.text = (gstData['gst18Price'] ?? 0).toString();
          _gst18HSNController.text = gstData['gst18HSN'] ?? '';
          
          _gst28QuantityController.text = (gstData['gst28Quantity'] ?? 0).toString();
          _gst28PriceController.text = (gstData['gst28Price'] ?? 0).toString();
          _gst28HSNController.text = gstData['gst28HSN'] ?? '';
          
          _itcController.text = (gstData['itcAmount'] ?? 0).toString();
        });
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading GST data: $e')),
      );
    }
  }

  Future<void> _saveGSTData() async {
    try {
      if (!_skipGST) {
        // Validate that at least one GST category has values
        bool hasValue = false;
        if (_gst0QuantityController.text.isNotEmpty || _gst0PriceController.text.isNotEmpty ||
            _gst5QuantityController.text.isNotEmpty || _gst5PriceController.text.isNotEmpty ||
            _gst12QuantityController.text.isNotEmpty || _gst12PriceController.text.isNotEmpty ||
            _gst18QuantityController.text.isNotEmpty || _gst18PriceController.text.isNotEmpty ||
            _gst28QuantityController.text.isNotEmpty || _gst28PriceController.text.isNotEmpty) {
          hasValue = true;
        }

        if (!hasValue) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter at least one GST item or select Skip')),
          );
          return;
        }
      }

      await _firebaseService.saveGST(
        gst0Quantity: double.tryParse(_gst0QuantityController.text) ?? 0,
        gst0Price: double.tryParse(_gst0PriceController.text) ?? 0,
        gst0HSN: _gst0HSNController.text,
        gst5Quantity: double.tryParse(_gst5QuantityController.text) ?? 0,
        gst5Price: double.tryParse(_gst5PriceController.text) ?? 0,
        gst5HSN: _gst5HSNController.text,
        gst12Quantity: double.tryParse(_gst12QuantityController.text) ?? 0,
        gst12Price: double.tryParse(_gst12PriceController.text) ?? 0,
        gst12HSN: _gst12HSNController.text,
        gst18Quantity: double.tryParse(_gst18QuantityController.text) ?? 0,
        gst18Price: double.tryParse(_gst18PriceController.text) ?? 0,
        gst18HSN: _gst18HSNController.text,
        gst28Quantity: double.tryParse(_gst28QuantityController.text) ?? 0,
        gst28Price: double.tryParse(_gst28PriceController.text) ?? 0,
        gst28HSN: _gst28HSNController.text,
        itcAmount: double.tryParse(_itcController.text) ?? 0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GST data saved successfully!')),
        );
        Navigator.pushNamed(context, '/regime_compare');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving GST data: $e')),
      );
    }
  }

  Widget _buildGSTCategoryField(String title, String rate, 
      TextEditingController quantityController, 
      TextEditingController priceController,
      TextEditingController hsnController) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title ($rate)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hsnController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'HSN/SAC Code',
                hintText: 'e.g., 8523, 9406',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      hintText: '0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Unit Price (₹)',
                      hintText: '0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Calculator'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.deepPurple.withOpacity(0.1),
                    child: const Text(
                      'Enter details for Goods & Services Tax (GST) by rate category. Rates: 0% (essentials), 5% (basic), 12% (mid-range), 18% (premium), 28% (luxury).',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: CheckboxListTile(
                      title: const Text('Skip GST (No goods/services)'),
                      value: _skipGST,
                      onChanged: (value) {
                        setState(() => _skipGST = value ?? false);
                      },
                    ),
                  ),
                  if (!_skipGST) ...[
                    _buildGSTCategoryField('Essentials', '0%', 
                      _gst0QuantityController, _gst0PriceController, _gst0HSNController),
                    _buildGSTCategoryField('Basic Goods', '5%', 
                      _gst5QuantityController, _gst5PriceController, _gst5HSNController),
                    _buildGSTCategoryField('Mid-Range Goods', '12%', 
                      _gst12QuantityController, _gst12PriceController, _gst12HSNController),
                    _buildGSTCategoryField('Premium Goods', '18%', 
                      _gst18QuantityController, _gst18PriceController, _gst18HSNController),
                    _buildGSTCategoryField('Luxury Items', '28%', 
                      _gst28QuantityController, _gst28PriceController, _gst28HSNController),
                    Card(
                      margin: const EdgeInsets.all(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Input Tax Credit (ITC)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'GST paid on inputs that can be credited against output GST',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _itcController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'ITC Amount (₹)',
                                hintText: '0',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveGSTData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Next (Tax Comparison)',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _gst0QuantityController.dispose();
    _gst0PriceController.dispose();
    _gst0HSNController.dispose();
    _gst5QuantityController.dispose();
    _gst5PriceController.dispose();
    _gst5HSNController.dispose();
    _gst12QuantityController.dispose();
    _gst12PriceController.dispose();
    _gst12HSNController.dispose();
    _gst18QuantityController.dispose();
    _gst18PriceController.dispose();
    _gst18HSNController.dispose();
    _gst28QuantityController.dispose();
    _gst28PriceController.dispose();
    _gst28HSNController.dispose();
    _itcController.dispose();
    super.dispose();
  }
}
