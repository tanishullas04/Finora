import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _hasUnsavedChanges = false;
  String _error = '';
  DateTime? _lastUpdated;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _panController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _selectedDob;

  String? _filingStatus;
  String? _residentialStatus;
  String? _taxRegime;
  String? _gender;

  static const _filingStatusOptions = ['Individual', 'HUF', 'Firm', 'Company', 'AOP/BOI'];
  static const _residentialStatusOptions = ['Resident', 'Non-Resident (NRI)', 'RNOR'];
  static const _taxRegimeOptions = ['New Regime (Default)', 'Old Regime'];
  static const _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

  // KEY FIX 1: DropdownButtonFormField crashes with "Missing values for keyframe"
  // when value is non-null but not present in its items list.
  // This returns null if the stored value isn't a valid option.
  static String? _safeDropdown(String? stored, List<String> options) {
    if (stored == null || stored.isEmpty) return null;
    return options.contains(stored) ? stored : null;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    for (final ctrl in [_nameController, _emailController, _phoneController, _panController, _dobController]) {
      ctrl.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _panController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      if (_firebaseService.currentUserId == null) throw Exception('No user logged in');
      final data = await _firebaseService.getUserProfile(_firebaseService.currentUserId!);
      if (data != null) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _panController.text = data['pan'] ?? '';
          _filingStatus = _safeDropdown(data['filingStatus'], _filingStatusOptions);
          _residentialStatus = _safeDropdown(data['residentialStatus'], _residentialStatusOptions);
          _taxRegime = _safeDropdown(data['taxRegime'], _taxRegimeOptions);
          _gender = _safeDropdown(data['gender'], _genderOptions);
          if (data['dob'] != null && data['dob'].toString().isNotEmpty) {
            _dobController.text = data['dob'];
            try { _selectedDob = DateTime.parse(data['dob']); } catch (_) {}
          }
          if (data['lastUpdated'] != null) {
            try { _lastUpdated = DateTime.parse(data['lastUpdated']); } catch (_) {}
          }
          _loading = false;
          _hasUnsavedChanges = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load profile: $e';
        _loading = false;
      });
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 30),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 1, 12, 31),
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        _hasUnsavedChanges = true;
      });
    }
  }

  // KEY FIX 2: Manual back button instead of PopScope/WillPopScope
  // avoids all framework-level animation/keyframe conflicts
  Future<void> _confirmLeave() async {
    if (!_hasUnsavedChanges) { Navigator.of(context).pop(); return; }
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Leave without saving?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_firebaseService.currentUserId == null) throw Exception('No user logged in');
      final updateData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'pan': _panController.text.trim().toUpperCase(),
        'dob': _dobController.text.trim(),
        'gender': _gender ?? '',
        'filingStatus': _filingStatus ?? '',
        'residentialStatus': _residentialStatus ?? '',
        'taxRegime': _taxRegime ?? '',
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await _firebaseService.updateUserProfile(
          userId: _firebaseService.currentUserId!, data: updateData);
      setState(() { _hasUnsavedChanges = false; _lastUpdated = DateTime.now(); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: AppColors.primary),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validatePan(String? v) {
    if (v == null || v.isEmpty) return null;
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v.trim().toUpperCase())) return 'Invalid PAN (e.g. ABCDE1234F)';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.isEmpty) return null;
    if (v.replaceAll(RegExp(r'\D'), '').length != 10) return 'Enter a valid 10-digit number';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email required';
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  String get _initials {
    final name = _nameController.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary, letterSpacing: 0.5)),
  );

  Widget _textField(String label, TextEditingController ctrl, {
    TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator, bool readOnly = false,
    VoidCallback? onTap, String? hint, Widget? suffixIcon, int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl, keyboardType: keyboardType, inputFormatters: inputFormatters,
      validator: validator, readOnly: readOnly, onTap: onTap, maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: suffixIcon, counterText: '',
      ),
    ),
  );

  Widget _dropdown({required String label, required String? value, required List<String> options, required void Function(String?) onChanged}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (v) { onChanged(v); setState(() => _hasUnsavedChanges = true); },
      ),
    );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _confirmLeave),
        title: const Text('Edit Profile', style: TextStyle(color: AppColors.widgetBackground, fontSize: 22)),
        actions: [
          if (_hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _saving ? null : _saveProfile,
                child: const Text('Save', style: TextStyle(color: AppColors.widgetBackground, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error.isNotEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
            ]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Column(children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        child: Text(_initials, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      if (_lastUpdated != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Last updated: ${_formatDate(_lastUpdated!)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ),
                    ])),
                    _sectionHeader('PERSONAL INFORMATION'),
                    _textField('Full Name', _nameController,
                        validator: (v) => (v == null || v.isEmpty) ? 'Name required' : null),
                    _dropdown(label: 'Gender', value: _gender, options: _genderOptions,
                        onChanged: (v) => setState(() => _gender = v)),
                    _textField('Date of Birth', _dobController, readOnly: true, onTap: _pickDob,
                        hint: 'YYYY-MM-DD', suffixIcon: const Icon(Icons.calendar_today, size: 18)),
                    _sectionHeader('CONTACT'),
                    _textField('Email', _emailController,
                        keyboardType: TextInputType.emailAddress, validator: _validateEmail),
                    _textField('Mobile Number', _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 10, validator: _validatePhone),
                    _sectionHeader('TAX INFORMATION'),
                    _textField('PAN', _panController, hint: 'ABCDE1234F',
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          UpperCaseTextFormatter(),
                        ],
                        maxLength: 10, validator: _validatePan),
                    _dropdown(label: 'Filing Status', value: _filingStatus, options: _filingStatusOptions,
                        onChanged: (v) => setState(() => _filingStatus = v)),
                    _dropdown(label: 'Residential Status', value: _residentialStatus, options: _residentialStatusOptions,
                        onChanged: (v) => setState(() => _residentialStatus = v)),
                    _dropdown(label: 'Tax Regime Preference', value: _taxRegime, options: _taxRegimeOptions,
                        onChanged: (v) => setState(() => _taxRegime = v)),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _saving
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white)))
                          : const Text('Save Profile',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}