import 'package:flutter/material.dart';

class DriverIdDialog extends StatefulWidget {
  const DriverIdDialog({Key? key}) : super(key: key);

  @override
  _DriverIdDialogState createState() => _DriverIdDialogState();
}

class _DriverIdDialogState extends State<DriverIdDialog> {
  final _formKey = GlobalKey<FormState>();
  final _driverIdController = TextEditingController();

  @override
  void dispose() {
    _driverIdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_driverIdController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Driver ID'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _driverIdController,
          decoration: const InputDecoration(
            labelText: 'Driver ID',
            hintText: 'Enter your driver ID',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your driver ID';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
