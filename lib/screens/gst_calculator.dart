import 'package:flutter/material.dart';
import 'package:finora/services/firebase_service.dart';

class GSTCalculator extends StatefulWidget {
  const GSTCalculator({Key? key}) : super(key: key);

  @override
  State<GSTCalculator> createState() => _GSTCalculatorState();
}

enum GSTStep { typeSelection, priceInput, location, itemType, result }

enum SellerType { goods, services }

// Indian States and Union Territories
const List<String> indianStates = [
  'Andaman and Nicobar Islands',
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chandigarh',
  'Chhattisgarh',
  'Dadra and Nagar Haveli',
  'Daman and Diu',
  'Delhi',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jammu and Kashmir',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Ladakh',
  'Lakshadweep',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Puducherry',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
];

class _GSTCalculatorState extends State<GSTCalculator> {
  final FirebaseService _firebaseService = FirebaseService();

  // Step-by-step form data
  GSTStep _currentStep = GSTStep.typeSelection;
  SellerType _sellerType = SellerType.goods;
  bool _isPriceInclusive = false;
  double _basePrice = 0;
  String _sellerState = '';
  String _buyerState = '';
  String _itemDescription = '';
  double _gstRate = 18;
  bool _skipGST = false;
  bool _isLoading = true;

  // Result data
  double _baseAmount = 0;
  double _gstAmount = 0;
  double _cgstAmount = 0;
  double _sgstAmount = 0;
  double _igstAmount = 0;
  double _totalAmount = 0;
  bool _isSameState = false;

  // Legacy controllers for backward compatibility
  final TextEditingController _gst0QuantityController = TextEditingController();
  final TextEditingController _gst0PriceController = TextEditingController();
  final TextEditingController _gst0HSNController = TextEditingController();
  final TextEditingController _gst5QuantityController = TextEditingController();
  final TextEditingController _gst5PriceController = TextEditingController();
  final TextEditingController _gst5HSNController = TextEditingController();
  final TextEditingController _gst12QuantityController =
      TextEditingController();
  final TextEditingController _gst12PriceController = TextEditingController();
  final TextEditingController _gst12HSNController = TextEditingController();
  final TextEditingController _gst18QuantityController =
      TextEditingController();
  final TextEditingController _gst18PriceController = TextEditingController();
  final TextEditingController _gst18HSNController = TextEditingController();
  final TextEditingController _gst28QuantityController =
      TextEditingController();
  final TextEditingController _gst28PriceController = TextEditingController();
  final TextEditingController _gst28HSNController = TextEditingController();
  final TextEditingController _itcController = TextEditingController();

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
          _gst0QuantityController.text = (gstData['gst0Quantity'] ?? 0)
              .toString();
          _gst0PriceController.text = (gstData['gst0Price'] ?? 0).toString();
          _gst0HSNController.text = gstData['gst0HSN'] ?? '';
          _gst5QuantityController.text = (gstData['gst5Quantity'] ?? 0)
              .toString();
          _gst5PriceController.text = (gstData['gst5Price'] ?? 0).toString();
          _gst5HSNController.text = gstData['gst5HSN'] ?? '';
          _gst12QuantityController.text = (gstData['gst12Quantity'] ?? 0)
              .toString();
          _gst12PriceController.text = (gstData['gst12Price'] ?? 0).toString();
          _gst12HSNController.text = gstData['gst12HSN'] ?? '';
          _gst18QuantityController.text = (gstData['gst18Quantity'] ?? 0)
              .toString();
          _gst18PriceController.text = (gstData['gst18Price'] ?? 0).toString();
          _gst18HSNController.text = gstData['gst18HSN'] ?? '';
          _gst28QuantityController.text = (gstData['gst28Quantity'] ?? 0)
              .toString();
          _gst28PriceController.text = (gstData['gst28Price'] ?? 0).toString();
          _gst28HSNController.text = gstData['gst28HSN'] ?? '';
          _itcController.text = (gstData['itcAmount'] ?? 0).toString();
        });
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading GST data: $e')));
    }
  }

  void _calculateGST() {
    if (_isPriceInclusive) {
      _baseAmount = _basePrice / (1 + _gstRate / 100);
    } else {
      _baseAmount = _basePrice;
    }

    _gstAmount = _baseAmount * (_gstRate / 100);
    _totalAmount = _baseAmount + _gstAmount;

    if (_isSameState) {
      _cgstAmount = _gstAmount / 2;
      _sgstAmount = _gstAmount / 2;
      _igstAmount = 0;
    } else {
      _cgstAmount = 0;
      _sgstAmount = 0;
      _igstAmount = _gstAmount;
    }
  }

  Future<void> _saveAndContinue() async {
    try {
      // Map current entry to legacy data structure for backward compatibility
      if (_sellerType == SellerType.goods) {
        if (_gstRate == 0) {
          _gst0QuantityController.text = '1';
          _gst0PriceController.text = _baseAmount.toString();
        } else if (_gstRate == 5) {
          _gst5QuantityController.text = '1';
          _gst5PriceController.text = _baseAmount.toString();
        } else if (_gstRate == 12) {
          _gst12QuantityController.text = '1';
          _gst12PriceController.text = _baseAmount.toString();
        } else if (_gstRate == 18) {
          _gst18QuantityController.text = '1';
          _gst18PriceController.text = _baseAmount.toString();
        } else if (_gstRate == 28) {
          _gst28QuantityController.text = '1';
          _gst28PriceController.text = _baseAmount.toString();
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
        Navigator.pushNamed(context, '/regime_compare');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving GST data: $e')));
    }
  }

  void _resetForm() {
    setState(() {
      _currentStep = GSTStep.typeSelection;
      _sellerType = SellerType.goods;
      _isPriceInclusive = false;
      _basePrice = 0;
      _sellerState = '';
      _buyerState = '';
      _itemDescription = '';
      _gstRate = 18;
    });
  }

  void _goToStep(GSTStep step) {
    setState(() {
      _currentStep = step;
      // Clear fields when entering new step
      if (step == GSTStep.location) {
        _buyerState = '';
      }
      if (step == GSTStep.itemType) {
        _itemDescription = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GST Calculator',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Step ${_currentStep.index + 1} of 5',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (_currentStep.index + 1) / 5,
                            minHeight: 6,
                            backgroundColor: Colors.deepPurple.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.deepPurple.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info Banner
                  if (_currentStep == GSTStep.typeSelection)
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
                            'GST is a tax charged on goods and services in India.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Answer a few simple questions and we\'ll calculate it for you.',
                            style: TextStyle(fontSize: 13, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),

                  // Step 1: Type Selection
                  if (_currentStep == GSTStep.typeSelection) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Step 1: What are you selling?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sellerTypeCard(
                      SellerType.goods,
                      '🧾',
                      'Goods (Products)',
                      'Physical items like clothes, electronics, etc.',
                    ),
                    _sellerTypeCard(
                      SellerType.services,
                      '🛠️',
                      'Services',
                      'Work or expertise like consulting, repairs, etc.',
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Step 2: Price Input
                  if (_currentStep == GSTStep.priceInput) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Step 2: Tell us about your price',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Is your price inclusive of GST?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Radio<bool>(
                                value: true,
                                groupValue: _isPriceInclusive,
                                onChanged: (value) {
                                  setState(
                                    () => _isPriceInclusive = value ?? false,
                                  );
                                },
                              ),
                              const Text('Yes (GST included)'),
                              const SizedBox(width: 32),
                              Radio<bool>(
                                value: false,
                                groupValue: _isPriceInclusive,
                                onChanged: (value) {
                                  setState(
                                    () => _isPriceInclusive = value ?? false,
                                  );
                                },
                              ),
                              const Text('No (GST extra)'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _basePrice = double.tryParse(value) ?? 0;
                      },
                      decoration: InputDecoration(
                        labelText: _isPriceInclusive
                            ? 'Total price (GST included)'
                            : 'Price before GST',
                        hintText: 'Enter amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Step 3: Location
                  if (_currentStep == GSTStep.location) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Step 3: Where is your business?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text('Select Seller State'),
                        value: _sellerState.isEmpty ? null : _sellerState,
                        items: indianStates.map((state) {
                          return DropdownMenuItem<String>(
                            value: state,
                            child: Text(state),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _sellerState = value ?? '';
                            _isSameState =
                                _sellerState.toLowerCase() ==
                                _buyerState.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text('Select Buyer State'),
                        value: _buyerState.isEmpty ? null : _buyerState,
                        items: indianStates.map((state) {
                          return DropdownMenuItem<String>(
                            value: state,
                            child: Text(state),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _buyerState = value ?? '';
                            _isSameState =
                                _sellerState.toLowerCase() ==
                                _buyerState.toLowerCase();
                          });
                        },
                      ),
                    ),
                    if (_sellerState.isNotEmpty && _buyerState.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isSameState
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isSameState
                                ? Colors.green.shade300
                                : Colors.orange.shade300,
                          ),
                        ),
                        child: Text(
                          _isSameState
                              ? '✓ Same state detected: CGST + SGST applies'
                              : '✓ Different states: IGST applies',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isSameState
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  // Step 4: Item Type & GST Rate
                  if (_currentStep == GSTStep.itemType) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Step 4: Select GST Rate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select GST rate:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...(_sellerType == SellerType.goods
                                  ? [5, 18, 40]
                                  : [0, 5, 18, 40])
                              .map((rate) {
                                String description = _getGSTRateDescription(
                                  rate,
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(
                                        () => _gstRate = rate.toDouble(),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _gstRate == rate
                                            ? Colors.deepPurple.shade50
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _gstRate == rate
                                              ? Colors.deepPurple
                                              : Colors.grey.shade300,
                                          width: _gstRate == rate ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Radio<double>(
                                            value: rate.toDouble(),
                                            groupValue: _gstRate,
                                            onChanged: (value) {
                                              setState(
                                                () => _gstRate = value ?? 18,
                                              );
                                            },
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$rate% GST',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  description,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Step 5: Result
                  if (_currentStep == GSTStep.result) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Step 5: Your GST Calculation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildResultCard(),
                    const SizedBox(height: 24),
                  ],

                  // Navigation Buttons
                  if (_currentStep != GSTStep.result)
                    Row(
                      children: [
                        if (_currentStep != GSTStep.typeSelection)
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _currentStep =
                                      GSTStep.values[_currentStep.index - 1];
                                });
                              },
                              child: const Text('Back'),
                            ),
                          ),
                        if (_currentStep != GSTStep.typeSelection)
                          const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_validateCurrentStep()) {
                                if (_currentStep == GSTStep.itemType) {
                                  _calculateGST();
                                }
                                setState(() {
                                  _currentStep =
                                      GSTStep.values[_currentStep.index + 1];
                                  // Clear fields when entering new step
                                  if (_currentStep == GSTStep.location) {
                                    _buyerState = '';
                                  }
                                  if (_currentStep == GSTStep.itemType) {
                                    _itemDescription = '';
                                  }
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Next',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Result Buttons
                  if (_currentStep == GSTStep.result) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _resetForm,
                            child: const Text('Start Over'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveAndContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  bool _validateCurrentStep() {
    if (_currentStep == GSTStep.priceInput && _basePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return false;
    }
    if (_currentStep == GSTStep.location &&
        (_sellerState.isEmpty || _buyerState.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter both states')));
      return false;
    }
    return true;
  }

  String _getGSTRateDescription(int rate) {
    if (_sellerType == SellerType.goods) {
      switch (rate) {
        case 5:
          return 'Essentials, FMCG, groceries, medicines';
        case 18:
          return 'Electronics, services, appliances, vehicles';
        case 40:
          return 'Luxury & sin goods (cars, tobacco, aerated drinks)';
        default:
          return '';
      }
    } else {
      // Services
      switch (rate) {
        case 0:
          return 'Essential services (education, healthcare)';
        case 5:
          return 'Passenger transport, food delivery, restaurant, hotel, beauty & wellness';
        case 18:
          return 'Professional services, legal, consulting, engineering, IT, financial, insurance, courier, air travel';
        case 40:
          return 'Casinos, online gaming, betting';
        default:
          return '';
      }
    }
  }

  Widget _sellerTypeCard(
    SellerType type,
    String emoji,
    String title,
    String subtitle,
  ) {
    bool isSelected = _sellerType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sellerType = type;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.deepPurple
                          : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.deepPurple, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tax Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),
              _resultRow('Base Amount', '₹${_baseAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              if (_isSameState) ...[
                _resultRow(
                  'CGST (${(_gstRate / 2).toStringAsFixed(0)}%)',
                  '₹${_cgstAmount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _resultRow(
                  'SGST (${(_gstRate / 2).toStringAsFixed(0)}%)',
                  '₹${_sgstAmount.toStringAsFixed(2)}',
                ),
              ] else ...[
                _resultRow(
                  'IGST (${_gstRate.toStringAsFixed(0)}%)',
                  '₹${_igstAmount.toStringAsFixed(2)}',
                ),
              ],
              const SizedBox(height: 12),
              _resultRow(
                'Total GST',
                '₹${_gstAmount.toStringAsFixed(2)}',
                isBold: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              _resultRow(
                'Total Amount',
                '₹${_totalAmount.toStringAsFixed(2)}',
                isBold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You need to charge ₹${_gstAmount.toStringAsFixed(2)} as GST.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The customer pays ₹${_totalAmount.toStringAsFixed(2)} in total.',
                style: TextStyle(fontSize: 13, color: Colors.green.shade700),
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
            color: isBold ? Colors.deepPurple : Colors.grey.shade800,
          ),
        ),
      ],
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
