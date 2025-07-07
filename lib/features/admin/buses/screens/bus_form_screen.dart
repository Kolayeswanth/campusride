import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/bus_service.dart';
import '../models/bus.dart';

class BusFormScreen extends StatefulWidget {
  final String collegeId;
  final Bus? bus;

  const BusFormScreen({
    Key? key,
    required this.collegeId,
    this.bus,
  }) : super(key: key);

  @override
  State<BusFormScreen> createState() => _BusFormScreenState();
}

class _BusFormScreenState extends State<BusFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleIdController = TextEditingController();
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.bus != null) {
      _vehicleIdController.text = widget.bus!.vehicleId;
    }
  }

  @override
  void dispose() {
    _vehicleIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final busService = context.read<BusService>();
      String? photoUrl;

      if (_imageBytes != null) {
        photoUrl = await busService.uploadBusPhoto(
          widget.bus?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          _imageBytes!,
        );
      }

      final bus = Bus(
        id: widget.bus?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        vehicleId: _vehicleIdController.text,
        collegeId: widget.collegeId,
        photoUrl: photoUrl,
        isActive: widget.bus?.isActive ?? true,
        createdAt: widget.bus?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.bus == null) {
        await busService.addBus(bus);
      } else {
        await busService.updateBus(bus);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save bus: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bus == null ? 'Add Bus' : 'Edit Bus'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            TextFormField(
              controller: _vehicleIdController,
              decoration: const InputDecoration(
                labelText: 'Vehicle ID',
                hintText: 'Enter vehicle ID',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter vehicle ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickImage,
              icon: const Icon(Icons.photo),
              label: const Text('Pick Photo'),
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _imageBytes!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(widget.bus == null ? 'Add Bus' : 'Update Bus'),
            ),
          ],
        ),
      ),
    );
  }
} 