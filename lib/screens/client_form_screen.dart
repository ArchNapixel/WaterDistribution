import 'package:flutter/material.dart';

import '../main.dart';
import '../models/client.dart';

class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _barangay = TextEditingController();
  final _meterNumber = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final client = Client(
      id: '',
      name: _name.text.trim(),
      contactNumber: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      barangay: _barangay.text.trim().isEmpty ? null : _barangay.text.trim(),
      latitude: double.tryParse(_latitude.text.trim()),
      longitude: double.tryParse(_longitude.text.trim()),
      meterNumber: _meterNumber.text.trim().isEmpty ? null : _meterNumber.text.trim(),
      connectionDate: DateTime.now(),
      status: 'active',
    );
    try {
      final inserted =
          await supabase.from('clients').insert(client.toInsertMap()).select().single();
      if (mounted) Navigator.of(context).pop(inserted['id'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Client')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _contact,
              decoration: const InputDecoration(labelText: 'Contact number'),
              keyboardType: TextInputType.phone,
            ),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            TextFormField(
              controller: _barangay,
              decoration: const InputDecoration(labelText: 'Barangay'),
            ),
            TextFormField(
              controller: _meterNumber,
              decoration: const InputDecoration(labelText: 'Meter number'),
            ),
            const SizedBox(height: 8),
            const Text('Coordinates (optional, needed to show on the map)',
                style: TextStyle(color: Colors.grey)),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitude,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitude,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save client'),
            ),
          ],
        ),
      ),
    );
  }
}
