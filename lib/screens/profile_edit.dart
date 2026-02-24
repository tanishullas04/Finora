import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _loading = true;
  String _error = '';

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  // dob, pan, aadhar removed per request
  // address removed per request
  final TextEditingController _filingStatusController = TextEditingController();
  final TextEditingController _residentialStatusController = TextEditingController();
  final TextEditingController _taxRegimeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      if (_firebaseService.currentUserId == null) {
        throw Exception('No user logged in');
      }

      final data = await _firebaseService.getUserProfile(_firebaseService.currentUserId!);
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _filingStatusController.text = data['filingStatus'] ?? '';
        _residentialStatusController.text = data['residentialStatus'] ?? '';
        _taxRegimeController.text = data['taxRegime'] ?? '';
      }
    } catch (e) {
      _error = 'Failed to load profile: $e';
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_firebaseService.currentUserId == null) {
        throw Exception('No user logged in');
      }

      Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'filingStatus': _filingStatusController.text.trim(),
        'residentialStatus': _residentialStatusController.text.trim(),
        'taxRegime': _taxRegimeController.text.trim(),
      };

      await _firebaseService.updateUserProfile(
          userId: _firebaseService.currentUserId!, data: updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),)
      ;
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Name required'
                              : null,
                        ),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Email required'
                              : null,
                        ),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                        TextFormField(
                          controller: _filingStatusController,
                          decoration: const InputDecoration(
                              labelText: 'Filing Status'),
                        ),
                        TextFormField(
                          controller: _residentialStatusController,
                          decoration: const InputDecoration(
                              labelText: 'Residential Status'),
                        ),
                        TextFormField(
                          controller: _taxRegimeController,
                          decoration: const InputDecoration(
                              labelText: 'Tax Regime Preference'),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _saveProfile,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}