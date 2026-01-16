import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

class CapitalGainsScreen extends StatefulWidget {
  const CapitalGainsScreen({super.key});

  @override
  State<CapitalGainsScreen> createState() => _CapitalGainsScreenState();
}

enum AssetType { property, stocks, mutualFunds, gold, none }

enum FormStep { assetSelection, details, result }

class _CapitalGainsScreenState extends State<CapitalGainsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _saving = false;

  // State management
  FormStep _currentStep = FormStep.assetSelection;
  AssetType _selectedAsset = AssetType.none;

  // Guided form data
  DateTime? _purchaseDate;
  DateTime? _saleDate;
  double _purchasePrice = 0;
  double _sellingPrice = 0;
  bool _sttPaid = false;
  bool _useIndexation = false;

  // Result data
  double _capitalGain = 0;
  bool _isLongTerm = false;
  double _taxRate = 0;
  double _taxPayable = 0;
  String _taxSection = '';

  // Legacy data for backward compatibility
  final TextEditingController _stcgRealEstateController =
      TextEditingController();
  final TextEditingController _stcgStocksController = TextEditingController();
  final TextEditingController _stcgMutualFundsController =
      TextEditingController();
  final TextEditingController _stcgOtherController = TextEditingController();
  final TextEditingController _ltcgRealEstateController =
      TextEditingController();
  final TextEditingController _ltcgStocksController = TextEditingController();
  final TextEditingController _ltcgMutualFundsController =
      TextEditingController();
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

  void _calculateCapitalGain() {
    _capitalGain = _sellingPrice - _purchasePrice;

    // Determine if long-term (2 years or more)
    if (_purchaseDate != null && _saleDate != null) {
      final difference = _saleDate!.difference(_purchaseDate!);
      _isLongTerm = difference.inDays >= 730; // ~2 years

      // Determine tax rate based on asset type and holding period
      if (_isLongTerm) {
        switch (_selectedAsset) {
          case AssetType.stocks:
            _taxRate = 0; // 0% for equity LTCG
            _taxSection = 'Section 112A';
            break;
          case AssetType.mutualFunds:
            _taxRate = 15;
            _taxSection = 'Section 112A';
            break;
          case AssetType.property:
            _taxRate = 20;
            _taxSection = 'Section 112';
            break;
          case AssetType.gold:
            _taxRate = 20;
            _taxSection = 'Section 112';
            break;
          default:
            _taxRate = 20;
        }
      } else {
        // STCG - taxed as regular income
        _taxRate = 0; // Will be added to regular income
        _taxSection = 'STCG - Regular Income';
      }
    }

    // Simple tax calculation (surcharge and cess not included for simplicity)
    _taxPayable = _capitalGain * (_taxRate / 100);
  }

  Future<void> _selectDate(bool isPurchaseDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        if (isPurchaseDate) {
          _purchaseDate = pickedDate;
        } else {
          _saleDate = pickedDate;
        }
      });
    }
  }

  void _resetForm() {
    setState(() {
      _currentStep = FormStep.assetSelection;
      _selectedAsset = AssetType.none;
      _purchaseDate = null;
      _saleDate = null;
      _purchasePrice = 0;
      _sellingPrice = 0;
      _sttPaid = false;
      _useIndexation = false;
    });
  }

  Future<void> _autoSaveCapitalGain() async {
    try {
      // Map current entry to legacy data structure
      double gainToSave = _capitalGain;
      if (_selectedAsset == AssetType.property && _isLongTerm) {
        _ltcgRealEstateController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.stocks && _isLongTerm) {
        _ltcgStocksController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.mutualFunds && _isLongTerm) {
        _ltcgMutualFundsController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.gold && _isLongTerm) {
        _ltcgOtherController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.property && !_isLongTerm) {
        _stcgRealEstateController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.stocks && !_isLongTerm) {
        _stcgStocksController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.mutualFunds && !_isLongTerm) {
        _stcgMutualFundsController.text = gainToSave.toString();
      } else {
        _stcgOtherController.text = gainToSave.toString();
      }

      // Save to Firebase
      await _firebaseService.saveCapitalGains(
        stcgRealEstate: double.tryParse(_stcgRealEstateController.text) ?? 0,
        stcgStocks: double.tryParse(_stcgStocksController.text) ?? 0,
        stcgMutualFunds: double.tryParse(_stcgMutualFundsController.text) ?? 0,
        stcgOther: double.tryParse(_stcgOtherController.text) ?? 0,
        ltcgRealEstate: double.tryParse(_ltcgRealEstateController.text) ?? 0,
        ltcgStocks: double.tryParse(_ltcgStocksController.text) ?? 0,
        ltcgMutualFunds: double.tryParse(_ltcgMutualFundsController.text) ?? 0,
        ltcgOther: double.tryParse(_ltcgOtherController.text) ?? 0,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capital gains saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving capital gains: $e')));
    }
  }

  Future<void> _saveAndContinue() async {
    try {
      setState(() => _saving = true);

      // Map current entry to legacy data structure
      double gainToSave = _capitalGain;
      if (_selectedAsset == AssetType.property && _isLongTerm) {
        _ltcgRealEstateController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.stocks && _isLongTerm) {
        _ltcgStocksController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.mutualFunds && _isLongTerm) {
        _ltcgMutualFundsController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.gold && _isLongTerm) {
        _ltcgOtherController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.property && !_isLongTerm) {
        _stcgRealEstateController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.stocks && !_isLongTerm) {
        _stcgStocksController.text = gainToSave.toString();
      } else if (_selectedAsset == AssetType.mutualFunds && !_isLongTerm) {
        _stcgMutualFundsController.text = gainToSave.toString();
      } else {
        _stcgOtherController.text = gainToSave.toString();
      }

      // Save to Firebase
      await _firebaseService.saveCapitalGains(
        stcgRealEstate: double.tryParse(_stcgRealEstateController.text) ?? 0,
        stcgStocks: double.tryParse(_stcgStocksController.text) ?? 0,
        stcgMutualFunds: double.tryParse(_stcgMutualFundsController.text) ?? 0,
        stcgOther: double.tryParse(_stcgOtherController.text) ?? 0,
        ltcgRealEstate: double.tryParse(_ltcgRealEstateController.text) ?? 0,
        ltcgStocks: double.tryParse(_ltcgStocksController.text) ?? 0,
        ltcgMutualFunds: double.tryParse(_ltcgMutualFundsController.text) ?? 0,
        ltcgOther: double.tryParse(_ltcgOtherController.text) ?? 0,
      );

      // Navigate to GST calculator screen
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/gst_calculator');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving capital gains: $e')));
      setState(() => _saving = false);
    }
  }

  String _getHoldingPeriod() {
    if (_purchaseDate == null || _saleDate == null) return '';
    final difference = _saleDate!.difference(_purchaseDate!);
    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    return '$years years $months months';
  }

  String _getAssetName(AssetType asset) {
    switch (asset) {
      case AssetType.property:
        return 'Property / Real Estate';
      case AssetType.stocks:
        return 'Shares / Stocks';
      case AssetType.mutualFunds:
        return 'Mutual Funds';
      case AssetType.gold:
        return 'Gold / Other Assets';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Capital Gains',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    _currentStep == FormStep.assetSelection
                        ? 'Step 1 of 3'
                        : _currentStep == FormStep.details
                        ? 'Step 2 of 3'
                        : 'Step 3 of 3',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _currentStep == FormStep.assetSelection
                          ? 0.33
                          : _currentStep == FormStep.details
                          ? 0.66
                          : 1.0,
                      minHeight: 6,
                      backgroundColor: Colors.indigo.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.indigo.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Asset Selection Step
            if (_currentStep == FormStep.assetSelection) ...[
              // Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capital gains tax applies when you sell assets like property, shares, or mutual funds.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'We\'ll ask you a few simple questions and calculate the tax automatically.',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Asset Selection Cards
              Text(
                'Step 1: What did you sell?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),

              _assetCard(AssetType.property, '🏠', 'Property / Real Estate'),
              _assetCard(AssetType.stocks, '📈', 'Shares / Stocks'),
              _assetCard(AssetType.mutualFunds, '💼', 'Mutual Funds'),
              _assetCard(AssetType.gold, '🪙', 'Gold / Other Assets'),

              const SizedBox(height: 24),

              // Skip Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    '/regime_compare',
                  ),
                  child: const Text(
                    'Skip (No capital gains)',
                    style: TextStyle(fontSize: 14, color: Colors.indigo),
                  ),
                ),
              ),
            ],

            // Details Form Step
            if (_currentStep == FormStep.details) ...[_buildDetailsForm()],

            // Result Step
            if (_currentStep == FormStep.result) ...[
              _buildResultCard(),
              const SizedBox(height: 24),
              _buildIndexationToggle(),
              const SizedBox(height: 28),
            ],

            // Back Button (for Result step)
            if (_currentStep == FormStep.result)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _resetForm,
                  child: const Text(
                    'Back',
                    style: TextStyle(fontSize: 14, color: Colors.indigo),
                  ),
                ),
              ),

            // Back & Continue Buttons (for Details step)
            if (_currentStep == FormStep.details) ...[
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _resetForm,
                      child: const Text(
                        'Back',
                        style: TextStyle(fontSize: 14, color: Colors.indigo),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_purchaseDate == null ||
                            _saleDate == null ||
                            _purchasePrice <= 0 ||
                            _sellingPrice <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all fields'),
                            ),
                          );
                          return;
                        }
                        _calculateCapitalGain();
                        setState(() => _currentStep = FormStep.result);
                        // Auto-save after transitioning to result
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _autoSaveCapitalGain();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'See Result',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    '/regime_compare',
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assetCard(AssetType asset, String emoji, String label) {
    bool isSelected = _selectedAsset == asset;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAsset = asset;
          _currentStep = FormStep.details;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.indigo : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.indigo : Colors.grey.shade800,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.indigo, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2: Tell us about your ${_getAssetName(_selectedAsset)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 24),

        // Purchase Date
        _buildDateField(
          label: '📅 When did you buy it?',
          selectedDate: _purchaseDate,
          onTap: () => _selectDate(true),
        ),
        const SizedBox(height: 20),

        // Sale Date
        _buildDateField(
          label: '📅 When did you sell it?',
          selectedDate: _saleDate,
          onTap: () => _selectDate(false),
        ),
        const SizedBox(height: 20),

        // Purchase Price
        TextField(
          keyboardType: TextInputType.number,
          onChanged: (value) {
            _purchasePrice = double.tryParse(value) ?? 0;
          },
          decoration: InputDecoration(
            labelText: '💰 Purchase price',
            hintText: 'Enter amount',
            prefixText: '₹ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Selling Price
        TextField(
          keyboardType: TextInputType.number,
          onChanged: (value) {
            _sellingPrice = double.tryParse(value) ?? 0;
          },
          decoration: InputDecoration(
            labelText: '💰 Selling price',
            hintText: 'Enter amount',
            prefixText: '₹ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // STT Paid - Only for Stocks and Mutual Funds
        if (_selectedAsset == AssetType.stocks ||
            _selectedAsset == AssetType.mutualFunds)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _sttPaid,
                  onChanged: (value) {
                    setState(() => _sttPaid = value ?? false);
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '☑️ Was STT paid?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('What is STT?'),
                              content: const Text(
                                'STT (Securities Transaction Tax) is a tax paid when buying/selling shares on the stock exchange.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Got it'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text(
                          '💡 What\'s this?',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.indigo,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade50,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedDate != null
                      ? DateFormat('dd MMM yyyy').format(selectedDate)
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selectedDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
            const Icon(Icons.calendar_today, color: Colors.indigo),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3: Your Capital Gains Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 20),

        // Status Badge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isLongTerm ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isLongTerm
                  ? Colors.green.shade300
                  : Colors.orange.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isLongTerm ? Icons.check_circle : Icons.schedule,
                    color: _isLongTerm ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isLongTerm
                          ? '✅ Long-Term Capital Gain'
                          : '⏱️ Short-Term Capital Gain',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isLongTerm
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _isLongTerm
                    ? 'You held this asset for ${_getHoldingPeriod()}, which qualifies as long-term.'
                    : 'You held this asset for ${_getHoldingPeriod()}, which is less than 2 years.',
                style: TextStyle(
                  fontSize: 13,
                  color: _isLongTerm
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tax Details Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tax Calculation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 16),

              _resultRow('Gain Amount', '₹${_capitalGain.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              _resultRow('Tax Rate', '${_taxRate.toStringAsFixed(0)}%'),
              const SizedBox(height: 12),
              _resultRow('Tax Section', _taxSection),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              _resultRow(
                'Tax Payable',
                '₹${_taxPayable.toStringAsFixed(2)}',
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? Colors.indigo : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildIndexationToggle() {
    if (!_isLongTerm || _selectedAsset == AssetType.stocks) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _useIndexation,
                onChanged: (value) {
                  setState(() => _useIndexation = value ?? false);
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apply Indexation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '💡 Indexation reduces tax by adjusting for inflation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_useIndexation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _resultRow(
                    'Original Cost',
                    '₹${_purchasePrice.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _resultRow(
                    'Indexed Cost',
                    '₹${(_purchasePrice * 1.15).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _resultRow(
                    'Tax Savings',
                    '₹${(_capitalGain * 0.15 * (_taxRate / 100)).toStringAsFixed(2)}',
                    isBold: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
