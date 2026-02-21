import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/ocr_service.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});
  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final TextEditingController taxableSalaryCtrl = TextEditingController();
  final TextEditingController grossSalaryCtrl = TextEditingController();
  final TextEditingController otherCtrl = TextEditingController();
  final TextEditingController rentCtrl = TextEditingController();
  final TextEditingController businessCtrl = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final OCRService _ocrService = OCRService();
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  
  bool _saving = false;
  bool _extracting = false;
  bool _loading = true;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      print('DEBUG: Loading saved income data...');
      final data = await _firebaseService.getIncome();
      
      if (mounted && data != null) {
        setState(() {
          if (data['taxableSalary'] != null && data['taxableSalary'] > 0) {
            taxableSalaryCtrl.text = data['taxableSalary'].toString();
          }
          if (data['grossSalary'] != null && data['grossSalary'] > 0) {
            grossSalaryCtrl.text = data['grossSalary'].toString();
          }
          if (data['otherIncome'] != null && data['otherIncome'] > 0) {
            otherCtrl.text = data['otherIncome'].toString();
          }
          if (data['rentalIncome'] != null && data['rentalIncome'] > 0) {
            rentCtrl.text = data['rentalIncome'].toString();
          }
          if (data['businessIncome'] != null && data['businessIncome'] > 0) {
            businessCtrl.text = data['businessIncome'].toString();
          }
          _loading = false;
        });
        print('DEBUG: Income data loaded successfully');
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      print('DEBUG: Error loading income data: $e');
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    taxableSalaryCtrl.dispose();
    grossSalaryCtrl.dispose();
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
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => ctrl.clear()),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _pickAndExtractFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && mounted) {
        final file = result.files.single;
        
        // Validate file bytes availability
        if (file.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to read file. Please try another file.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFileName = file.name;
          _extracting = true;
        });

        try {
          final fileBytes = file.bytes!;
          print('DEBUG: File selected - ${_selectedFileName} (${fileBytes.length} bytes)');
          
          // Send to backend for OCR
          print('DEBUG: Calling OCR service...');
          final incomeData = await _ocrService.extractIncomeFromFile(
            fileBytes,
            _selectedFileName!,
          );
          
          print('DEBUG: OCR service returned: $incomeData');

          if (mounted) {
            if (incomeData != null && _isValidIncomeData(incomeData)) {
              setState(() {
                // Map extracted data to fields
                if (incomeData['grossSalary'] != null && incomeData['grossSalary'] > 0) {
                  grossSalaryCtrl.text = incomeData['grossSalary'].toString();
                }
                if (incomeData['taxableSalary'] != null && incomeData['taxableSalary'] > 0) {
                  taxableSalaryCtrl.text = incomeData['taxableSalary'].toString();
                }
                if (incomeData['otherIncome'] != null && incomeData['otherIncome'] > 0) {
                  otherCtrl.text = incomeData['otherIncome'].toString();
                }
                if (incomeData['rentalIncome'] != null && incomeData['rentalIncome'] > 0) {
                  rentCtrl.text = incomeData['rentalIncome'].toString();
                }
                if (incomeData['businessIncome'] != null && incomeData['businessIncome'] > 0) {
                  businessCtrl.text = incomeData['businessIncome'].toString();
                }
              });

              // Show extraction summary dialog
              _showExtractionSummary(incomeData);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ No income data found in document. Please check the file.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            }
          }
        } on TimeoutException catch (e) {
          print('DEBUG: TimeoutException: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⏱️ Connection timeout: ${e.message}\n\nMake sure the backend is running:\npython /Users/tanishullas/Desktop/Finora/backend/api.py'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 8),
              ),
            );
          }
        } catch (e) {
          print('DEBUG: Error extracting file: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Error: $e\n\nEnsure backend is running on http://localhost:5001'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _extracting = false);
          }
        }
      }
    } catch (e) {
      print('DEBUG: Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  bool _isValidIncomeData(Map<String, dynamic> data) {
    final hasAny = (data['taxableSalary'] ?? 0) > 0 ||
        (data['grossSalary'] ?? 0) > 0 ||
        (data['otherIncome'] ?? 0) > 0 ||
        (data['rentalIncome'] ?? 0) > 0 ||
        (data['businessIncome'] ?? 0) > 0;
    return hasAny;
  }

  void _showExtractionSummary(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('✅ Data Extracted'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data['grossSalary'] != null && data['grossSalary'] > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Gross Salary: ${_currencyFormatter.format(data['grossSalary'])}'),
                ),
              if (data['taxableSalary'] != null && data['taxableSalary'] > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Taxable Salary: ${_currencyFormatter.format(data['taxableSalary'])}'),
                ),
              if (data['otherIncome'] != null && data['otherIncome'] > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Other Income: ${_currencyFormatter.format(data['otherIncome'])}'),
                ),
              if (data['rentalIncome'] != null && data['rentalIncome'] > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Rental Income: ${_currencyFormatter.format(data['rentalIncome'])}'),
                ),
              if (data['businessIncome'] != null && data['businessIncome'] > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Business Income: ${_currencyFormatter.format(data['businessIncome'])}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Edit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Income data extracted successfully')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final taxableSalary = double.tryParse(taxableSalaryCtrl.text) ?? 0;
    final other = double.tryParse(otherCtrl.text) ?? 0;
    final rent = double.tryParse(rentCtrl.text) ?? 0;
    final business = double.tryParse(businessCtrl.text) ?? 0;

    // Validate no negative values
    if (taxableSalary < 0 || other < 0 || rent < 0 || business < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Income values cannot be negative'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    if (taxableSalary + other + rent + business == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please enter at least one income source'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Wrap with timeout
      await _firebaseService.saveIncome(
        taxableSalary: taxableSalary,
        grossSalary: double.tryParse(grossSalaryCtrl.text) ?? 0,
        otherIncome: other,
        rentalIncome: rent,
        businessIncome: business,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Save operation timed out. Please check your internet connection.');
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Income details saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏱️ ${e.message}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving income: $e'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Income Details", style: TextStyle(color: AppColors.widgetBackground, fontSize: 27)),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Income Details", style: TextStyle(color: AppColors.widgetBackground, fontSize: 27)),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryVeryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Fill: Upload TDS Certificate',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: (_extracting || _saving) ? null : _pickAndExtractFile,
                        icon: _extracting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(
                          _extracting ? 'Processing...' : 'Upload PDF/Image',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.widgetBackground,
                        ),
                      ),
                      if (_selectedFileName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'File: $_selectedFileName',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _field("Taxable Salary (₹) *", taxableSalaryCtrl),
                        _field("Gross Salary (₹)", grossSalaryCtrl),
                        _field("Other Income (₹)", otherCtrl),
                        _field("Rental Income (₹)", rentCtrl),
                        _field("Business / Professional Income (₹)", businessCtrl),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (_saving || _extracting) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text("Save"),
                    ),
                  ),
                )
              ],
            ),
          ),
          // Loading Overlay
          if (_saving || _extracting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.widgetBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _extracting ? 'Extracting data...' : 'Saving income details...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}