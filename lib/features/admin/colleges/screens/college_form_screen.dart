import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/college.dart';
import '../services/college_service.dart';
import 'package:uuid/uuid.dart';

class CollegeFormScreen extends StatefulWidget {
  final College? college;
  const CollegeFormScreen({Key? key, this.college}) : super(key: key);

  @override
  State<CollegeFormScreen> createState() => _CollegeFormScreenState();
}

class _CollegeFormScreenState extends State<CollegeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _codeController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  bool _loading = false;
  String? _error;
  Uint8List? _logoBytes;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    if (widget.college != null) {
      _nameController.text = widget.college!.name;
      _addressController.text = widget.college!.address;
      _codeController.text = widget.college!.code;
      _contactPhoneController.text = widget.college!.contactPhone ?? '';
      _contactEmailController.text = widget.college!.contactEmail ?? '';
      _logoUrl = widget.college!.logoUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _codeController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _logoBytes = bytes;
          _logoUrl = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final collegeService = Provider.of<CollegeService>(context, listen: false);

    try {
      String? finalLogoUrl = _logoUrl;
      if (_logoBytes != null) {
        final String collegeIdForLogo = widget.college?.id ?? const Uuid().v4();

        finalLogoUrl = await collegeService.uploadLogo(
          collegeIdForLogo,
          _logoBytes!,
        );
      }

      final now = DateTime.now();
      final Map<String, dynamic> collegeData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'code': _codeController.text.trim(),
        'contact_phone': _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
        'contact_email': _contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim(),
        'logo_url': finalLogoUrl,
        'is_active': widget.college?.isActive ?? true,
        'created_at': widget.college?.createdAt.toIso8601String() ?? now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      if (widget.college != null) {
        collegeData['id'] = widget.college!.id;
        final updatedCollege = College.fromJson(collegeData);
        await collegeService.updateCollege(updatedCollege);
      } else {
        await collegeService.addCollege(collegeData);
      }

      Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = 'Failed to save college: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.college != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit College' : 'Add College'),
        actions: [
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo Section
              Center(
                child: Column(
                  children: [
                    if (_logoUrl != null || _logoBytes != null)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: _logoBytes != null
                                ? MemoryImage(_logoBytes!)
                                : NetworkImage(_logoUrl!) as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                        ),
                        child: const Icon(Icons.school, size: 48, color: Colors.grey),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _pickLogo,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Upload Logo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Form Fields
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'College Name',
                  prefixIcon: Icon(Icons.school),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter college name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter address' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  prefixIcon: Icon(Icons.code),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter code' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactEmailController,
                decoration: const InputDecoration(
                  labelText: 'Contact Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: _loading ? null : _onSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEdit ? 'Update College' : 'Add College'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 