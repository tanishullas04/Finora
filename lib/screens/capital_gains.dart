import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

// Capital Gains Calculator - Config and CII per FY 2025-26
class CapitalGainConfig {
  static const String financialYear = '2025-26';
  static const double ltcgRate = 0.10;
  static const double stcgRate = 0.15;
  static const double ltcgExemption = 100000;
  static const double cessRate = 0.04;
  static const double stcgSlabRate = 0.30; // For assets without STT
  static const Map<String, int> cii = {
    '2021-22': 317,
    '2022-23': 331,
    '2023-24': 348,
    '2024-25': 363,
    '2025-26': 365,
  };
}

String _getFinancialYear(DateTime date) {
  final year = date.year;
  if (date.month < 4) {
    return '${year - 1}-${year.toString().substring(2)}';
  }
  return '$year-${(year + 1).toString().substring(2)}';
}

// Capital Gains Calculator - Separates business logic from UI
class CapitalGainCalculator {
  static bool isLongTermAsset(AssetType asset, int days) {
    switch (asset) {
      case AssetType.property:
        return days >= 730; // 2 years
      case AssetType.gold:
        return days >= 1095; // 3 years
      case AssetType.stocks:
      case AssetType.mutualFunds:
        return days >= 365; // 1 year for equity
      default:
        return false;
    }
  }

  /// Calculate capital gains tax per config.
  /// sttPaid: true if STT paid (equity). For property/gold, always treated as false.
  static Map<String, dynamic> calculate({
    required AssetType asset,
    required double purchasePrice,
    required double sellingPrice,
    required bool isLongTerm,
    required DateTime purchaseDate,
    required DateTime saleDate,
    required bool sttPaid,
  }) {
    final gain = sellingPrice - purchasePrice;
    double tax = 0;
    String taxSection = '';
    double taxableAmount = gain;
    double exemptionAmount = 0;
    bool isCapitalLoss = gain < 0;

    // Property and Gold don't have STT - use non-STT path
    final effectiveSttPaid =
        (asset == AssetType.stocks || asset == AssetType.mutualFunds)
        ? sttPaid
        : false;

    if (isCapitalLoss) {
      taxSection = 'Capital Loss (can be carried forward)';
    } else if (isLongTerm) {
      if (effectiveSttPaid) {
        // Section 112A - LTCG with STT
        taxSection = 'Section 112A';
        exemptionAmount = gain > CapitalGainConfig.ltcgExemption
            ? CapitalGainConfig.ltcgExemption
            : gain;
        taxableAmount = (gain - CapitalGainConfig.ltcgExemption) > 0
            ? gain - CapitalGainConfig.ltcgExemption
            : 0;
        tax = taxableAmount * CapitalGainConfig.ltcgRate;
      } else {
        // Section 112 - LTCG without STT (indexation)
        taxSection = 'Section 112';
        final purchaseFy = _getFinancialYear(purchaseDate);
        final saleFy = _getFinancialYear(saleDate);
        final ciiPurchase = CapitalGainConfig.cii[purchaseFy] ?? 317;
        final ciiSale = CapitalGainConfig.cii[saleFy] ?? 365;
        final indexedCost = purchasePrice * (ciiSale / ciiPurchase);
        final indexedGain = (sellingPrice - indexedCost) > 0
            ? sellingPrice - indexedCost
            : 0;
        final tax20 = indexedGain * 0.20;
        final tax10 = gain * CapitalGainConfig.ltcgRate;
        tax = tax20 < tax10 ? tax20 : tax10;
        taxableAmount = gain;
      }
    } else {
      // STCG
      if (effectiveSttPaid) {
        taxSection = 'STCG (Sec 111A)';
        tax = gain * CapitalGainConfig.stcgRate;
        taxableAmount = gain;
      } else {
        taxSection = 'STCG (taxed at slab rate)';
        tax = gain * CapitalGainConfig.stcgSlabRate;
        taxableAmount = gain;
      }
    }

    final cess = tax * CapitalGainConfig.cessRate;
    final totalTax = tax + cess;

    return {
      'capitalGain': gain,
      'taxRate': tax > 0 ? (tax / taxableAmount) * 100 : 0,
      'taxSection': taxSection,
      'taxPayable': tax,
      'cess': cess,
      'totalTax': totalTax,
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
  double _cess = 0;
  double _totalTax = 0;
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

    final result = CapitalGainCalculator.calculate(
      asset: _selectedAsset,
      purchasePrice: _purchasePrice,
      sellingPrice: _sellingPrice,
      isLongTerm: _isLongTerm,
      purchaseDate: _purchaseDate!,
      saleDate: _saleDate!,
      sttPaid: _sttPaid,
    );

    _capitalGain = (result['capitalGain'] as num).toDouble();
    _taxRate = (result['taxRate'] as num).toDouble();
    _taxSection = result['taxSection'] as String;
    _taxPayable = (result['taxPayable'] as num).toDouble();
    _cess = (result['cess'] as num).toDouble();
    _totalTax = (result['totalTax'] as num).toDouble();
    _isCapitalLoss = result['isCapitalLoss'] as bool;
    _taxableAmount = (result['taxableAmount'] as num).toDouble();
    _exemptionAmount = (result['exemptionAmount'] as num).toDouble();

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
            color: AppColors.widgetBackground,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
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
                color: AppColors.primaryLight,
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
                      color: AppColors.primary,
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
                      backgroundColor: AppColors.secondary,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
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
                  color: AppColors.primaryVeryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondary),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capital gains tax applies when you sell assets like property, shares, or mutual funds.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'We\'ll ask you a few simple questions and calculate the tax automatically.',
                      style: TextStyle(fontSize: 13, color: AppColors.primary),
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
                  color: AppColors.text,
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
                  color: AppColors.widgetBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Indexation benefit removed as per Budget 2024',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
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
                    style: TextStyle(fontSize: 14, color: AppColors.primary),
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
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
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
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'See Result',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.widgetBackground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
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
          color: isSelected
              ? AppColors.primaryLight
              : AppColors.widgetBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
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
                  color: isSelected ? AppColors.primary : AppColors.text,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 24),
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
            color: AppColors.text,
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
              color: AppColors.widgetBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
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
                            color: AppColors.primary,
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
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
          color: AppColors.widgetBackground,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedDate != null
                      ? DateFormat('dd MMM yyyy').format(selectedDate)
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selectedDate != null ? AppColors.text : Colors.grey,
                  ),
                ),
              ],
            ),
            const Icon(Icons.calendar_today, color: AppColors.primary),
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
            color: AppColors.text,
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
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tax Calculation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
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
                          color: AppColors.primary,
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
                        'LTCG Tax (10%)',
                        '₹${_taxPayable.toStringAsFixed(2)}',
                      ),
                      if (_cess > 0)
                        _resultRow(
                          'Health & Edu. Cess (4%)',
                          '₹${_cess.toStringAsFixed(2)}',
                        ),
                      _resultRow(
                        'Total Tax Payable',
                        '₹${_totalTax.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹1,00,000 exemption as per Section 112A',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ] else ...[
                      _resultRow('Tax', '₹${_taxPayable.toStringAsFixed(2)}'),
                      if (_cess > 0)
                        _resultRow(
                          'Health & Edu. Cess (4%)',
                          '₹${_cess.toStringAsFixed(2)}',
                        ),
                      _resultRow(
                        'Total Tax Payable',
                        '₹${_totalTax.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                    ],
                  ],
                )
              else if (_capitalGain > 0) ...[
                const SizedBox(height: 12),
                _resultRow('Tax', '₹${_taxPayable.toStringAsFixed(2)}'),
                if (_cess > 0)
                  _resultRow(
                    'Health & Edu. Cess (4%)',
                    '₹${_cess.toStringAsFixed(2)}',
                  ),
                _resultRow(
                  'Total Tax Payable',
                  '₹${_totalTax.toStringAsFixed(2)}',
                  isBold: true,
                ),
                const SizedBox(height: 8),
                Text(
                  _sttPaid
                      ? 'STCG @ 15% (Sec 111A) + 4% cess'
                      : 'STCG taxed at slab rate (30% assumed) + 4% cess',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMuted,
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
                color: AppColors.widgetBackground,
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
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppColors.primary : AppColors.text,
          ),
        ),
      ],
    );
  }
}
