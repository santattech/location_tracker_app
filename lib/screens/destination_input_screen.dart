import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/destination.dart';

class DestinationInputScreen extends StatefulWidget {
  const DestinationInputScreen({Key? key}) : super(key: key);

  @override
  _DestinationInputScreenState createState() => _DestinationInputScreenState();
}

class _DestinationInputScreenState extends State<DestinationInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentDestination();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentDestination() async {
    final box = await Hive.openBox<Destination>('destinationBox');
    final destination = box.get('current');
    if (destination != null) {
      setState(() {
        _latController.text = destination.destLatitude.toString();
        _lngController.text = destination.destLongitude.toString();
      });
    }
  }

  Future<void> _saveDestination() async {
    if (_formKey.currentState!.validate()) {
      final box = await Hive.openBox<Destination>('destinationBox');
      final destination = Destination(
        destLatitude: double.parse(_latController.text),
        destLongitude: double.parse(_lngController.text),
      );
      
      await box.put('current', destination);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Destination saved successfully!')),
        );
        Navigator.pop(context);
      }
    }
  }

  String? _validateCoordinate(String? value, bool isLatitude) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    try {
      final double coord = double.parse(value);
      if (isLatitude && (coord < -90 || coord > 90)) {
        return 'Latitude must be between -90 and 90';
      }
      if (!isLatitude && (coord < -180 || coord > 180)) {
        return 'Longitude must be between -180 and 180';
      }
    } catch (e) {
      return 'Please enter a valid number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Destination'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'Enter latitude (e.g., 22.5731795)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => _validateCoordinate(value, true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lngController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'Enter longitude (e.g., 88.1795762)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => _validateCoordinate(value, false),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveDestination,
                child: const Text('Save Destination'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 