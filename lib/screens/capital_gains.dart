import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

// Capital Gains Calculator - Separates business logic from UI
class CapitalGainCalculator {
  // LTCG exemption constants
  static const double ltcgExemption = 125000; // ₹1,25,000 exemption
  static const double ltcgMutualFundsTaxRate = 0.125; // 12.5% tax

  static bool isLongTermAsset(AssetType asset, int days) {
    switch (asset) {
      case AssetType.property:
        return days >= 730; // 2 years
      case AssetType.gold:
        return days >= 1095; // 3 years
      case AssetType.stocks:
      case AssetType.mutualFunds:
        return days >= 365; // 1 year
      default:
        return false;
    }
  }

  static Map<String, dynamic> calculate({
    required AssetType asset,
    required double purchasePrice,
    required double sellingPrice,
    required bool isLongTerm,
  }) {
    final capitalGain = sellingPrice - purchasePrice;
    double taxRate = 0;
    String taxSection = '';
    double taxPayable = 0;
    bool isCapitalLoss = capitalGain < 0;
    double taxableAmount = capitalGain;
    double exemptionAmount = 0;

    if (isCapitalLoss) {
      // Capital Loss
      taxSection = 'Capital Loss (can be carried forward)';
      taxPayable = 0;
    } else if (isLongTerm) {
      // Long-term capital gains
      switch (asset) {
        case AssetType.stocks:
          taxRate = 0; // 0% for equity LTCG
          taxSection = 'Section 112A';
          taxableAmount = capitalGain;
          break;
        case AssetType.mutualFunds:
          taxRate = 12.5;
          taxSection = 'Section 112A';
          // Apply exemption for LTCG
          exemptionAmount = capitalGain > ltcgExemption
              ? ltcgExemption
              : capitalGain;
          taxableAmount = capitalGain > ltcgExemption
              ? capitalGain - ltcgExemption
              : 0;
          taxPayable = taxableAmount * ltcgMutualFundsTaxRate;
          break;
        case AssetType.property:
          taxRate = 20;
          taxSection = 'Section 112';
          taxableAmount = capitalGain;
          taxPayable = capitalGain * (taxRate / 100);
          break;
        case AssetType.gold:
          taxRate = 20;
          taxSection = 'Section 112';
          taxableAmount = capitalGain;
          taxPayable = capitalGain * (taxRate / 100);
          break;
        default:
          taxRate = 20;
          taxPayable = capitalGain * (taxRate / 100);
      }
      // For non-mutual fund LTCG, recalculate if not already done
      if (asset != AssetType.mutualFunds && taxPayable == 0) {
        taxPayable = capitalGain * (taxRate / 100);
      }
    } else {
      // Short-term capital gains - taxed as regular income
      taxRate = 0;
      taxSection = 'Added to your total income';
      taxPayable = 0; // Will depend on total income
    }

    return {
      'capitalGain': capitalGain,
      'taxRate': taxRate,
      'taxSection': taxSection,
      'taxPayable': taxPayable,
      'isCapitalLoss': isCapitalLoss,
      'taxableAmount': taxableAmount,
      'exemptionAmount': exemptionAmount,
    };
  }
}

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
  bool _isCapitalLoss = false;
  Map<String, double> _stcgSlabTaxes = {};
  double _taxableAmount = 0;
  double _exemptionAmount = 0;

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
    if (_purchaseDate == null || _saleDate == null) return;

    final difference = _saleDate!.difference(_purchaseDate!);
    _isLongTerm = CapitalGainCalculator.isLongTermAsset(
      _selectedAsset,
      difference.inDays,
    );

    // Use calculator to determine tax
    final result = CapitalGainCalculator.calculate(
      asset: _selectedAsset,
      purchasePrice: _purchasePrice,
      sellingPrice: _sellingPrice,
      isLongTerm: _isLongTerm,
    );

    _capitalGain = result['capitalGain'];
    _taxRate = result['taxRate'];
    _taxSection = result['taxSection'];
    _taxPayable = result['taxPayable'];
    _isCapitalLoss = result['isCapitalLoss'] ?? false;
    _taxableAmount = result['taxableAmount'] ?? 0;
    _exemptionAmount = result['exemptionAmount'] ?? 0;

    // Calculate STCG slab-wise taxes
    if (!_isLongTerm && _capitalGain > 0) {
      _stcgSlabTaxes = {
        '5% slab': _capitalGain * 0.05,
        '20% slab': _capitalGain * 0.20,
        '30% slab': _capitalGain * 0.30,
      };
    }
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
            ],

            // Details Form Step
            if (_currentStep == FormStep.details) ...[_buildDetailsForm()],

            // Result Step
            if (_currentStep == FormStep.result) ...[
              _buildResultCard(),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'Indexation benefit removed as per Budget 2024',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
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

              _resultRow(
                'Gain Amount',
                _isCapitalLoss
                    ? '-₹${_capitalGain.abs().toStringAsFixed(2)}'
                    : '₹${_capitalGain.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 12),
              if (_taxRate > 0 && !_isCapitalLoss)
                _resultRow('Tax Rate', '${_taxRate.toStringAsFixed(1)}%'),
              if (_taxRate > 0 && !_isCapitalLoss) const SizedBox(height: 12),
              _resultRow('Tax Section', _taxSection),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              if (_isCapitalLoss)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _resultRow('Tax Payable', 'No tax liability', isBold: true),
                    const SizedBox(height: 8),
                    Text(
                      'You can carry forward this loss to offset future capital gains.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                )
              else if (_isLongTerm)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show exemption details if it applies (Mutual Funds)
                    if (_exemptionAmount > 0) ...[
                      Text(
                        'Long-Term Capital Gains (LTCG)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _resultRow(
                        'Total LTCG',
                        '₹${_capitalGain.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 6),
                      _resultRow(
                        'Exemption',
                        '-₹${_exemptionAmount.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 6),
                      _resultRow(
                        'Taxable LTCG',
                        '₹${_taxableAmount.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 12),
                      _resultRow(
                        'LTCG Tax (12.5%)',
                        '₹${_taxPayable.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹1,25,000 exemption as per Section 112A',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ] else
                      _resultRow(
                        'Tax Payable',
                        '₹${_taxPayable.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                  ],
                )
              else if (_capitalGain > 0) ...[
                const SizedBox(height: 12),
                const Text(
                  'Estimated Tax (based on income slab)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                ..._stcgSlabTaxes.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _resultRow(
                      entry.key,
                      '₹${entry.value.toStringAsFixed(2)}',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Final tax depends on your total annual income.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.indigo.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Slabs shown are indicative as per current income tax structure.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
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
}